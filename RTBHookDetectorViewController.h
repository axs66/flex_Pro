#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Hook检测控制器，用于检测和显示系统中被hook的方法
 */
@interface RTBHookDetectorViewController : UIViewController

/**
 * 开始扫描hook
 * 扫描系统中被hook的方法并显示结果
 */
- (void)startScan;

/**
 * 获取hook检测结果
 * @return 返回检测到的hook信息数组
 */
- (NSArray *)getHookDetectionResults;

@end

NS_ASSUME_NONNULL_END