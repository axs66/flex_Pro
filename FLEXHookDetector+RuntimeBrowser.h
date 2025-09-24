#import "FLEXHookDetector.h"

@interface FLEXHookDetector (RuntimeBrowser)

// 保留分类中特有的方法
- (NSArray *)getKnownHookingFrameworks;

@end