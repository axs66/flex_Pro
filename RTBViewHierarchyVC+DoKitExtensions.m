#import "RTBViewHierarchyVC+DoKitExtensions.h"
#import <objc/runtime.h>

static char kHierarchyAnalysisKey;
static char kPerformanceIssuesKey;

@implementation RTBViewHierarchyVC (DoKitExtensions)

- (void)setHierarchyAnalysis:(RTBViewNode *)hierarchyAnalysis {
    objc_setAssociatedObject(self, &kHierarchyAnalysisKey, hierarchyAnalysis, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RTBViewNode *)hierarchyAnalysis {
    return objc_getAssociatedObject(self, &kHierarchyAnalysisKey);
}

- (void)setPerformanceIssues:(NSArray *)performanceIssues {
    objc_setAssociatedObject(self, &kPerformanceIssuesKey, performanceIssues, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)performanceIssues {
    return objc_getAssociatedObject(self, &kPerformanceIssuesKey);
}

@end