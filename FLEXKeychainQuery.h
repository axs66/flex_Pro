//
//  FLEXKeychainQuery.h
//
//  Derived from:
//  SSKeychainQuery.h in SSKeychain
//  Created by Caleb Davenport on 3/19/13.
//  Copyright (c) 2010-2014 Sam Soffes. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// iOS 7 可用的同步类型
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
#define FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE 1
#endif

#ifdef FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE
typedef NS_ENUM(NSUInteger, FLEXKeychainQuerySynchronizationMode) {
    FLEXKeychainQuerySynchronizationModeAny,
    FLEXKeychainQuerySynchronizationModeNo,
    FLEXKeychainQuerySynchronizationModeYes
};
#endif

typedef NS_ENUM(NSInteger, FLEXKeychainAccessOptions) {
    FLEXKeychainAccessOptionDefault = 0,
    FLEXKeychainAccessOptionAccessibleWhenUnlocked,
    FLEXKeychainAccessOptionAccessibleAfterFirstUnlock,
    FLEXKeychainAccessOptionAccessibleAlways,
    FLEXKeychainAccessOptionAccessibleWhenPasscodeSetThisDeviceOnly,
    FLEXKeychainAccessOptionAccessibleWhenUnlockedThisDeviceOnly,
    FLEXKeychainAccessOptionAccessibleAfterFirstUnlockThisDeviceOnly,
    FLEXKeychainAccessOptionAccessibleAlwaysThisDeviceOnly
};

/**
 FLEXKeychainQuery 封装了与钥匙串相关的操作，提供简单的访问和管理钥匙串项目的方法
 */
@interface FLEXKeychainQuery : NSObject

/** 
 钥匙串中项目的kSecAttrAccount值
 */
@property (nonatomic, copy, nullable) NSString *account;

/** 
 钥匙串中项目的kSecAttrService值 
 */
@property (nonatomic, copy, nullable) NSString *service;

/**
 钥匙串中项目的kSecAttrAccessGroup值
 */
@property (nonatomic, copy, nullable) NSString *accessGroup;

/**
 钥匙串中项目关联的密码
 */
@property (nonatomic, copy, nullable) NSString *password;

/**
 钥匙串中项目关联的原始密码数据
 */
@property (nonatomic, copy, nullable) NSData *passwordData;

#ifdef FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE
/**
 钥匙串中项目的kSecAttrSynchronizable值
 */
@property (nonatomic, assign) FLEXKeychainQuerySynchronizationMode synchronizationMode;
#endif

/**
 钥匙串中项目的访问选项
 */
@property (nonatomic, assign) FLEXKeychainAccessOptions access;

/**
 将接收者的值存储到钥匙串中

 @param error 发生错误时设置为具体错误
 @return 成功返回YES，否则返回NO
 */
- (BOOL)save:(NSError **)error;

/**
 从钥匙串中删除接收者匹配的项
 
 @param error 发生错误时设置为具体错误
 @return 成功返回YES，否则返回NO
 */
- (BOOL)deleteItem:(NSError **)error;

/**
 从钥匙串中获取接收者匹配项的密码
 
 @param error 发生错误时设置为具体错误
 @return 成功返回YES，否则返回NO
 */
- (BOOL)fetch:(NSError **)error;

/**
 从钥匙串中获取接收者匹配的所有项目
 
 @param error 发生错误时设置为具体错误
 @return 匹配项的数组，失败时返回nil
 */
- (NSArray *)fetchAll:(NSError **)error;

/**
 返回一个表示查询的字典，可用于钥匙串操作
 
 @return 表示查询的字典
 */
- (NSMutableDictionary *)query;

@end

NS_ASSUME_NONNULL_END
