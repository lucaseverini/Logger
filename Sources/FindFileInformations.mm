//
//  FindFileInformations.mm
//  Logger
//
//  Created by Luca Severini on 8-Sep-2021.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <libproc.h>
#include <sys/sysctl.h>
#include <pwd.h>
#include "FindFileInformations.h"

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

// --------------------------------------------------------------------------
pid_t* pidlist(int *listSize)
{
    int bufsize = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    assert(bufsize > 0);
    pid_t pids[(bufsize / sizeof(pid_t)) * 2];
    bufsize = proc_listpids(PROC_ALL_PIDS, 0, pids, (int)sizeof(pids));
    assert(bufsize > 0);
    pid_t *list = (pid_t*)malloc(bufsize);
    memcpy(list, pids, bufsize);
    int num_pids = bufsize / sizeof(pid_t);
    *listSize = num_pids;
    return list;
}

// --------------------------------------------------------------------------
uid_t uidFromPid(pid_t pid)
{
    uid_t uid = -1;

    struct kinfo_proc process;
    size_t procBufferSize = sizeof(process);
    int path[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    int result = sysctl(path, sizeof(path) / sizeof(int), &process, &procBufferSize, NULL, 0);
    if (result == 0 && procBufferSize != 0)
    {
        uid = process.kp_eproc.e_ucred.cr_uid;
    }

    return uid;
}

// --------------------------------------------------------------------------
int findFileInformations(const char *path, int *foundPid, int *foundUid, const char* *foundUname)
{
    *foundPid = -1;
    *foundUid = -1;
    *foundUname = NULL;

    printf("File: %s\n", path);

    int numPids = 0;
    pid_t *pids = pidlist(&numPids);
    assert(pids != NULL && numPids > 0);

    int pidFound = 0;
    for (int idx = 0; idx < numPids; idx++)
    {
        if (pidFound != 0)
        {
            break;
        }

        int pid = pids[idx];

        struct proc_fdinfo *fds = NULL;
        int fds_count = 0;
        size_t fds_size = 0;

        int buf_used = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
        if (buf_used <= 0)
        {
            continue;
        }

        while (1)
        {
            if (buf_used > fds_size)
            {
                // if we need to allocate [more] space
                while (buf_used > fds_size)
                {
                    fds_size += (sizeof(struct proc_fdinfo) * 32);
                }

                if (fds == NULL)
                {
                    fds = (struct proc_fdinfo*)malloc(fds_size);
                }
                else
                {
                    fds = (struct proc_fdinfo*)reallocf(fds, fds_size);
                }
                if (fds == NULL)
                {
                    return -1;
                }
            }

            buf_used = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, (int)fds_size);
            if (buf_used <= 0)
            {
                return -1;
            }

            if ((buf_used + sizeof(struct proc_fdinfo)) >= fds_size)
            {
                // if not enough room in the buffer for an extra fd
                buf_used = (int)(fds_size + sizeof(struct proc_fdinfo));
                // continue;
            }

            fds_count = (int)(buf_used / sizeof(struct proc_fdinfo));
            break;
        }

        for (int i = 0; i < fds_count; i++)
        {
            struct proc_fdinfo *fdp;

            fdp = &fds[i];

            switch (fdp->proc_fdtype)
            {
                case PROX_FDTYPE_VNODE :
                {
                    int buf_used;
#if 1
                    struct vnode_fdinfowithpath pi;
                    buf_used = proc_pidfdinfo(pid, fdp->proc_fd, PROC_PIDFDVNODEPATHINFO, &pi, sizeof(pi));
                    if (buf_used <= 0)
                    {
                        printf("errno: %s\n", strerror(errno));
                        if (errno == ENOENT)
                        {
                            /*
                             * The file descriptor's vnode may have been revoked. This is a
                             * bit of a hack, since an ENOENT error might not always mean the
                             * descriptor's vnode has been revoked. As the libproc API
                             * matures, this code may need to be revisited.
                             */
                        }
                        continue;
                    }
                    else if (buf_used < sizeof(pi))
                    {
                        // Not enough information
                        return -1;
                    }
                    else
                    {
                        // printf("path: %s\n", pi.pvip.vip_path);

                        if (strcmp(pi.pvip.vip_path, path) == 0)
                        {
                            pidFound = pid;
                            break;
                        }
                    }
#endif
#if 0
                    struct stat statBuf;
                    int ret = stat(path, &statBuf);
                    if (ret != 0)
                    {
                        return -1;
                    }

                    struct vnode_fdinfo vi;
                    buf_used = proc_pidfdinfo(pid, fdp->proc_fd, PROC_PIDFDVNODEINFO, &vi, sizeof(vi));
                    if (buf_used <= 0)
                    {
                        printf("errno: %s\n", strerror(errno));
                        if (errno == ENOENT)
                        {
                            /*
                             * The file descriptor's vnode may have been revoked. This is a
                             * bit of a hack, since an ENOENT error might not always mean the
                             * descriptor's vnode has been revoked. As the libproc API
                             * matures, this code may need to be revisited.
                             */
                        }
                        continue;
                    }
                    else if (buf_used < sizeof(vi))
                    {
                        // Not enough information
                        return -1;
                    }

                    if (vi.pvi.vi_stat.vst_ino == statBuf.st_ino && vi.pvi.vi_stat.vst_dev == statBuf.st_dev)
                    {
                        pidFound = pid;
                        break;
                     }
#endif
                    break;
                }
                default :
                    break;
            }
        }
    }

    if (pidFound)
    {
        int uid = uidFromPid(pidFound);
        struct passwd *pws = getpwuid(uid);

        *foundPid = pidFound;
        *foundUid = uid;
        *foundUname = pws != NULL ? pws->pw_name : NULL;
        
        return 1;
    }

    return 0;
}

