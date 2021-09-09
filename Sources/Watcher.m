//
//  Watcher.m
//  Logger
//
//  Created by Luca Severini on 7-Sep-2021.
//

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/event.h>
#include <assert.h>
#include <vector>
#include "Watcher.h"
#include "Utilities.h"

// Local globals
static FSEventStreamRef stream_ref;
static watcherSettings settings;

// FSEventsStreamCallback
// --------------------------------------------------------------------------------
static void fsevents_callback (FSEventStreamRef streamRef, void *clientCallBackInfo,
							   int numEvents,
							   const char *const eventPaths[],
							   const FSEventStreamEventFlags *eventFlags,
							   const uint64_t *eventIDs)
{
    watcherSettings *settings = (watcherSettings*)clientCallBackInfo;
    const char *curTimeStr = [[settings->dateFormatter stringFromDate:[NSDate date]] UTF8String];

    printf("\n");
    printf("Time: %s\n", curTimeStr);
    printf("Events: %d\n", numEvents);

    for (int idx = 0; idx < numEvents; idx++)
    {
        printf("id: 0x%llX\n", eventIDs[idx]);
        printf("flags: 0x%08X\n", eventFlags[idx]);

        NSString *fullPath = [NSString stringWithUTF8String:eventPaths[idx]];
        NSString *name = [fullPath lastPathComponent];
        NSString *path = [fullPath stringByDeletingLastPathComponent];

        // Don't report hidden or wrongly named items
        if (name.length == 0)
        {
            printf("## Skip invalid path %s\n", [fullPath UTF8String]);
            // assert(0);
            continue;
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagRootChanged)
        {
            printf("Root path %s changed\n", [fullPath UTF8String]);
            // Should update the whatched path?
            continue;
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemIsDir)
        {
            printf("## Skip directory %s\n", [fullPath UTF8String]);
            continue;
        }

#if 0 // Skip symlinks and hardlinks
        if (eventFlags[idx] & kFSEventStreamEventFlagItemIsSymlink)
        {
            printf("## Skip symlink %s\n", [fullPath UTF8String]);
            continue;
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemIsHardlink ||
            eventFlags[idx] & kFSEventStreamEventFlagItemIsLastHardlink)
        {
            printf("## Skip hardlink %s\n", [fullPath UTF8String]);
            continue;
        }
#endif

#if 0 // Skip invisible files
        if ([name characterAtIndex:0] == '.')
        {
            printf("## Skip invisible path %s\n", [fullPath UTF8String]);
            continue;
        }
#endif
        // Don't report items in subfolders
        if (settings->dontCheckSubFolders)
        {
            if ([settings->folders containsObject:path] == NO)
            {
                printf("Skip file %s in subfolder %s\n", [name UTF8String], [path UTF8String]);
                continue;
            }
        }


		if (eventFlags[idx] & kFSEventStreamEventFlagMustScanSubDirs)
		{
			if (eventFlags[idx] & kFSEventStreamEventFlagUserDropped)
			{
                printf("\n##### DROPPED EVENTS: %s\n", [fullPath UTF8String]);
			}
			else if (eventFlags[idx] & kFSEventStreamEventFlagKernelDropped)
			{
                printf("\n##### KERNEL DROPPED EVENTS: %s\n", [fullPath UTF8String]);
			}
		}
		
		if (eventFlags[idx] & kFSEventStreamEventFlagItemCreated)
		{
            printf("## File %s in %s created\n", [name UTF8String], [path UTF8String]);
		}
		
		if (eventFlags[idx] & kFSEventStreamEventFlagItemRemoved)
		{
            printf("## File %s in %s deleted\n", [name UTF8String], [path UTF8String]);
		}
		
		if (eventFlags[idx] & kFSEventStreamEventFlagItemRenamed)
		{
			if (access([fullPath UTF8String], F_OK) != -1)
			{
                printf("## File %s in %s renamed/moved into\n", [name UTF8String], [path UTF8String]);
 			}
			else
			{
                printf("## File %s in %s renamed/moved away\n", [name UTF8String], [path UTF8String]);
 			}
		}
		
		if (eventFlags[idx] & kFSEventStreamEventFlagItemModified)
		{
            printf("## File %s in %s modified\n", [name UTF8String], [path UTF8String]);
		}

        if (eventFlags[idx] & kFSEventStreamEventFlagItemCloned)
        {
            printf("## File %s in %s cloned\n", [name UTF8String], [path UTF8String]);
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemXattrMod)
        {
            printf("## File %s in %s extended attributes modified\n", [name UTF8String], [path UTF8String]);
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemFinderInfoMod)
        {
            printf("## File %s in %s finder information modified\n", [name UTF8String], [path UTF8String]);
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemInodeMetaMod)
        {
            printf("## File %s in %s metadata modified\n", [name UTF8String], [path UTF8String]);
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemChangeOwner)
        {
            printf("## File %s in %s owner changed\n", [name UTF8String], [path UTF8String]);
        }

        reportFSEvent(eventFlags[idx], eventPaths[idx], curTimeStr);
    }
}

// --------------------------------------------------------------------------------
void reportFSEvent(FSEventStreamEventFlags eventFlags, const char *eventPath, const char* eventTime)
{
    static dispatch_queue_t queue;
    if (queue == NULL)
    {
        queue = dispatch_queue_create("com.lucaseverini.logger.eventsQueue", DISPATCH_QUEUE_SERIAL);
    }

    const char *eventPathCopy = strdup(eventPath);
    const char *eventTimeCopy = strdup(eventTime);

    dispatch_async(queue,
    ^{
        static char buffer[PATH_MAX * 2];
        static char tmpStr[PATH_MAX * 2];

        buffer[0] = '\0';
        tmpStr[0] = '\0';

        sprintf(tmpStr, "\n%s\n%s\n", eventTimeCopy, eventPathCopy);
        strcat(buffer, tmpStr);

        free((void*)eventPathCopy);
        free((void*)eventTimeCopy);

        if (eventFlags & kFSEventStreamEventFlagMustScanSubDirs)
        {
            if (eventFlags & kFSEventStreamEventFlagUserDropped)
            {
                strcat(buffer, "Logger DROPPED EVENTS\n");
            }
            else if (eventFlags & kFSEventStreamEventFlagKernelDropped)
            {
                strcat(buffer, "KERNEL DROPPED EVENTS\n");
            }
        }

        if (eventFlags & kFSEventStreamEventFlagItemCreated)
        {
            strcat(buffer, "File created\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemRemoved)
        {
            strcat(buffer, "File deleted\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemRenamed)
        {
            if (access(eventPath, F_OK) != -1)
            {
                strcat(buffer, "File renamed/moved into\n");
            }
            else
            {
                strcat(buffer, "File renamed/moved out\n");
            }
        }

        if (eventFlags & kFSEventStreamEventFlagItemModified)
        {
            strcat(buffer, "File modified\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemCloned)
        {
            strcat(buffer, "File cloned\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemXattrMod)
        {
            strcat(buffer, "Extended attributes modified\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemFinderInfoMod)
        {
            strcat(buffer, "Finder information modified\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemInodeMetaMod)
        {
            strcat(buffer, "Finder metadata modified\n");
        }

        if (eventFlags & kFSEventStreamEventFlagItemChangeOwner)
        {
            strcat(buffer, "Finder owner changed\n");
        }

        writeMessageToLog(buffer, true);
    });
}

// --------------------------------------------------------------------------------
void writeMessageToLog(const char *message, bool asynchronous)
{
    static dispatch_queue_t queue;
    if (queue == NULL)
    {
        queue = dispatch_queue_create("com.lucaseverini.logger.logQueue", DISPATCH_QUEUE_SERIAL);
    }

    assert(settings.logFd != 0);
    assert(message != NULL);

    if (asynchronous)
    {
        const char *messageCopy = strdup(message);

        dispatch_async(queue,
        ^{
            if(write(settings.logFd, messageCopy, strlen(messageCopy)) < 0)
            {
                printf("Asynch write log error: %s\n", strerror(errno));
            }

            free((void*)messageCopy);
        });
    }
    else
    {
        dispatch_sync(queue,
        ^{
            if(write(settings.logFd, message, strlen(message)) < 0)
            {
                printf("Synch write log error: %s\n", strerror(errno));
            }
        });
    }
}

// --------------------------------------------------------------------------------
static int createWatcher(watcherSettings *settings)
{
    FSEventStreamContext context = {0, NULL, NULL, NULL, NULL};
    context.info = (void*)settings;
    stream_ref = FSEventStreamCreate(kCFAllocatorDefault,
	                            (FSEventStreamCallback)&fsevents_callback,
	                            &context,
                                (__bridge CFArrayRef)settings->folders,
                                settings->since_when,
	                            settings->latency,
	                            kFSEventStreamCreateFlagWatchRoot | 
								kFSEventStreamCreateFlagFileEvents |
								kFSEventStreamCreateFlagIgnoreSelf);
    if (stream_ref == NULL)
	{
		printf("Failed to create the stream for paths: %s\n", [[settings->folders debugDescription] UTF8String]);

		return 1;
    }

    FSEventStreamScheduleWithRunLoop(stream_ref, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    if (FSEventStreamStart(stream_ref) == false)
	{
		printf("Failed to start the FSEventStream\n");
		
		FSEventStreamFlushSync(stream_ref);
		FSEventStreamStop(stream_ref);

        return 1;
    }

 	return 0;
}

// --------------------------------------------------------------------------------
void disposeWatcher (void)
{
	// Although it's not strictly necessary, make sure we see any pending events...
	FSEventStreamFlushSync(stream_ref);
	FSEventStreamStop(stream_ref);

    // Invalidation and final shutdown of the stream
    FSEventStreamInvalidate(stream_ref);
    FSEventStreamRelease(stream_ref);

    char buffer[1024];
    sprintf(buffer, "\n%s\nLogger stopped.\n", [[settings.dateFormatter stringFromDate:[NSDate date]] UTF8String]);
    writeMessageToLog(buffer, false);

    if (settings.logFd != 0)
    {
        if (close(settings.logFd) != 0)
        {
            printf("Error closing the log: %s\n", strerror(errno));
        }
    }

    memset(&settings, 0, sizeof(watcherSettings));

    return;
}

// paths specify the paths to be checked
// sinceWhen <when> specify a time from whence to search for applicable events
// latency <seconds> specify latency
// --------------------------------------------------------------------------------
int initWatcher (NSArray<NSString*> *folders, NSString *sinceWhen, CFTimeInterval latency, NSString *logPath, BOOL dontCheckSubFolders)
{
	if ([folders count] == 0)
	{
		return 0;
	}

    memset(&settings, 0, sizeof(watcherSettings));

    settings.dateFormatter = [[NSDateFormatter alloc] init];
    [settings.dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    settings.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    settings.dontCheckSubFolders = dontCheckSubFolders;

    NSMutableArray *realPaths = [NSMutableArray new];
    for (NSString *folder in folders)
    {
        char fullpath[PATH_MAX];
        if (realpath([folder UTF8String], fullpath) != NULL)
        {
            [realPaths addObject:[NSString stringWithUTF8String:fullpath]];
        }
        else
        {
            printf("Invalid folder path: %s\n", [folder UTF8String]);
            return 1;
        }
    }

    settings.folders = [realPaths copy];

    int mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH;
    int access = O_RDWR | O_CREAT | O_APPEND;
    int logFd = open([logPath UTF8String], access, mode);
    if (logFd == -1)
    {
        printf("Invalid log path: %s error: %s\n", [logPath UTF8String], strerror(errno));
        return 1;
    }
    settings.logFd = logFd;

    settings.since_when = kFSEventStreamEventIdSinceNow;
    if ([sinceWhen length] != 0)
    {
        settings.since_when = strtoull([sinceWhen UTF8String], NULL, 0);
    }

    settings.latency = latency;

    if (createWatcher(&settings) != 0)
    {
        printf("Watcher not created\n");
        return 1;
    }

    printf("Watching folders: %s\n", [[settings.folders debugDescription] UTF8String]);
    printf("Log: %d %s\n", settings.logFd, [logPath UTF8String]);
    printf("Check subfolders: %s\n", dontCheckSubFolders == NO ? "Yes" : "No");
    printf("Latency: %.03f\n", settings.latency);
    printf("Since: 0x%llX\n", settings.since_when);

    char buffer[1024];
    sprintf(buffer, "\n%s\nLogger started.\n", [[settings.dateFormatter stringFromDate:[NSDate date]] UTF8String]);
    writeMessageToLog(buffer, false);

    return 0;
}

