//
//  PreferencesController.h
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

@interface PreferencesController : NSWindowController<NSWindowDelegate>

@property (nonatomic, strong) IBOutlet NSButton *button;
@property (nonatomic, strong) IBOutlet NSButton *loginItemButton;
@property (nonatomic, strong) IBOutlet NSButton *autoStartButton;

- (IBAction) setUnsetLoginItem:(id)sender;

@end
