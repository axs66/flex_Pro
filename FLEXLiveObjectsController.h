//
//  FLEXLiveObjectsController.h
//  Flipboard
//
//  Created by Ryan Olson on 5/28/14.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 活动对象监控控制器，显示当前内存中的对象实例
@interface FLEXLiveObjectsController : UITableViewController <UISearchResultsUpdating, UISearchBarDelegate>

/// 被跟踪的类列表
@property (nonatomic, strong) NSMutableArray<Class> *trackedClasses;  // 改为NSMutableArray

/// 类实例数量字典
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *classCounts;  // 改为NSMutableDictionary

/// 刷新活动对象数据
- (void)refreshLiveObjects;

/// 加载所有已注册的类
- (void)loadAllClasses;

/// 清除所有跟踪的类
- (void)clearTrackedClasses;

@end

/// 实例列表查看控制器
@interface FLEXLiveObjectsInstanceViewController : UITableViewController

/// 实例数组
@property (nonatomic, readonly) NSArray *instances;

/// 目标类
@property (nonatomic, readonly) Class targetClass;

/// 初始化方法
/// @param instances 实例数组
/// @param cls 目标类
- (instancetype)initWithInstances:(NSArray *)instances forClass:(Class)cls;

@end

NS_ASSUME_NONNULL_END
