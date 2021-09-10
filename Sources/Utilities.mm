//
//  Utilities.mm
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#include <stdlib.h>
#include <sys/time.h>
#import "ApplicationDelegate.h"
#import "Utilities.h"

// --------------------------------------------------------------------------------
NSString *getApplicationSupportFolder (void)
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *supportDirectory = [paths firstObject];

	NSString *execName = [[[NSBundle mainBundle] executablePath] lastPathComponent];
	NSString *folderPath = [supportDirectory stringByAppendingPathComponent:execName];

	NSFileManager *fileMgr = [NSFileManager defaultManager];

	if (![fileMgr fileExistsAtPath:folderPath])
	{
		if ([fileMgr createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil])
		{
			return folderPath;
		}
		else
		{
			return nil;
		}
	}
	else
	{
		return folderPath;
	}
}

// -------------------------------------------------------------------------------------------------------
void sendNotification (NSString *message)
{
    printf("sendNotification\n");

    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Hyphen HSL";
    notification.informativeText = message;
    notification.soundName = NSUserNotificationDefaultSoundName;
    notification.hasActionButton = NO;
    notification.hasReplyButton = NO;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

// ---------------------------------------------------------------------
NSModalResponse showAlert(NSString *message, NSAlertStyle style, NSArray *buttons)
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setAlertStyle:style];

    if (buttons == nil)
    {
        [alert addButtonWithTitle:@"Ok"];
    }
    else
    {
        for (NSString *button in buttons)
        {
            [alert addButtonWithTitle:button];
        }
    }

    return [alert runModal];
}

// --------------------------------------------------------------------------
int64_t currentMillisecs(void)
{
    struct timeval time;
    gettimeofday(&time, NULL);

    int64_t millis = (time.tv_sec * 1000) + (time.tv_usec / 1000);

    return millis;
}

// --------------------------------------------------------------------------
int64_t currentMicrosecs(void)
{
    struct timeval time;
    gettimeofday(&time, NULL);

    int64_t millis = (time.tv_sec * 1000000) + time.tv_usec;

    return millis;
}
