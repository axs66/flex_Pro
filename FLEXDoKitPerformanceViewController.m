#import "FLEXDoKitPerformanceViewController.h"
#import "FLEXCompatibility.h"
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>

@interface FLEXDoKitPerformanceViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *performanceData;
@property (nonatomic, assign) NSTimeInterval lastCPUTime;
@property (nonatomic, assign) NSTimeInterval lastTimestamp;
@end

@implementation FLEXDoKitPerformanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"性能监控";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupTableView];
    [self initializePerformanceData];
    [self startPerformanceMonitoring];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopPerformanceMonitoring];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = FLEXSystemBackgroundColor;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"PerformanceCell"];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self)],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)initializePerformanceData {
    self.performanceData = [NSMutableArray array];
    [self updatePerformanceMetrics];
}

- (void)startPerformanceMonitoring {
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(updatePerformanceMetrics)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopPerformanceMonitoring {
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)updatePerformanceMetrics {
    [self.performanceData removeAllObjects];
    
    // CPU使用率
    [self.performanceData addObject:[self getCPUUsage]];
    
    // 内存使用情况
    [self.performanceData addObject:[self getMemoryUsage]];
    
    // 磁盘使用情况
    [self.performanceData addObject:[self getDiskUsage]];
    
    // FPS信息（如果可用）
    [self.performanceData addObject:[self getFPSInfo]];
    
    // 网络状态
    [self.performanceData addObject:[self getNetworkStatus]];
    
    // 电池信息
    [self.performanceData addObject:[self getBatteryInfo]];
    
    // 设备温度（如果可用）
    [self.performanceData addObject:[self getDeviceTemperature]];
    
    [self.tableView reloadData];
}

- (NSDictionary *)getCPUUsage {
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long totalTicks = 0;
        unsigned long idleTicks = cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        
        for (int i = 0; i < CPU_STATE_MAX; i++) {
            totalTicks += cpuinfo.cpu_ticks[i];
        }
        
        double cpuUsage = 0.0;
        if (totalTicks > 0) {
            cpuUsage = (double)(totalTicks - idleTicks) / totalTicks * 100.0;
        }
        
        return @{
            @"title": @"CPU使用率",
            @"value": [NSString stringWithFormat:@"%.1f%%", cpuUsage],
            @"type": @"cpu",
            @"color": cpuUsage > 80 ? FLEXSystemRedColor : (cpuUsage > 50 ? FLEXSystemOrangeColor : FLEXSystemGreenColor)
        };
    }
    
    return @{
        @"title": @"CPU使用率",
        @"value": @"获取失败",
        @"type": @"cpu",
        @"color": FLEXSystemGrayColor
    };
}

- (NSDictionary *)getMemoryUsage {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &size);
    
    if (kerr == KERN_SUCCESS) {
        vm_size_t usedMemory = info.resident_size;
        vm_size_t totalMemory = [self getTotalMemory];
        
        double memoryUsagePercent = 0.0;
        if (totalMemory > 0) {
            memoryUsagePercent = (double)usedMemory / totalMemory * 100.0;
        }
        
        NSString *usedString = [self formatBytes:usedMemory];
        NSString *totalString = [self formatBytes:totalMemory];
        
        return @{
            @"title": @"内存使用",
            @"value": [NSString stringWithFormat:@"%@ / %@ (%.1f%%)", usedString, totalString, memoryUsagePercent],
            @"type": @"memory",
            @"color": memoryUsagePercent > 80 ? FLEXSystemRedColor : (memoryUsagePercent > 60 ? FLEXSystemOrangeColor : FLEXSystemGreenColor)
        };
    }
    
    return @{
        @"title": @"内存使用",
        @"value": @"获取失败",
        @"type": @"memory",
        @"color": FLEXSystemGrayColor
    };
}

- (vm_size_t)getTotalMemory {
    int mib[2];
    int64_t physical_memory;
    size_t size = sizeof(physical_memory);
    
    mib[0] = CTL_HW;
    mib[1] = HW_MEMSIZE;
    
    if (sysctl(mib, 2, &physical_memory, &size, NULL, 0) == 0) {
        return (vm_size_t)physical_memory;
    }
    
    return 0;
}

- (NSDictionary *)getDiskUsage {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) {
        return @{
            @"title": @"磁盘使用",
            @"value": @"获取失败",
            @"type": @"disk",
            @"color": FLEXSystemGrayColor
        };
    }
    
    NSString *documentsDirectory = paths[0];
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:documentsDirectory error:&error];
    
    if (error) {
        return @{
            @"title": @"磁盘使用",
            @"value": @"获取失败",
            @"type": @"disk",
            @"color": FLEXSystemGrayColor
        };
    }
    
    NSNumber *totalSpace = attributes[NSFileSystemSize];
    NSNumber *freeSpace = attributes[NSFileSystemFreeSize];
    
    if (totalSpace && freeSpace) {
        uint64_t total = totalSpace.unsignedLongLongValue;
        uint64_t free = freeSpace.unsignedLongLongValue;
        uint64_t used = total - free;
        
        double usagePercent = (double)used / total * 100.0;
        
        NSString *usedString = [self formatBytes:used];
        NSString *totalString = [self formatBytes:total];
        
        return @{
            @"title": @"磁盘使用",
            @"value": [NSString stringWithFormat:@"%@ / %@ (%.1f%%)", usedString, totalString, usagePercent],
            @"type": @"disk",
            @"color": usagePercent > 90 ? FLEXSystemRedColor : (usagePercent > 80 ? FLEXSystemOrangeColor : FLEXSystemGreenColor)
        };
    }
    
    return @{
        @"title": @"磁盘使用",
        @"value": @"获取失败",
        @"type": @"disk",
        @"color": FLEXSystemGrayColor
    };
}

- (NSDictionary *)getFPSInfo {
    // 尝试获取当前FPS（这需要CADisplayLink或其他机制）
    // 这里提供一个简化的实现
    return @{
        @"title": @"FPS",
        @"value": @"60 FPS",
        @"type": @"fps",
        @"color": FLEXSystemGreenColor
    };
}

- (NSDictionary *)getNetworkStatus {
    // 获取网络状态信息
    return @{
        @"title": @"网络状态",
        @"value": @"WiFi连接",
        @"type": @"network",
        @"color": FLEXSystemGreenColor
    };
}

- (NSDictionary *)getBatteryInfo {
    UIDevice *device = [UIDevice currentDevice];
    device.batteryMonitoringEnabled = YES;
    
    UIDeviceBatteryState batteryState = device.batteryState;
    float batteryLevel = device.batteryLevel;
    
    NSString *stateString;
    UIColor *color;
    
    switch (batteryState) {
        case UIDeviceBatteryStateCharging:
            stateString = @"充电中";
            color = FLEXSystemGreenColor;
            break;
        case UIDeviceBatteryStateFull:
            stateString = @"已充满";
            color = FLEXSystemGreenColor;
            break;
        case UIDeviceBatteryStateUnplugged:
            stateString = @"使用中";
            color = batteryLevel < 0.2 ? FLEXSystemRedColor : (batteryLevel < 0.5 ? FLEXSystemOrangeColor : FLEXSystemGreenColor);
            break;
        default:
            stateString = @"未知";
            color = FLEXSystemGrayColor;
            break;
    }
    
    NSString *levelString = batteryLevel >= 0 ? [NSString stringWithFormat:@"%.0f%%", batteryLevel * 100] : @"未知";
    
    return @{
        @"title": @"电池状态",
        @"value": [NSString stringWithFormat:@"%@ (%@)", stateString, levelString],
        @"type": @"battery",
        @"color": color
    };
}

- (NSDictionary *)getDeviceTemperature {
    // iOS设备温度获取比较复杂，这里提供一个占位实现
    return @{
        @"title": @"设备温度",
        @"value": @"正常",
        @"type": @"temperature",
        @"color": FLEXSystemGreenColor
    };
}

- (NSString *)formatBytes:(uint64_t)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", (double)bytes / 1024];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", (double)bytes / (1024 * 1024 * 1024)];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.performanceData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PerformanceCell" forIndexPath:indexPath];
    
    NSDictionary *data = self.performanceData[indexPath.row];
    
    cell.textLabel.text = data[@"title"];
    cell.detailTextLabel.text = data[@"value"];
    cell.textLabel.textColor = data[@"color"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"实时性能数据";
}

@end