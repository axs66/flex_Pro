//
//  FLEXMemoryAnalyzer.h
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXMemoryAnalyzer : NSObject

+ (instancetype)sharedAnalyzer;
- (NSDictionary *)getAllClassesMemoryUsage;

@end

NS_ASSUME_NONNULL_END