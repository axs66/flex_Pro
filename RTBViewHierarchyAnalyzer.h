#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RTBViewNode : NSObject
@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) NSArray<RTBViewNode *> *children;
@property (nonatomic, assign) NSInteger depth;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, strong) NSString *className;
@property (nonatomic, strong) NSDictionary *properties;
@end

@interface RTBViewHierarchyAnalyzer : NSObject

+ (instancetype)sharedInstance;

// 视图层次分析
- (RTBViewNode *)analyzeViewHierarchy:(UIView *)rootView;
- (NSArray *)findViewsWithDepthGreaterThan:(NSInteger)maxDepth;
- (NSArray *)findOverlappingViews;
- (NSArray *)findHiddenViews;

// 性能问题检测
- (NSArray *)detectPerformanceIssues:(UIView *)rootView;
- (NSArray *)findLargeImages;
- (NSArray *)findComplexDrawingViews;

@end