//
//  ApplicationDelegate.m
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#import "ApplicationDelegate.h"
#import "Watcher.h"
#import "Utilities.h"

#define STATUS_ITEM_WIDTH 24.0

ApplicationDelegate *appDelegate;
NSApplication *app;

@implementation ApplicationDelegate

#pragma mark - NSApplicationDelegate

- (void) applicationWillFinishLaunching:(NSNotification *)notification
{
	// Init global pointers to app and app delegate asap
	app = [NSApplication sharedApplication];
	appDelegate = (ApplicationDelegate*)[app delegate];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
    printf("Home directory: %s\n", [NSHomeDirectory() UTF8String]);

    NSString * OSVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
    printf("OS %s\n", [OSVersion UTF8String]);

    self.appSupportFolder = getApplicationSupportFolder();
    printf("App Support Folder: %s\n", [self.appSupportFolder UTF8String]);

    // Set default preferences
    // Reset the preferences with: defaults delete com.lucaseverini.logger
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    
    NSURL *defaultPrefsFile = [[NSBundle mainBundle] URLForResource:@"DefaultPrefs" withExtension:@"plist"];
    NSDictionary *defaultPrefs = [NSDictionary dictionaryWithContentsOfURL:defaultPrefsFile];
    [settings registerDefaults:defaultPrefs];

	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];

    if ([settings boolForKey:@"StartAtLaunch"])
    {
        [self start];
    }
}

- (void) applicationWillBecomeActive:(NSNotification *)notification
{
	// NSLog(@"applicationWillBecomeActive");
}

- (void) applicationDidBecomeActive:(NSNotification *)notification;
{
	// NSLog(@"applicationDidBecomeActive");
}

- (void) applicationWillResignActive:(NSNotification *)notification;
{
	// NSLog(@"applicationWillResignActive");
}

- (void) applicationDidResignActive:(NSNotification *)notification;
{
	// NSLog(@"applicationDidResignActive");
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
    [self stop];

	printf("%s quit\n", [[[NSRunningApplication currentApplication] localizedName] UTF8String]);

    return NSTerminateNow;
}

#pragma mark - NSUserNotificationCenterDelegate

- (BOOL) userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
	return YES;
}

- (void) userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
	printf("User clicked on notification %s\n", [[notification debugDescription] UTF8String]);
}

- (void) start
{
    if (self.loggerStarted)
    {
        printf("Logger already started\n");
        return;
    }

    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSArray<NSString*> *folders = [settings stringArrayForKey:@"Folders"];

    // For testing
    NSString *folder1 = @"/Volumes/Data/Desktop/MalwareBytes/Test/Folder-1";
    NSString *folder2 = @"/Volumes/Data/Desktop/MalwareBytes/Test/Folder-2";
    folders = @[folder1, folder2];

    if ([folders count] == 0)
    {
        showAlert(@"No folders to watch.");
        return;
    }

    printf("Logger starting...\n");

    if (initWatcher(folders, nil, @"1.0") != 0)
    {
        printf("initWatcher non initialized for folders: %s\n", [[folders debugDescription] UTF8String]);
    }

    printf("### Logger started\n");

    self.loggerStarted = YES;
}

- (void) stop
{
    if (self.loggerStarted == NO)
    {
        printf("Logger already stopped\n");
        return;
    }

    printf("Logger stopping...\n");

    disposeWatcher();

    printf("### Logger stopped\n");
}

- (void) setMenubarIcon:(BOOL)processing
{
    static NSInteger curIcon = -1;

    if (processing && curIcon != 1)
    {
        curIcon = 1;

        self.statusItem.button.image = [NSImage imageNamed:@"MenubarIcon_Processing"];
        self.statusItem.button.alternateImage = [NSImage imageNamed:@"MenubarIconAlt_Processing"];
    }
    else if (!processing && curIcon != 0)
    {
        curIcon = 0;

        self.statusItem.button.image = [NSImage imageNamed:@"MenubarIcon"];
        self.statusItem.button.alternateImage = [NSImage imageNamed:@"MenubarIconAlt"];
    }
}

- (void) awakeFromNib
{
    // Set the MenuBar Status Item as a sticky button
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:STATUS_ITEM_WIDTH];
    [((NSButtonCell*)self.statusItem.button.cell) setHighlightsBy:NSContentsCellMask | NSChangeBackgroundCellMask];
    self.statusItem.button.image = [NSImage imageNamed:@"MenubarIcon"];
    self.statusItem.menu = self.statusMenu;
/*
    [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventTypeLeftMouseDown | NSEventTypeRightMouseDown)
        handler:^NSEvent *(NSEvent *event)
        {
            NSUInteger clearFlags = ([event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);
            BOOL commandPressed = (clearFlags == NSEventModifierFlagCommand);
            if (commandPressed == NO)
            {
                if (event.window == self.statusItem.button.window)
                {
                    [self togglePanel:self.statusItem];
                    return nil;
                }
            }

            return event;
        }];
*/
    // If application is background (LSBackgroundOnly) you need this call
    // otherwise the window manager may draw other windows on top of the menu
    // [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction) startLoggerAction:(id)sender
{
    printf("Start Logger\n");
    [self start];
}

- (IBAction) stopLoggerAction:(id)sender
{
    printf("Stop Logger\n");
    [self stop];
}

- (IBAction) quitLoggerAction:(id)sender
{
    printf("Quit Logger\n");

    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction) openLogAction:(id)sender
{
    printf("Open Log\n");
}

- (IBAction) preferencesAction:(id)sender
{
    printf("Preferences\n");

    [NSApp activateIgnoringOtherApps:YES];

    if(self.prefsPanel.window == nil)
    {
        self.prefsPanel = [[PreferencesController alloc] init];
    }

    [self.prefsPanel.window makeKeyAndOrderFront:self];
}

@end