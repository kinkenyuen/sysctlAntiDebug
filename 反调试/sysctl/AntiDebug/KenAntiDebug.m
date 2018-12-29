//
//  KenAntiDebug.m
//  AntiDebug
//
//  Created by kinken on 2018/12/28.
//  Copyright © 2018 kinkenyuen. All rights reserved.
//

#import "KenAntiDebug.h"
#import <sys/sysctl.h>
#import <sys/types.h>
#import <dlfcn.h>

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
#if !defined(PT_DENY_ATTACH)
#define PT_DENY_ATTACH 31
#endif

@implementation KenAntiDebug

+ (void)load {
    //开启定时器检测
    debugCheckTiming();
}

BOOL isDebuggingWithSysctl(){
    /**
     需要检测进程信息的字段数组
     */
    int name[4];
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();

    /**
     查询进程信息结果的结构体
     */
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    info.kp_proc.p_flag = 0;

    /*查询成功返回0*/
    int error = sysctl(name, sizeof(name) / sizeof(*name), &info, &info_size, NULL, 0);
    if (error == -1) {
        NSLog(@"sysctl process check error ...");
        return NO;
    }

    /*根据标记位检测调试状态*/
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}

/**
 定时器检测是否在调试状态
 */
static dispatch_source_t timer;
void debugCheckTiming() {
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        if (isDebuggingWithSysctl()) {
            NSLog(@"检测到调试");
            //1、使用exit退出
            exit(-1);
            //2、使用ptrace退出
//            void* handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
//            ptrace_ptr_t ptrace_ptr = dlsym(handle, "ptrace");
//            ptrace_ptr(31, 0, 0, 0);
//            dlclose(handle);
        }else {
            NSLog(@"正常");
        }
    });
    dispatch_resume(timer);
}

@end
