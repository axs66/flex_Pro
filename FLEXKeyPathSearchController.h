//
//  FLEXKeyPathSearchController.h
//  FLEX
//
//  Created by Tanner on 3/23/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FLEXRuntimeBrowserToolbar.h"
#import "FLEXMethod.h"
#import "FLEXRuntimeKeyPath.h"

@protocol FLEXKeyPathSearchControllerDelegate <UITableViewDataSource>

@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, readonly) UISearchController *searchController;

/// For loaded images which don't have an NSBundle
- (void)didSelectImagePath:(NSString *)message shortName:(NSString *)shortName;
- (void)didSelectBundle:(NSBundle *)bundle;
- (void)didSelectClass:(Class)cls;

@end


@interface FLEXKeyPathSearchController : NSObject <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

+ (instancetype)delegate:(id<FLEXKeyPathSearchControllerDelegate>)delegate;

// 将 delegate 改为 assign 而非 readonly，以支持 MRC 环境
@property (nonatomic, assign) id<FLEXKeyPathSearchControllerDelegate> delegate;
@property (nonatomic) FLEXRuntimeBrowserToolbar *toolbar;

/// 当前键路径
@property (nonatomic, strong) FLEXRuntimeKeyPath *keyPath;

/// 用于过滤的类数组
@property (nonatomic, strong) NSArray<NSString *> *classes;

/// 显示在屏幕上的绑定或类
@property (nonatomic, strong) NSArray *bundlesOrClasses;

/// 过滤后的类
@property (nonatomic, strong) NSArray<NSString *> *filteredClasses;

/// 空建议字符串
@property (nonatomic, copy) NSString *emptySuggestion;

/// Suggestions for the toolbar
@property (nonatomic, readonly) NSArray<NSString *> *suggestions;

- (void)didSelectKeyPathOption:(NSString *)text;
- (void)didPressButton:(NSString *)text insertInto:(UISearchBar *)searchbar;

@end