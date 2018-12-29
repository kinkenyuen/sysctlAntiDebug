//  weibo: http://weibo.com/xiaoqing28
//  blog:  http://www.alonemonkey.com
//
//  AntiDebugTestDylib.m
//  AntiDebugTestDylib
//
//  Created by kinken on 2018/12/28.
//  Copyright (c) 2018 kinkenyuen. All rights reserved.
//

#import "AntiDebugTestDylib.h"
#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <Cycript/Cycript.h>
#import <MDCycriptManager.h>

#import "fishhook/fishhook.h"
#import <sys/sysctl.h>

CHConstructor{
    NSLog(INSERT_SUCCESS_WELCOME);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        
#ifndef __OPTIMIZE__
        CYListenServer(6666);

        MDCycriptManager* manager = [MDCycriptManager sharedInstance];
        [manager loadCycript:NO];

        NSError* error;
        NSString* result = [manager evaluateCycript:@"UIApp" error:&error];
        NSLog(@"result: %@", result);
        if(error.code != 0){
            NSLog(@"error: %@", error.localizedDescription);
        }
#endif
        
    }];
}

@implementation AntiAntiDebug

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
int my_sysctl(int *name, u_int nameLen ,void *info ,size_t *info_size, void *newp, size_t newLen);

+ (void)load {
    rebind_symbols((struct rebinding[1]){{"sysctl",my_sysctl,(void *)&orig_sysctl}}, 1);
}

int my_sysctl(int *name, u_int nameLen ,void *info ,size_t *info_size, void *newp, size_t newLen) {
    if (nameLen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID && info && info_size && ((int)*info_size == sizeof(struct kinfo_proc))) {
        //先调用原始sysctl查询进程信息
        int result = orig_sysctl(name, nameLen, info, info_size, NULL, 0);
        
        //获取进程信息
        struct kinfo_proc *info_ptr = (struct kinfo_proc *)info;
        NSLog(@"检测到调试时p_flag的值:%d",info_ptr->kp_proc.p_flag);
        
        if (info_ptr && (info_ptr->kp_proc.p_flag & P_TRACED) != 0) {
            NSLog(@"检测到反调试，尝试绕过...");
            //两个值按位异或，赋值给p_flag，实质是将p_flag的第12位标记位改为0
            info_ptr->kp_proc.p_flag ^= P_TRACED;
            if ((info_ptr->kp_proc.p_flag & P_TRACED) == 0) {
                NSLog(@"反反调试成功!");
            }
        }
        NSLog(@"去掉检测调试后p_flag的值:%d",info_ptr->kp_proc.p_flag);
        return result;
    }
    return orig_sysctl(name, nameLen, info, info_size, NULL, 0);
}

@end


