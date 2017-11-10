//
//  ULAVAssetResourceLoader.h
//  ULAVPlayer
//
//  Created by 王传正 on 18/09/2017.
//  Copyright © 2017 王传正. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

static NSString *kCacheScheme = @"UPLiveMediaCache";

@interface ULAVAssetResourceLoader : NSObject <AVAssetResourceLoaderDelegate>

/// 返回一个带缓存的AVPlayerItem
- (AVPlayerItem *)playerItemWithURL:(NSURL *)url;

/// 取消全部播放器请求
- (void)cancel;
- (void)removeCache;
@end
