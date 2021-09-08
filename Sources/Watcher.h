//
//  Watcher.h
//  Logger
//
// Created by Luca Severini on 7-Sep-2021.
//

#define DEFAULT_LANTENCY 1.0 // 1 second latency when collecting FSEvents

typedef struct watcherSettings
{
	FSEventStreamEventId	since_when;
	CFTimeInterval			latency;
	NSArray<NSString*>		*folders;
    NSDateFormatter         *dateFormatter;
}
watcherSettings;

int initWatcher (NSArray<NSString*> *folders, NSString *sinceWhen, NSString *latency);
void disposeWatcher (void);
