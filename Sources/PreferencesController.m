//
//  PreferencesController.m
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#import "PreferencesController.h"

@implementation PreferencesController

- (id) init
{
    self = [super initWithWindowNibName:@"PreferencesController"];
    if(self != nil)
    {
    }
    
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];

    [self.window makeKeyAndOrderFront:self];
}

- (void) windowDidBecomeMain:(NSNotification *)notification
{
    printf("windowDidBecomeMain...\n");

    LSSharedFileListRef loginItem = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    BOOL isLoginItem = [self checkLoginItem:loginItem withBundle:[[NSBundle mainBundle] bundleIdentifier]];
    [self.loginItemButton setState:isLoginItem ? NSControlStateValueOn : NSControlStateValueOff];
}

- (IBAction) setUnsetLoginItem:(id)sender
{
    printf("setUnsetLoginItem...\n");

    LSSharedFileListRef loginItem = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItem != 0)
    {
        if ([[sender selectedCell] state] == YES)
        {
            CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
            [self addLoginItem:loginItem forUrl:url];

            BOOL isLoginItem = [self checkLoginItem:loginItem withBundle:[[NSBundle mainBundle] bundleIdentifier]];
            [self.loginItemButton setState:isLoginItem ? NSControlStateValueOn : NSControlStateValueOff];
        }
        else
        {
            [self removeLoginItem:loginItem withBundle:[[NSBundle mainBundle] bundleIdentifier]];
        }

        CFRelease(loginItem);
    }
}

- (void) addLoginItem:(LSSharedFileListRef)loginItemRef forUrl:(CFURLRef)url
{
    LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemRef, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
    if (item != 0)
    {
        printf("Login item added.\n");
        CFRelease(item);
    }
}

- (BOOL) checkLoginItem:(LSSharedFileListRef)loginItemRef withBundle:(NSString*)bundleId
{
    UInt32 seedValue;
    NSArray *loginItems = (NSArray*)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemRef, &seedValue));
    for (id item in loginItems)
    {
        LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
        CFURLRef itemUrl;
        if (LSSharedFileListItemResolve(itemRef, 0, &itemUrl, NULL) == noErr)
        {
            NSBundle *itemBundle = [NSBundle bundleWithURL:(__bridge NSURL*)itemUrl];
            NSString *itemBundleId = [itemBundle bundleIdentifier];

            if ([bundleId isEqualToString:itemBundleId])
            {
                printf("Login item present.\n");
                return YES;
            }
        }
    }

    return NO;
}

- (BOOL) removeLoginItem:(LSSharedFileListRef)loginItemRef withBundle:(NSString*)bundleId
{
    UInt32 seedValue;
    NSArray *loginItems = (NSArray*)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItemRef, &seedValue));
    for (id item in loginItems)
    {
        LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
        CFURLRef itemUrl;
        if (LSSharedFileListItemResolve(itemRef, 0, &itemUrl, NULL) == noErr)
        {
            NSBundle *itemBundle = [NSBundle bundleWithURL:(__bridge NSURL*)itemUrl];
            NSString *itemBundleId = [itemBundle bundleIdentifier];

            if ([bundleId isEqualToString:itemBundleId])
            {
                if (LSSharedFileListItemRemove(loginItemRef, itemRef) == noErr)
                {
                    printf("Login item removed.\n");
                    return YES;
                }
                else
                {
                    printf("Login item not removed.\n");
                    return NO;
                }
            }
        }
    }

    return NO;
}

@end
