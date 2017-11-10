//
//  ULAVAssetSessionCache.m
//  ULAVPlayer
//
//  Created by 王传正 on 20/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import "ULAVAssetSessionCache.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "NSData+MD5.h"

@interface ULAVAssetSessionCache ()

@property (nonatomic, strong) NSFileHandle *readFileHandle;
@property (nonatomic, strong) NSFileHandle *writeFileHandle;

@property (nonatomic, strong) NSString *cachePath;

@property (nonatomic, assign) long long cachefileSize;
@property (nonatomic, assign) BOOL isCancel;

@end

@implementation ULAVAssetSessionCache

- (void)dealloc{
    NSLog(@"%s",__func__);
    _isCancel = YES;
    [self.writeFileHandle closeFile];
    [self.readFileHandle closeFile];
}

#pragma mark - Open

- (BOOL)cacheAvailable{
    @try {
        NSString *md5 = [[self.readFileHandle readDataToEndOfFile] MD5];
        if ([md5 isEqualToString:self.config.md5]) {
            return YES;
        }
        return NO;
    } @catch (NSException *exception) {
        NSLog(@"read cached data error %@",exception);
    }
    
}

- (void)save {
    [self.writeFileHandle synchronizeFile];
}

- (void)deleteCache {
    if (!self.cachePath.length) {
        return;
    }
    self.isCancel = YES;
    
    [self.readFileHandle closeFile];
    [self.writeFileHandle closeFile];
    
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSError *error = nil;
    BOOL removeSuccess = [fileMgr removeItemAtPath:self.cachePath error:&error];
    if (!removeSuccess) {
        // Error handling
        NSLog(@"Delete cache error %@",error.description);
    }else{
        [self.config deleteConfigFile];
    }
    self.isCancel = NO;
}

- (void)saveConfig{
    if (_isCancel) {
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:self.cachePath];
    self.config.md5 = [data MD5];
    [self.config saveWithPath:self.cachePath];
}

- (void)cacheData:(NSData *)data range:(NSRange)range{
    if (_isCancel) {
        return;
    }
    @try {
        [self.writeFileHandle seekToFileOffset:range.location];
        [self.writeFileHandle writeData:data];
        
        self.config.downloadedContentLength += data.length;
        
    } @catch (NSException *exception) {
        NSLog(@"write to file error");
    }}

- (NSData *)cachedDataForRange:(NSRange)range error:(NSError **)error {
    @synchronized(self.readFileHandle) {
        @try {
            [self.readFileHandle seekToFileOffset:range.location];
            NSData *data = [self.readFileHandle readDataOfLength:range.length]; // 空数据也会返回，所以如果 range 错误，会导致播放失效
            return data;
        } @catch (NSException *exception) {
            NSLog(@"read cached data error %@",exception);
            *error = [NSError errorWithDomain:exception.name code:123 userInfo:@{NSLocalizedDescriptionKey: exception.reason, @"exception": exception}];
        }
    }
    return nil;
}

- (void)setCacheConfigWithResponse:(NSURLResponse *)response{
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
        NSDictionary *allHeaderFields = HTTPURLResponse.allHeaderFields;
        NSString *acceptRange = allHeaderFields[@"Accept-Ranges"];
        BOOL byteRangeAccessSupported = [acceptRange isEqualToString:@"bytes"];
        
        NSString *mimeType = response.MIMEType;
        CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
        
        long long contentLength = [[[HTTPURLResponse.allHeaderFields[@"Content-Range"] componentsSeparatedByString:@"/"] lastObject] longLongValue];
        
        self.config.contentLength = contentLength;
        self.config.byteRangeAccessSupported = byteRangeAccessSupported;
        self.config.contentType = CFBridgingRelease(contentType);
        
        [self.config saveWithPath:self.cachePath];
     
        [self configFileOffset:self.config.contentLength];
    }
}

- (void)configFileOffset:(long long)offset{
    @try {
        [self.writeFileHandle truncateFileAtOffset:offset];
        [self.writeFileHandle synchronizeFile];
    } @catch (NSException *exception) {
        NSLog(@"read cached data error %@", exception);
    }
}

- (NSString *)cachePathWithUrl:(NSURL *)url{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"UPLiveMedia"];
    path = [path stringByAppendingPathComponent:[url lastPathComponent]];
    return path;
}

- (void)createFolderFileHandle{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSString *cacheFolder = [self.cachePath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:cacheFolder]) {
        [fileManager createDirectoryAtPath:cacheFolder
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    
    if (!error) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.cachePath]) {
            [[NSFileManager defaultManager] createFileAtPath:self.cachePath contents:nil attributes:nil];
        }
        NSURL *fileURL = [NSURL fileURLWithPath:self.cachePath];
        if (!error) {
            self.readFileHandle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&error];
            self.writeFileHandle = [NSFileHandle fileHandleForWritingToURL:fileURL error:&error];
        }
    }
}

- (instancetype)initWithUrl:(NSURL *)url{
    self = [super init];
    if (self) {
        
        self.cachePath = [self cachePathWithUrl:url];
        [self createFolderFileHandle];
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.cachePath error:nil];
        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
        self.cachefileSize = [fileSizeNumber longLongValue];
        
        self.config = [ULAVAssetCacheFileConfig loadCacheConfigWithPath:self.cachePath];
    }
    return self;
}

+ (void)ul_clearCache{
    NSString *folderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"UPLiveMedia"];
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    NSError *error = nil;
    NSArray *directoryContents = [fileMgr contentsOfDirectoryAtPath:folderPath error:&error];
    if (error == nil) {
        for (NSString *path in directoryContents) {
            NSString *fullPath = [folderPath stringByAppendingPathComponent:path];
            BOOL removeSuccess = [fileMgr removeItemAtPath:fullPath error:&error];
            if (!removeSuccess) {
                // Error handling
            }
        }
    } else {
        // Error handling
    }
}

+ (float)ul_getCacheSize{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"UPLiveMedia"];
    return [self folderSizeAtPath:path];
}

+ (long long)fileSizeAtPath:(NSString*)filePath{
    NSFileManager* manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

+ (float)folderSizeAtPath:(NSString*)folderPath{
    NSFileManager* manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:folderPath]) return 0;
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:folderPath] objectEnumerator];
    NSString* fileName;
    long long folderSize = 0;
    while ((fileName = [childFilesEnumerator nextObject]) != nil){
        NSString* fileAbsolutePath = [folderPath stringByAppendingPathComponent:fileName];
        folderSize += [self fileSizeAtPath:fileAbsolutePath];
    }
    return folderSize/(1024.0*1024.0);
}

@end
