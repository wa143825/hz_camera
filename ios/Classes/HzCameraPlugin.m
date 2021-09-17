#import "HzCameraPlugin.h"
#if __has_include(<hz_camera/hz_camera-Swift.h>)
#import <hz_camera/hz_camera-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "hz_camera-Swift.h"
#endif

@implementation HzCameraPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHzCameraPlugin registerWithRegistrar:registrar];
}
@end
