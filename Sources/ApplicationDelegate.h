//
//  ApplicationDelegate.h
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#import "PreferencesController.h"

@interface ApplicationDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>

@property (nonatomic, strong) IBOutlet NSMenu *statusMenu;

@property (nonatomic, strong) NSString *appSupportFolder;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (atomic, assign) BOOL loggerStarted;
@property (nonatomic, strong) PreferencesController *prefsPanel;

- (IBAction) startLoggerAction:(id)sender;
- (IBAction) stopLoggerAction:(id)sender;
- (IBAction) quitLoggerAction:(id)sender;
- (IBAction) openLogAction:(id)sender;
- (IBAction) preferencesAction:(id)sender;

- (void) start;
- (void) stop;

@end
