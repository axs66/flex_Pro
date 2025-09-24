#import "RTBRuntime.h"
#import <mach/mach.h>

@interface RTBRuntime (FLEXSafety)

// 安全的指针读取检查
- (BOOL)flex_pointerIsReadable:(const void *)pointer;
- (BOOL)flex_pointerIsValidObjcObject:(const void *)ptr;

// 获取堆快照
- (NSDictionary *)flex_getHeapSnapshot;

// 基本内存信息
- (NSDictionary *)flex_getBasicMemoryInfo;

// 实例查找方法
- (NSArray *)flex_findInstancesWithPrefix:(NSString *)prefix;
- (NSArray *)flex_safeGetAllInstancesOfClass:(Class)cls;
- (id)flex_safeGetObjectAtAddress:(NSUInteger)address;

@end

@interface NSObject (RTBRuntimeSafety)

+ (NSArray *)flex_safePropertyList;
+ (NSArray *)flex_safeMethodList;
+ (NSArray *)flex_safeProtocolList;
+ (NSArray *)flex_safeIvarList;

@end