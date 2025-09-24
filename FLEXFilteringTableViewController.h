//
//  FLEXFilteringTableViewController.h
//  FLEX
//
//  Created by Tanner on 3/9/20.
//  Copyright © 2020 FLEX Team. All rights reserved.
//

#import "FLEXTableViewController.h"

@class FLEXTableViewSection;

NS_ASSUME_NONNULL_BEGIN

// 定义 FLEXTableViewFiltering 协议
@protocol FLEXTableViewFiltering <NSObject>

/// 所有部分，包括空的
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *allSections;
/// 仅非空部分
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *sections;

@end

/// 一个带有搜索和过滤功能的表格视图控制器基类
@interface FLEXFilteringTableViewController : FLEXTableViewController

/// 所有部分，包括空的
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *allSections;
/// 仅非空部分
@property (nonatomic, copy) NSArray<FLEXTableViewSection *> *sections;

/// 过滤委托，默认为 self
@property (nonatomic, assign, nullable) id<FLEXTableViewFiltering> filterDelegate;

/// 当前搜索文本
@property (nonatomic, copy, nullable) NSString *filterText;
/// 是否在后台线程执行过滤
@property (nonatomic) BOOL filterInBackground;
/// 是否需要显示索引标题
@property (nonatomic) BOOL wantsSectionIndexTitles;

/// 子类应重写此方法以提供所有部分
- (NSArray<FLEXTableViewSection *> *)makeSections;
/// 返回非空部分
- (NSArray<FLEXTableViewSection *> *)nonemptySections;

/// 重新加载数据
- (void)reloadData;
- (void)reloadData:(NSArray<FLEXTableViewSection *> *)nonemptySections;
/// 重新加载所有部分
- (void)reloadSections;

/// 更新搜索结果
- (void)updateSearchResults:(NSString *)newText;

@end

NS_ASSUME_NONNULL_END