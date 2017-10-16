# ULVideoResourceLoader

使用 ULAVAssetResourceLoader 返回一个 AVPlayerItem 即可，其它业务逻辑和正常用 AVPlayer 完全一致。

```Objective-C ULAVAssetResourceLoader *resourceLoader = [[ULAVAssetResourceLoader alloc]init];<br>AVPlayerItem *playerItem = [resourceLoader playerItemWithURL:self.videoUrl];```
