#import "FLEXDoKitColorPickerViewController.h"
#import "FLEXDoKitVisualTools.h"
#import "FLEXCompatibility.h"

@interface FLEXDoKitColorPickerViewController ()
@property (nonatomic, strong) UIView *colorPreview;
@property (nonatomic, strong) UILabel *colorInfoLabel;
@property (nonatomic, strong) UILabel *instructionLabel;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *stopButton;
@end

@implementation FLEXDoKitColorPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"颜色吸管";
    self.view.backgroundColor = FLEXSystemBackgroundColor;
    
    [self setupUI];
}

- (void)setupUI {
    // 说明标签
    self.instructionLabel = [[UILabel alloc] init];
    self.instructionLabel.text = @"点击「开始取色」后，在屏幕上任意点击获取该位置的颜色";
    self.instructionLabel.numberOfLines = 0;
    self.instructionLabel.textAlignment = NSTextAlignmentCenter;
    self.instructionLabel.font = [UIFont systemFontOfSize:16];
    self.instructionLabel.textColor = FLEXSecondaryLabelColor;
    
    // 颜色预览
    self.colorPreview = [[UIView alloc] init];
    self.colorPreview.backgroundColor = [UIColor lightGrayColor];
    self.colorPreview.layer.borderWidth = 1;
    self.colorPreview.layer.borderColor = FLEXSystemGrayColor.CGColor;
    self.colorPreview.layer.cornerRadius = 8;
    
    // 颜色信息标签
    self.colorInfoLabel = [[UILabel alloc] init];
    self.colorInfoLabel.text = @"暂未选择颜色";
    self.colorInfoLabel.textAlignment = NSTextAlignmentCenter;
    // 使用兼容性方法而不是直接调用
    self.colorInfoLabel.font = [FLEXCompatibility monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.colorInfoLabel.numberOfLines = 0;
    self.colorInfoLabel.textColor = FLEXLabelColor;
    
    // 开始按钮
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"开始取色" forState:UIControlStateNormal];
    self.startButton.backgroundColor = FLEXSystemBlueColor;
    self.startButton.layer.cornerRadius = 8;
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startButton addTarget:self action:@selector(startPicking) forControlEvents:UIControlEventTouchUpInside];
    
    // 停止按钮
    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopButton setTitle:@"停止取色" forState:UIControlStateNormal];
    self.stopButton.backgroundColor = [UIColor lightGrayColor];
    self.stopButton.layer.cornerRadius = 8;
    self.stopButton.alpha = 0.5;
    self.stopButton.enabled = NO;
    [self.stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.stopButton addTarget:self action:@selector(stopPicking) forControlEvents:UIControlEventTouchUpInside];
    
    // 布局
    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 20;
    mainStack.alignment = UIStackViewAlignmentFill;
    mainStack.distribution = UIStackViewDistributionFill;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [mainStack addArrangedSubview:self.instructionLabel];
    [mainStack addArrangedSubview:self.colorPreview];
    [mainStack addArrangedSubview:self.colorInfoLabel];
    
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 20;
    buttonStack.distribution = UIStackViewDistributionFillEqually;
    
    [buttonStack addArrangedSubview:self.startButton];
    [buttonStack addArrangedSubview:self.stopButton];
    
    [mainStack addArrangedSubview:buttonStack];
    
    [self.view addSubview:mainStack];
    
    // 使用Auto Layout约束
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:FLEXSafeAreaTopAnchor(self) constant:40],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.colorPreview.heightAnchor constraintEqualToConstant:120]
    ]];
}

- (void)startPicking {
    self.startButton.enabled = NO;
    self.startButton.alpha = 0.5;
    self.stopButton.enabled = YES;
    self.stopButton.alpha = 1.0;
    self.stopButton.backgroundColor = FLEXSystemRedColor;
    
    [[FLEXDoKitVisualTools sharedInstance] startColorPicker:^(UIColor *pickedColor) {
        [self updateWithColor:pickedColor];
    }];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)stopPicking {
    self.startButton.enabled = YES;
    self.startButton.alpha = 1.0;
    self.stopButton.enabled = NO;
    self.stopButton.alpha = 0.5;
    self.stopButton.backgroundColor = [UIColor lightGrayColor];
    
    [[FLEXDoKitVisualTools sharedInstance] stopColorPicker];
}

- (void)updateWithColor:(UIColor *)color {
    self.colorPreview.backgroundColor = color;
    
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    
    NSString *hexString = [NSString stringWithFormat:@"#%02X%02X%02X", 
                           (int)(r * 255), (int)(g * 255), (int)(b * 255)];
    
    NSString *rgbaString = [NSString stringWithFormat:@"RGBA(%.0f, %.0f, %.0f, %.2f)", 
                           r * 255, g * 255, b * 255, a];
    
    self.colorInfoLabel.text = [NSString stringWithFormat:@"%@\n%@", hexString, rgbaString];
}

- (void)dealloc {
    // 添加缺失的 super 调用
    [super dealloc];
}

@end