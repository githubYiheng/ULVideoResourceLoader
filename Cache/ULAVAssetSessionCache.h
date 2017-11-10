//
//  ULAVAssetSessionCache.h
//  ULAVPlayer
//
//  Created by 王传正 on 20/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ULAVAssetCacheFileConfig.h"

@class ULAVAssetCacheFileConfig;

@interface ULAVAssetSessionCache : NSObject

- (instancetype)initWithUrl:(NSURL *)url;

/// 缓存大小
@property (nonatomic, readonly) long long cachefileSize;

/// 缓存路径
@property (nonatomic, readonly) NSString *cachePath;

/// 磁盘里面存的当前缓存配置文件
@property (nonatomic, strong) ULAVAssetCacheFileConfig *config;

/// 缓存一段数据到磁盘
- (void)cacheData:(NSData *)data range:(NSRange)range;

/// 从磁盘获取一段缓存
- (NSData *)cachedDataForRange:(NSRange)range error:(NSError **)error;

/// 通过请求头初始化缓存配置文件
- (void)setCacheConfigWithResponse:(NSURLResponse *)response;

/// 保存缓存文件
- (void)save;

/// 保存缓存配置文件
- (void)saveConfig;

- (void)deleteCache;

/// 当前缓存是否可用
- (BOOL)cacheAvailable;

/// 清空全部
+ (void)ul_clearCache;

/// 返回缓存文件夹大小,m单位
+ (float)ul_getCacheSize;

@end
