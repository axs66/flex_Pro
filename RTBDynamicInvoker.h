#import <Foundation/Foundation.h>

@interface RTBDynamicInvoker : NSObject

// 动态调用实例方法
+ (id)invokeMethod:(SEL)selector onTarget:(id)target withArguments:(NSArray *)arguments;

// 动态调用类方法
+ (id)invokeClassMethod:(SEL)selector onClass:(Class)cls withArguments:(NSArray *)arguments;

@end