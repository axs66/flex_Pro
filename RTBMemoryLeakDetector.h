#import <Foundation/Foundation.h>

@interface RTBLeakRecord : NSObject
@property (nonatomic, strong) NSString *className;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, strong) NSString *stackTrace;
@property (nonatomic, assign) NSUInteger referenceCount;
@end

@interface RTBMemoryLeakDetector : NSObject

+ (instancetype)sharedInstance;

// 内存泄漏检测
- (void)startLeakDetection;
- (void)stopLeakDetection;

// 获取泄漏记录
- (NSArray<RTBLeakRecord *> *)getLeakRecords;
- (void)clearLeakRecords;

// 手动检测特定对象
- (BOOL)checkObjectForLeak:(id)object;

@end