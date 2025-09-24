#import "RTBObjectsTVC+DoKitExtensions.h"
#import <objc/runtime.h>

static char kEnabledDoKitAnalysisKey;
static char kMemoryLeakDetectedKey;
static char kNetworkMonitoringEnabledKey;

@implementation RTBObjectsTVC (DoKitExtensions)

- (void)setEnabledDoKitAnalysis:(BOOL)enabledDoKitAnalysis {
    objc_setAssociatedObject(self, &kEnabledDoKitAnalysisKey, @(enabledDoKitAnalysis), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)enabledDoKitAnalysis {
    NSNumber *value = objc_getAssociatedObject(self, &kEnabledDoKitAnalysisKey);
    return [value boolValue];
}

- (void)setMemoryLeakDetected:(BOOL)memoryLeakDetected {
    objc_setAssociatedObject(self, &kMemoryLeakDetectedKey, @(memoryLeakDetected), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)memoryLeakDetected {
    NSNumber *value = objc_getAssociatedObject(self, &kMemoryLeakDetectedKey);
    return [value boolValue];
}

- (void)setNetworkMonitoringEnabled:(BOOL)networkMonitoringEnabled {
    objc_setAssociatedObject(self, &kNetworkMonitoringEnabledKey, @(networkMonitoringEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)networkMonitoringEnabled {
    NSNumber *value = objc_getAssociatedObject(self, &kNetworkMonitoringEnabledKey);
    return [value boolValue];
}

@end