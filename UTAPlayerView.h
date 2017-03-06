//
//  UTAPlayerView.h
//  UTADigest
//
//  Created by David on 16/9/23.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UTAPlayerProtocol.h"

#define ShareUTAPlayerView [UTAPlayerView sharePlayerView]

/** 滚动到过程如果需要添加的某个cell上 */
typedef void (^UTAPlayerMoveToCellBlock)();

@protocol UTAPlayerViewDelegate;

@interface UTAPlayerView : UIView

@property (nonatomic, weak) id<UTAPlayerViewDelegate> delegate;
@property (nonatomic, copy) void(^callbackPlayStateChanged)(BOOL isPlaying);

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) BOOL isPlaying;
/** 是否可以播放了，判断是否有url即可*/
@property (nonatomic, assign, readonly) BOOL canPlay;
@property (nonatomic, strong) UIView<UTAPlayerProtocol> *controlView;
@property (nonatomic, assign) UTAPlayerStyle style;
@property (nonatomic, assign, readonly) BOOL isFullscreen;
/** 悬浮样式的父视图（悬浮在哪个视图上）；默认nil时使用App根控制器的view */
@property (nonatomic, weak) UIView *superViewOfFloatStyle;
/** 悬浮样式是否允许拖拽，默认：YES */
@property (nonatomic, assign) BOOL canDragWhenFloat;
/** 悬浮样式 播放器和父视图的边距； 默认 UIEdgeInsetsMake(20, 10, 10, 10)*/
@property (nonatomic, assign) UIEdgeInsets floatStyleInsetsInSuperView;
/** 悬浮样式 播放器的宽度；默认为200px */
@property (nonatomic, assign) CGFloat floatStyleWidth;

- (void)play;
- (void)pause;
- (void)seekToTime:(NSInteger)time;
- (void)replay;
- (void)resetPlayer;

- (void)fullscreenWithOrientation:(UIInterfaceOrientation)orientation animated:(BOOL)animated;
- (void)exitFullscreenWithAnimated:(BOOL)animated;

// ----------- ShareUTAPlayerView
@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, copy) NSIndexPath *indexPath;
@property (nonatomic, copy) UTAPlayerMoveToCellBlock playerMoveToCellBlock;

@end


/** 共享播放器 */
@interface UTAPlayerView (Share)

+ (instancetype)sharePlayerView;

@end

@protocol UTAPlayerViewDelegate <NSObject>

- (void)playerView:(UTAPlayerView *)playerView currentTime:(CGFloat)currentTime duration:(CGFloat)duration progress:(CGFloat)progress;

@end
