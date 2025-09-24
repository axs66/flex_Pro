//
//  NSObject+Doraemon.h
//  FLEX_Pro
//
//  Created on 2025/6/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Doraemon)

/**
 交换实例方法的实现
 
 @param originalSel 原始方法selector
 @param swizzledSel 交换后的方法selector
 */
+ (void)doraemon_swizzleInstanceMethodWithOriginSel:(SEL)originalSel swizzledSel:(SEL)swizzledSel;

/**
 交换类方法的实现
 
 @param originalSel 原始方法selector
 @param swizzledSel 交换后的方法selector
 */
+ (void)doraemon_swizzleClassMethodWithOriginSel:(SEL)originalSel swizzledSel:(SEL)swizzledSel;

@end

NS_ASSUME_NONNULL_END