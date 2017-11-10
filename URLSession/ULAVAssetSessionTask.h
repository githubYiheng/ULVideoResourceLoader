//
//  ULAVAssetSessionTask.h
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface ULAVAssetSessionTask : NSObject

@property (nonatomic, readonly) AVAssetResourceLoadingRequest *loadingRequest;

- (instancetype)initWithRequest:(AVAssetResourceLoadingRequest *)request;

- (void)cancel;
- (void)resume;
- (void)removeCache;
@end
