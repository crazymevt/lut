#include "bridge.h"
#include "include/cef_app.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_context_menu_handler.h"
#include "include/cef_render_handler.h"
#include "include/cef_parser.h"
#include "include/wrapper/cef_helpers.h"
#include <atomic>
#include <limits>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include "include/cef_command_line.h"
#include <string>
#include <vector>
#include <deque>
#include <filesystem>
#include <chrono>
#include "include/cef_request_handler.h"
#ifndef _WIN32
#include <signal.h>
#include <unistd.h>
#endif
#ifdef __APPLE__
#include "include/wrapper/cef_library_loader.h"
extern bool lut_cef_prepare_cocoa();
#endif
namespace {
std::atomic<int64_t> pump_deadline{std::numeric_limits<int64_t>::max()};
std::atomic<uint64_t> pump_schedules{0}, pump_calls{0}, pump_fallbacks{0};
int64_t pump_last = 0;
// CEF's reference external pump retains a 30 Hz maximum servicing interval.
// Restrict that compatibility deadline to live clients, independently of paint.
constexpr int64_t pump_client_interval = 33;
using WakeFunction = void (*)();
std::atomic<WakeFunction> pump_wake{nullptr};
int64_t pump_now() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
    std::chrono::steady_clock::now().time_since_epoch()).count();
}
class BridgeApp final : public CefApp, public CefBrowserProcessHandler {
 public:
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }
  void OnScheduleMessagePumpWork(int64_t delay_ms) override {
    ++pump_schedules;
    const auto now = pump_now();
    const auto deadline = now + std::max<int64_t>(0, std::min<int64_t>(delay_ms, std::numeric_limits<int64_t>::max() - now - 1));
    const auto previous = pump_deadline.exchange(deadline);
    if (deadline < previous) { if (auto wake = pump_wake.load()) wake(); }
  }
  void OnBeforeCommandLineProcessing(const CefString&, CefRefPtr<CefCommandLine> command) override {
    if(std::getenv("LUT_CEF_DISABLE_GPU")) command->AppendSwitch("disable-gpu");
  }
  IMPLEMENT_REFCOUNTING(BridgeApp);
};
bool initialized = false;
std::filesystem::path profile;
int live = 0;
class View final : public CefClient, public CefRenderHandler,
                   public CefLifeSpanHandler, public CefDisplayHandler,
                   public CefLoadHandler, public CefContextMenuHandler, public CefRequestHandler {
 public:
  int width, height; double scale; bool focus=false, hidden=false; bool closed = false, closing = false, loading = true;
  uint64_t revision = 0;
  // Bounded spatial history: latest changed revision per 128px block. A slow
  // consumer sees every block changed since its last successful upload.
  std::vector<uint64_t> damage;
  std::vector<unsigned char> patch;
  static constexpr int damage_size = 128;
  std::string title, url, error, trusted_url, last_message;
  std::deque<std::string> messages;
  std::vector<unsigned char> pixels;
  int pixel_width = 0, pixel_height = 0;
  CefRefPtr<CefBrowser> browser;
  View(int w, int h, double s) : width(w), height(h), scale(s) { ++live; }
  ~View() override { --live; }
  CefRefPtr<CefRenderHandler> GetRenderHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }
  bool OnBeforeBrowse(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame>,
                      CefRefPtr<CefRequest> request, bool, bool) override {
    // A privileged local shell never becomes an arbitrary web browser.
    return !trusted_url.empty() && request->GetURL().ToString() != trusted_url;
  }
  bool OnConsoleMessage(CefRefPtr<CefBrowser> b, cef_log_severity_t,
                        const CefString& message, const CefString& source, int) override {
    const std::string prefix="LUT_LOCAL_MESSAGE:";
    auto text=message.ToString();
    if(trusted_url.empty() || b->GetMainFrame()->GetURL().ToString()!=trusted_url ||
       source.ToString()!=trusted_url || text.compare(0,prefix.size(),prefix)!=0) return false;
    if(text.size()>1048576 || messages.size()>=128) {
      error="Local page message limit exceeded"; return true;
    }
    messages.push_back(text.substr(prefix.size())); return true;
  }
  void GetViewRect(CefRefPtr<CefBrowser>, CefRect& r) override { r = CefRect(0, 0, width, height); }
  bool GetScreenInfo(CefRefPtr<CefBrowser>, CefScreenInfo& info) override {
    info.device_scale_factor=scale;
    info.rect=info.available_rect=CefRect(0,0,width,height);
    return true;
  }
  void OnPaint(CefRefPtr<CefBrowser>, PaintElementType type, const RectList& dirty,
               const void* data, int w, int h) override {
    // Popup surfaces need separate composition; disabled in this first prototype.
    if (type != PET_VIEW || closing) return;
    if (w <= 0 || h <= 0 || w > 8192 || h > 8192) return;
    bool resized = pixel_width != w || pixel_height != h;
    if (resized) { pixels.resize(size_t(w)*h*4); pixel_width=w; pixel_height=h; }
    const int columns=(w+damage_size-1)/damage_size;
    if(resized) damage.assign(size_t(columns)*((h+damage_size-1)/damage_size), revision+1);
    bool changed = resized;
    auto copy = [&](int x, int y, int rw, int rh) {
      auto src = static_cast<const unsigned char*>(data);
      for (int row=y; row<y+rh; ++row) for (int col=x; col<x+rw; ++col) {
        size_t i=(size_t(row)*w+col)*4;
        if(pixels[i]!=src[i+2] || pixels[i+1]!=src[i+1] || pixels[i+2]!=src[i] || pixels[i+3]!=src[i+3]) {
          pixels[i]=src[i+2]; pixels[i+1]=src[i+1]; pixels[i+2]=src[i]; pixels[i+3]=src[i+3];
          damage[size_t(row/damage_size)*columns+col/damage_size]=revision+1;
          changed=true;
        }
      }
    };
    if (resized) copy(0,0,w,h);
    else for (const auto& r : dirty) {
      int x=std::clamp(r.x,0,w), y=std::clamp(r.y,0,h);
      copy(x,y,std::max(0,std::min(w,r.x+r.width)-x),std::max(0,std::min(h,r.y+r.height)-y));
    }
    if(changed) ++revision;
  }
  void OnAfterCreated(CefRefPtr<CefBrowser> b) override {
    browser=b; browser->GetHost()->SetFocus(focus); browser->GetHost()->WasHidden(hidden); if (closing) browser->GetHost()->CloseBrowser(true);
  }
  void OnBeforeClose(CefRefPtr<CefBrowser>) override { browser=nullptr; closed=true; }
  bool OnBeforePopup(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame>, int,
    const CefString&, const CefString&, CefLifeSpanHandler::WindowOpenDisposition, bool,
    const CefPopupFeatures&, CefWindowInfo&, CefRefPtr<CefClient>&,
    CefBrowserSettings&, CefRefPtr<CefDictionaryValue>&, bool*) override { return true; }
  void OnBeforeContextMenu(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame>,
    CefRefPtr<CefContextMenuParams>, CefRefPtr<CefMenuModel> model) override { model->Clear(); }
  void OnTitleChange(CefRefPtr<CefBrowser>, const CefString& s) override { title=s.ToString(); }
  void OnAddressChange(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> f, const CefString& s) override {
    if (f->IsMain()) url=s.ToString();
  }
  void OnLoadingStateChange(CefRefPtr<CefBrowser>, bool value, bool, bool) override { loading=value; }
  void OnLoadStart(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> f, TransitionType) override {
    if (f->IsMain()) error.clear();
  }
  void OnLoadError(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> f, ErrorCode code,
                   const CefString& text, const CefString&) override {
    if (f->IsMain() && code != ERR_ABORTED) error=text.ToString();
  }
  IMPLEMENT_REFCOUNTING(View);
};
View* view(void* p) { return static_cast<View*>(p); }
CefRefPtr<CefBrowser> browser(void* p) { return view(p)->browser; }
}
int lut_cef_init(const char* runtime, const char* helper) {
  if (initialized) return 0;
#ifdef __APPLE__
  std::string framework=std::string(runtime)+"/Chromium Embedded Framework.framework/Chromium Embedded Framework";
  if (!cef_load_library(framework.c_str()) || !lut_cef_prepare_cocoa()) return 0;
  CefMainArgs args(0,nullptr);
#elif defined(_WIN32)
  CefMainArgs args(GetModuleHandle(nullptr));
#else
  char name[]="lut-webview"; char* argv[]={name,nullptr}; CefMainArgs args(1,argv);
#endif
  CefSettings settings;
  settings.no_sandbox=true; // Explicit development-only build, see README.
  settings.windowless_rendering_enabled=true;
  settings.external_message_pump=true;
  // Ephemeral per-host profile: independent editor processes do not share
  // Chromium's SingletonLock or need write access to the installed runtime.
  std::error_code profile_error;
  auto temporary=std::filesystem::temp_directory_path(profile_error);
  if(profile_error) return 0;
#ifdef _WIN32
  auto process_id=GetCurrentProcessId();
#else
  auto process_id=getpid();
#endif
  profile=temporary/("lut-cef-"+std::to_string(process_id)+"-"+
    std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
  std::filesystem::create_directory(profile,profile_error);
  if(profile_error) return 0;
  auto profile_utf8=profile.u8string();
  CefString(&settings.root_cache_path)=std::string(profile_utf8.begin(),profile_utf8.end());
  CefString(&settings.browser_subprocess_path)=helper;
#ifndef __APPLE__
  CefString(&settings.resources_dir_path)=runtime;
  CefString(&settings.locales_dir_path)=std::string(runtime)+"/locales";
#else
  CefString(&settings.framework_dir_path)=std::string(runtime)+"/Chromium Embedded Framework.framework";
  std::string helper_path(helper);
  CefString(&settings.main_bundle_path)=helper_path.substr(0,helper_path.find("/Contents/MacOS/"));
#endif
#ifndef _WIN32
  // Chromium resets host signal dispositions during initialization. SBCL uses
  // synchronous traps for allocation/GC; preserve its handlers in the host.
  const int signals[]={SIGTRAP,SIGSEGV,SIGBUS,SIGILL,SIGFPE};
  struct sigaction previous[5];
  for(int i=0;i<5;++i) sigaction(signals[i],nullptr,&previous[i]);
#endif
  initialized=CefInitialize(args,settings,new BridgeApp,nullptr);
#ifndef _WIN32
  for(int i=0;i<5;++i) sigaction(signals[i],&previous[i],nullptr);
#endif
  if(!initialized) std::filesystem::remove_all(profile,profile_error);
  return initialized;
}
void lut_cef_pump() {
  if(initialized) {
    auto deadline = pump_deadline.load();
    if (deadline <= pump_now()) pump_deadline.compare_exchange_strong(deadline, std::numeric_limits<int64_t>::max());
    if (live && pump_now() - pump_last >= pump_client_interval) ++pump_fallbacks;
    ++pump_calls;
    CefDoMessageLoopWork();
    pump_last = pump_now();
  }
}
uint64_t lut_cef_schedule_count() { return pump_schedules.load(); }
uint64_t lut_cef_pump_count() { return pump_calls.load(); }
uint64_t lut_cef_fallback_count() { return pump_fallbacks.load(); }
void lut_cef_set_wake(void (*wake)()) { pump_wake.store(wake); }
int64_t lut_cef_next_delay_ms() {
  const auto deadline = pump_deadline.load();
  int64_t delay = deadline == std::numeric_limits<int64_t>::max() ? -1 : std::max<int64_t>(0, deadline - pump_now());
  if (live) {
    const auto client_delay = std::max<int64_t>(0, pump_client_interval - (pump_now() - pump_last));
    delay = delay < 0 ? client_delay : std::min(delay, client_delay);
  }
  return delay;
}
int lut_cef_shutdown() {
  if(!initialized || live) return 0;
  CefShutdown(); initialized=false;
  std::error_code ignored; std::filesystem::remove_all(profile,ignored); return 1;
}
void* lut_cef_create(const char* url, int w, int h, double scale) {
  if(!initialized || w<1 || h<1 || scale<=0 || w*scale>8192 || h*scale>8192) return nullptr;
  CefRefPtr<View> v=new View(w,h,scale);
  CefWindowInfo info; info.SetAsWindowless(kNullWindowHandle);
  CefBrowserSettings settings; settings.windowless_frame_rate=30;
  settings.background_color=CefColorSetARGB(255,255,255,255);
  if(!CefBrowserHost::CreateBrowser(info,v,url,settings,nullptr,nullptr)) return nullptr;
  v->AddRef(); return v.get();
}
void lut_cef_close(void* p) { auto v=view(p); if(v->closing) return; v->closing=true; if(v->browser) v->browser->GetHost()->CloseBrowser(true); }
int lut_cef_closed(void* p) { return view(p)->closed; }
void lut_cef_release(void* p) { if(view(p)->closed) view(p)->Release(); }
void lut_cef_resize(void* p,int w,int h,double scale) {
  auto v=view(p); if(w<1 || h<1 || scale<=0 || w*scale>8192 || h*scale>8192 || (v->width==w && v->height==h && v->scale==scale)) return;
  v->width=w; v->height=h; v->scale=scale; if(v->browser) { v->browser->GetHost()->NotifyScreenInfoChanged(); v->browser->GetHost()->WasResized(); }
}
void lut_cef_state(void* p,int focus,int hidden) { view(p)->focus=focus;view(p)->hidden=hidden; if(auto b=browser(p)) { b->GetHost()->SetFocus(focus); b->GetHost()->WasHidden(hidden); } }
void lut_cef_navigate(void* p,const char* url) {
  auto v=view(p); CefURLParts parts;
  if(!v->trusted_url.empty() && (!CefParseURL(url,parts) ||
     v->trusted_url!=CefString(&parts.spec).ToString())) return;
  if(auto b=browser(p)) b->GetMainFrame()->LoadURL(url);
}
void lut_cef_messages(void* p,const char* url) {
  auto v=view(p); const std::string target=url?url:"";
  // Canonicalize spaces, Unicode and Windows paths exactly as Chromium does.
  // Privileges cannot be granted to network documents or changed after enable.
  CefURLParts parts;
  if(v->trusted_url.empty() && CefParseURL(target,parts) &&
     CefString(&parts.scheme).ToString()=="file" &&
     (CefString(&parts.host).empty() || CefString(&parts.host).ToString()=="localhost"))
    v->trusted_url=CefString(&parts.spec).ToString();
}
int lut_cef_execute(void* p,const char* script) {
  auto v=view(p); auto b=browser(p);
  if(!b || v->closing || v->trusted_url.empty() ||
     b->GetMainFrame()->GetURL().ToString()!=v->trusted_url || !script || std::strlen(script)>4194304) return 0;
  b->GetMainFrame()->ExecuteJavaScript(script,v->trusted_url,1); return 1;
}
const char* lut_cef_message(void* p) {
  auto v=view(p); if(v->messages.empty()) return nullptr;
  v->last_message=std::move(v->messages.front()); v->messages.pop_front(); return v->last_message.c_str();
}
void lut_cef_command(void* p,int cmd) { if(!view(p)->trusted_url.empty() && cmd<2) return; if(auto b=browser(p)) switch(cmd) { case 0:b->GoBack();break; case 1:b->GoForward();break; case 2:b->Reload();break; case 3:b->StopLoad();break; } }
void lut_cef_mouse(void* p,int kind,int x,int y,int modifiers,int delta) {
  if(auto b=browser(p)) { CefMouseEvent e; e.x=x;e.y=y;e.modifiers=modifiers;
    if(kind==0) b->GetHost()->SendMouseMoveEvent(e,false);
    if(kind==1 || kind==2) b->GetHost()->SendMouseClickEvent(e,MBT_LEFT,kind==2,1);
    if(kind==3) b->GetHost()->SendMouseWheelEvent(e,0,delta);
    if(kind==4) b->GetHost()->SendMouseMoveEvent(e,true);
  }
}
void lut_cef_key(void* p,int key,int modifiers) {
  if(auto b=browser(p)) {
#ifdef __APPLE__
    // OSR has no NSView responder chain to translate Command editing shortcuts.
    // Use Chromium's focused-frame actions, not injected text: Paste must retain
    // native clipboard formats and dispatch the page's trusted paste event.
    if ((modifiers & EVENTFLAG_COMMAND_DOWN) &&
        !(modifiers & (EVENTFLAG_CONTROL_DOWN | EVENTFLAG_ALT_DOWN))) {
      auto frame = b->GetFocusedFrame();
      if (frame) {
        const bool shift = (modifiers & EVENTFLAG_SHIFT_DOWN) != 0;
        if (!shift) {
          switch (key) {
            case 'V': frame->Paste(); return;
            case 'C': frame->Copy(); return;
            case 'X': frame->Cut(); return;
            case 'A': frame->SelectAll(); return;
          }
        }
        if (key == 'Z') {
          if (shift) frame->Redo(); else frame->Undo();
          return;
        }
      }
    }
#endif
    CefKeyEvent e; e.windows_key_code=key; e.modifiers=modifiers;
#ifdef __APPLE__
    switch(key) {
      case 8:e.native_key_code=51;e.character=0x7f;break;
      case 9:e.native_key_code=48;e.character=9;break;
      case 13:e.native_key_code=36;e.character=13;break;
      case 27:e.native_key_code=53;e.character=27;break;
      case 37:e.native_key_code=123;e.character=0xf702;break;
      case 38:e.native_key_code=126;e.character=0xf700;break;
      case 39:e.native_key_code=124;e.character=0xf703;break;
      case 40:e.native_key_code=125;e.character=0xf701;break;
      case 46:e.native_key_code=117;e.character=0xf728;break;
      case 36:e.native_key_code=115;e.character=0xf729;break;
      case 35:e.native_key_code=119;e.character=0xf72b;break;
      case 33:e.native_key_code=116;e.character=0xf72c;break;
      case 34:e.native_key_code=121;e.character=0xf72d;break;
      default:e.character=key;break;
    }
    e.unmodified_character=e.character;
#endif
    e.type=KEYEVENT_RAWKEYDOWN; b->GetHost()->SendKeyEvent(e);
    e.type=KEYEVENT_KEYUP; b->GetHost()->SendKeyEvent(e);
  }
}
void lut_cef_text(void* p,const char* text) {
  if(auto b=browser(p)) { CefString s(text); auto u=s.ToString16();
    for(auto ch:u) { CefKeyEvent e; e.type=KEYEVENT_CHAR;e.windows_key_code=ch;e.character=ch;e.unmodified_character=ch;b->GetHost()->SendKeyEvent(e); }
  }
}
// Packed RGBA patches, borrowed until the next bridge call. CURSOR is a
// block index, advanced past each returned block; no destructive acknowledgement.
const void* lut_cef_damage(void* p,uint64_t since,int* cursor,int* x,int* y,int* w,int* h) {
  auto v=view(p);
  const int size=View::damage_size, columns=(v->pixel_width+size-1)/size;
  while(*cursor>=0 && size_t(*cursor)<v->damage.size()) {
    int i=(*cursor)++;
    if(v->damage[i]<=since) continue;
    *x=(i%columns)*size; *y=(i/columns)*size;
    *w=std::min(size,v->pixel_width-*x); *h=std::min(size,v->pixel_height-*y);
    v->patch.resize(size_t(*w)*(*h)*4);
    for(int row=0;row<*h;++row)
      std::memcpy(v->patch.data()+size_t(row)*(*w)*4,
                  v->pixels.data()+(size_t(*y+row)*v->pixel_width+*x)*4,size_t(*w)*4);
    return v->patch.data();
  }
  return nullptr;
}
const void* lut_cef_frame(void* p,int* w,int* h,uint64_t* r) { auto v=view(p); *w=v->pixel_width;*h=v->pixel_height;*r=v->revision;return v->pixels.empty()?nullptr:v->pixels.data(); }
const char* lut_cef_title(void* p) { return view(p)->title.c_str(); }
const char* lut_cef_url(void* p) { return view(p)->url.c_str(); }
int lut_cef_loading(void* p) { return view(p)->loading; }
const char* lut_cef_error(void* p) { return view(p)->error.c_str(); }
