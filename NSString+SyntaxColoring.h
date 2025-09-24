//
//  NSTextView+SyntaxColoring.h
//  RuntimeBrowser
//
//  Created by Nicolas Seriot on 04.08.08.
//  Copyright 2008 seriot.ch. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 语法高亮扩展
@interface NSMutableAttributedString (SyntaxColoring)

/// 为Objective-C代码添加语法高亮
- (void)colorizeObjC;

/// 为Swift代码添加语法高亮
- (void)colorizeSwift;

/// 为JSON添加语法高亮
- (void)colorizeJSON;

/// 为XML/HTML添加语法高亮
- (void)colorizeXML;

/// 为JavaScript添加语法高亮
- (void)colorizeJavaScript;

/// 为CSS添加语法高亮
- (void)colorizeCSS;

/// 为Plist添加语法高亮
- (void)colorizePlist;

@end

@interface NSString (SyntaxColoring)

/// 使用关键字和类名进行语法高亮
- (NSAttributedString *)colorizeWithKeywords:(NSArray *)keywords classes:(nullable NSArray *)classes colorize:(BOOL)colorize;

@end

NS_ASSUME_NONNULL_END
