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

- (void) applicationWillFinishLaunching:(NSNotification*)notification
{
	// Init global pointers to app and app delegate asap
	app = [NSApplication sharedApplication];
	appDelegate = (ApplicationDelegate*)[app delegate];
}

- (void) applicationDidFinishLaunching:(NSNotification*)notification
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

- (void) applicationWillBecomeActive:(NSNotification*)notification;
{
	// NSLog(@"applicationDidBecomeActive");
    // TODO: Some update should be done here.
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication*)sender
{
    if (self.loggerStarted)
    {
        [self stop];
    }

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
    if ([folders count] == 0)
    {
        showAlert(@"No folders to watch.");
        return;
    }

    NSString *logPath = [settings stringForKey:@"LogPath"];
    if ([logPath length] == 0)
    {
        showAlert(@"Log path not defined.");
        return;
    }

    printf("Logger starting...\n");

    BOOL checkSubfolders = [settings boolForKey:@"DontCheckSubfolders"];
    CFTimeInterval latency = [[settings objectForKey:@"Latency"] doubleValue];
    if (initWatcher(folders, nil, latency, logPath, checkSubfolders) == 0)
    {
        printf("### Logger started\n");
        self.loggerStarted = YES;
    }
    else
    {
        printf("initWatcher initialization failed.\n");
    }
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

    self.loggerStarted = NO;
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

    // If application is background (LSBackgroundOnly) you need this call
    // otherwise the window manager may draw other windows on top of the menu
    // [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction) startLoggerAction:(id)sender
{
    [self start];
}

- (IBAction) stopLoggerAction:(id)sender
{
    [self stop];
}

- (IBAction) quitLoggerAction:(id)sender
{
    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction) openLogAction:(id)sender
{
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSString *logPath = [settings stringForKey:@"LogPath"];
    if (access([logPath UTF8String], F_OK) != -1)
    {
        char command[PATH_MAX];
        sprintf(command, "open -t \"%s\"", [logPath UTF8String]);
        system(command);
    }
    else
    {
        showAlert(@"Log file not found.");
    }
}

- (IBAction) preferencesAction:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];

    if(self.prefsPanel.window == nil)
    {
        self.prefsPanel = [[PreferencesController alloc] init];
    }

    [self.prefsPanel.window makeKeyAndOrderFront:self];
}

@end
