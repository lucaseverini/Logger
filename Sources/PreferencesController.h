//
//  PreferencesController.h
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

@interface PreferencesController : NSWindowController<NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, unsafe_unretained) IBOutlet NSButton *selectLogButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *loginItemButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *autoStartButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *dontCheckSubfoldersButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *addFolderButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *removeFolderButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSButton *dontSearchPidUserButton;
@property (nonatomic, unsafe_unretained) IBOutlet NSTableView *tableView;
@property (nonatomic, unsafe_unretained) IBOutlet NSScrollView *scrollView;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *latency;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *logFile;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextField *folder;

@property (nonatomic, strong) NSMutableArray<NSString*> *folders;

- (IBAction) setUnsetLoginItem:(id)sender;
- (IBAction) setUnsetAutoStart:(id)sender;
- (IBAction) selectLog:(id)sender;
- (IBAction) setUnsetDontCheckSubfolders:(id)sender;
- (IBAction) addFolder:(id)sender;
- (IBAction) removeFolder:(id)sender;
- (IBAction) confirm:(id)sender;
- (IBAction) cancel:(id)sender;
- (IBAction) tableViewSelected:(id)sender;
- (IBAction) setUnsetDontSearchPidUser:(id)sender;

@end
