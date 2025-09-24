#import "FLEXDoKitViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 文件浏览器视图控制器，用于浏览和管理设备文件系统
@interface FLEXDoKitFileBrowserViewController : FLEXDoKitViewController <UITableViewDataSource, UITableViewDelegate>

/// 当前目录路径
@property (nonatomic, copy) NSString *currentPath;

/// 当前目录下的文件和文件夹
@property (nonatomic, strong) NSArray<NSString *> *directoryContents;

/// 文件属性缓存
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary<NSFileAttributeKey, id> *> *fileAttributes;

/// 导航到指定路径
/// @param path 目标路径
- (void)navigateToPath:(NSString *)path;

/// 刷新当前目录内容
- (void)refreshCurrentDirectory;

/// 显示文件操作菜单
/// @param filePath 文件路径
- (void)showFileActionsForPath:(NSString *)filePath;

/// 查看文件内容
/// @param filePath 文件路径
- (void)viewFileAtPath:(NSString *)filePath;

/// 分享文件
/// @param filePath 文件路径
- (void)shareFileAtPath:(NSString *)filePath;

/// 删除文件
/// @param filePath 文件路径
- (void)deleteFileAtPath:(NSString *)filePath;

/// 重命名文件
/// @param filePath 文件路径
- (void)renameFileAtPath:(NSString *)filePath;

/// 创建文件夹
/// @param directory 所在目录
- (void)createDirectoryInPath:(NSString *)directory;

/// 创建文件
/// @param directory 所在目录
- (void)createFileInPath:(NSString *)directory;

/// 获取文件大小字符串表示
/// @param filePath 文件路径
- (NSString *)fileSizeStringForPath:(NSString *)filePath;

/// 获取格式化的文件大小字符串
/// @param size 文件大小（字节）
- (NSString *)formatFileSize:(unsigned long long)size;

@property (nonatomic, strong) UITableView *fileTableView; // 使用不同名称以避免与父类冲突

@end

NS_ASSUME_NONNULL_END