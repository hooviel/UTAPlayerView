//
//  UTAPlayerControlView.h
//  UTADigest
//
//  Created by David on 16/9/24.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "UTAPlayerProtocol.h"

@interface UTAPlayerControlView : UIControl <UTAPlayerProtocol>

@property (nonatomic, assign) CGFloat current;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, assign) CGFloat bufferProgress;

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL playEnd;

/** 是否全屏（只读）*/
@property (nonatomic, assign, readonly) BOOL isFullscreen;
/** 只修改样式，不需要动画切换 */
@property (nonatomic, assign) UTAPlayerStyle style;
@property (nonatomic, copy) NSString *title;

// --------- UI element
/** 播放暂停按钮*/
@property (nonatomic, strong) UIButton *btnPlayPause;
/** 全屏/非全屏按钮*/
@property (nonatomic, strong) UIButton *btnFullscreen;
/** 返回/关闭按钮*/
@property (nonatomic, strong) UIButton *btnBack;
/** 占位图*/
@property (nonatomic, strong) UIImageView *imageViewPlaceholder;
/** 重播按钮*/
@property (nonatomic, strong) UIButton *btnReplay;
/** 播放器*/
@property (nonatomic, weak) UTAPlayerView *playerView;

@end
