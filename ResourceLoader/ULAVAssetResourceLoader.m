//
//  ULAVAssetResourceLoader.m
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import "ULAVAssetResourceLoader.h"
#import "ULAVAssetSessionTask.h"
#import "ULAVAssetSessionCache.h"
@interface ULAVAssetResourceLoader ()<ULAVAssetSessionTaskDelegate>

/// 存储播放器发起的每个请求，用于回调播放器和协助播放器取消某个请求
@property (nonatomic, strong) NSMutableDictionary *sessionTaskSet;

@property (nonatomic, strong) dispatch_queue_t operationQueue;
@property (nonatomic, strong) dispatch_queue_t writeDataQueue;
@property (nonatomic, strong) dispatch_queue_t readDataQueue;

@property (nonatomic, strong) AVURLAsset *urlAsset;
@property (nonatomic, strong) NSURL *originURL;
/// 缓存类
@property (nonatomic, strong) ULAVAssetSessionCache *sessionCache;
@end

@implementation ULAVAssetResourceLoader

- (instancetype)init{
    self = [super init];
    if (self) {
        self.sessionTaskSet = [NSMutableDictionary dictionary];
        
        self.operationQueue = dispatch_queue_create("com.ULAVAssetResourceLoader.operationQueue", DISPATCH_QUEUE_SERIAL);
        self.writeDataQueue = dispatch_queue_create("com.ULAVAssetResourceLoader.writeDataQueue", DISPATCH_QUEUE_SERIAL);
        self.readDataQueue = dispatch_queue_create("com.ULAVAssetResourceLoader.readDataQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Open

- (AVPlayerItem *)playerItemWithURL:(NSURL *)url {
    if (_urlAsset) {
        [self cancel];
    }
    self.originURL = url;
    NSURL *assetURL = [self assetURLWithURL:url];
    
    _urlAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    [_urlAsset.resourceLoader setDelegate:self queue:self.operationQueue];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:_urlAsset];
    if ([playerItem respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]) {
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    return playerItem;
}

- (void)cancel {
    [_urlAsset.resourceLoader setDelegate:nil queue:self.operationQueue];
    _urlAsset = nil;
    
    [self.sessionTaskSet enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, ULAVAssetSessionTask * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
    
    [self.sessionTaskSet removeAllObjects];
}

- (void)removeCache {
    [self.sessionCache deleteCache];
}

#pragma mark - Private

- (void)setOriginURL:(NSURL *)originURL {
    _originURL = originURL;
    self.sessionCache = [[ULAVAssetSessionCache alloc]initWithUrl:self.originURL];
}

- (NSURL *)assetURLWithURL:(NSURL *)url {
    if (!url) {
        return nil;
    }
    
    NSURLComponents *componnents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    componnents.scheme = kCacheScheme;
    
    NSString *appendStr = componnents.query.length > 0 ? @"&" : @"?";
    NSURL *assetURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@ORIUrl=%@", componnents.URL.absoluteString, appendStr, url.absoluteString]];
    
    return assetURL;
}

/// 通过request获取一个保存session用的key
- (NSString *)keyForRequest:(AVAssetResourceLoadingRequest *)request{
    return [NSString stringWithFormat:@"%@%@", request.request.URL.absoluteString, request.request.allHTTPHeaderFields[@"Range"]];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest{
    NSURL *resourceURL = [loadingRequest.request URL];
    if ([resourceURL.scheme isEqualToString:kCacheScheme]) {
        
        // 通过缓存返回给播放器数据
        if ([self.sessionCache cacheAvailable]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (self.sessionCache.config.contentLength > 0) {
                    AVAssetResourceLoadingContentInformationRequest *contentInformationRequest = loadingRequest.contentInformationRequest;
                    contentInformationRequest.byteRangeAccessSupported = self.sessionCache.config.byteRangeAccessSupported;
                    contentInformationRequest.contentLength = self.sessionCache.config.contentLength;;
                    contentInformationRequest.contentType = self.sessionCache.config.contentType;
                    NSLog(@"Use cached data fill Information");
                }
            });
           
            AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
            unsigned long long requestedLength = dataRequest.requestedLength;
            unsigned long long offset = dataRequest.requestedOffset;
            if (dataRequest.currentOffset != 0) {
                offset = dataRequest.currentOffset;
            }
            
            NSRange range = NSMakeRange(offset, requestedLength);
            
            dispatch_async(self.readDataQueue, ^{
                NSError *error;
                NSData *data = [self.sessionCache cachedDataForRange:range error:&error];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                        [loadingRequest finishLoadingWithError:error];
                    } else {
                        [loadingRequest.dataRequest respondWithData:data];
                        [loadingRequest finishLoading];
                    }
                });
            });
            
        }else{
            NSString *key = [self keyForRequest:loadingRequest];
            ULAVAssetSessionTask *task = self.sessionTaskSet[key];
            if (task) {
                [task cancel];
                [self.sessionTaskSet removeObjectForKey:key];
            }
            
            ULAVAssetSessionTask *newTask = [[ULAVAssetSessionTask alloc]initWithRequest:loadingRequest];
            newTask.delegate = self;
            self.sessionTaskSet[key] = newTask;
            [newTask resume];
        }
        return YES;
    }
    return NO;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest{
    NSString *key = [self keyForRequest:loadingRequest];
    ULAVAssetSessionTask *task = self.sessionTaskSet[key];
    if (task) {
        [task cancel];
        [self.sessionTaskSet removeObjectForKey:key];
    }else{
        NSError *error = [[NSError alloc] initWithDomain:@"com.resourceloader"
                                                    code:-3
                                                userInfo:@{NSLocalizedDescriptionKey:@"Resource loader cancelled"}];
        [loadingRequest finishLoadingWithError:error];
    }
}

#pragma mark - ULAVAssetSessionTaskDelegate

- (void)didReceiveResponse:(NSURLResponse *)response loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    dispatch_sync(self.writeDataQueue, ^{
        
        [self.sessionCache setCacheConfigWithResponse:response];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (self.sessionCache.config.contentLength > 0) {
                AVAssetResourceLoadingContentInformationRequest *contentInformationRequest = loadingRequest.contentInformationRequest;
                contentInformationRequest.byteRangeAccessSupported = self.sessionCache.config.byteRangeAccessSupported;
                contentInformationRequest.contentLength = self.sessionCache.config.contentLength;;
                contentInformationRequest.contentType = self.sessionCache.config.contentType;
                NSLog(@"DidReceiveResponse fill Information");
            }
        });
    });
}

- (void)didReceiveData:(NSData *)data loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    dispatch_sync(self.writeDataQueue, ^{
        // 读取当前偏移和长度用来存磁盘
        NSRange range = NSMakeRange(loadingRequest.dataRequest.currentOffset, data.length);
        // 储存到磁盘
        [self.sessionCache cacheData:data range:range];
        
        NSLog(@"Receive DataRange:%zd - %zd",range.location,range.length);
    });
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        // 回调给AVPlayer
        [loadingRequest.dataRequest respondWithData:data];
    });
}

- (void)didCompleteloadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest error:(NSError *)error {
    dispatch_async(self.operationQueue, ^{
        
        NSString *key = [self keyForRequest:loadingRequest];
        ULAVAssetSessionTask *task = self.sessionTaskSet[key];
        if (task) {
            [self.sessionTaskSet removeObjectForKey:key];
        }
        
        dispatch_sync(self.writeDataQueue, ^{
            /// 同步资源缓存
            [self.sessionCache save];
        });
        
        if (!error) {
            dispatch_sync(self.writeDataQueue, ^{
                ///如果当前请求是最后一个请求，完成了全部资源下载后保存缓存配置文件，生成md5
                long long currentRequestLength = loadingRequest.dataRequest.requestedOffset + loadingRequest.dataRequest.requestedLength;
                if (currentRequestLength == self.sessionCache.config.contentLength) {
                    [self.sessionCache saveConfig];
                }
            });
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                [loadingRequest finishLoading];
            });
            
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [loadingRequest finishLoadingWithError:error];
            });
        }
        
    });
    
}

@end
