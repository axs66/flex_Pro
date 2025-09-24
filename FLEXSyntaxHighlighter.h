#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FLEXSyntaxHighlighter : NSObject

+ (NSAttributedString *)highlightMethodString:(NSString *)methodString;
+ (NSAttributedString *)highlightSource:(NSString *)source forFileExtension:(NSString *)fileExtension;
+ (NSAttributedString *)highlightObjcCode:(NSString *)objcCode;
+ (NSAttributedString *)highlightJSONString:(NSString *)jsonString;

@end