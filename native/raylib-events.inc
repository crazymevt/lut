/* LUT event bridge, MIT, 2026. Included in raylib's desktop GLFW backend.
 * GLFW owns the platform implementation (Cocoa, Win32, X11/Wayland).
 * Only LUTWakeEvents may be called off the native UI thread. */
#if defined(_WIN32)
#include <windows.h>
static volatile LONG lutWakePending = 0;
#define LUT_WAKE_EXCHANGE(v) InterlockedExchange(&lutWakePending, (v))
#else
#include <stdatomic.h>
static atomic_int lutWakePending;
#define LUT_WAKE_EXCHANGE(v) atomic_exchange(&lutWakePending, (v))
#endif
/* Gate native wake lifetime against UI-thread teardown. No Lisp callback is
   entered from CEF/worker threads, and no GLFW calls occur after deactivation. */
#if defined(_WIN32)
static volatile LONG lutWakeGate = 0;
static void LUTLockWake(void) { while (InterlockedCompareExchange(&lutWakeGate, 1, 0)) Sleep(0); }
static void LUTUnlockWake(void) { InterlockedExchange(&lutWakeGate, 0); }
#else
static atomic_flag lutWakeGate = ATOMIC_FLAG_INIT;
static void LUTLockWake(void) { while (atomic_flag_test_and_set(&lutWakeGate)) { } }
static void LUTUnlockWake(void) { atomic_flag_clear(&lutWakeGate); }
#endif
static bool lutNativeActive = false;
static double lutWaitTimeout = 0.0;
static bool lutDamage = true;
static GLFWwindowrefreshfun lutPreviousRefresh = NULL;
extern bool lutManualEvents;
static void LUTRefreshWindow(GLFWwindow *window)
{
    lutDamage = true;
    if (lutPreviousRefresh) lutPreviousRefresh(window);
}
RLAPI int LUTEventBridgeVersion(void) { return 1; }
RLAPI void LUTSetManualEvents(int enabled)
{
    if (enabled && !lutManualEvents)
    {
        lutPreviousRefresh = glfwSetWindowRefreshCallback(platform.handle, LUTRefreshWindow);
        lutDamage = true;
    }
    else if (!enabled && lutManualEvents)
        glfwSetWindowRefreshCallback(platform.handle, lutPreviousRefresh);
    LUTLockWake();
    lutManualEvents = enabled != 0;
    lutNativeActive = enabled != 0;
    LUTUnlockWake();
}
RLAPI void LUTWakeEvents(void)
{
    /* Publication precedes the persistent native event. The pending latch covers
       wakes before the queue/deadline check as well as before entering wait. */
    LUTLockWake();
    if (lutNativeActive) { LUT_WAKE_EXCHANGE(1); glfwPostEmptyEvent(); }
    LUTUnlockWake();
}
RLAPI void LUTWaitEvents(double seconds)
{
    lutWaitTimeout = seconds;
    PollInputEvents(); /* resets previous input state BEFORE waiting/callbacks */
    lutWaitTimeout = 0.0;
}
RLAPI int LUTConsumeDamage(void)
{
    int damage = lutDamage;
    lutDamage = false;
    return damage;
}
static void LUTDispatchEvents(void)
{
    if (LUT_WAKE_EXCHANGE(0) || lutWaitTimeout == 0.0) glfwPollEvents();
    else if (lutWaitTimeout < 0.0) glfwWaitEvents();
    else glfwWaitEventsTimeout(lutWaitTimeout);
}
