//
//  main.m
//  FSLogger
//
//  Created by Luca Severini on 9/12/21.
//

/*
 * fslogger.c
 *
 * Copyright (c) 2008 Amit Singh (osxbook.com).
 * http://osxbook.com/software/fslogger/
 *
 * Source released under the GNU GENERAL PUBLIC LICENSE (GPL) Version 2.0.
 * See http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt for details.
 *
 * Compile (Mac OS X 10.5.x only) as follows:
 *
 * gcc -I/path/to/xnu/bsd -Wall -o fslogger fslogger.c
 *
 */

#include <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <pwd.h>
#include <grp.h>
#include <assert.h>
#include <libgen.h>
#include <time.h>
#include <vector>
#include "FSEvents.h"

#define DEV_FSEVENTS     "/dev/fsevents" // the fsevents pseudo-device
#define FSEVENT_BUFSIZ   131072          // buffer for reading from the device
#define EVENT_QUEUE_SIZE 4096            // limited by MAX_KFS_EVENTS

// an event argument
#pragma pack(push, 4)
typedef struct kfs_event_arg {
    u_int16_t  type;         // argument type
    u_int16_t  len;          // size of argument data that follows this field
    union {
        struct vnode *vp;
        char         *str;
        void         *ptr;
        int32_t       int32;
        dev_t         dev;
        ino_t         ino;
        int32_t       mode;
        uid_t         uid;
        gid_t         gid;
        uint64_t      timestamp;
    } data;
} kfs_event_arg_t;
#pragma pack(pop)

#define KFS_NUM_ARGS  FSE_MAX_ARGS

// an event
typedef struct kfs_event {
    int32_t         type; // event type
    pid_t           pid;  // pid of the process that performed the operation
    kfs_event_arg_t args[KFS_NUM_ARGS]; // event arguments
} kfs_event;

// event names
static const char *kEventNames[] = {
    "FSE_CREATE_FILE",
    "FSE_DELETE",
    "FSE_STAT_CHANGED",
    "FSE_RENAME",
    "FSE_CONTENT_MODIFIED",
    "FSE_EXCHANGE",
    "FSE_FINDER_INFO_CHANGED",
    "FSE_CREATE_DIR",
    "FSE_CHOWN", // chown chgrp chmod
    "FSE_XATTR_MODIFIED",
    "FSE_XATTR_REMOVED",
    "FSE_DOCID_CREATED",
    "FSE_DOCID_CHANGED",
    "FSE_UNMOUNT_PENDING", // iOS-only: client must respond via FSEVENTS_UNMOUNT_PENDING_ACK",
    "FSE_CLONE",
};

// for pretty-printing of vnode types
enum vtype {
    VNON, VREG, VDIR, VBLK, VCHR, VLNK, VSOCK, VFIFO, VBAD, VSTR, VCPLX
};

enum vtype iftovt_tab[] = {
    VNON, VFIFO, VCHR, VNON, VDIR,  VNON, VBLK, VNON,
    VREG, VNON,  VLNK, VNON, VSOCK, VNON, VNON, VBAD,
};

bool stopCollector;

typedef struct fsEventRecord
{
    int16_t     type;       // Event type
    u_int16_t   flags;      // Event flags
    uint64_t    time;       // Event Timestamp
    int32_t     pid;        // Process PID
    const char  *path1;     // Path source item (1)
    dev_t       fsid1;      // File system source item (1)
    dev_t       dev1;       // Device source item (1)
    ino_t       inode1;     // Inode source item (1)
    int16_t     vnodetype1; // Vnode type source item (1)
    u_int16_t   mode1;      // Mode source item (1)
    uid_t       uid1;       // User id source item (1)
    gid_t       gid1;       // Group id source item (1)
    const char  *path2;     // Path dest item (2)
    dev_t       fsid2;      // File system source item (2)
    dev_t       dev2;       // Device dest item (2)
    ino_t       inode2;     // Inode dest item (2)
    int16_t     vnodetype2; // Vnode type source item (2)
    u_int16_t   mode2;      // Mode dest item (2)
    uid_t       uid2;       // User id dest item (2)
    gid_t       gid2;       // Group id dest item (2)
} fsEventRecord_t;

static void signalHandler(int value)
{
    printf("\nSignal %d\n", value);
    assert(value == SIGINT);
    stopCollector = true;
}

static const char* getProcessName(pid_t pid)
{
    size_t len = sizeof(struct kinfo_proc);
    static int path[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, 0 };
    static struct kinfo_proc kp;

    path[3] = pid;
    kp.kp_proc.p_comm[0] = '\0';
    if (sysctl((int *)path, sizeof(path) / sizeof(*path), &kp, &len, NULL, 0))
    {
        return (const char*)"Process name not found.";
    }

    if (kp.kp_proc.p_comm[0] == '\0')
    {
        return (const char*)"Process not found.";
    }

    return kp.kp_proc.p_comm;
}

typedef void (^CollectEventBlock)(std::vector<fsEventRecord> &events);

int collectFSEvents(const std::vector<const char*> &folders, bool watchSubfolders, bool collectFolders, CollectEventBlock block);
int collectFSEvents(const std::vector<const char*> &folders, bool watchSubfolders, bool collectFolders, CollectEventBlock block)
{
    int fd, clonefd = -1;
    int eoff, off, ret;
    kfs_event_arg_t *kea;
    struct           fsevent_clone_args fca;
    char             buffer[FSEVENT_BUFSIZ];
    u_int32_t        is_fse_arg_vnode = 0;
    int8_t           event_list[] = { // action to take for each event
                         FSE_REPORT,  // FSE_CREATE_FILE,
                         FSE_REPORT,  // FSE_DELETE,
                         FSE_REPORT,  // FSE_STAT_CHANGED,
                         FSE_REPORT,  // FSE_RENAME,
                         FSE_REPORT,  // FSE_CONTENT_MODIFIED,
                         FSE_REPORT,  // FSE_EXCHANGE,
                         FSE_REPORT,  // FSE_FINDER_INFO_CHANGED,
                         FSE_REPORT,  // FSE_CREATE_DIR,
                         FSE_REPORT,  // FSE_CHOWN,
                         FSE_REPORT,  // FSE_XATTR_MODIFIED,
                         FSE_REPORT,  // FSE_XATTR_REMOVED,
                         FSE_REPORT,  // FSE_DOCID_CREATED,
                         FSE_REPORT,  // FSE_DOCID_CHANGED,
                         FSE_REPORT,  // FSE_UNMOUNT_PENDING,
                         FSE_REPORT,  // FSE_CLONE,
                     };

    dispatch_queue_t queue;
    if (queue == NULL)
    {
        queue = dispatch_queue_create("com.lucaseverini.logger.events", DISPATCH_QUEUE_SERIAL);
    }

    std::vector<const char*> folderPaths;
    for (auto folder = folders.cbegin(); folder != folders.cend(); folder++)
    {
        const char *folderPath = realpath(*folder, NULL);
        if (folderPath == NULL)
        {
            perror("realpath");
            return 1;
        }

        printf("Folder: %s\n", folderPath);

        folderPaths.push_back(folderPath);
    }

    if ((fd = open(DEV_FSEVENTS, O_RDONLY)) < 0)
    {
        perror("open");
        return 1;
    }

    fca.event_list = (int8_t *)event_list;
    fca.num_events = sizeof(event_list) / sizeof(int8_t);
    fca.event_queue_depth = EVENT_QUEUE_SIZE;
    fca.fd = &clonefd;
    if ((ret = ioctl(fd, FSEVENTS_CLONE, (char *)&fca)) < 0)
    {
        perror("ioctl");
        close(fd);
        return 1;
    }

    close(fd);
    printf("fsevents device cloned (fd %d)\nfslogger ready\n", clonefd);

    if ((ret = ioctl(clonefd, FSEVENTS_WANT_EXTENDED_INFO, NULL)) < 0)
    {
        perror("ioctl");
        close(clonefd);
        return 1;
    }

    printf("Started receiving FSEvents...\n");

    std::vector<fsEventRecord> events;

    // event processing loop
    while (stopCollector == false)
    {
        ret = (int)read(clonefd, buffer, FSEVENT_BUFSIZ);
        off = 0;

        // Process received events
        while (off < ret)
        {
            // printf("Processing received event...\n");

            struct kfs_event *kfse = (struct kfs_event*)((char *)buffer + off);
            assert(kfse);

            off += sizeof(int32_t) + sizeof(pid_t); // type + pid

            fsEventRecord_t curEvent;
            memset(&curEvent, 0, sizeof(fsEventRecord_t));
            curEvent.uid1 = -1;
            curEvent.uid2 = -1;
            curEvent.gid1 = -1;
            curEvent.gid2 = -1;
            curEvent.vnodetype1 = -1;
            curEvent.vnodetype2 = -1;

            curEvent.type = kfse->type & FSE_TYPE_MASK;
            curEvent.flags = FSE_GET_FLAGS(kfse->type);
            curEvent.pid = kfse->pid;

            if (curEvent.type == FSE_EVENTS_DROPPED) // special event
            {
                printf("# Event\n");
                printf("  %-14s = %s\n", "type", "EVENTS DROPPED");
                printf("  %-14s = %d\n", "pid", curEvent.pid);
                off += sizeof(u_int16_t); // FSE_ARG_DONE: sizeof(type)
                continue;
            }
#if 0
            if (curEvent.type == FSE_DELETE)
            {
                // Save remaining data
                int fd = open("/tmp/out.dmp", O_CREAT|O_WRONLY, 0600);
                if (fd >=0)
                {
                    write(fd, buffer, ret);
                    close(fd);
                }
            }
#endif
            if ((curEvent.type < FSE_MAX_EVENTS) && (curEvent.type >= -1))
            {
                // printf("# Event\n");
                // printf("  %-14s = %s", "type", kEventNames[curEvent.type]);

                if (curEvent.flags & FSE_COMBINED_EVENTS)
                {
                    printf("##### %s", ", combined events\n");
                }
                if (curEvent.flags & FSE_CONTAINS_DROPPED_EVENTS)
                {
                    printf("##### %s", ", contains dropped events\n");
                }
            }
            else
            {
                // should never happen
                printf("##### Program error (type = %d).\n", curEvent.type);
                return 1;
            }

            // printf("  %-14s = %d (%s)\n", "pid", curEvent.pid, get_proc_name(curEvent.pid));

            // printf("  # Details\n    # %-14s%4s  %s\n", "type", "len", "data");

            kea = kfse->args;
            int argIdx = 0;

            // while ((off < ret) && (i <= FSE_MAX_ARGS))
            while (off < ret)
            {
                argIdx++;

                if (kea->type == FSE_ARG_DONE)
                {
                    // no more arguments
                    // printf("    %s (%#x)\n", "FSE_ARG_DONE", kea->type);
                    off += sizeof(u_int16_t);
                    break;
                }

                eoff = sizeof(kea->type) + sizeof(kea->len) + kea->len;
                off += eoff;

                // int32_t arg_id = (kea->type > FSE_MAX_ARGS) ? 0 : kea->type;
                // printf("    %-16s%4hd  ", kfseArgNames[arg_id], kea->len);

                switch (kea->type)
                {
                    // handle based on argument type
                    case FSE_ARG_VNODE:  // a vnode (string) pointer
                        is_fse_arg_vnode = 1;
                        // printf("%-6s = %s\n", "path", (char *)&(kea->data.vp));
                        break;

                    case FSE_ARG_STRING: // a string pointer
                        if (curEvent.path1 == NULL)
                        {
                            curEvent.path1 = (char*)&(kea->data.str);
                        }
                        else if (curEvent.path2 == NULL)
                        {
                            curEvent.path2 = (char*)&(kea->data.str);
                        }
                        else
                        {
                            printf("##### Program error (type = %d).\n", curEvent.type);
                            return 1;
                        }
                        break;

                    case FSE_ARG_INT64: // timestamp
                        curEvent.time = kea->data.timestamp;
                        break;

                    case FSE_ARG_INT32:
                        break;

                    case FSE_ARG_RAW: // a void pointer
                        break;

                    case FSE_ARG_INO: // an inode number
                        if (curEvent.inode1 == 0)
                        {
                            curEvent.inode1 = kea->data.ino;
                        }
                        else if (curEvent.inode2 == 0)
                        {
                            curEvent.inode2 = kea->data.ino;
                        }
                        else
                        {
                            printf("##### Program error (type = %d).\n", curEvent.type);
                            return 1;
                        }
                        break;

                    case FSE_ARG_UID: // a user ID
                        if (curEvent.uid1 == -1)
                        {
                            curEvent.uid1 = kea->data.uid;
                        }
                        else if (curEvent.uid2 == -1)
                        {
                            curEvent.uid2 = kea->data.uid;
                        }
                        else
                        {
                            printf("##### Program error (type = %d).\n", curEvent.type);
                            return 1;
                        }
                        break;

                    case FSE_ARG_GID: // a group ID
                        if (curEvent.gid1 == -1)
                        {
                            curEvent.gid1 = kea->data.gid;
                        }
                        else if (curEvent.gid2 == -1)
                        {
                            curEvent.gid2 = kea->data.gid;
                        }
                        else
                        {
                            printf("##### Program error (type = %d).\n", curEvent.type);
                            return 1;
                        }
                        break;

                    case FSE_ARG_DEV: // a file system ID or a device number
                        if (is_fse_arg_vnode)
                        {
                            if (curEvent.fsid1 == 0)
                            {
                                curEvent.fsid1 = kea->data.dev;
                            }
                            else if (curEvent.fsid2 == 0)
                            {
                                curEvent.fsid2 = kea->data.dev;
                            }
                            else
                            {
                                printf("##### Program error (type = %d).\n", curEvent.type);
                                return 1;
                            }
                        }
                        else
                        {
                            if (curEvent.dev1 == 0)
                            {
                                curEvent.dev1 = kea->data.dev;
                            }
                            else if (curEvent.dev2 == 0)
                            {
                                curEvent.dev2 = kea->data.dev;
                            }
                            else
                            {
                                printf("##### Program error (type = %d).\n", curEvent.type);
                                return 1;
                            }
                        }
                        break;

                    case FSE_ARG_MODE: // a combination of file mode and file type
                    {
                        u_int32_t va_type = (kea->data.mode & 0xfffff000);
                        va_type = iftovt_tab[(va_type & S_IFMT) >> 12];
                        mode_t va_mode = (kea->data.mode & 0x0000ffff);

                        if (curEvent.vnodetype1 == -1)
                        {
                            curEvent.vnodetype1 = va_type;
                            curEvent.mode1 = va_mode;
                        }
                        else if (curEvent.vnodetype2 == -1)
                        {
                            curEvent.vnodetype2 = va_type;
                            curEvent.mode2 = va_mode;
                        }
                    }
                        break;

                    default:
                        // printf("%-6s = ?\n", "unknown");
                        break;
                }

                kea = (kfs_event_arg_t *)((char *)kea + eoff); // next
            } // for each argument

            if (collectFolders == false && (curEvent.vnodetype1 == 2 && curEvent.vnodetype2 == 2))
            {
                continue;  // Don't collect folders
            }
            if ((curEvent.vnodetype1 != 1 && curEvent.vnodetype2 != 1) &&
                (curEvent.vnodetype1 != 5 && curEvent.vnodetype2 != 5))
            {
                continue;  // Don't collect anynthing else than files && links
            }
            if (curEvent.path1[0] == '\0' && curEvent.path2[0] == '\0')
            {
                continue;  // Should never happen
            }

            char itemName1[NAME_MAX] = "";
            char itemName2[NAME_MAX] = "";
            char itemPath1[PATH_MAX] = "";
            char itemPath2[PATH_MAX] = "";

            char pathBuff1[PATH_MAX] = "";
            const char *realPath1 = pathBuff1;

            char pathBuff2[PATH_MAX] = "";
            const char *realPath2 = pathBuff2;

            // realPath1 = realpath(curEvent.path1, pathBuff1);
            strcpy(pathBuff1, curEvent.path1);
            // if (realPath1 == NULL)
            {
                realPath1 = curEvent.path1;
                if (strncmp("/System/Volumes/Data/", realPath1, strlen("/System/Volumes/Data/")) == 0)
                {
                    realPath1 += strlen("/System/Volumes/Data");
                }
            }
            assert(basename_r(realPath1, itemName1));
            assert(dirname_r(realPath1, itemPath1));

            if (curEvent.path2 != NULL)
            {
                // realPath2 = realpath(curEvent.path2, pathBuff2);
                strcpy(pathBuff2, curEvent.path2);
                // if (realPath2 == NULL)
                {
                    realPath2 = curEvent.path2;
                    if (strncmp("/System/Volumes/Data/", realPath2, strlen("/System/Volumes/Data/")) == 0)
                    {
                        realPath2 += strlen("/System/Volumes/Data");
                    }
                }
                assert(basename_r(realPath2, itemName2));
                assert(dirname_r(realPath2, itemPath2));
            }
#if 0
            printf("path1: %s\n", curEvent.path1);
            printf("realPath1: %s\n", realPath1);
            printf("itemName1: %s\n", itemName1);
            printf("itemPath1: %s\n", itemPath1);
            printf("path2: %s\n", curEvent.path2);
            printf("realPath2: %s\n", realPath2);
            printf("itemName2: %s\n", itemName2);
            printf("itemPath2: %s\n", itemPath2);
#endif
            bool collectEvent = false;
            for (auto folderPath = folderPaths.cbegin(); folderPath != folderPaths.cend(); folderPath++)
            {
                if (strcasecmp(*folderPath, realPath1) == 0)
                {
                    // printf("Event in watched folder: %s\n", curEvent.path1);
                    collectEvent = true;
                    break;
                }

                if (strcasecmp(*folderPath, itemPath1) == 0)
                {
                    // printf("Event item 1 \"%s\" in watched folder \"%s\"\n", itemName1, itemPath1);
                    collectEvent = true;
                    break;
                }

                if (strcasecmp(*folderPath, itemPath2) == 0)
                {
                    // printf("Event item 2 \"%s\" in watched folder \"%s\"\n", itemName2, itemPath2);
                    collectEvent = true;
                    break;
                }
            }

            if (collectEvent == false)
            {
                continue;
            }

            // printf("####### COLLECT EVENT #######\n");

            curEvent.path1 = strdup(curEvent.path1);
            curEvent.path2 = curEvent.path2 != NULL ? strdup(curEvent.path2) : NULL;

            events.push_back(curEvent);
        }

        if (events.empty() == false)
        {
            dispatch_async(queue,
            ^{
                std::vector<fsEventRecord> tmp(events);
                block(tmp);
            });

            events.clear();
        }
    } // forever until signal

    close(clonefd);

    printf("Stopped receiving FSEvents...\n");

    return 0;
}

int main(int argc, char **argv)
{
    if (geteuid() != 0)
    {
        fprintf(stderr, "You must be root.\n");
        exit(1);
    }

    setbuf(stdout, NULL);

    void* prev = (void*)signal(SIGINT, signalHandler);
    assert(prev != SIG_ERR);

    std::vector<const char*> folders;
    folders.push_back("/Volumes/Data/Desktop/MalwareBytes/Test/Folder-1");
    folders.push_back("/Volumes/Data/Desktop/MalwareBytes/Test/Folder-2");
    folders.push_back("/Users/Shared");

    collectFSEvents(folders, false, false,
    ^(std::vector<fsEventRecord> &events)
    {
        printf("#### Events in queue: %d\n", (int)events.size());
        for (auto event = events.cbegin(); event != events.cend(); event++)
        {
            printf("  Event: %s\n", kEventNames[event->type]);
            printf("  Path: %s\n", event->path1);

            printf("  Timestamp: %llu\n", event->time);

            printf("  Pid: %d %s\n",  event->pid, getProcessName(event->pid));

            struct passwd *pws = getpwuid(event->uid1);
            printf("  User: %d %s\n", event->uid1, pws->pw_name);

            if (event->path2 != NULL)
            {
                printf("  Path-2: %s\n", event->path2);
            }
            printf("\n");
        }
    });

    // Keep running
    // [[NSRunLoop currentRunLoop] run];

    printf("Done.\n");

    exit(0);
}
