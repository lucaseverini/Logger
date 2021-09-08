//
//  Macros.h
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#undef dispatch_main_sync_safe
#define dispatch_main_sync_safe(block)					\
if ([NSThread isMainThread])							\
{														\
	block();											\
}														\
else													\
{														\
	dispatch_sync(dispatch_get_main_queue(), block);	\
}														\

#undef dispatch_main_async_safe
#define dispatch_main_async_safe(block)						\
if ([NSThread isMainThread])								\
{															\
	block();												\
}															\
else														\
{															\
	dispatch_async(dispatch_get_main_queue(), block);		\
}															\

#define IOS_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]
#define IOS_VERSION_7 (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0)
#define IOS_VERSION_8 (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0)

// To ensure to put a non-null NSString or NSNUMBER in any NS-CONTAINER use these definitions
#define SAFE_NSSTRING(s)  (s != nil ? s : @"")
#define SAFE_NSNUMBER(n)  (n != nil ? n : @(0))

#define kDeviceInfo [NSString stringWithFormat:@"Apple %@, Version %@ Build %@, %@ iOS%@", [[UIDevice currentDevice] model], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"], [UIDevice machineName], [[UIDevice currentDevice] systemVersion]]
