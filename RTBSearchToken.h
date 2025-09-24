#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, RTBWildcardOptions) {
    RTBWildcardOptionsNone   = 0,
    RTBWildcardOptionsAny    = 1 << 0,
    RTBWildcardOptionsPrefix = 1 << 1,
    RTBWildcardOptionsSuffix = 1 << 2
};

/// 定义搜索令牌，用于运行时类查询
@interface RTBSearchToken : NSObject

/// 搜索的字符串
@property (nonatomic, copy) NSString *string;

/// 搜索选项
@property (nonatomic, assign) NSUInteger options;

/// 使用给定字符串和选项创建令牌
/// @param string 搜索字符串
/// @param options 通配符选项
+ (instancetype)tokenWithString:(NSString *)string options:(NSUInteger)options;

/// 创建匹配任何内容的令牌
+ (instancetype)any;

@end

NS_ASSUME_NONNULL_END