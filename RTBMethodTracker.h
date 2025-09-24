#import <Foundation/Foundation.h>

@interface RTBMethodTrackerRecord : NSObject

@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *methodName;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) int depth;

@end

@interface RTBMethodTracker : NSObject

+ (instancetype)sharedTracker;

// 跟踪设置
- (void)startTrackingClass:(Class)cls;
- (void)stopTrackingClass:(Class)cls;
- (void)startTrackingClassesWithPrefix:(NSString *)prefix;
- (void)stopTrackingAllClasses;

// 获取结果
- (NSArray<RTBMethodTrackerRecord *> *)recentCalls;
- (NSArray<RTBMethodTrackerRecord *> *)callsForClass:(Class)cls;
- (NSArray<RTBMethodTrackerRecord *> *)callsWithDurationAbove:(NSTimeInterval)threshold;

// 统计信息
- (NSDictionary<NSString *, NSNumber *> *)callCountByClass;
- (NSDictionary<NSString *, NSNumber *> *)averageDurationByMethod;
- (NSArray<NSString *> *)mostCalledMethods;

@end