#import <Cocoa/Cocoa.h>
#include "include/cef_application_mac.h"
// Must be installed before GLFW/raylib creates NSApplication.
@interface LUTCEFApplication : NSApplication <CefAppProtocol> {
  BOOL handlingSendEvent_;
}
@end
@implementation LUTCEFApplication
- (BOOL)isHandlingSendEvent { return handlingSendEvent_; }
- (void)setHandlingSendEvent:(BOOL)value { handlingSendEvent_=value; }
- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent scope;
  [super sendEvent:event];
}
@end
bool lut_cef_prepare_cocoa() {
  [LUTCEFApplication sharedApplication];
  return [NSApp isKindOfClass:[LUTCEFApplication class]];
}
