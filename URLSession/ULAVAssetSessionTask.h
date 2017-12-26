//
//  ULAVAssetSessionTask.h
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol ULAVAssetSessionTaskDelegate <NSObject>
@optional
- (void)didReceiveResponse:(NSURLResponse *)response loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest ;
- (void)didReceiveData:(NSData *)data loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest ;
- (void)didCompleteloadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest error:(NSError *)error ;
@end

@interface ULAVAssetSessionTask : NSObject

@property (nonatomic, weak) id<ULAVAssetSessionTaskDelegate> delegate;
@property (nonatomic, readonly) AVAssetResourceLoadingRequest *loadingRequest;

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)request;

- (void)cancel;
- (void)resume;

@end
