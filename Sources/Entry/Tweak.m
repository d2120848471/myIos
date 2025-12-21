#import <UIKit/UIKit.h>

#import "ATWindowManager.h"

/// dylib 入口：App 启动后创建悬浮窗。
__attribute__((constructor))
static void AutoTapInit(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            [[ATWindowManager shared] start];
        }];

        // 某些注入时机下可能已经完成启动，兜底直接启动一次。
        if ([UIApplication sharedApplication]) {
            [[ATWindowManager shared] start];
        }
    });
}

