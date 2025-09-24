//
//  RTBViewHierarchyVC.h
//  pxx917144686
//
//  Created for RuntimeBrowser
//

#import <UIKit/UIKit.h>

@interface RTBViewHierarchyVC : UITableViewController

@property (nonatomic, strong) UIView *targetView;
@property (nonatomic, strong) NSMutableArray *viewsHierarchy;

@end