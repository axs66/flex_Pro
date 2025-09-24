#import "FLEXHookDetector+RuntimeBrowser.h"
#import <dlfcn.h>

@implementation FLEXHookDetector (RuntimeBrowser)

// 删除 getDetailedHookAnalysis 方法的实现，因为已经在主类中实现了

// 删除 getSwizzledMethodsForClass 方法的实现，因为已经在主类中实现了

// 删除 isMethodSwizzled 方法的实现，因为已经在主类中实现了

// 保留这个只在分类中定义的方法
- (NSArray *)getKnownHookingFrameworks {
    NSMutableArray *frameworks = [NSMutableArray array];
    
    NSArray *knownFrameworks = @[
        @"libfishhook.dylib",
        @"CydiaSubstrate.framework",
        @"substitute.dylib",
        @"frida-agent.dylib",
        @"Aspects.framework",
        @"libhooker.dylib"
    ];
    
    for (NSString *framework in knownFrameworks) {
        void *handle = dlopen(framework.UTF8String, RTLD_NOLOAD);
        if (handle) {
            [frameworks addObject:@{
                @"name": framework,
                @"loaded": @YES
            }];
            dlclose(handle);
        } else {
            [frameworks addObject:@{
                @"name": framework,
                @"loaded": @NO
            }];
        }
    }
    
    return frameworks;
}

@end