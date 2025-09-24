#import "FLEXRuntimeClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLEXRuntimeClient (RuntimeBrowser)

/// 获取指定类的所有实例
- (NSArray *)getAllInstancesOfClass:(Class)cls;

/// 获取指定类的实例数量
- (NSUInteger)getInstanceCountForClass:(Class)cls;

/// 获取指定类名的所有子类
- (NSArray *)subclassesOfClass:(NSString *)className;

/// 为指定类生成头文件
- (NSString *)generateHeaderForClass:(Class)cls;

// 其他现有方法...

@end

@interface FLEXRuntimeClient (RuntimeBrowserAdditions)

// 添加缺少的方法声明
- (NSArray *)sortedClassStubs;
- (NSArray *)rootClasses;
- (void)emptyCachesAndReadAllRuntimeClasses;
- (NSDictionary *)getDetailedClassInfo:(Class)cls;
- (NSString *)generateHeaderForClass:(Class)cls;

@end

NS_ASSUME_NONNULL_END