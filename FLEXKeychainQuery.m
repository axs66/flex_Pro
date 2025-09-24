//
//  FLEXKeychainQuery.m
//  FLEXKeychain
//
//  Created by Caleb Davenport on 3/19/13.
//  Copyright (c) 2013-2014 Sam Soffes. All rights reserved.
//

#import "FLEXKeychainQuery.h"
#import <Security/Security.h>

@implementation FLEXKeychainQuery

#pragma mark - 初始化

- (instancetype)init {
    self = [super init];
    if (self) {
#ifdef FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE
        self.synchronizationMode = FLEXKeychainQuerySynchronizationModeAny;
#endif
    }
    return self;
}

#pragma mark - 公共方法

- (BOOL)save:(NSError **)error {
    OSStatus status = [self performSaveOperation:error];
    return status == errSecSuccess;
}

- (BOOL)deleteItem:(NSError **)error {
    OSStatus status = [self performDeleteOperation:error];
    return status == errSecSuccess;
}

- (BOOL)fetch:(NSError **)error {
    OSStatus status = [self performFetchOperation:error];
    return status == errSecSuccess;
}

- (NSArray *)fetchAll:(NSError **)error {
    NSMutableDictionary *query = [self query];
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    query[(__bridge id)kSecReturnAttributes] = @YES;
    query[(__bridge id)kSecReturnData] = @YES;
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess && error) {
        *error = [self errorWithCode:status];
        return nil;
    }
    
    NSArray *array = (NSArray *)result;
    [array retain];
    CFRelease(result);
    return [array autorelease];
}

#pragma mark - 核心操作

- (OSStatus)performSaveOperation:(NSError **)error {
    if (!self.service || !self.account || !self.passwordData) {
        if (error) {
            *error = [self errorWithCode:errSecParam];
        }
        return errSecParam;
    }
    
    NSMutableDictionary *query = [self query];
    NSMutableDictionary *attributesToUpdate = [NSMutableDictionary dictionary];
    attributesToUpdate[(__bridge id)kSecValueData] = self.passwordData;
    
#ifdef FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE
    if (self.synchronizationMode != FLEXKeychainQuerySynchronizationModeAny) {
        id value = @(self.synchronizationMode == FLEXKeychainQuerySynchronizationModeYes);
        attributesToUpdate[(__bridge id)(kSecAttrSynchronizable)] = value;
    }
#endif
    
    // 首先尝试更新现有项目
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributesToUpdate);
    
    // 如果没有项目可更新，则创建一个新的
    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:attributesToUpdate];
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    
    if (status != errSecSuccess && error) {
        *error = [self errorWithCode:status];
    }
    
    return status;
}

- (OSStatus)performDeleteOperation:(NSError **)error {
    if (!self.service || !self.account) {
        if (error) {
            *error = [self errorWithCode:errSecParam];
        }
        return errSecParam;
    }
    
    NSMutableDictionary *query = [self query];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    if (status != errSecSuccess && error) {
        *error = [self errorWithCode:status];
    }
    
    return status;
}

- (OSStatus)performFetchOperation:(NSError **)error {
    if (!self.service || !self.account) {
        if (error) {
            *error = [self errorWithCode:errSecParam];
        }
        return errSecParam;
    }
    
    CFTypeRef result = NULL;
    NSMutableDictionary *query = [self query];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status != errSecSuccess) {
        if (error) {
            *error = [self errorWithCode:status];
        }
        return status;
    }
    
    // 修改 __bridge_transfer 转换，适用于非ARC环境
    NSData *data = (NSData *)result;
    [data retain];
    CFRelease(result);
    self.passwordData = [data autorelease];
    return errSecSuccess;
}

#pragma mark - 访问器

- (void)setPassword:(NSString *)password {
    if (!password) {
        self.passwordData = nil;
    } else {
        self.passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    }
}

- (NSString *)password {
    if (self.passwordData) {
        return [[NSString alloc] initWithData:self.passwordData encoding:NSUTF8StringEncoding];
    }
    return nil;
}

#pragma mark - 同步状态

#ifdef FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE
- (void)setAccess:(FLEXKeychainAccessOptions)access {
    _access = access; // 将参数 access 赋值给对应的实例变量
}

- (void)setSynchronizationMode:(FLEXKeychainQuerySynchronizationMode)synchronizationMode {
    _synchronizationMode = synchronizationMode;
}
#endif

#pragma mark - 查询生成

- (NSMutableDictionary *)query {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    
    if (self.service) {
        query[(__bridge id)kSecAttrService] = self.service;
    }
    
    if (self.account) {
        query[(__bridge id)kSecAttrAccount] = self.account;
    }
    
    if (self.accessGroup) {
        query[(__bridge id)kSecAttrAccessGroup] = self.accessGroup;
    }
    
#ifdef FLEXKEYCHAIN_SYNCHRONIZATION_AVAILABLE
    if (self.synchronizationMode != FLEXKeychainQuerySynchronizationModeAny) {
        id value = @(self.synchronizationMode == FLEXKeychainQuerySynchronizationModeYes);
        query[(__bridge id)(kSecAttrSynchronizable)] = value;
    }
#endif
    
    return query;
}

#pragma mark - 错误处理

- (NSError *)errorWithCode:(OSStatus)code {
    NSString *message = [self keychainErrorMessageForCode:code];
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: message};
    return [NSError errorWithDomain:@"FLEXKeychainErrorDomain" code:code userInfo:userInfo];
}

- (NSString *)keychainErrorMessageForCode:(OSStatus)code {
    switch (code) {
        case errSecSuccess:
            return @"操作成功完成";
        case errSecUnimplemented:
            return @"功能未实现";
        case errSecParam:
            return @"参数无效";
        case errSecAllocate:
            return @"无法分配内存";
        case errSecNotAvailable:
            return @"没有可信设备";
        case errSecDuplicateItem:
            return @"项目已存在";
        case errSecItemNotFound:
            return @"找不到项目";
        case errSecInteractionNotAllowed:
            return @"不允许交互";
        case errSecDecode:
            return @"解码失败";
        case errSecAuthFailed:
            return @"认证失败";
        default:
            return [NSString stringWithFormat:@"错误代码 %ld", (long)code];
    }
}

@end
