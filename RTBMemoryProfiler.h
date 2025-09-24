#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RTBMemoryProfiler : NSObject

// 内存分析
+ (void)startMemoryTracking;
+ (void)stopMemoryTracking;
+ (NSDictionary * _Nonnull)getMemoryProfile;

// 对象引用分析
- (void)trackObjectReferences:(id _Nullable)object;
- (NSArray * _Nonnull)getObjectReferencesChain;

// 循环引用检测
- (void)detectRetainCycles;
- (NSArray * _Nonnull)getRetainCycleInfo;

// 获取共享实例
+ (instancetype _Nonnull)sharedInstance;

@end

NS_ASSUME_NONNULL_END