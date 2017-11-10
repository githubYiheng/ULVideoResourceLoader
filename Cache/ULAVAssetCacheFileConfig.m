//
//  ULAVAssetCacheFileConfig.m
//  ULAVPlayer
//
//  Created by 王传正 on 20/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import "ULAVAssetCacheFileConfig.h"

static NSString *kContentLengthKey = @"kContentLengthKey";
static NSString *kContentTypeKey = @"kContentTypeKey";
static NSString *kMd5Key = @"kMd5y";
static NSString *kByteRangeAccessSupported = @"kByteRangeAccessSupported";
static NSString *kDownloadedContentLength = @"kDownloadedContentLength";

@implementation ULAVAssetCacheFileConfig

+ (instancetype)loadCacheConfigWithPath:(NSString *)filePath {
    NSString *path = [self configurationFilePathForFilePath:filePath];
    ULAVAssetCacheFileConfig *configuration = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    configuration.configFilePath = path;
    if (!configuration) {
        configuration = [[self alloc] init];
    }
    return configuration;
}

- (void)deleteConfigFile {
    if (!self.configFilePath.length) {
        return;
    }
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSError *error = nil;
    BOOL removeSuccess = [fileMgr removeItemAtPath:self.configFilePath error:&error];
    if (!removeSuccess) {
        // Error handling
        NSLog(@"Delete cache error %@",error.description);
    }
}

- (void)saveWithPath:(NSString *)filePath {
    @synchronized (self) {
        NSString *path = [ULAVAssetCacheFileConfig configurationFilePathForFilePath:filePath];
        [NSKeyedArchiver archiveRootObject:self toFile:path];
    }
}

+ (NSString *)configurationFilePathForFilePath:(NSString *)filePath {
    return [filePath stringByAppendingPathExtension:@"cache_cfg"];
}


- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.contentLength) forKey:kContentLengthKey];
    [aCoder encodeObject:self.contentType forKey:kContentTypeKey];
    [aCoder encodeObject:self.md5 forKey:kMd5Key];
    [aCoder encodeObject:@(self.byteRangeAccessSupported) forKey:kByteRangeAccessSupported];
    [aCoder encodeObject:@(self.downloadedContentLength) forKey:kDownloadedContentLength];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _contentLength = [[aDecoder decodeObjectForKey:kContentLengthKey] longLongValue];
        _downloadedContentLength = [[aDecoder decodeObjectForKey:kDownloadedContentLength] longLongValue];
        _contentType = [aDecoder decodeObjectForKey:kContentTypeKey];
        _md5 = [aDecoder decodeObjectForKey:kMd5Key];
        _byteRangeAccessSupported = [[aDecoder decodeObjectForKey:kByteRangeAccessSupported] boolValue];
    }
    return self;
}

@end
