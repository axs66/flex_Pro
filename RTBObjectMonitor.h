#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 对象运行时监控器
 * 用于监控对象的方法调用和行为
 */
@interface RTBObjectMonitor : NSObject

/**
 * 开始监控指定对象
 * @param object 要监控的对象
 */
+ (void)startMonitoringObject:(id)object;

/**
 * 停止监控指定对象
 * @param object 要停止监控的对象
 */
+ (void)stopMonitoringObject:(id)object;

/**
 * 创建监控的实现
 * @param selector 要监控的方法选择器
 * @return 监控实现
 */
+ (IMP)createMonitoredImplementationForSelector:(SEL)selector;

@end

NS_ASSUME_NONNULL_END