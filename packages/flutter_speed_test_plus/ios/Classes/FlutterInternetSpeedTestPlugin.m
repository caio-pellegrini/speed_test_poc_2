#import "FlutterInternetSpeedTestPlugin.h"
#if __has_include(<flutter_speed_test_plus/flutter_speed_test_plus-Swift.h>)
#import <flutter_speed_test_plus/flutter_speed_test_plus-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_internet_speed_test-Swift.h"
#endif

@implementation FlutterInternetSpeedTestPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftInternetSpeedTestPlugin registerWithRegistrar:registrar];
}
@end
