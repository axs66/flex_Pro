#import "FLEXSyntaxHighlighter.h"
#import "NSString+SyntaxColoring.h"
#import "NSMutableAttributedString+RTB.h"

@implementation FLEXSyntaxHighlighter

+ (NSAttributedString *)highlightMethodString:(NSString *)methodString {
    if (!methodString) {
        return [[NSAttributedString alloc] initWithString:@""];
    }
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:methodString];
    [attributedString colorizeObjC];
    return attributedString;
}

+ (NSAttributedString *)highlightSource:(NSString *)source forFileExtension:(NSString *)fileExtension {
    if (!source) {
        return [[NSAttributedString alloc] initWithString:@""];
    }
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:source];
    
    if ([fileExtension isEqualToString:@"m"] ||
        [fileExtension isEqualToString:@"mm"] ||
        [fileExtension isEqualToString:@"h"]) {
        [attributedString colorizeObjC];
    } else if ([fileExtension isEqualToString:@"swift"]) {
        [attributedString colorizeSwift];
    } else if ([fileExtension isEqualToString:@"json"]) {
        [attributedString colorizeJSON];
    } else if ([fileExtension isEqualToString:@"xml"] ||
               [fileExtension isEqualToString:@"html"]) {
        [attributedString colorizeXML];
    } else if ([fileExtension isEqualToString:@"js"]) {
        [attributedString colorizeJavaScript];
    } else if ([fileExtension isEqualToString:@"css"]) {
        [attributedString colorizeCSS];
    } else if ([fileExtension isEqualToString:@"plist"]) {
        [attributedString colorizePlist];
    }
    
    return attributedString;
}

+ (NSAttributedString *)highlightObjcCode:(NSString *)objcCode {
    if (!objcCode) {
        return [[NSAttributedString alloc] initWithString:@""];
    }
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:objcCode];
    [attributedString colorizeObjC];
    return attributedString;
}

+ (NSAttributedString *)highlightJSONString:(NSString *)jsonString {
    if (!jsonString) {
        return [[NSAttributedString alloc] initWithString:@""];
    }
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:jsonString];
    [attributedString colorizeJSON];
    return attributedString;
}

@end