//
//  FLEXDoKitNetworkMonitor.h
//  FLEX
//
//  DoKit网络监控器
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 网络监控器，用于拦截和记录网络请求
@interface FLEXDoKitNetworkMonitor : NSObject

/// 共享实例
+ (instancetype)sharedInstance;

/// 网络请求记录数组
@property (nonatomic, readonly) NSMutableArray<NSDictionary *> *networkRequests;

/// Mock规则数组
@property (nonatomic, readonly) NSMutableArray<NSDictionary *> *mockRules;

/// 是否启用网络监控
@property (nonatomic, assign) BOOL enabled;

/// 网络延迟模拟（秒）
@property (nonatomic, assign) NSTimeInterval networkDelay;

/// 网络错误率（0.0-1.0）
@property (nonatomic, assign) CGFloat errorRate;

/// 开始网络监控
- (void)startMonitoring;

/// 停止网络监控
- (void)stopMonitoring;

/// 切换网络监控状态
- (void)toggleNetworkMonitoring;

/// 当前是否在监控网络
- (BOOL)isMonitoring;

/// 获取当前监控的网络请求
- (NSArray *)currentNetworkRequests;

/// 清除网络请求记录
- (void)clearNetworkRequests;

/// 添加Mock规则
/// @param rule Mock规则字典
- (void)addMockRule:(NSDictionary *)rule;

/// 移除Mock规则
/// @param rule Mock规则字典
- (void)removeMockRule:(NSDictionary *)rule;

/// 清除所有Mock规则
- (void)clearMockRules;

/// 记录网络请求
/// @param request 请求对象
/// @param response 响应对象
/// @param data 响应数据
/// @param error 错误信息
/// @param startTime 开始时间
- (void)recordNetworkRequest:(NSURLRequest *)request
                    response:(NSURLResponse * _Nullable)response
                        data:(NSData * _Nullable)data
                       error:(NSError * _Nullable)error
                   startTime:(NSDate *)startTime;

/// 网络监控相关
@property (nonatomic, assign, getter=isMonitoring) BOOL monitoring;

/// 弱网模拟相关
- (void)simulateSlowNetwork:(float)delayInSeconds;
- (void)simulateNetworkError;
- (void)resetNetworkSimulation;

/// Mock数据相关
- (BOOL)handleRequestIfMocked:(id)request;

/// 启用Mock模式
- (void)enableMockMode;

/// 禁用Mock模式
- (void)disableMockMode;

@end

NS_ASSUME_NONNULL_END