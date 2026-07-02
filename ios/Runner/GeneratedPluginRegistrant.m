//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<background_downloader/BackgroundDownloaderPlugin.h>)
#import <background_downloader/BackgroundDownloaderPlugin.h>
#else
@import background_downloader;
#endif

#if __has_include(<file_picker/FilePickerPlugin.h>)
#import <file_picker/FilePickerPlugin.h>
#else
@import file_picker;
#endif

#if __has_include(<flutter_gemma/FlutterGemmaPlugin.h>)
#import <flutter_gemma/FlutterGemmaPlugin.h>
#else
@import flutter_gemma;
#endif

#if __has_include(<flutter_secure_storage_darwin/FlutterSecureStorageDarwinPlugin.h>)
#import <flutter_secure_storage_darwin/FlutterSecureStorageDarwinPlugin.h>
#else
@import flutter_secure_storage_darwin;
#endif

#if __has_include(<image_picker_ios/FLTImagePickerPlugin.h>)
#import <image_picker_ios/FLTImagePickerPlugin.h>
#else
@import image_picker_ios;
#endif

#if __has_include(<large_file_handler/LargeFileHandlerPlugin.h>)
#import <large_file_handler/LargeFileHandlerPlugin.h>
#else
@import large_file_handler;
#endif

#if __has_include(<mobile_scanner/MobileScannerPlugin.h>)
#import <mobile_scanner/MobileScannerPlugin.h>
#else
@import mobile_scanner;
#endif

#if __has_include(<package_info_plus/FPPPackageInfoPlusPlugin.h>)
#import <package_info_plus/FPPPackageInfoPlusPlugin.h>
#else
@import package_info_plus;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<receive_sharing_intent/ReceiveSharingIntentPlugin.h>)
#import <receive_sharing_intent/ReceiveSharingIntentPlugin.h>
#else
@import receive_sharing_intent;
#endif

#if __has_include(<share_plus/FPPSharePlusPlugin.h>)
#import <share_plus/FPPSharePlusPlugin.h>
#else
@import share_plus;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [BackgroundDownloaderPlugin registerWithRegistrar:[registry registrarForPlugin:@"BackgroundDownloaderPlugin"]];
  [FilePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FilePickerPlugin"]];
  [FlutterGemmaPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterGemmaPlugin"]];
  [FlutterSecureStorageDarwinPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterSecureStorageDarwinPlugin"]];
  [FLTImagePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTImagePickerPlugin"]];
  [LargeFileHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"LargeFileHandlerPlugin"]];
  [MobileScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"MobileScannerPlugin"]];
  [FPPPackageInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPPackageInfoPlusPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
  [ReceiveSharingIntentPlugin registerWithRegistrar:[registry registrarForPlugin:@"ReceiveSharingIntentPlugin"]];
  [FPPSharePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPSharePlusPlugin"]];
  [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
}

@end
