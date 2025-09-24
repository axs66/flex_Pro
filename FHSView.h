//
//  FHSView.h
//  FLEX
//
//  Created by Tanner Bennett on 1/6/20.
//

#import <UIKit/UIKit.h>

@interface FHSView : NSObject {
    @private
    BOOL _inScrollView;
}

+ (instancetype)forView:(UIView *)view isInScrollView:(BOOL)inScrollView;

@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readwrite) BOOL important;

@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) BOOL hidden;
@property (nonatomic, readonly) UIImage *snapshotImage;

@property (nonatomic, readonly) NSArray<FHSView *> *children;
@property (nonatomic, readonly) NSString *summary;

@end
