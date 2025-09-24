//
//  NSMutableAttributedString+RTB.m
//  OCRuntime
//
//  Created by Nicolas Seriot on 7/21/13.
//  Copyright (c) 2013 Nicolas Seriot. All rights reserved.
//

#import "NSMutableAttributedString+RTB.h"
#import "FLEXCompatibility.h"
#import "FLEXColor.h"

// 定义平台相关的颜色和字体类型
#if TARGET_OS_IPHONE
typedef UIColor ColorClass;
typedef UIFont FontClass;
#else
typedef NSColor ColorClass;
typedef NSFont FontClass;
#endif

// 定义缺失的颜色常量，使用兼容 iOS 9.0 的颜色
#define FLEXSystemPurpleColor [UIColor purpleColor]
// 使用标准的 cyanColor 替代 systemCyanColor
#define FLEXSystemCyanColor [UIColor cyanColor]

@implementation NSMutableAttributedString (RTB)

- (void)setTextColor:(ColorClass *)color font:(FontClass *)font range:(NSRange)range {
    if(range.location + range.length > [self length]) return;
    
    #if TARGET_OS_IPHONE
    NSDictionary *d = @{
        NSForegroundColorAttributeName : color,
        NSFontAttributeName : font
    };
    #else
    NSDictionary *d = @{
        NSForegroundColorAttributeName : color,
        NSFontAttributeName : font
    };
    #endif
    
    [self setAttributes:d range:range];
}

- (void)rtb_highlightObjCCode {
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
        @"@autoreleasepool", @"@available", @"@weakify", @"@strongify",
        @"id", @"Class", @"SEL", @"IMP", @"BOOL", @"YES", @"NO", @"nil", @"NULL",
        @"IBOutlet", @"IBAction", @"IBInspectable", @"NS_ENUM", @"NS_OPTIONS",
        @"nonatomic", @"atomic", @"strong", @"weak", @"copy", @"assign", @"retain", @"readonly", @"readwrite",
        @"getter", @"setter", @"nullable", @"nonnull", @"null_resettable", @"_Nullable", @"_Nonnull",
        @"__weak", @"__strong", @"__unsafe_unretained", @"__autoreleasing", @"__block",
        @"void", @"int", @"float", @"double", @"char", @"short", @"long", @"unsigned", @"signed",
        @"const", @"static", @"extern", @"inline", @"typedef", @"struct", @"union", @"enum",
        @"if", @"else", @"switch", @"case", @"default", @"for", @"while", @"do", @"break", @"continue",
        @"return", @"goto", @"sizeof", @"typeof", @"__typeof__"
    ];
    
    for (NSString *keyword in objcKeywords) {
        [self rtb_highlightKeyword:keyword withColor:FLEXSystemPurpleColor];
    }
    
    // 字符串字面量
    [self rtb_highlightPattern:@"@\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self rtb_highlightPattern:@"\"([^\"\\\\]|\\\\.)*\"" withColor:FLEXSystemRedColor];
    [self rtb_highlightPattern:@"'([^'\\\\]|\\\\.)*'" withColor:FLEXSystemRedColor];
    
    // 注释
    [self rtb_highlightPattern:@"//.*$" withColor:FLEXSystemGrayColor options:NSRegularExpressionAnchorsMatchLines];
    [self rtb_highlightPattern:@"/\\*[\\s\\S]*?\\*/" withColor:FLEXSystemGrayColor];
    
    // 数字
    [self rtb_highlightPattern:@"\\b\\d+(\\.\\d+)?[fFdDlL]?\\b" withColor:FLEXSystemBlueColor];
    [self rtb_highlightPattern:@"\\b0[xX][0-9a-fA-F]+\\b" withColor:FLEXSystemBlueColor];
    
    // 预处理指令
    [self rtb_highlightPattern:@"^\\s*#\\w+.*$" withColor:FLEXSystemOrangeColor options:NSRegularExpressionAnchorsMatchLines];
}

- (void)rtb_highlightRuntimeMethodSignature {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11] 
                 range:NSMakeRange(0, text.length)];
    
    // 方法类型标识符 (- 或 +)
    [self rtb_highlightPattern:@"^[-+]" withColor:FLEXSystemBlueColor];
    
    // 返回类型
    [self rtb_highlightPattern:@"\\([^)]+\\)" withColor:FLEXSystemOrangeColor];
    
    // 方法名部分
    [self rtb_highlightPattern:@"\\w+:" withColor:FLEXSystemPurpleColor];
    
    // 参数类型
    [self rtb_highlightPattern:@"\\([^)]+\\)\\s*\\w+" withColor:FLEXSystemGreenColor];
}

- (void)rtb_highlightPropertyAttributes {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11] 
                 range:NSMakeRange(0, text.length)];
    
    // 属性特性关键字
    NSArray *propertyAttributes = @[
        @"nonatomic", @"atomic", @"strong", @"weak", @"copy", @"assign", @"retain",
        @"readonly", @"readwrite", @"getter", @"setter", @"nullable", @"nonnull"
    ];
    
    for (NSString *attribute in propertyAttributes) {
        [self rtb_highlightKeyword:attribute withColor:FLEXSystemBlueColor];
    }
    
    // 类型信息
    [self rtb_highlightPattern:@"T@\"[^\"]+\"" withColor:FLEXSystemOrangeColor];
    [self rtb_highlightPattern:@"T[ildqcsfBv]" withColor:FLEXSystemGreenColor];
    
    // 实例变量名
    [self rtb_highlightPattern:@"V_\\w+" withColor:FLEXSystemPurpleColor];
}

- (void)rtb_highlightTypeEncoding {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11] 
                 range:NSMakeRange(0, text.length)];
    
    // 基本类型编码
    NSDictionary *typeEncodings = @{
        @"c": @"char",
        @"i": @"int", 
        @"s": @"short",
        @"l": @"long",
        @"q": @"long long",
        @"C": @"unsigned char",
        @"I": @"unsigned int",
        @"S": @"unsigned short",
        @"L": @"unsigned long",
        @"Q": @"unsigned long long",
        @"f": @"float",
        @"d": @"double",
        @"B": @"bool",
        @"v": @"void",
        @"*": @"char *",
        @"@": @"id",
        @"#": @"Class",
        @":": @"SEL",
        @"?": @"unknown"
    };
    
    for (NSString *encoding in typeEncodings.allKeys) {
        [self rtb_highlightKeyword:encoding withColor:FLEXSystemBlueColor];
    }
    
    // 对象类型 @"ClassName"
    [self rtb_highlightPattern:@"@\"[^\"]+\"" withColor:FLEXSystemOrangeColor];
    
    // 指针和数组
    [self rtb_highlightPattern:@"\\^" withColor:FLEXSystemRedColor]; // 指针
    [self rtb_highlightPattern:@"\\[\\d+[^\\]]*\\]" withColor:FLEXSystemGreenColor]; // 数组
    
    // 结构体和联合体
    [self rtb_highlightPattern:@"\\{[^}]*\\}" withColor:FLEXSystemPurpleColor]; // 结构体
    [self rtb_highlightPattern:@"\\([^)]*\\)" withColor:FLEXSystemCyanColor]; // 联合体
}

- (void)rtb_highlightClassHierarchy {
    NSString *text = self.string;
    if (!text || text.length == 0) {
        return;
    }
    
    // 设置基础字体
    [self addAttribute:NSFontAttributeName 
                 value:[UIFont systemFontOfSize:14] 
                 range:NSMakeRange(0, text.length)];
    
    // 根据层级缩进着色
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSUInteger currentIndex = 0;
    
    for (NSString *line in lines) {
        NSRange lineRange = NSMakeRange(currentIndex, line.length);
        
        // 计算缩进级别
        NSUInteger indentLevel = 0;
        for (NSUInteger i = 0; i < line.length; i++) {
            if ([line characterAtIndex:i] == ' ') {
                indentLevel++;
            } else {
                break;
            }
        }
        indentLevel = indentLevel / 4; // 假设每级缩进4个空格
        
        // 根据层级设置颜色
        UIColor *color;
        switch (indentLevel % 6) {
            case 0: color = FLEXLabelColor; break;
            case 1: color = FLEXSystemBlueColor; break;
            case 2: color = FLEXSystemGreenColor; break;
            case 3: color = FLEXSystemOrangeColor; break;
            case 4: color = FLEXSystemPurpleColor; break;
            case 5: color = FLEXSystemRedColor; break;
            default: color = FLEXLabelColor; break;
        }
        
        if (lineRange.location + lineRange.length <= self.length) {
            [self addAttribute:NSForegroundColorAttributeName value:color range:lineRange];
        }
        
        currentIndex += line.length + 1; // +1 for newline
        if (currentIndex >= text.length) break;
    }
}

#pragma mark - Helper Methods

- (void)rtb_highlightKeyword:(NSString *)keyword withColor:(UIColor *)color {
    NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", [NSRegularExpression escapedPatternForString:keyword]];
    [self rtb_highlightPattern:pattern withColor:color];
}

- (void)rtb_highlightPattern:(NSString *)pattern withColor:(UIColor *)color {
    [self rtb_highlightPattern:pattern withColor:color options:0];
}

- (void)rtb_highlightPattern:(NSString *)pattern withColor:(UIColor *)color options:(NSRegularExpressionOptions)options {
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
