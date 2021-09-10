//
//  PreferencesController.m
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#import "PreferencesController.h"
#import "ApplicationDelegate.h"
#import "Utilities.h"

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
    [self.loginItemButton setState:[self checkLoginItem]];
}

- (void) windowDidChangeOcclusionState:(NSNotification *)notification
{
    NSWindow *window = notification.object;
    if (window.occlusionState & NSWindowOcclusionStateVisible)
    {
        NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];

        [self.autoStartButton setState:[self checkLoginItem]];

        self.latency.doubleValue = [[settings objectForKey:@"Latency"] doubleValue];

        [self.autoStartButton setState:[settings boolForKey:@"StartAtLaunch"]];

        [self.dontCheckSubfoldersButton setState:[settings boolForKey:@"DontCheckSubfolders"]];

        [self.dontSearchPidUserButton setState:[settings boolForKey:@"DontSearchPidUser"]];

        NSString *logPath = [settings stringForKey:@"LogPath"];
        if ([logPath length] != 0)
        {
            self.logFile.stringValue = logPath;
            self.logFile.toolTip = logPath;
        }
        else
        {
            self.logFile.stringValue = @"";
            self.logFile.toolTip = nil;
        }

        self.folders = [[settings stringArrayForKey:@"Folders"] mutableCopy];
        [self.tableView reloadData];
        [self tableViewSelected:nil];
    }
}

- (BOOL) windowShouldClose:(NSWindow*)sender
{
    return [self checkPreferences];
}

- (BOOL) addLoginItem
{
    LSSharedFileListRef loginItem = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItem != 0)
    {
        CFURLRef itemUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItem, kLSSharedFileListItemLast, NULL, NULL, itemUrl, NULL, NULL);

        CFRelease(loginItem);

        if (item != 0)
        {
            printf("Login item added.\n");
            CFRelease(item);

            return YES;
        }
    }

    return NO;
}

- (BOOL) checkLoginItem
{
    LSSharedFileListRef loginItem = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItem != 0)
    {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];

        UInt32 seedValue;
        NSArray *loginItems = (NSArray*)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItem, &seedValue));
        for (id item in loginItems)
        {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            CFURLRef itemUrl;
            if (LSSharedFileListItemResolve(itemRef, 0, &itemUrl, NULL) == noErr)
            {
                NSBundle *itemBundle = [NSBundle bundleWithURL:(__bridge NSURL*)itemUrl];
                NSString *itemBundleId = [itemBundle bundleIdentifier];

                CFRelease(itemUrl);

                if ([bundleId isEqualToString:itemBundleId])
                {
                    return YES;
                }
            }
        }

        CFRelease(loginItem);
    }

    return NO;
}

- (BOOL) removeLoginItem
{
    LSSharedFileListRef loginItem = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItem != 0)
    {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];

        UInt32 seedValue;
        NSArray *loginItems = (NSArray*)CFBridgingRelease(LSSharedFileListCopySnapshot(loginItem, &seedValue));
        for (id item in loginItems)
        {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
            CFURLRef itemUrl;
            if (LSSharedFileListItemResolve(itemRef, 0, &itemUrl, NULL) == noErr)
            {
                NSBundle *itemBundle = [NSBundle bundleWithURL:(__bridge NSURL*)itemUrl];
                NSString *itemBundleId = [itemBundle bundleIdentifier];

                CFRelease(itemUrl);

                if ([bundleId isEqualToString:itemBundleId])
                {
                    if (LSSharedFileListItemRemove(loginItem, itemRef) == noErr)
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

        CFRelease(loginItem);
    }

    return NO;
}

- (IBAction) setUnsetLoginItem:(id)sender
{
}

- (IBAction) setUnsetAutoStart:(id)sender
{
}

- (IBAction) selectLog:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.showsHiddenFiles = true;
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
}

- (IBAction) setUnsetDontSearchPidUser:(id)sender
{
}

- (IBAction) addFolder:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.showsHiddenFiles = true;
    openPanel.allowsMultipleSelection = false;
    openPanel.canChooseDirectories = true;
    openPanel.canChooseFiles = false;

    if ([openPanel runModal] == NSModalResponseOK)
    {
        [self.folders addObject:[[openPanel URL] path]];

        [self.tableView beginUpdates];
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:[self.folders count] - 1];
        [self.tableView insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectNone];
        [self.tableView endUpdates];

        [self.tableView selectRowIndexes:indexSet byExtendingSelection:NO];
        [self tableViewSelected:nil];
    }
}

- (IBAction) removeFolder:(id)sender
{
    if (self.tableView.selectedRow >= 0)
    {
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:self.tableView.selectedRow];
        [self.tableView removeRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectNone];

        [self.folders removeObjectAtIndex:[indexSet firstIndex]];
        [self tableViewSelected:nil];
    }
}

- (IBAction) cancel:(id)sender;
{
    [self.window orderOut:nil];

    [[appDelegate.statusItem.menu itemAtIndex:0] setEnabled:YES];
    [[appDelegate.statusItem.menu itemAtIndex:5] setEnabled:YES];
    [[appDelegate.statusItem.menu itemAtIndex:7] setEnabled:YES];
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
        [settings setBool:self.dontSearchPidUserButton.state forKey:@"DontSearchPidUser"];

        if ([self.loginItemButton state] && [self checkLoginItem] == NO)
        {
            if ([self addLoginItem] == NO)
            {
                if (showAlert(@"Logger not added to login items list.", NSAlertStyleWarning, @[@"Cancel", @"Continue"]) == 1000)
                {
                    return;
                }
            }
        }
        else if ([self.loginItemButton state] == NO && [self checkLoginItem])
        {
            if([self removeLoginItem] == NO)
            {
                if (showAlert(@"Logger not removed from login items list.", NSAlertStyleWarning, @[@"Cancel", @"Continue"]) == 1000)
                {
                    return;
                }
            }
        }

        [self.window orderOut:nil];

        [[appDelegate.statusItem.menu itemAtIndex:0] setEnabled:YES];
        [[appDelegate.statusItem.menu itemAtIndex:5] setEnabled:YES];
        [[appDelegate.statusItem.menu itemAtIndex:7] setEnabled:YES];
    }
}

- (IBAction) tableViewSelected:(id)sender
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
