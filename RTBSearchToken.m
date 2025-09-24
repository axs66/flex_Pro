#import "RTBSearchToken.h"

@implementation RTBSearchToken

+ (instancetype)tokenWithString:(NSString *)string options:(NSUInteger)options {
    RTBSearchToken *token = [[self alloc] init];
    token.string = string;
    token.options = options;
    return token;
}

+ (instancetype)any {
    return [self tokenWithString:@"" options:0];
}

@end