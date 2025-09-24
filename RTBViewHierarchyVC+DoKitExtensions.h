#import "RTBViewHierarchyVC.h"
#import "RTBViewHierarchyAnalyzer.h"

@interface RTBViewHierarchyVC (DoKitExtensions)

@property (nonatomic, strong) RTBViewNode *hierarchyAnalysis;
@property (nonatomic, strong) NSArray *performanceIssues;

@end