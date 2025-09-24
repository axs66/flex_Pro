/*
 
 AllClasses.m created by eepstein on Sat 16-Mar-2002 

 Author: Ezra Epstein (eepstein@prajna.com)

 Copyright (c) 2002 by Prajna IT Consulting.
                       http://www.prajna.com

 ========================================================================

 THIS PROGRAM AND THIS CODE COME WITH ABSOLUTELY NO WARRANTY.
 THIS CODE HAS BEEN PROVIDED "AS IS" AND THE RESPONSIBILITY
 FOR ITS OPERATIONS IS 100% YOURS.

 ========================================================================
 This file is part of RuntimeBrowser.

 RuntimeBrowser is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 RuntimeBrowser is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with RuntimeBrowser (in a file called "COPYING.txt"); if not,
 write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
 Boston, MA  02111-1307  USA

*/

#import "RTBRuntime.h"
#import "RTBClass.h"
#import "RTBProtocol.h"
#import <objc/runtime.h>

// 添加缺失的属性声明
@interface RTBRuntime ()
@property (nonatomic, strong) NSMutableDictionary *runtimeClassInfo;
@property (nonatomic, strong) NSMutableDictionary *classLoadTimes;
- (void)analyzeClass:(Class)cls;
- (void)swizzleMethodForTimeTrack:(Class)cls selector:(SEL)selector;
@end

// 添加静态实例变量声明
static RTBRuntime *sharedInstance = nil;

@implementation RTBRuntime

+ (RTBRuntime *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RTBRuntime alloc] init];
        sharedInstance.rootClasses = [NSMutableArray array];
        sharedInstance.allClassStubsByName = [NSMutableDictionary dictionary];
        sharedInstance.allClassStubsByImagePath = [NSMutableDictionary dictionary];
        sharedInstance.allProtocolsByName = [NSMutableDictionary dictionary];
        
        // 主动读取所有类
        [sharedInstance readAllRuntimeClasses];
    });
    
    return sharedInstance;
}

+ (void)thisClassIsPartOfTheRuntimeBrowser {}

- (RTBClass *)classStubForClassName:(NSString *)classname {
    return [_allClassStubsByName valueForKey:classname];
}

- (void)addProtocolsAdoptedByProtocol:(RTBProtocol *)p {
    for(NSString *adoptedProtocolName in [p sortedAdoptedProtocolsNames]) {
        RTBProtocol *ap = _allProtocolsByName[adoptedProtocolName];
        if(ap == nil) {
            ap = [RTBProtocol protocolStubWithProtocolName:adoptedProtocolName];
            _allProtocolsByName[adoptedProtocolName] = ap;
            
            [self addProtocolsAdoptedByProtocol:ap];
        }
    }
}

- (RTBClass *)getOrCreateClassStubsRecursivelyForClass:(Class)klass {
    
	//Lookup the ClassStub for klass or create one if none exists and add it to +allClassStuds.
    NSString *klassName = NSStringFromClass(klass);
	
    // First check if we've already got a ClassStub for klass. If yes, we'll return it.
    RTBClass *cs = [self classStubForClassName:klassName];
	if(cs) return cs;
	
    // klass doesn't yet have a ClassStub...
	cs = [RTBClass classStubWithClass:klass]; // Create a ClassStub for klass
	
	if(cs == nil) {
		NSLog(@"-- cannot create classStub for %@, ignore it", klassName);
		return nil;
	}

    NSString *path = [cs imagePath];
    
    // users may want to ignore OCRuntime classes
    BOOL showOCRuntimeClasses = [[NSUserDefaults standardUserDefaults] boolForKey:@"RTBShowOCRuntimeClasses"];
    if(showOCRuntimeClasses == NO && [path hasSuffix:@"OCRuntime.app/OCRuntime"]) {
        //NSLog(@"-- ignore %@", cs.classObjectName);
        return nil;
    }

	_allClassStubsByName[klassName] = cs; // Add it to our uniquing dictionary.
    
#if TARGET_IPHONE_SIMULATOR
    // remove path prefix, eg.
    //   /Applications/Xcode5-DP.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI
    // will become
    //   /System/Library/PrivateFrameworks/CoreUI.framework/CoreUI

    if([path hasPrefix:@"/Applications/"]) {
        NSUInteger i = [path rangeOfString:@".sdk"].location;
        if(i != NSNotFound) {
            NSUInteger start = i + 4;
            path = [path substringFromIndex:start];
        }
    }
#endif
    
    // ShowOCRuntimeClasses
    
	if(path) {
		NSMutableArray *stubsForImage = [_allClassStubsByImagePath valueForKey:path];
		if(stubsForImage == nil) {
            _allClassStubsByImagePath[path] = [NSMutableArray array];
			stubsForImage = [_allClassStubsByImagePath valueForKey:path];
		}
		if([stubsForImage containsObject:cs] == NO) [stubsForImage addObject:cs]; // TODO: use a set?
	}
	
	Class parent = class_getSuperclass(klass);   // Get klass's superclass 
	if (parent != nil) {               // and recursively create (or get) its stub.
		RTBClass *parentCs = [self getOrCreateClassStubsRecursivelyForClass:parent];
		[parentCs addSubclassStub:cs];  // we are a subclass of our parent.
	} else  // If there is no superclass, then klass is a root class.
		[[self rootClasses] addObject:cs];
	
    /**/
    
    NSArray *protocolNames = [cs sortedProtocolsNames];
    for(NSString *protocolName in protocolNames) {
        RTBProtocol *p = _allProtocolsByName[protocolName];
        if(p == nil) {
            p = [RTBProtocol protocolStubWithProtocolName:protocolName];
            _allProtocolsByName[protocolName] = p;

            [self addProtocolsAdoptedByProtocol:p];
        }

        [p.conformingClassesStubsSet addObject:cs];
    }
    
    return cs;
}

- (NSArray *)sortedClassStubs {
	if([_allClassStubsByName count] == 0) [self readAllRuntimeClasses];
	
	NSMutableArray *stubs = [NSMutableArray arrayWithArray:[_allClassStubsByName allValues]];
	[stubs sortUsingSelector:@selector(compare:)];
	return stubs;
}

+ (NSArray *)readAndSortAllRuntimeProtocolNames {

    NSMutableArray *ma = [NSMutableArray array];
    
    unsigned int protocolListCount = 0;
    __unsafe_unretained Protocol **protocolList = objc_copyProtocolList(&protocolListCount);
    for(NSUInteger i = 0; i < protocolListCount; i++) {
        __unsafe_unretained Protocol *p = protocolList[i];
        NSString *protocolName = NSStringFromProtocol(p);
        [ma addObject:protocolName];
    }
    free(protocolList);
    
    [ma sortUsingSelector:@selector(compare:)];
    
    return ma;
}

- (NSArray *)sortedProtocolStubs {
    
    if([_allProtocolsByName count] == 0) {
        [self readAllRuntimeClasses];
    }
    
    return [[_allProtocolsByName allValues] sortedArrayUsingSelector:@selector(compare:)];
}

- (void)readAllRuntimeClasses {
    unsigned int count = 0;
    // 获取所有已注册的类
    Class *classes = objc_copyClassList(&count);
    
    // 遍历并记录类信息
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        // 记录继承层次
        NSMutableArray *hierarchy = [NSMutableArray array];
        Class currentClass = cls;
        while (currentClass) {
            [hierarchy addObject:NSStringFromClass(currentClass)];
            currentClass = class_getSuperclass(currentClass);
        }
        
        // 获取类的所有成员变量
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        NSMutableArray *ivarInfo = [NSMutableArray array];
        for (unsigned int j = 0; j < ivarCount; j++) {
            Ivar ivar = ivars[j];
            [ivarInfo addObject:@{
                @"name": @(ivar_getName(ivar)),
                @"type": @(ivar_getTypeEncoding(ivar))
            }];
        }
        free(ivars);
        
        // 获取类的所有属性
        unsigned int propertyCount = 0;
        objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
        NSMutableArray *propertyInfo = [NSMutableArray array];
        for (unsigned int j = 0; j < propertyCount; j++) {
            objc_property_t property = properties[j];
            [propertyInfo addObject:@{
                @"name": @(property_getName(property)),
                @"attributes": @(property_getAttributes(property))
            }];
        }
        free(properties);
        
        // 获取类的所有方法
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        NSMutableArray *methodInfo = [NSMutableArray array];
        for (unsigned int j = 0; j < methodCount; j++) {
            Method method = methods[j];
            [methodInfo addObject:@{
                @"name": NSStringFromSelector(method_getName(method)),
                @"encoding": @(method_getTypeEncoding(method)),
                @"args": @(method_getNumberOfArguments(method))
            }];
        }
        free(methods);
        
        // 存储该类的完整信息
        NSString *className = NSStringFromClass(cls);
        self.allClassStubsByName[className] = @{
            @"hierarchy": hierarchy,
            @"ivars": ivarInfo,
            @"properties": propertyInfo,
            @"methods": methodInfo
        };
    }
    free(classes);
}

- (NSMutableDictionary *)allClassStubsByImagePath {
	if([_allClassStubsByImagePath count] == 0) {
		[self readAllRuntimeClasses];
	}
	return _allClassStubsByImagePath;
}

- (NSMutableArray *)rootClasses {
    /*" Classes are wrapped by ClassStub.  This array contains wrappers for root classes (classes that have no superclass). "*/
	if ([_rootClasses count] == 0) {
		[self readAllRuntimeClasses];
	}
	return _rootClasses;
}

- (void)emptyCachesAndReadAllRuntimeClasses {
/*"
We autorelease and reset the nil the global, static containers that
 hold the parsed runtime info.  This forces the entire runtime to\
 be re-parsed.

 +reset is designed to be called after the user has loaded new
 bundles (via "File -> Open..." in the UI's menu).
"*/	
	self.rootClasses = [NSMutableArray array];
	self.allClassStubsByName = [NSMutableDictionary dictionary];
	self.allClassStubsByImagePath = [NSMutableDictionary dictionary];
    self.allProtocolsByName = [NSMutableDictionary dictionary];
	
	[self readAllRuntimeClasses];
}

- (void)readRuntimeClasses {
    // 1. 增加内存分析
    unsigned int outCount = 0;
    Class *classes = objc_copyClassList(&outCount);
    
    for (unsigned int i = 0; i < outCount; i++) {
        Class cls = classes[i];
        
        // 2. 分析类的内存布局
        NSMutableDictionary *classInfo = [NSMutableDictionary dictionary];
        
        // 获取实例大小
        classInfo[@"instanceSize"] = @(class_getInstanceSize(cls));
        
        // 获取成员变量布局
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        NSMutableArray *ivarLayouts = [NSMutableArray array];
        
        for (unsigned int j = 0; j < ivarCount; j++) {
            Ivar ivar = ivars[j];
            NSString *ivarName = @(ivar_getName(ivar));
            NSString *ivarType = @(ivar_getTypeEncoding(ivar));
            ptrdiff_t ivarOffset = ivar_getOffset(ivar);
            
            [ivarLayouts addObject:@{
                @"name": ivarName,
                @"type": ivarType,
                @"offset": @(ivarOffset)
            }];
        }
        free(ivars);
        
        classInfo[@"ivarLayouts"] = ivarLayouts;
        
        // 3. 分析方法内存占用
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        NSMutableArray *methodSizes = [NSMutableArray array];
        
        for (unsigned int j = 0; j < methodCount; j++) {
            Method method = methods[j];
            SEL selector = method_getName(method);
            IMP implementation = method_getImplementation(method);
            
            [methodSizes addObject:@{
                @"name": NSStringFromSelector(selector),
                @"address": [NSString stringWithFormat:@"%p", implementation]
            }];
        }
        free(methods);
        
        classInfo[@"methods"] = methodSizes;
        
        // 存储类信息
        _runtimeClassInfo[NSStringFromClass(cls)] = classInfo;
    }
    free(classes);
}

- (void)trackClassLoadTime {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        [self analyzeClass:cls];
        CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
        // 记录加载时间
        [self.classLoadTimes setObject:@((endTime - startTime) * 1000) 
                               forKey:NSStringFromClass(cls)];
    }
    free(classes);
}

- (void)trackMethodCallTime {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        [self trackMethodsForClass:cls];
    }
    free(classes);
}

- (void)trackMethodsForClass:(Class)cls {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        // 添加方法调用耗时统计
        [self swizzleMethodForTimeTrack:cls selector:selector];
    }
    free(methods);
}

- (NSArray *)getClassLoadTimeInfo {
    // 实现代码
    return @[];
}

- (NSDictionary *)getMethodTimeProfileInfo {
    // 返回方法调用时间分析信息
    return @{};
}

// 添加辅助方法
- (BOOL)isRuntimeReady {
    // 实现代码
    return YES;
}

- (void)readAllRuntimeClassesWithCompletion:(void(^)(BOOL success))completion {
    // 实现代码
    if (completion) completion(YES);
}

// 实现在头文件中声明但在实现文件中缺少的方法
+ (void)startAnalyze {
    [[self sharedInstance] trackMethodCallTime];
    [[self sharedInstance] trackClassLoadTime];
}

+ (void)stopAnalyze {
    // 停止分析逻辑
    // 可以在这里清理资源或保存结果
}

+ (NSDictionary *)getAnalyzeResult {
    RTBRuntime *runtime = [self sharedInstance];
    return @{
        @"classLoadTimes": runtime.classLoadTimes ?: @{},
        @"methodTimes": [runtime getMethodTimeProfileInfo] ?: @{}
    };
}

// 实现之前引用但未实现的方法
- (id)init {
    if (self = [super init]) {
        _runtimeClassInfo = [NSMutableDictionary dictionary];
        _classLoadTimes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)analyzeClass:(Class)cls {
    // 基本的类分析实现
    if (!cls) return;
    
    NSString *className = NSStringFromClass(cls);
    if (_runtimeClassInfo[className]) return; // 已经分析过
    
    NSMutableDictionary *classInfo = [NSMutableDictionary dictionary];
    classInfo[@"name"] = className;
    classInfo[@"superclass"] = class_getSuperclass(cls) ? NSStringFromClass(class_getSuperclass(cls)) : @"";
    classInfo[@"instanceSize"] = @(class_getInstanceSize(cls));
    
    _runtimeClassInfo[className] = classInfo;
}

- (void)swizzleMethodForTimeTrack:(Class)cls selector:(SEL)selector {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    
    // 这里仅提供一个简单的实现框架，实际实现会更复杂
    NSLog(@"尝试跟踪方法: %@ in class %@", NSStringFromSelector(selector), NSStringFromClass(cls));
}

+ (void)ensureRuntimeInitialized {
    RTBRuntime *runtime = [RTBRuntime sharedInstance];
    if (runtime.rootClasses.count == 0) {
        [runtime readAllRuntimeClasses];
    }
}

- (NSArray *)getClassStubsForRegex:(NSString *)regex {
    if([_allClassStubsByName count] == 0) {
        [self readAllRuntimeClasses];
    }
    
    NSMutableArray *matchingClasses = [NSMutableArray array];
    NSError *error = nil;
    NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:regex 
                                                                            options:0 
                                                                              error:&error];
    if (error) {
        NSLog(@"正则表达式错误: %@", error.localizedDescription);
        return @[];
    }
    
    for (NSString *className in [_allClassStubsByName allKeys]) {
        NSTextCheckingResult *match = [regExp firstMatchInString:className 
                                                         options:0 
                                                           range:NSMakeRange(0, [className length])];
        if (match) {
            RTBClass *classStub = [_allClassStubsByName objectForKey:className];
            [matchingClasses addObject:classStub];
        }
    }
    
    return [matchingClasses sortedArrayUsingSelector:@selector(compare:)];
}
@end
