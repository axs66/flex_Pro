/*
 AllClasses.h created by eepstein on Sat 16-Mar-2002


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

#import <Foundation/Foundation.h>
#import "RTBClass.h"

// 添加 RTBProtocol 类的前向声明
@class RTBProtocol;

@interface RTBRuntime : NSObject

// 单例访问
+ (instancetype)sharedInstance;

// 确保运行时已初始化
+ (void)ensureRuntimeInitialized;

// 类列表访问方法
- (NSArray *)sortedClassStubs;
- (RTBClass *)classStubForClassName:(NSString *)className;
- (NSArray *)getClassStubsForRegex:(NSString *)regex;

// 根类访问
@property (nonatomic, strong) NSMutableArray *rootClasses;

// 类缓存字典
@property (nonatomic, strong) NSMutableDictionary *allClassStubsByName;
@property (nonatomic, strong) NSMutableDictionary *allClassStubsByImagePath;
@property (nonatomic, strong) NSMutableDictionary *allProtocolsByName;

// 缓存管理
- (void)emptyCachesAndReadAllRuntimeClasses;
- (void)readAllRuntimeClasses;

// 其他辅助方法
- (RTBClass *)getOrCreateClassStubsRecursivelyForClass:(Class)klass;
- (void)addProtocolsAdoptedByProtocol:(RTBProtocol *)p;

// 协议相关
- (NSArray *)sortedProtocolStubs;

@end
