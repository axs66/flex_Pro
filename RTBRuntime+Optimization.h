#import "RTBRuntime.h"

@interface RTBRuntime (Optimization)

/**
 * 检查运行时是否已准备就绪
 * @return 如果运行时已准备就绪，返回YES
 */
+ (BOOL)isRuntimeReady;

/**
 * 异步读取所有运行时类
 * @param completion 完成后的回调，参数表示是否成功
 */
- (void)readAllRuntimeClassesAsync:(void(^)(BOOL success))completion;

@end