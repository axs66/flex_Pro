#import "RTBMemoryLeakDetector.h"
#import <objc/runtime.h>
#import <execinfo.h>
#import <UIKit/UIKit.h>

@implementation RTBLeakRecord

- (instancetype)init {
    self = [super init];
    if (self) {
        _timestamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

@end

@interface RTBMemoryLeakDetector ()
@property (nonatomic, strong) NSMutableArray<RTBLeakRecord *> *leakRecords;
@property (nonatomic, strong) NSHashTable *weakReferenceTable;
@property (nonatomic, assign) BOOL isDetecting;
@end

@implementation RTBMemoryLeakDetector

+ (instancetype)sharedInstance {
    static RTBMemoryLeakDetector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _leakRecords = [NSMutableArray array];
        _weakReferenceTable = [NSHashTable weakObjectsHashTable];
        _isDetecting = NO;
    }
    return self;
}

- (void)startLeakDetection {
    self.isDetecting = YES;
    [self swizzleViewControllerDealloc];
}

- (void)stopLeakDetection {
    self.isDetecting = NO;
}

- (NSArray<RTBLeakRecord *> *)getLeakRecords {
    return [self.leakRecords copy];
}

- (void)clearLeakRecords {
    [self.leakRecords removeAllObjects];
}

- (BOOL)checkObjectForLeak:(id)object {
    if (!object) return NO;
    
    // 添加到弱引用表中，后续检查是否被释放
    [self.weakReferenceTable addObject:object];
    
    // 模拟对象泄露检测
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.weakReferenceTable containsObject:object]) {
            // 如果5秒后对象仍未释放，记录可能的泄露
            RTBLeakRecord *record = [[RTBLeakRecord alloc] init];
            record.className = NSStringFromClass([object class]);
            record.stackTrace = [self getCurrentStackTrace];
            record.referenceCount = CFGetRetainCount((__bridge CFTypeRef)object);  // 使用改名后的属性
            [self.leakRecords addObject:record];
        }
    });
    
    return YES;
}

- (NSString *)getCurrentStackTrace {
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    
    NSMutableArray *stackTraceEntries = [NSMutableArray array];
    for (int i = 0; i < frames; i++) {
        [stackTraceEntries addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return [stackTraceEntries componentsJoinedByString:@"\n"];
}

- (void)swizzleViewControllerDealloc {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [UIViewController class];
        
        SEL originalSelector = NSSelectorFromString(@"dealloc");
        SEL swizzledSelector = @selector(rtb_dealloc);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        
        // 删除了未使用的变量 swizzledMethod
        
        IMP originalImp = method_getImplementation(originalMethod);
        
        class_addMethod(class, swizzledSelector, imp_implementationWithBlock(^(id self) {
            // 只在检测模式下执行检测逻辑
            if ([RTBMemoryLeakDetector sharedInstance].isDetecting) {
                // 在这里添加检测逻辑
            }
            
            // 调用原始的dealloc
            ((void (*)(id, SEL))originalImp)(self, originalSelector);
        }), method_getTypeEncoding(originalMethod));
    });
}

@end