//
//  ULAVAssetSessionTask.m
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import "ULAVAssetSessionTask.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "ULAVAssetSessionCache.h"

static NSInteger kBufferSize = 10 * 1024;

@interface ULAVAssetSessionTask ()<NSURLSessionDataDelegate>

/// 播放器的loadingRequest
@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;

/// URLSession的delegate队列
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, strong) NSURLSession *session;

/// 缓冲数据
@property (nonatomic, strong) NSMutableData *bufferData;

/// 资源原始URL
@property (nonatomic, strong) NSURL *originURL;

/// 保存缓存用的seekOffset
@property (nonatomic, assign) NSInteger startOffset;

/// 已取消
@property (nonatomic, assign) BOOL isCancelled;

/// 缓存类
@property (nonatomic, strong) ULAVAssetSessionCache *sessionCache;

@end

@implementation ULAVAssetSessionTask

- (void)dealloc{
    NSLog(@"func %s",__func__);
}

#pragma mark - Open

- (void)resume{
    AVAssetResourceLoadingDataRequest *dataRequest = self.loadingRequest.dataRequest;
    long long offset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0) {
        offset = dataRequest.currentOffset;
    }
    /// 通过缓存返回给播放器数据
    if ([self.sessionCache cacheAvailable]) {
        NSError *error;
        NSRange range = NSMakeRange(offset, dataRequest.requestedLength);
        NSData *data = [self.sessionCache cachedDataForRange:range error:&error];
        if (error) {
            [self.loadingRequest finishLoadingWithError:error];
        } else {
            [self.loadingRequest.dataRequest respondWithData:data];
            [self.loadingRequest finishLoading];
        }
    }else{
        /// 去网络请求数据给播放器
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.originURL];
        request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
        
        /// 配置本次请求资源的起点和长度
        NSString *rangeStr = [NSString stringWithFormat:@"bytes=%zd-%zd", offset, offset + dataRequest.requestedLength - 1];
        [request setValue:rangeStr forHTTPHeaderField:@"Range"];
        
        /// 设置缓存起点
        self.startOffset = offset;
        
        NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
        [task resume];
    }
}

- (void)cancel{
    self.isCancelled = YES;
    
    /// 取消掉session代理队列的任务，理论上没什么作用
    [self.downloadQueue cancelAllOperations];
    
    if (self.session) {
        [self.session invalidateAndCancel];
    }
    
    /// 完成本次请求，返回一个取消类型的error
    if (!self.loadingRequest.isFinished) {
        [self.loadingRequest finishLoadingWithError:[self loaderCancelledError]];
    }
    
}

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)request{
    self = [super init];
    if (self) {
        self.bufferData = [NSMutableData data];
        self.loadingRequest = request;
        
        self.originURL =  [self configOriginURL];
        self.sessionCache = [[ULAVAssetSessionCache alloc]initWithUrl:self.originURL];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.name = @"com.videoCache.download";
        queue.maxConcurrentOperationCount = 1;
        self.downloadQueue = queue;
        
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                     delegate:self
                                                delegateQueue:self.downloadQueue];
        
        /// 如果有缓存，欲先通过缓存来填充infomationRequest
        [self fillInfomationRequet];
    }
    return self;
}

#pragma mark - Private

- (void)fillInfomationRequet{
    if (self.sessionCache.config.contentLength > 0) {
        AVAssetResourceLoadingContentInformationRequest *contentInformationRequest = self.loadingRequest.contentInformationRequest;
        contentInformationRequest.byteRangeAccessSupported = self.sessionCache.config.byteRangeAccessSupported;
        contentInformationRequest.contentLength = self.sessionCache.config.contentLength;//18584541;
        contentInformationRequest.contentType = self.sessionCache.config.contentType;
    }
}

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

- (void)respondToLoadingRequest:(NSData *)data{
    /// 返回数据给播放器
    [self.loadingRequest.dataRequest respondWithData:data];
}

- (void)cacheData:(NSData *)data{
    NSRange range = NSMakeRange(self.startOffset, data.length);
    [self.sessionCache cacheData:data range:range];
    self.startOffset += data.length;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"%s",__func__);
    if (self.isCancelled) {
        return;
    }
    NSString *mimeType = response.MIMEType;
    /// 目前只支持视频,理论上声音也支持，没测试
    if ([mimeType rangeOfString:@"video/"].location == NSNotFound) {
        completionHandler(NSURLSessionResponseCancel);
    } else {
        
        /// 保存缓存配置文件，主要为了保存资源总长
        [self.sessionCache setCacheConfigWithResponse:response];
        
        /// 填充infomationRequst给播放器
        [self fillInfomationRequet];
        
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
//    NSLog(@"%s",__func__);
    if (self.isCancelled) {
        return;
    }
    
    [self.bufferData appendData:data];
    
    /// 大于kBufferSize再给播放器，直接给也可以，当前设置的10k
    if (self.bufferData.length > kBufferSize) {
        NSRange chunkRange = NSMakeRange(0, self.bufferData.length);
        NSData *chunkData = [self.bufferData subdataWithRange:chunkRange];
        [self.bufferData replaceBytesInRange:chunkRange withBytes:NULL length:0];
        
        [self respondToLoadingRequest:chunkData];
    }
    
    [self cacheData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"%s",__func__);
    if (self.isCancelled) {
        return;
    }
    /// 如果存在没有返回给播放器的小数据，返回给播放器
    if (self.bufferData.length > 0 && !error) {
        NSRange chunkRange = NSMakeRange(0, self.bufferData.length);
        NSData *chunkData = [self.bufferData subdataWithRange:chunkRange];
        [self.bufferData replaceBytesInRange:chunkRange withBytes:NULL length:0];
        
        [self respondToLoadingRequest:chunkData];
        
        [self cacheData:chunkData];
    }
    
    if (!error) {
        [self.loadingRequest finishLoading];
    } else {
        [self.loadingRequest finishLoadingWithError:error];
    }
    /// 保存资源缓存
    [self.sessionCache save];
    
    ///如果当前请求是最后一个请求，完成了全部资源下载后保存缓存配置文件，生成md5
    long long currentRequestLength = self.loadingRequest.dataRequest.requestedOffset + self.loadingRequest.dataRequest.requestedLength;
    if (currentRequestLength == self.sessionCache.config.contentLength) {
        [self.sessionCache saveConfig];
    }
}

@end
