#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface RTBSwizzlingHelper : NSObject

/**
 * 使用指定方法和选择器进行方法交换
 * @param oriSel 原始选择器
 * @param oriMethod 原始方法
 * @param swizzledSel 替换选择器
 * @param swizzledMethod 替换方法
 * @param cls 目标类
 */
+ (void)swizzleMethodWithOriginSel:(SEL)oriSel
                         oriMethod:(Method)oriMethod
                       swizzledSel:(SEL)swizzledSel
                    swizzledMethod:(Method)swizzledMethod
                            class:(Class)cls;

/**
 * 交换类方法
 * @param oriSel 原始选择器
 * @param swiSel 替换选择器
 * @param cls 目标类
 */
+ (void)swizzleClassMethodWithOriginSel:(SEL)oriSel
                            swizzledSel:(SEL)swiSel
                                  class:(Class)cls;

/**
 * 交换实例方法
 * @param oriSel 原始选择器
 * @param swiSel 替换选择器
 * @param cls 目标类
 */
+ (void)swizzleInstanceMethodWithOriginSel:(SEL)oriSel
                              swizzledSel:(SEL)swiSel
                                    class:(Class)cls;

@end

NS_ASSUME_NONNULL_END