#import <UIKit/UIKit.h>

@class RTBToolbarItem;

@interface RTBExplorerToolbar : UIView

@property (nonatomic, strong) UIView *dragHandle;
@property (nonatomic, strong) RTBToolbarItem *hierarchyButton;
@property (nonatomic, strong) RTBToolbarItem *inspectButton;
@property (nonatomic, strong) RTBToolbarItem *generateButton;
@property (nonatomic, strong) RTBToolbarItem *searchButton;
@property (nonatomic, strong) RTBToolbarItem *closeButton;

- (void)addDragGesture:(UIPanGestureRecognizer *)gesture;

@end

@interface RTBToolbarItem : UIButton

@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image;

@end