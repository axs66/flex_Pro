#import "RTBExplorerToolbar.h"

@implementation RTBToolbarItem

- (instancetype)initWithTitle:(NSString *)title image:(UIImage *)image {
    if (self = [super init]) {
        _title = title;
        _image = image;
        
        [self setImage:image forState:UIControlStateNormal];
        [self setTitle:title forState:UIControlStateNormal];
        
        // FLEX风格的按钮配置
        self.titleLabel.font = [UIFont systemFontOfSize:10];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        // 垂直排列图标和文字
        [self layoutIfNeeded];
        CGSize imageSize = self.imageView.frame.size;
        CGSize titleSize = [self.titleLabel.text sizeWithAttributes:@{NSFontAttributeName: self.titleLabel.font}];
        
        CGFloat totalHeight = imageSize.height + titleSize.height + 4;
        
        self.imageEdgeInsets = UIEdgeInsetsMake(-(totalHeight - imageSize.height), 0, 0, -titleSize.width);
        self.titleEdgeInsets = UIEdgeInsetsMake(0, -imageSize.width, -(totalHeight - titleSize.height), 0);
        
        self.backgroundColor = [UIColor clearColor];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];
    }
    return self;
}

@end

@implementation RTBExplorerToolbar

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // 设置工具栏背景
        self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.9];
        self.layer.cornerRadius = 8;
        self.clipsToBounds = YES;
        
        // 创建左侧拖动手柄
        _dragHandle = [[UIView alloc] init];
        _dragHandle.backgroundColor = [UIColor clearColor];
        [self addSubview:_dragHandle];
        
        // 添加拖动指示器 - 三条白线
        for (int i = 0; i < 3; i++) {
            UIView *line = [[UIView alloc] init];
            line.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1.0];
            line.layer.cornerRadius = 1;
            [_dragHandle addSubview:line];
        }
        
        // 创建功能按钮
        _hierarchyButton = [[RTBToolbarItem alloc] initWithTitle:@"类层次" image:nil];
        _inspectButton = [[RTBToolbarItem alloc] initWithTitle:@"检查" image:nil];
        _generateButton = [[RTBToolbarItem alloc] initWithTitle:@"头文件" image:nil];
        _searchButton = [[RTBToolbarItem alloc] initWithTitle:@"搜索" image:nil];
        _closeButton = [[RTBToolbarItem alloc] initWithTitle:@"关闭" image:nil];
        
        [self addSubview:_hierarchyButton];
        [self addSubview:_inspectButton];
        [self addSubview:_generateButton];
        [self addSubview:_searchButton];
        [self addSubview:_closeButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    
    // 左侧拖动手柄区域
    CGFloat dragHandleWidth = 40;
    _dragHandle.frame = CGRectMake(0, 0, dragHandleWidth, height);
    
    // 布局拖动指示器线条
    CGFloat lineWidth = 20;
    CGFloat lineHeight = 2;
    CGFloat lineSpacing = 4;
    CGFloat startY = (height - (3 * lineHeight + 2 * lineSpacing)) / 2;
    
    for (int i = 0; i < 3; i++) {
        UIView *line = _dragHandle.subviews[i];
        line.frame = CGRectMake((dragHandleWidth - lineWidth) / 2, 
                               startY + i * (lineHeight + lineSpacing), 
                               lineWidth, 
                               lineHeight);
    }
    
    // 计算按钮区域
    CGFloat buttonArea = width - dragHandleWidth;
    CGFloat buttonWidth = buttonArea / 5.0;
    
    // 布局功能按钮
    _hierarchyButton.frame = CGRectMake(dragHandleWidth, 0, buttonWidth, height);
    _inspectButton.frame = CGRectMake(dragHandleWidth + buttonWidth, 0, buttonWidth, height);
    _generateButton.frame = CGRectMake(dragHandleWidth + buttonWidth * 2, 0, buttonWidth, height);
    _searchButton.frame = CGRectMake(dragHandleWidth + buttonWidth * 3, 0, buttonWidth, height);
    _closeButton.frame = CGRectMake(dragHandleWidth + buttonWidth * 4, 0, buttonWidth, height);
}

- (void)addDragGesture:(UIPanGestureRecognizer *)gesture {
    // 添加拖动手势到拖动区域
    if (self.dragHandle) {
        [self.dragHandle addGestureRecognizer:gesture];
    } else {
        // 如果没有专用的拖动区域，则添加到整个工具栏
        [self addGestureRecognizer:gesture];
    }
}

@end