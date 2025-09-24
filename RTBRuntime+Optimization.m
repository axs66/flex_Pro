#import "RTBRuntime+Optimization.h"

@implementation RTBRuntime (Optimization)

+ (BOOL)isRuntimeReady {
    RTBRuntime *runtime = [RTBRuntime sharedInstance];
    return runtime.rootClasses.count > 0;
}

- (void)readAllRuntimeClassesAsync:(void(^)(BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            [self readAllRuntimeClasses];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(YES);
            });
        } @catch (NSException *exception) {
            NSLog(@"RuntimeBrowser: 读取类失败 - %@", exception.reason);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO);
            });
        }
    });
}

@end