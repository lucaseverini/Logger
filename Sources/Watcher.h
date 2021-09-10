//
//  Watcher.h
//  Logger
//
// Created by Luca Severini on 7-Sep-2021.
//

typedef struct watcherSettings
{
	FSEventStreamEventId    since_when;
	CFTimeInterval			latency;
	NSArray<NSString*>		*folders;
    NSDateFormatter         *dateFormatter;
    int                     logFd;
    BOOL                    dontCheckSubFolders;
    BOOL                    dontSearchPidUser;
}
watcherSettings;

int initWatcher(NSArray<NSString*> *folders, NSString *sinceWhen, CFTimeInterval latency, NSString *logPath, BOOL dontCheckSubFolders, BOOL dontSearchPidUser);
void disposeWatcher(void);
void writeMessageToLog(const char *message, bool asynchronous = true);
void reportFSEvent(FSEventStreamEventFlags eventFlags, const char *eventPath, const char* eventTime);
