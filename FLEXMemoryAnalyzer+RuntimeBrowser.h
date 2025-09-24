#import "FLEXMemoryAnalyzer.h"

@interface FLEXMemoryAnalyzer (RuntimeBrowser)

// 移植 RTB 的内存分析功能
- (NSDictionary *)getDetailedHeapSnapshot;
- (NSArray *)findMemoryLeaks;
- (NSArray *)getDetailedMemoryZoneInfo;
- (NSDictionary *)getClassInstanceDistribution;
- (NSUInteger)getInstanceCountForClass:(Class)cls;

@end