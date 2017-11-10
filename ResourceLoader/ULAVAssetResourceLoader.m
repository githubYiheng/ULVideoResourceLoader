//
//  ULAVAssetResourceLoader.m
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import "ULAVAssetResourceLoader.h"
#import "ULAVAssetSessionTask.h"

@interface ULAVAssetResourceLoader ()

/// 存储播放器发起的每个请求，用于回调播放器和协助播放器取消某个请求
@property (nonatomic, strong) NSMutableDictionary *sessionTaskSet;

@property (nonatomic, strong) dispatch_queue_t operationQueue;

@property (nonatomic, strong) AVURLAsset *urlAsset;
@end

@implementation ULAVAssetResourceLoader

- (instancetype)init{
    self = [super init];
    if (self) {
        self.sessionTaskSet = [NSMutableDictionary dictionary];
        
        self.operationQueue = dispatch_queue_create("com.ULAVAssetResourceLoader.operationQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Open

- (AVPlayerItem *)playerItemWithURL:(NSURL *)url {
    if (_urlAsset) {
        [self cancel];
    }
    
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
    [self.sessionTaskSet enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, ULAVAssetSessionTask * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj removeCache];
        *stop = YES;
    }];
}

#pragma mark - Private

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
        NSString *key = [self keyForRequest:loadingRequest];
        ULAVAssetSessionTask *task = self.sessionTaskSet[key];
        if (task) {
            [task cancel];
            [self.sessionTaskSet removeObjectForKey:key];
        }
        
        ULAVAssetSessionTask *newTask = [[ULAVAssetSessionTask alloc]initWithRequest:loadingRequest];
        self.sessionTaskSet[key] = newTask;
        [newTask resume];
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
    }
}

@end
