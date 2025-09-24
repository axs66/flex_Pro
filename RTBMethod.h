//
//  RTBMethod.h
//  OCRuntime
//
//  Created by Nicolas Seriot on 06/05/15.
//  Copyright (c) 2015 Nicolas Seriot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface RTBMethod : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) void *implementation;
@property (nonatomic, copy) NSString *encoding;
@property (nonatomic, strong) NSArray *arguments;
@property (nonatomic, readonly) Method method;
@property (nonatomic, readonly) BOOL isClassMethod;

// 核心属性和方法
+ (instancetype)methodObjectWithMethod:(Method)method isClassMethod:(BOOL)isClassMethod;
- (NSString *)filePath;
- (NSString *)categoryName;
- (NSComparisonResult)compare:(RTBMethod *)otherMethod;

// RTBMethodCell需要的方法
- (BOOL)hasArguments;
- (NSString *)returnTypeEncoded;
- (NSString *)returnTypeDecoded;
- (NSString *)selectorString;
- (SEL)selector;
- (NSString *)headerDescriptionWithNewlineAfterArgs:(BOOL)newlineAfterArgs;
- (NSArray *)argumentsTypesDecoded;

@end
