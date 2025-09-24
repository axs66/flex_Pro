//
//  FLEXHookDetector.h
//  FLEX
//
//  Created from RuntimeBrowser functionalities.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLEXHookDetector : NSObject

+ (instancetype)sharedDetector;

- (NSDictionary *)getAllHookedMethods;
- (NSArray *)getHookedMethodsForClass:(Class)cls;
- (BOOL)isMethodHooked:(Method)method ofClass:(Class)cls;

// 确保其他方法声明与实现一致
- (NSDictionary *)getDetailedHookAnalysis;
- (NSArray *)getAllSwizzledMethods;

@end

NS_ASSUME_NONNULL_END