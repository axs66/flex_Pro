#import "FLEXDoKitFileBrowserViewController.h"
#import "FLEXCompatibility.h"
#import "FLEXSyntaxHighlighter.h"
#import <QuickLook/QuickLook.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "FLEXDoKitDatabaseViewController.h"

@interface FLEXDoKitFileBrowserViewController () <QLPreviewControllerDataSource, QLPreviewControllerDelegate, UIDocumentInteractionControllerDelegate>
@property (nonatomic, strong) NSString *selectedFilePath;
@property (nonatomic, strong) UIDocumentInteractionController *documentController;
@property (nonatomic, strong) UIBarButtonItem *createButton;
@end

@implementation FLEXDoKitFileBrowserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"文件浏览器";
    [self setupTableView];
    
    // 添加创建按钮
    self.createButton = [[UIBarButtonItem alloc] 
                         initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
                         target:self 
                         action:@selector(showCreateOptions)];
    self.navigationItem.rightBarButtonItem = self.createButton;
    
    // 初始化文件属性缓存
    self.fileAttributes = [NSMutableDictionary dictionary];
    
    // 默认导航到应用沙盒
    [self navigateToPath:NSHomeDirectory()];
}

- (void)setupTableView {
    // 使用不同的变量名，不要直接给self.tableView赋值
    UITableView *fileTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    fileTableView.delegate = self;
    fileTableView.dataSource = self;
    
    [fileTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FileCell"];
    
    fileTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:fileTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [fileTableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [fileTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [fileTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [fileTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    self.fileTableView = fileTableView;
}

#pragma mark - File Navigation

- (void)navigateToPath:(NSString *)path {
    self.currentPath = path;
    [self refreshCurrentDirectory];
    
    // 更新标题
    NSString *displayName = [path.lastPathComponent stringByDeletingPathExtension];
    if (displayName.length == 0) {
        displayName = @"根目录";
    } else if ([path isEqualToString:NSHomeDirectory()]) {
        displayName = @"沙盒";
    }
    self.title = displayName;
    
    // 如果不在根目录，添加返回上一级按钮
    if (![path isEqualToString:@"/"]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] 
                                                initWithTitle:@"上级" 
                                                style:UIBarButtonItemStylePlain 
                                                target:self 
                                                action:@selector(navigateToParentDirectory)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)navigateToParentDirectory {
    NSString *parentPath = [self.currentPath stringByDeletingLastPathComponent];
    [self navigateToPath:parentPath];
}

- (void)refreshCurrentDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    // 获取目录内容
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:self.currentPath error:&error];
    if (error) {
        [self showError:[NSString stringWithFormat:@"读取目录失败：%@", error.localizedDescription]];
        self.directoryContents = @[];
        return;
    }
    
    // 首先显示目录，然后是文件（两组都按字母排序）
    NSMutableArray *directories = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *item in contents) {
        NSString *fullPath = [self.currentPath stringByAppendingPathComponent:item];
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                [directories addObject:item];
            } else {
                [files addObject:item];
            }
        }
    }
    
    // 按名称排序
    NSArray *sortedDirectories = [directories sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *sortedFiles = [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // 合并结果
    self.directoryContents = [sortedDirectories arrayByAddingObjectsFromArray:sortedFiles];
    
    // 预加载文件属性
    [self preloadFileAttributes];
    
    [self.tableView reloadData];
}

- (void)preloadFileAttributes {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        for (NSString *item in self.directoryContents) {
            NSString *fullPath = [self.currentPath stringByAppendingPathComponent:item];
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
            if (attributes) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.fileAttributes[fullPath] = attributes;
                });
            }
        }
    });
}

#pragma mark - File Operations

- (void)showCreateOptions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"创建"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"新建文件夹" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createDirectoryInPath:self.currentPath];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"新建文本文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self createFileInPath:self.currentPath];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // iPad需要设置弹出位置
        UIPopoverPresentationController *popover = alert.popoverPresentationController;
        popover.barButtonItem = self.createButton;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFileActionsForPath:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    BOOL exists = [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    if (!exists) {
        [self showError:@"文件不存在"];
        return;
    }
    
    self.selectedFilePath = filePath;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:filePath.lastPathComponent
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (isDirectory) {
        [alert addAction:[UIAlertAction actionWithTitle:@"打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self navigateToPath:filePath];
        }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"查看" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self viewFileAtPath:filePath];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"分享" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self shareFileAtPath:filePath];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"重命名" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self renameFileAtPath:filePath];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self deleteFileAtPath:filePath];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // 在iPad上必须设置弹出位置
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        if (indexPath) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            alert.popoverPresentationController.sourceView = cell;
            alert.popoverPresentationController.sourceRect = cell.bounds;
        } else {
            alert.popoverPresentationController.sourceView = self.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 0, 0);
        }
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewFileAtPath:(NSString *)filePath {
    NSString *fileExtension = [filePath pathExtension].lowercaseString;
    
    // 处理常见文本文件格式
    NSArray *textFileExtensions = @[@"txt", @"log", @"md", @"json", @"xml", @"html", @"css", @"js", @"plist", @"m", @"h", @"mm", @"c", @"cpp", @"swift", @"strings", @"java", @"py", @"rb"];
    
    if ([textFileExtensions containsObject:fileExtension]) {
        [self viewTextFileAtPath:filePath];
    } else {
        // 使用QuickLook预览其他文件类型
        [self previewFileAtPath:filePath];
    }
}

- (void)viewTextFileAtPath:(NSString *)filePath {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        // 尝试其他常见编码
        content = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding error:&error];
        if (error) {
            content = [NSString stringWithContentsOfFile:filePath encoding:NSISOLatin1StringEncoding error:&error];
            if (error) {
                [self showError:[NSString stringWithFormat:@"无法读取文件内容：%@", error.localizedDescription]];
                return;
            }
        }
    }
    
    UIViewController *textViewController = [[UIViewController alloc] init];
    textViewController.title = filePath.lastPathComponent;
    
    // 创建文本视图
    UITextView *textView = [[UITextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.editable = NO;
    textView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    
    // 创建高亮文本（如果适用）
    NSString *fileExtension = [filePath pathExtension].lowercaseString;
    NSAttributedString *highlightedText = [FLEXSyntaxHighlighter highlightSource:content forFileExtension:fileExtension];
    if (highlightedText) {
        textView.attributedText = highlightedText;
    } else {
        textView.text = content;
    }
    
    [textViewController.view addSubview:textView];
    
    [NSLayoutConstraint activateConstraints:@[
        [textView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(textViewController)],
        [textView.leadingAnchor constraintEqualToAnchor:textViewController.view.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:textViewController.view.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:textViewController.view.bottomAnchor]
    ]];
    
    // 添加分享按钮
    textViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] 
                                                           initWithBarButtonSystemItem:UIBarButtonSystemItemAction 
                                                           target:self 
                                                           action:@selector(shareSelectedFile)];
    
    [self.navigationController pushViewController:textViewController animated:YES];
}

- (void)previewFileAtPath:(NSString *)filePath {
    self.selectedFilePath = filePath;
    
    QLPreviewController *previewController = [[QLPreviewController alloc] init];
    previewController.dataSource = self;
    previewController.delegate = self;
    
    [self.navigationController pushViewController:previewController animated:YES];
}

- (void)shareFileAtPath:(NSString *)filePath {
    self.selectedFilePath = filePath;
    [self shareSelectedFile];
}

- (void)shareSelectedFile {
    if (!self.selectedFilePath) {
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:self.selectedFilePath];
    self.documentController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.documentController.delegate = self;
    
    // 显示分享菜单
    BOOL didShow = [self.documentController presentOptionsMenuFromRect:CGRectZero 
                                                                inView:self.view 
                                                              animated:YES];
    
    if (!didShow) {
        // 没有应用能处理此文件
        [self showError:@"没有应用可以打开此文件"];
    }
}

- (void)deleteFileAtPath:(NSString *)filePath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                   message:[NSString stringWithFormat:@"确定要删除 %@？此操作无法撤销。", filePath.lastPathComponent]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSError *error;
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        
        if (!success) {
            [self showError:[NSString stringWithFormat:@"删除失败：%@", error.localizedDescription]];
        } else {
            [self refreshCurrentDirectory];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)renameFileAtPath:(NSString *)filePath {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重命名"
                                                                   message:[NSString stringWithFormat:@"输入 %@ 的新名称", filePath.lastPathComponent]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = filePath.lastPathComponent;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *newName = alert.textFields.firstObject.text;
        if (newName.length == 0) {
            [self showError:@"文件名不能为空"];
            return;
        }
        
        NSString *newPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName];
        
        NSError *error;
        BOOL success = [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error];
        
        if (!success) {
            [self showError:[NSString stringWithFormat:@"重命名失败：%@", error.localizedDescription]];
        } else {
            [self refreshCurrentDirectory];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createDirectoryInPath:(NSString *)directory {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建文件夹"
                                                                   message:@"输入文件夹名称"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"文件夹名称";
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *dirName = alert.textFields.firstObject.text;
        if (dirName.length == 0) {
            [self showError:@"文件夹名称不能为空"];
            return;
        }
        
        NSString *newDirPath = [directory stringByAppendingPathComponent:dirName];
        
        NSError *error;
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:newDirPath 
                                                withIntermediateDirectories:YES 
                                                                 attributes:nil 
                                                                      error:&error];
        
        if (!success) {
            [self showError:[NSString stringWithFormat:@"创建文件夹失败：%@", error.localizedDescription]];
        } else {
            [self refreshCurrentDirectory];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createFileInPath:(NSString *)directory {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"新建文件"
                                                                   message:@"输入文件名称和内容"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"文件名称";
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"文件内容";
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"创建" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *fileName = alert.textFields[0].text;
        NSString *fileContent = alert.textFields[1].text;
        
        if (fileName.length == 0) {
            [self showError:@"文件名称不能为空"];
            return;
        }
        
        NSString *newFilePath = [directory stringByAppendingPathComponent:fileName];
        
        NSError *error;
        BOOL success = [fileContent writeToFile:newFilePath 
                                     atomically:YES 
                                       encoding:NSUTF8StringEncoding 
                                          error:&error];
        
        if (!success) {
            [self showError:[NSString stringWithFormat:@"创建文件失败：%@", error.localizedDescription]];
        } else {
            [self refreshCurrentDirectory];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Helper Methods

- (NSString *)fileSizeStringForPath:(NSString *)filePath {
    NSDictionary *attributes = self.fileAttributes[filePath];
    
    if (!attributes) {
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        if (attributes) {
            self.fileAttributes[filePath] = attributes;
        }
    }
    
    if (!attributes) {
        return @"";
    }
    
    NSNumber *sizeValue = attributes[NSFileSize];
    if (!sizeValue) {
        return @"";
    }
    
    return [self formatFileSize:[sizeValue unsignedLongLongValue]];
}

- (NSString *)formatFileSize:(unsigned long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%llu B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", (double)size / 1024];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", (double)size / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", (double)size / (1024 * 1024 * 1024)];
    }
}

- (NSString *)formattedDateStringFromDate:(NSDate *)date {
    if (!date) {
        return @"";
    }
    
    static NSDateFormatter *dateFormatter = nil;
    if (!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
    }
    
    return [dateFormatter stringFromDate:date];
}

- (UIImage *)iconForItemAtPath:(NSString *)path isDirectory:(BOOL)isDirectory {
    if (isDirectory) {
        return [FLEXCompatibility systemImageNamed:@"folder" fallbackImageNamed:@"folder_icon"];
    }
    
    NSString *fileExtension = [path pathExtension].lowercaseString;
    
    // 基于扩展名返回适当的图标
    if ([fileExtension isEqualToString:@"png"] ||
        [fileExtension isEqualToString:@"jpg"] ||
        [fileExtension isEqualToString:@"jpeg"] ||
        [fileExtension isEqualToString:@"gif"] ||
        [fileExtension isEqualToString:@"heic"]) {
        return [FLEXCompatibility systemImageNamed:@"photo" fallbackImageNamed:@"image_icon"];
    } else if ([fileExtension isEqualToString:@"pdf"]) {
        return [FLEXCompatibility systemImageNamed:@"doc.text" fallbackImageNamed:@"document_icon"];
    } else if ([fileExtension isEqualToString:@"plist"]) {
        return [FLEXCompatibility systemImageNamed:@"list.bullet.rectangle" fallbackImageNamed:@"list_icon"];
    } else if ([fileExtension isEqualToString:@"html"] ||
               [fileExtension isEqualToString:@"htm"]) {
        return [FLEXCompatibility systemImageNamed:@"globe" fallbackImageNamed:@"web_icon"];
    } else if ([fileExtension isEqualToString:@"txt"] ||
               [fileExtension isEqualToString:@"log"]) {
        return [FLEXCompatibility systemImageNamed:@"doc.text" fallbackImageNamed:@"text_icon"];
    } else if ([fileExtension isEqualToString:@"json"] ||
               [fileExtension isEqualToString:@"xml"]) {
        return [FLEXCompatibility systemImageNamed:@"curlybraces" fallbackImageNamed:@"code_icon"];
    } else if ([fileExtension isEqualToString:@"mp3"] ||
               [fileExtension isEqualToString:@"aac"] ||
               [fileExtension isEqualToString:@"m4a"] ||
               [fileExtension isEqualToString:@"wav"]) {
        return [FLEXCompatibility systemImageNamed:@"music.note" fallbackImageNamed:@"audio_icon"];
    } else if ([fileExtension isEqualToString:@"mp4"] ||
               [fileExtension isEqualToString:@"mov"]) {
        return [FLEXCompatibility systemImageNamed:@"film" fallbackImageNamed:@"video_icon"];
    } else if ([fileExtension isEqualToString:@"sqlite"] ||
               [fileExtension isEqualToString:@"db"]) {
        return [FLEXCompatibility systemImageNamed:@"externaldrive" fallbackImageNamed:@"database_icon"];
    } else {
        return [FLEXCompatibility systemImageNamed:@"doc" fallbackImageNamed:@"file_icon"];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.directoryContents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FileCell" forIndexPath:indexPath];
    
    NSString *fileName = self.directoryContents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:fileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    // 配置单元格
    cell.textLabel.text = fileName;
    cell.detailTextLabel.text = isDirectory ? @"目录" : [self fileSizeStringForPath:fullPath];
    
    // 设置图标
    cell.imageView.image = [self iconForItemAtPath:fullPath isDirectory:isDirectory];
    
    cell.accessoryType = isDirectory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryDetailButton;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *selectedItem = self.directoryContents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:selectedItem];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    
    if (isDirectory) {
        [self navigateToPath:fullPath];
    } else {
        [self viewFileAtPath:fullPath];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedItem = self.directoryContents[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:selectedItem];
    [self showFileActionsForPath:fullPath];
}

#pragma mark - QLPreviewControllerDataSource

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return self.selectedFilePath ? 1 : 0;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return [NSURL fileURLWithPath:self.selectedFilePath];
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
    return self.view;
}

- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller {
    return self.view.bounds;
}

@end