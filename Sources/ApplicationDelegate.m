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
    // TODO: Some update should be done here?
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication*)sender
{
    if (self.loggerStarted)
    {
        showAlert(@"Logger must be stopped before to quit.", NSAlertStyleCritical, @[@"Cancel"]);
        return NSTerminateCancel;
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

- (void) awakeFromNib
{
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:STATUS_ITEM_WIDTH];
    [((NSButtonCell*)self.statusItem.button.cell) setHighlightsBy:NSContentsCellMask | NSChangeBackgroundCellMask];
    self.statusItem.button.image = [NSImage imageNamed:@"MenubarIcon"];
    self.statusItem.menu = self.statusMenu;

    // If application is background (LSBackgroundOnly) you need this call
    // otherwise the window manager may draw other windows on top of the menu
    // [NSApp activateIgnoringOtherApps:YES];
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
    BOOL dontSearchPidUser = [settings boolForKey:@"DontSearchPidUser"];
    CFTimeInterval latency = [[settings objectForKey:@"Latency"] doubleValue];
    if (initWatcher(folders, nil, latency, logPath, checkSubfolders, dontSearchPidUser) == 0)
    {
        printf("### Logger started\n");
        self.loggerStarted = YES;

        [[self.statusItem.menu itemAtIndex:0] setEnabled:NO];
        [[self.statusItem.menu itemAtIndex:1] setEnabled:YES];
        [[self.statusItem.menu itemAtIndex:5] setEnabled:NO];
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

    [[self.statusItem.menu itemAtIndex:0] setEnabled:YES];
    [[self.statusItem.menu itemAtIndex:1] setEnabled:NO];
    [[self.statusItem.menu itemAtIndex:5] setEnabled:YES];

    self.loggerStarted = NO;
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
        NSString *msg = [NSString stringWithFormat:@"Log file %@ not found.", logPath];
        showAlert(msg, NSAlertStyleCritical);
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
