//
//  NSMutableAttributedString+RTB.h
//  OCRuntime
//
//  Created by Nicolas Seriot on 7/21/13.
//  Copyright (c) 2013 Nicolas Seriot. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 运行时浏览器专用的属性字符串扩展
@interface NSMutableAttributedString (RTB)

/// 高亮Objective-C代码
- (void)rtb_highlightObjCCode;

/// 高亮运行时方法签名
- (void)rtb_highlightRuntimeMethodSignature;

/// 高亮属性特性字符串
- (void)rtb_highlightPropertyAttributes;

/// 高亮类型编码字符串
- (void)rtb_highlightTypeEncoding;

/// 高亮类层次结构
- (void)rtb_highlightClassHierarchy;

@end

NS_ASSUME_NONNULL_END
