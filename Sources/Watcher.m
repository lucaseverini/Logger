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

// The FSEventsStreamCallback
// --------------------------------------------------------------------------------
static void fsevents_callback (FSEventStreamRef streamRef, void *clientCallBackInfo,
							   int numEvents,
							   const char *const eventPaths[],
							   const FSEventStreamEventFlags *eventFlags,
							   const uint64_t *eventIDs)
{
    watcherSettings *settings = (watcherSettings*)clientCallBackInfo;
    NSDate *curTime = [NSDate date];

    printf("\n");
    printf("time: %s\n", [[settings->dateFormatter stringFromDate:curTime] UTF8String]);
    printf("numEvents: %d\n", numEvents);

    for (int idx = 0; idx < numEvents; idx++)
    {
        printf("id: 0x%llX\n", eventIDs[idx]);
        printf("flag: 0x%08X\n", eventFlags[idx]);

        NSString *fullPath = [NSString stringWithUTF8String:eventPaths[idx]];
        NSString *name = [fullPath lastPathComponent];
        NSString *path = [fullPath stringByDeletingLastPathComponent];

        if (eventFlags[idx] & kFSEventStreamEventFlagRootChanged)
        {
            printf("Root path %s changed\n", [fullPath UTF8String]);
        }

        if (eventFlags[idx] & kFSEventStreamEventFlagItemIsDir)
        {
            printf("## Skip directory %s\n", [fullPath UTF8String]);
            continue;
        }

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

        // Don't report hidden or wrongly named items
        if (name.length == 0)
        {
            printf("## Skip invalid path %s\n", [fullPath UTF8String]);

            assert(0);
        }

#if 0
        // Skip invisible files?
        if (false)
        {
            if ([name characterAtIndex:0] == '.')
            {
                printf("## Skip invisible path %s\n", [fullPath UTF8String]);
                continue;
            }
        }
#endif
#if 0
        // Don't report items in subfolders
        if (true)
        {
            if ([settings->folders containsObject:path] == NO)
            {
                printf("Skip file %s in subfolder %s\n", [name UTF8String], [path UTF8String]);
                continue;
            }
        }
#endif
		if (eventFlags[idx] & kFSEventStreamEventFlagMustScanSubDirs)
		{
			if (eventFlags[idx] & kFSEventStreamEventFlagUserDropped)
			{
                printf("\n##### DROPPED EVENTS\n");

                assert(0);
			}
			else if (eventFlags[idx] & kFSEventStreamEventFlagKernelDropped)
			{
                printf("\n##### KERNEL DROPPED EVENTS\n");

                assert(0);
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
            printf("## File %s cloned in %s\n", [name UTF8String], [path UTF8String]);
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
    }
 }

// --------------------------------------------------------------------------------
static void watch_dir_hierarchy(watcherSettings *settings)
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

		return;
    }

    FSEventStreamScheduleWithRunLoop(stream_ref, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    if (FSEventStreamStart(stream_ref) == false)
	{
		printf("Failed to start the FSEventStream\n");
		
		FSEventStreamFlushSync(stream_ref);
		FSEventStreamStop(stream_ref);
    }

 	return;
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

    memset(&settings, 0, sizeof(watcherSettings));

    return;
}

// paths specify the paths to be checked
// sinceWhen <when> specify a time from whence to search for applicable events
// latency <seconds> specify latency
// --------------------------------------------------------------------------------
int initWatcher (NSArray<NSString*> *folders, NSString *sinceWhen, NSString *latency)
{
	if ([folders count] == 0)
	{
		return 0;
	}

    memset(&settings, 0, sizeof(watcherSettings));

    settings.dateFormatter = [[NSDateFormatter alloc] init];
    [settings.dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    settings.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

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
            printf("Invalid path: %s\n", [folder UTF8String]);
            return 1;
        }
    }

    settings.folders = [realPaths copy];

    settings.since_when = kFSEventStreamEventIdSinceNow;
    if ([sinceWhen length] != 0)
    {
        settings.since_when = strtoull([sinceWhen UTF8String], NULL, 0);
    }

    settings.latency = DEFAULT_LANTENCY;
    if ([latency length] != 0)
    {
        settings.latency = strtod([latency UTF8String], NULL);
    }

    watch_dir_hierarchy(&settings);

    printf("Watching: %s\n", [[settings.folders debugDescription] UTF8String]);
    printf("Latency: %.03f\n", settings.latency);
    printf("Since: 0x%llX\n", settings.since_when);
    
    return 0;
}

