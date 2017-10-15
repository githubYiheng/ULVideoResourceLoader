//
//  ULAVAssetCacheFileConfig.h
//  ULAVPlayer
//
//  Created by 王传正 on 20/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ULAVAssetCacheFileConfig : NSObject

/// 资源类型
@property (nonatomic, strong) NSString *contentType;
/// 目前使用文件md5值来判断缓存是否可用
@property (nonatomic, strong) NSString *md5;

/// 是否支持分段请求
@property (nonatomic, assign) BOOL byteRangeAccessSupported;

/// 资源总长，远端返回的
@property (nonatomic, assign) unsigned long long contentLength;

/// 这个不准，之前想用来判断缓存来着，先留着以后可能别的需求用吧
@property (nonatomic, assign) unsigned long long downloadedContentLength;

/// 通过（实际媒体资源路径）获取缓存配置文件，如果没有找到会返回一个新的
+ (instancetype)loadCacheConfigWithPath:(NSString *)filePath;

/// 通过（实际媒体资源路径）保存配置
- (void)saveWithPath:(NSString *)filePath;

@end
