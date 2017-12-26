//
//  ULAVAssetSessionTask.m
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import "ULAVAssetSessionTask.h"
#import <MobileCoreServices/MobileCoreServices.h>

// 暂停使用
static NSInteger kBufferSize = 80 * 1024;

@interface ULAVAssetSessionTask ()<NSURLSessionDataDelegate>

/// 播放器的loadingRequest
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;

/// URLSession的delegate队列
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, strong) NSURLSession *session;

/// 缓冲数据
@property (nonatomic, strong) NSMutableData *bufferData;//暂停使用

/// 资源原始URL
@property (nonatomic, strong) NSURL *originURL;

/// 保存缓存用的seekOffset
@property (nonatomic, assign) NSInteger startOffset;

/// 已取消
@property (nonatomic, assign) BOOL isCancelled;



@end

@implementation ULAVAssetSessionTask

- (void)dealloc{
    NSLog(@"func %s",__func__);
}

#pragma mark - Open

- (void)resume{
    AVAssetResourceLoadingDataRequest *dataRequest = self.loadingRequest.dataRequest;
    unsigned long long offset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0) {
        offset = dataRequest.currentOffset;
    }
    /// 配置本次请求资源的起点和长度
    unsigned long long length = offset + dataRequest.requestedLength - 1;
    
    /// 去网络请求数据给播放器
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.originURL];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    request.timeoutInterval = 15;
    
    if (length < 5) {
        request.timeoutInterval = 10;
    }
    
    NSString *rangeStr = [NSString stringWithFormat:@"bytes=%lld-%lld", offset, length];
    [request setValue:rangeStr forHTTPHeaderField:@"Range"];
    /// 设置缓存起点
    self.startOffset = offset;
    
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
    
    NSLog(@"ULVideoPlayer 发起请求 DataRange:%@",rangeStr);
}

- (void)cancel{
    self.isCancelled = YES;
    
    if (self.session) {
        [self.session invalidateAndCancel];
        self.session = nil;
    }
    
    /// 完成本次请求，返回一个取消类型的error
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(didCompleteloadingRequest:error:)]) {
            [self.delegate didCompleteloadingRequest:self.loadingRequest error:[self loaderCancelledError]];
        }
    }
}

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)request{
    self = [super init];
    if (self) {
        self.bufferData = [NSMutableData data];
        self.loadingRequest = request;
        
        self.originURL =  [self configOriginURL];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.name = @"com.videoCache.download";
        queue.maxConcurrentOperationCount = 1;
        self.downloadQueue = queue;
        
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                     delegate:self
                                                delegateQueue:self.downloadQueue];
        
    }
    return self;
}

#pragma mark - Private

- (NSURL *)configOriginURL{
    NSURL *url = [self.loadingRequest.request URL];
    NSURLComponents *components = [NSURLComponents componentsWithString:url.absoluteString];
    NSURL *originURL;
    if ([components respondsToSelector:@selector(queryItems)]) {
        NSURLQueryItem *queryItem = [components.queryItems lastObject];
        originURL = [NSURL URLWithString:queryItem.value];
    } else {
        NSString *url = [[components.query componentsSeparatedByString:@"="] lastObject];
        originURL = [NSURL URLWithString:url];
    }
    return originURL;
}

- (NSError *)loaderCancelledError{
    NSError *error = [[NSError alloc] initWithDomain:@"com.resourceloader"
                                                code:-3
                                            userInfo:@{NSLocalizedDescriptionKey:@"Resource loader cancelled"}];
    return error;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"ULVideoPlayer 收到响应");
    if (self.isCancelled) {
        return;
    }
    NSString *mimeType = response.MIMEType;
    /// 目前只支持视频
    if ([mimeType rangeOfString:@"video/"].location == NSNotFound) {
        completionHandler(NSURLSessionResponseCancel);
    } else {
        if (self.delegate) {
            if ([self.delegate respondsToSelector:@selector(didReceiveResponse:loadingRequest:)]) {
                [self.delegate didReceiveResponse:response loadingRequest:self.loadingRequest];
            }
        }
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (self.isCancelled) {
        return;
    }
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(didReceiveData:loadingRequest:)]) {
            [self.delegate didReceiveData:data loadingRequest:self.loadingRequest];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"ULVideoPlayer 请求完成 Error : %@",error);
    if (self.isCancelled) {
        return;
    }
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(didCompleteloadingRequest:error:)]) {
            [self.delegate didCompleteloadingRequest:self.loadingRequest error:error];
        }
    }
}

@end
