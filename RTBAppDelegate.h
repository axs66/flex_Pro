//
//  RTBAppDelegate.h
//  pxx917144686
//
//  Created for RuntimeBrowser project
//  Copyright © 2025. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RTBRootViewController;

@interface RTBAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;

// 添加可能在RTBClassDisplayVC中用到的方法
- (void)saveHeadersToDirectoryWithPath:(NSString *)path;
- (NSString *)headerPathForClass:(NSString *)className;
- (void)useClass:(NSString *)className;

@end