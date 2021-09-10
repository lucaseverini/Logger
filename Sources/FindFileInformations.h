//
//  FindFileInformations.h
//  Logger
//
//  Created by Luca Severini on 8-Sep-2021.
//

#include <stdio.h>

pid_t* pidlist(int *listSize);
uid_t uidFromPid(pid_t pid);
int findFileInformations(const char *path, int *foundPid, int *foundUid, const char* *foundUname);
