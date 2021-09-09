//
//  Watcher.h
//  Logger
//
// Created by Luca Severini on 7-Sep-2021.
//

#define DEFAULT_LATENCY 1.0 // 1 second latency when collecting FSEvents

typedef struct watcherSettings
{
	FSEventStreamEventId	since_when;
	CFTimeInterval			latency;
	NSArray<NSString*>		*folders;
    NSDateFormatter         *dateFormatter;
    int                     logFd;
    BOOL                    dontCheckSubFolders;
}
watcherSettings;

int initWatcher(NSArray<NSString*> *folders, NSString *sinceWhen, CFTimeInterval latency, NSString *logPath, BOOL dontCheckSubFolders);
void disposeWatcher(void);
void writeMessageToLog(const char *message, bool asynchronous = true);
void reportFSEvent(FSEventStreamEventFlags eventFlags, const char *eventPath, const char* eventTime);
