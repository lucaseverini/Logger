//
//  Utilities.h
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

void sendNotification (NSString *message);
NSString *getApplicationSupportFolder (void);
NSModalResponse showAlert (NSString *message, NSAlertStyle style = NSAlertStyleWarning, NSArray *buttons = nil);
