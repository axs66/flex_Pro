//
//  NSTextView+SyntaxColoring.m
//  RuntimeBrowser
//
//  Created by Nicolas Seriot on 04.08.08.
//  Copyright 2008 seriot.ch. All rights reserved.
//

// written and optimized for runtime browser

#import "NSString+SyntaxColoring.h"
#import "FLEXCompatibility.h"
#import <UIKit/UIKit.h>

// 定义缺失的颜色常量
#define FLEXSystemPurpleColor [UIColor purpleColor]
#define FLEXSystemCyanColor [UIColor cyanColor]

@implementation NSMutableAttributedString (SyntaxColoring)

- (void)colorizeObjC {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12] 
                 range:NSMakeRange(0, text.length)];
    
    [self addAttribute:NSForegroundColorAttributeName 
                 value:FLEXLabelColor 
                 range:NSMakeRange(0, text.length)];
    
    // Objective-C 关键字
    NSArray *objcKeywords = @[
        @"@interface", @"@implementation", @"@protocol", @"@property", @"@synthesize", @"@dynamic",
        @"@class", @"@public", @"@private", @"@protected", @"@package", @"@optional", @"@required",
        @"@selector", @"@encode", @"@synchronized", @"@try", @"@catch", @"@finally", @"@throw",
        @"@autoreleasepool", @"@available", @"@weakify", @"@strongify", @"@end",
        @"id", @"Class", @"SEL", @"IMP", @"BOOL", @"YES", @"NO", @"nil", @"NULL",
        @"IBOutlet", @"IBAction", @"IBInspectable", @"NS_ENUM", @"NS_OPTIONS",
        @"nonatomic", @"atomic", @"strong", @"weak", @"copy", @"assign", @"retain", @"readonly", @"readwrite",
        @"getter", @"setter", @"nullable", @"nonnull", @"null_resettable", @"_Nullable", @"_Nonnull",
        @"__weak", @"__strong", @"__unsafe_unretained", @"__autoreleasing", @"__block",
        @"void", @"int", @"float", @"double", @"char", @"short", @"long", @"unsigned", @"signed",
        @"const", @"static", @"extern", @"inline", @"typedef", @"struct", @"union", @"enum",
        @"if", @"else", @"switch", @"case", @"default", @"for", @"while", @"do", @"break", @"continue",
        @"return", @"goto", @"sizeof", @"typeof", @"__typeof__", @"self", @"super"
    ];
    
    for (NSString *keyword in objcKeywords) {
        [self highlightKeyword:keyword withColor:FLEXSystemPurpleColor];
    }
    
    // 字符串字面量
    [self highlightPattern:@"@\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"'([^'\\\\]|\\\\.)*'" withColor:FLEXSystemRedColor];
    
    // 注释
    [self highlightPattern:@"//.*$" withColor:FLEXSystemGrayColor options:NSRegularExpressionAnchorsMatchLines];
    [self highlightPattern:@"/\\*[\\s\\S]*?\\*/" withColor:FLEXSystemGrayColor];
    
    // 数字
    [self highlightPattern:@"\\b\\d+(\\.\\d+)?[fFdDlL]?\\b" withColor:FLEXSystemBlueColor];
    [self highlightPattern:@"\\b0[xX][0-9a-fA-F]+\\b" withColor:FLEXSystemBlueColor];
    
    // 预处理指令
    [self highlightPattern:@"^\\s*#\\w+.*$" withColor:FLEXSystemOrangeColor options:NSRegularExpressionAnchorsMatchLines];
    
    // 方法名和选择器
    [self highlightPattern:@"\\w+:" withColor:FLEXSystemCyanColor];
    
    // 类名（大写字母开头）
    [self highlightPattern:@"\\b[A-Z][A-Za-z0-9_]*\\b" withColor:FLEXSystemGreenColor];
}

- (void)colorizeSwift {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12] 
                 range:NSMakeRange(0, text.length)];
    
    // Swift 关键字
    NSArray *swiftKeywords = @[
        @"class", @"struct", @"enum", @"protocol", @"extension", @"func", @"var", @"let",
        @"import", @"if", @"else", @"switch", @"case", @"default", @"for", @"while", @"repeat",
        @"break", @"continue", @"return", @"throw", @"try", @"catch", @"guard", @"defer",
        @"init", @"deinit", @"subscript", @"override", @"final", @"open", @"public", @"internal",
        @"fileprivate", @"private", @"static", @"mutating", @"nonmutating", @"convenience",
        @"required", @"optional", @"lazy", @"weak", @"unowned", @"indirect", @"inout",
        @"true", @"false", @"nil", @"self", @"Self", @"super"
    ];
    
    for (NSString *keyword in swiftKeywords) {
        [self highlightKeyword:keyword withColor:FLEXSystemPurpleColor];
    }
    
    // 字符串字面量
    [self highlightPattern:@"\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"'([^'\\\\]|\\\\.)*'" withColor:FLEXSystemRedColor];
    
    // 注释
    [self highlightPattern:@"//.*$" withColor:FLEXSystemGrayColor options:NSRegularExpressionAnchorsMatchLines];
    [self highlightPattern:@"/\\*[\\s\\S]*?\\*/" withColor:FLEXSystemGrayColor];
    
    // 数字
    [self highlightPattern:@"\\b\\d+(\\.\\d+)?\\b" withColor:FLEXSystemBlueColor];
    
    // 类型注解
    [self highlightPattern:@":\\s*[A-Za-z_][A-Za-z0-9_]*" withColor:FLEXSystemOrangeColor];
}

- (void)colorizeJSON {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12] 
                 range:NSMakeRange(0, text.length)];
    
    // JSON 字符串
    [self highlightPattern:@"\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    
    // JSON 数字
    [self highlightPattern:@"\\b-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b" withColor:FLEXSystemBlueColor];
    
    // JSON 布尔值和null
    [self highlightKeyword:@"true" withColor:FLEXSystemGreenColor];
    [self highlightKeyword:@"false" withColor:FLEXSystemGreenColor];
    [self highlightKeyword:@"null" withColor:FLEXSystemGrayColor];
    
    // JSON 结构符号
    [self highlightPattern:@"[{}\\[\\]]" withColor:FLEXSystemPurpleColor];
    [self highlightPattern:@"[,:]" withColor:FLEXSystemOrangeColor];
}

- (void)colorizeXML {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12] 
                 range:NSMakeRange(0, text.length)];
    
    // XML 标签
    [self highlightPattern:@"<[^>]+>" withColor:FLEXSystemBlueColor];
    
    // XML 属性
    [self highlightPattern:@"\\w+=" withColor:FLEXSystemOrangeColor];
    
    // XML 属性值
    [self highlightPattern:@"=\"[^\"]*\"" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"='[^']*'" withColor:FLEXSystemRedColor];
    
    // XML 注释
    [self highlightPattern:@"<!--[\\s\\S]*?-->" withColor:FLEXSystemGrayColor];
    
    // CDATA
    [self highlightPattern:@"<!\\[CDATA\\[[\\s\\S]*?\\]\\]>" withColor:FLEXSystemGreenColor];
}

- (void)colorizeJavaScript {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // JavaScript 关键字
    NSArray *jsKeywords = @[
        @"abstract", @"arguments", @"await", @"boolean", @"break", @"byte", @"case", @"catch",
        @"char", @"class", @"const", @"continue", @"debugger", @"default", @"delete", @"do",
        @"double", @"else", @"enum", @"eval", @"export", @"extends", @"false", @"final",
        @"finally", @"float", @"for", @"function", @"goto", @"if", @"implements", @"import",
        @"in", @"instanceof", @"int", @"interface", @"let", @"long", @"native", @"new",
        @"null", @"package", @"private", @"protected", @"public", @"return", @"short",
        @"static", @"super", @"switch", @"synchronized", @"this", @"throw", @"throws",
        @"transient", @"true", @"try", @"typeof", @"undefined", @"var", @"void", @"volatile",
        @"while", @"with", @"yield"
    ];
    
    for (NSString *keyword in jsKeywords) {
        [self highlightKeyword:keyword withColor:FLEXSystemPurpleColor];
    }
    
    // 字符串和正则表达式
    [self highlightPattern:@"\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"'([^'\\\\]|\\\\.)*'" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"`([^`\\\\]|\\\\.)*`" withColor:FLEXSystemRedColor]; // 模板字符串
    [self highlightPattern:@"/([^/\\\\]|\\\\.)+/[gimuy]*" withColor:FLEXSystemGreenColor]; // 正则表达式
    
    // 注释
    [self highlightPattern:@"//.*$" withColor:FLEXSystemGrayColor options:NSRegularExpressionAnchorsMatchLines];
    [self highlightPattern:@"/\\*[\\s\\S]*?\\*/" withColor:FLEXSystemGrayColor];
    
    // 数字
    [self highlightPattern:@"\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b" withColor:FLEXSystemBlueColor];
}

- (void)colorizeCSS {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // CSS 选择器
    [self highlightPattern:@"[.#]?[a-zA-Z_][a-zA-Z0-9_-]*(?=\\s*\\{)" withColor:FLEXSystemBlueColor];
    
    // CSS 属性
    [self highlightPattern:@"[a-zA-Z-]+(?=\\s*:)" withColor:FLEXSystemOrangeColor];
    
    // CSS 值
    [self highlightPattern:@":\\s*[^;]+;" withColor:FLEXSystemGreenColor];
    
    // CSS 字符串
    [self highlightPattern:@"\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self highlightPattern:@"'([^'\\\\]|\\\\.)*'" withColor:FLEXSystemRedColor];
    
    // CSS 注释
    [self highlightPattern:@"/\\*[\\s\\S]*?\\*/" withColor:FLEXSystemGrayColor];
    
    // CSS 数字和单位
    [self highlightPattern:@"\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|pt|pc|in|cm|mm|ex|ch|vmin|vmax|deg|rad|turn|s|ms|Hz|kHz|dpi|dpcm|dppx)?\\b" withColor:FLEXSystemCyanColor];
}

- (void)colorizePlist {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // Plist 键
    [self highlightPattern:@"<key>([^<]+)</key>" withColor:FLEXSystemBlueColor];
    
    // Plist 字符串值
    [self highlightPattern:@"<string>([^<]*)</string>" withColor:FLEXSystemRedColor];
    
    // Plist 数字值
    [self highlightPattern:@"<(integer|real)>([^<]+)</(integer|real)>" withColor:FLEXSystemGreenColor];
    
    // Plist 布尔值
    [self highlightPattern:@"<(true|false)/>" withColor:FLEXSystemOrangeColor];
    
    // Plist 日期
    [self highlightPattern:@"<date>([^<]+)</date>" withColor:FLEXSystemCyanColor];
    
    // Plist 数据
    [self highlightPattern:@"<data>([^<]*)</data>" withColor:FLEXSystemPurpleColor];
    
    // XML 标签
    [self highlightPattern:@"<[^>]+>" withColor:FLEXSystemGrayColor];
}

#pragma mark - Helper Methods

- (void)highlightKeyword:(NSString *)keyword withColor:(UIColor *)color {
    NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", [NSRegularExpression escapedPatternForString:keyword]];
    [self highlightPattern:pattern withColor:color];
}

- (void)highlightPattern:(NSString *)pattern withColor:(UIColor *)color {
    [self highlightPattern:pattern withColor:color options:0];
}

- (void)highlightPattern:(NSString *)pattern withColor:(UIColor *)color options:(NSRegularExpressionOptions)options {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
    
    if (error) {
        NSLog(@"Regex error for pattern '%@': %@", pattern, error.localizedDescription);
        return;
    }
    
    NSString *text = self.string;
    [regex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [self addAttribute:NSForegroundColorAttributeName value:color range:match.range];
    }];
}

@end

@implementation NSString (SyntaxColoring)

- (NSAttributedString *)colorizeWithKeywords:(NSArray *)keywords classes:(NSArray *)classes colorize:(BOOL)colorize {
    if (!colorize) {
        return [[NSAttributedString alloc] initWithString:self];
    }
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:self];
    
    // 默认文本属性
    UIFont *font = [UIFont fontWithName:@"Menlo" size:12.0];
    if (!font) {
        font = [UIFont fontWithName:@"Courier" size:12.0];
    }
    
    [attributedString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, self.length)];
    
    // 对关键字进行高亮
    if (keywords) {
        for (NSString *keyword in keywords) {
            NSRange searchRange = NSMakeRange(0, self.length);
            NSRange foundRange;
            
            while ((foundRange = [self rangeOfString:keyword options:0 range:searchRange]).location != NSNotFound) {
                // 确保是单词边界
                BOOL isWordStart = (foundRange.location == 0) || 
                    ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[self characterAtIndex:foundRange.location-1]];
                BOOL isWordEnd = (NSMaxRange(foundRange) == self.length) || 
                    ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[self characterAtIndex:NSMaxRange(foundRange)]];
                
                if (isWordStart && isWordEnd) {
                    [attributedString addAttribute:NSForegroundColorAttributeName 
                                            value:[UIColor blueColor] 
                                            range:foundRange];
                }
                
                searchRange.location = NSMaxRange(foundRange);
                searchRange.length = self.length - searchRange.location;
                
                if (searchRange.length == 0) {
                    break;
                }
            }
        }
    }
    
    // 对类名进行高亮
    if (classes) {
        for (NSString *className in classes) {
            NSRange searchRange = NSMakeRange(0, self.length);
            NSRange foundRange;
            
            while ((foundRange = [self rangeOfString:className options:0 range:searchRange]).location != NSNotFound) {
                [attributedString addAttribute:NSForegroundColorAttributeName 
                                        value:[UIColor purpleColor] 
                                        range:foundRange];
                
                searchRange.location = NSMaxRange(foundRange);
                searchRange.length = self.length - searchRange.location;
                
                if (searchRange.length == 0) {
                    break;
                }
            }
        }
    }
    
    return attributedString;
}

@end
