//
//  NSURLRequest+Doraemon.h
//  FLEX_Pro
//
//  Created on 2025/6/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest (Doraemon)

/**
 * 请求唯一标识符
 */
@property (nonatomic, copy, nullable) NSString *rtb_requestId;

/**
 * 请求开始时间戳
 */
@property (nonatomic, copy, nullable) NSNumber *rtb_startTime;

@end

NS_ASSUME_NONNULL_END