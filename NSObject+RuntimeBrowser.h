#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (RuntimeBrowser)

/**
 * 获取对象的所有属性
 */
- (NSArray *)rtb_allProperties;

/**
 * 获取对象的所有实例变量
 */
- (NSArray *)rtb_allIvars;

/**
 * 获取对象的所有方法
 */
- (NSArray *)rtb_allMethods;

/**
 * 获取类继承层次
 */
- (NSArray *)rtb_classHierarchy;

/**
 * 检查对象是否响应选择器（安全方式）
 */
- (BOOL)rtb_respondsToSelector:(SEL)selector;

/**
 * 获取对象的详细描述
 */
- (NSString *)rtb_detailedDescription;

@end

NS_ASSUME_NONNULL_END