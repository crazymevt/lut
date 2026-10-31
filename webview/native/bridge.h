#pragma once
#include <stdint.h>
#ifdef _WIN32
#define LUT_CEF_API __declspec(dllexport)
#else
#define LUT_CEF_API __attribute__((visibility("default")))
#endif
#ifdef __cplusplus
extern "C" {
#endif
/* All calls, including frame access, must occur on the initializing UI thread.
   Strings and frame pointers are borrowed until the next bridge call/pump. */
LUT_CEF_API int lut_cef_init(const char* runtime, const char* helper);
LUT_CEF_API void lut_cef_pump(void);
LUT_CEF_API int lut_cef_shutdown(void);
LUT_CEF_API void* lut_cef_create(const char* url, int width, int height, double scale);
LUT_CEF_API void lut_cef_close(void* view);
LUT_CEF_API int lut_cef_closed(void* view);
LUT_CEF_API void lut_cef_release(void* view);
LUT_CEF_API void lut_cef_resize(void* view, int width, int height, double scale);
LUT_CEF_API void lut_cef_state(void* view, int focus, int hidden);
LUT_CEF_API void lut_cef_navigate(void* view, const char* url);
/* Opt-in local-page messaging. Enabling locks top-level navigation to URL.
   Messages are JSON strings from a page-owned console bridge; max 1 MiB each. */
LUT_CEF_API void lut_cef_messages(void* view, const char* trusted_url);
LUT_CEF_API int lut_cef_execute(void* view, const char* script);
LUT_CEF_API const char* lut_cef_message(void* view);
LUT_CEF_API void lut_cef_command(void* view, int command);
LUT_CEF_API void lut_cef_mouse(void* view, int kind, int x, int y, int modifiers, int delta);
LUT_CEF_API void lut_cef_key(void* view, int key, int modifiers);
LUT_CEF_API void lut_cef_text(void* view, const char* utf8);
LUT_CEF_API const void* lut_cef_frame(void* view, int* width, int* height, uint64_t* revision);
LUT_CEF_API const char* lut_cef_title(void* view);
LUT_CEF_API const char* lut_cef_url(void* view);
LUT_CEF_API int lut_cef_loading(void* view);
LUT_CEF_API const char* lut_cef_error(void* view);
#ifdef __cplusplus
}
#endif
