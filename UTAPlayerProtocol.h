//
//  UTAPlayerProtocol.h
//  UTADigest
//
//  Created by David on 16/9/24.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifndef UTAPlayerProtocel_h
#define UTAPlayerProtocel_h

#define UTAPlayerImage(name) [UIImage imageNamed:[@"UTAPlayer.bundle" stringByAppendingPathComponent:name]]

/*!
 *  播放器类型
 */
typedef NS_ENUM(NSInteger, UTAPlayerStyle) {
    /*!
     *  未知
     */
    UTAPlayerStyleUnknow,
    /*!
     *  普通，可以切换到任何样式
     */
    UTAPlayerStyleNormal,
    /*!
     *  全屏，不能切换到任何样式，只能退出全屏，但能继续调用进入全屏到其他方向；
     */
    UTAPlayerStyleFullscreen,
    /*!
     *  嵌入，可以切换到任何样式
     */
    UTAPlayerStyleEmbed,
    /*!
     *  浮动，不能切换到全屏，仅支持切换到非全屏的其他样式
     */
    UTAPlayerStyleFloat
};

@class UTAPlayerView;
@protocol UTAPlayerProtocol <NSObject>

@property (nonatomic, assign) CGFloat current;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, assign) CGFloat bufferProgress;

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL playEnd;

@property (nonatomic, assign, readonly) BOOL isFullscreen;
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


#endif /* UTAPlayerProtocel_h */
