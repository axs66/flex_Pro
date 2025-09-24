#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface RTBHookManager : NSObject

+ (instancetype)sharedInstance;

// 基于DoKit的Hook机制
- (BOOL)hookClass:(Class)targetClass 
         selector:(SEL)originalSEL 
   withBlockImps:(id)block;

// 恢复Hook
- (BOOL)unhookClass:(Class)targetClass selector:(SEL)originalSEL;

// 获取所有已Hook的方法
- (NSArray *)getAllHookedMethods;

// 监控方法调用
- (void)startMethodCallMonitoring;
- (void)stopMethodCallMonitoring;

@end