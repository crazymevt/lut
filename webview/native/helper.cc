#include "include/cef_app.h"
#ifdef __APPLE__
#include "include/wrapper/cef_library_loader.h"
#endif
#ifdef _WIN32
#include <windows.h>
int APIENTRY wWinMain(HINSTANCE instance,HINSTANCE, wchar_t*,int) {
  CefMainArgs args(instance);
#else
int main(int argc,char** argv) {
#ifdef __APPLE__
  CefScopedLibraryLoader loader;
  if(!loader.LoadInHelper()) return 1;
#endif
  CefMainArgs args(argc,argv);
#endif
  return CefExecuteProcess(args,nullptr,nullptr);
}
