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

- (void) windowDidBecomeMain:(NSNotification *)notification
{
    LSSharedFileListRef loginItem = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    BOOL isLoginItem = [self checkLoginItem:loginItem withBundle:[[NSBundle mainBundle] bundleIdentifier]];
    [self.loginItemButton setState:isLoginItem ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void) windowDidChangeOcclusionState:(NSNotification *)notification
{
    NSWindow *window = notification.object;
    if (window.occlusionState & NSWindowOcclusionStateVisible)
    {
        NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
        BOOL isAutoStart = [settings boolForKey:@"StartAtLaunch"];
        [self.autoStartButton setState:isAutoStart ? NSControlStateValueOn : NSControlStateValueOff];

        CFTimeInterval latencyValue = [[settings objectForKey:@"Latency"] doubleValue];
        self.latency.doubleValue = latencyValue;

        NSString *logPath = [settings stringForKey:@"LogPath"];
        if ([logPath length] != 0)
        {
            self.logFile.stringValue = logPath;
            self.logFile.toolTip = logPath;
        }

        self.folders = [[settings stringArrayForKey:@"Folders"] mutableCopy];
        [self.tableView reloadData];
    }
}

- (BOOL) windowShouldClose:(NSWindow*)sender
{
    return [self checkPreferences];
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

- (IBAction) setUnsetLoginItem:(id)sender
{
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

- (IBAction) setUnsetAutoStart:(id)sender
{
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    BOOL isAutoStart = [settings boolForKey:@"StartAtLaunch"];
    isAutoStart ^= 1;
    [self.autoStartButton setState:isAutoStart ? NSControlStateValueOn : NSControlStateValueOff];
    [settings setBool:isAutoStart forKey:@"StartAtLaunch"];
}

- (IBAction) selectLog:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"txt", @"log"]];

    NSString *logPath = self.logFile.stringValue;
    NSString *defaultFilename = [logPath lastPathComponent];
    if ([defaultFilename length] == 0)
    {
        defaultFilename = @"Logger_Log.txt";
    }
    else
    {
        [savePanel setDirectoryURL:[NSURL fileURLWithPath:[logPath stringByDeletingLastPathComponent]]];
    }
    [savePanel setNameFieldStringValue:defaultFilename];

    if ([savePanel runModal] == NSModalResponseOK)
    {
        NSURL *logFile = [savePanel URL];
        self.logFile.stringValue = [logFile path];
        self.logFile.toolTip = [logFile path];
    }
}

- (IBAction) setUnsetDontCheckSubfolders:(id)sender
{
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    BOOL dontCheckSubfolders = [settings boolForKey:@"DontCheckSubfolders"];
    dontCheckSubfolders ^= 1;
    [self.dontCheckSubfoldersButton setState:dontCheckSubfolders ? NSControlStateValueOn : NSControlStateValueOff];
    [settings setBool:dontCheckSubfolders forKey:@"DontCheckSubfolders"];
}

- (IBAction) addFolder:(id)sender
{
    printf("addFolder...\n");

    [self.folders addObject:@"AAAAAAAAAAAAAAAAAAAAAAA"];

    [self.tableView beginUpdates];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:[self.folders count] - 1];
    [self.tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectNone];
    [self.tableView endUpdates];

    [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
}

- (IBAction) removeFolder:(id)sender
{
    if (self.tableView.selectedRow >= 0)
    {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.tableView.selectedRow];
        [self.tableView removeRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectNone];

        [self.folders removeObjectAtIndex:[indexSet firstIndex]];

        if (self.tableView.selectedRow < 0)
        {
            [self.removeFolderButton setEnabled:NO];
        }
    }
}

- (IBAction) confirm:(id)sender
{
    if ([self checkPreferences ])
    {
        NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
        [settings setDouble:self.latency.doubleValue forKey:@"Latency"];
        [settings setBool:self.dontCheckSubfoldersButton.state forKey:@"DontCheckSubfolders"];
        [settings setBool:self.autoStartButton.state forKey:@"StartAtLaunch"];
        [settings setObject:self.logFile.stringValue forKey:@"LogPath"];
        [settings setObject:self.folders forKey:@"Folders"];

        [self.window orderOut:nil];
    }
}

- (IBAction) cancel:(id)sender;
{
    [self.window orderOut:nil];
}

- (IBAction) tableViewClicked:(id)sender
{
    if (self.tableView.selectedRow >= 0)
    {
        [self.removeFolderButton setEnabled:YES];
    }
    else
    {
        [self.removeFolderButton setEnabled:NO];
    }
}

- (BOOL) checkPreferences
{
    if (self.latency.doubleValue < 0.1 || self.latency.doubleValue > 5.0)
    {
        [self.latency selectText:self];

        NSBeep();
        return NO;
    }

    return YES;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView*)tableView
{
    printf("numberOfRowsInTableView: %d\n", (int)[self.folders count]);
    return [self.folders count];
}

- (CGFloat) tableView:(NSTableView*)tableView heightOfRow:(NSInteger)row
{
    return 20.0;
}

- (NSView*) tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row
{
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"COL1"])
    {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        NSString *folderPath = [self.folders objectAtIndex:row];
        cellView.textField.stringValue = folderPath;
        cellView.textField.toolTip = folderPath;
        return cellView;
    }

    return nil;
}

@end
