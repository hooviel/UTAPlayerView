//
//  UTAPlayerView.m
//  UTADigest
//
//  Created by David on 16/9/23.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import "UTAPlayerView.h"

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import <CoreGraphics/CGGeometry.h>
#import "YYKitMacro.h"
#import "UIView+YYAdd.h"
#import "NSObject+YYAddForKVO.h"
#import <objc/runtime.h>


@interface UTAPlayerFullscreenInfo : NSObject

@property (nonatomic, assign) UIInterfaceOrientation orientation;
@property (nonatomic, assign) UTAPlayerStyle style;
@property (nonatomic, weak) UIView *superview;
@property (nonatomic, assign) CGRect frameInSuperview;

+ (instancetype)fullscreenInfo;

@end

@implementation UTAPlayerFullscreenInfo

+ (instancetype)fullscreenInfo {
    return [UTAPlayerFullscreenInfo new];
}

@end

static UIView *_backgroundView;

@interface UTAPlayerView ()

/** 播放属性 */
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) id playerObserver;
/** 播放属性 */
@property (nonatomic, strong) AVPlayerItem *playerItem;
/** playerLayer */
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
/** 全屏前播放器信息*/
@property (nonatomic, strong) UTAPlayerFullscreenInfo *beforeFullscreenInfo;
/** 全屏后播放器信息*/
@property (nonatomic, strong) UTAPlayerFullscreenInfo *afterFullscreenInfo;

@property (nonatomic, strong) UIPanGestureRecognizer *floatPanGesture;

@end

@implementation UTAPlayerView {
    BOOL _isRotationAnimating;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _instances];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self _instances];
}

- (void)_instances {
    self.backgroundColor = [UIColor blackColor];

    _beforeFullscreenInfo = [UTAPlayerFullscreenInfo new];
    _afterFullscreenInfo = [UTAPlayerFullscreenInfo new];
    _style = UTAPlayerStyleNormal;
    _floatStyleInsetsInSuperView = UIEdgeInsetsMake(20, 10, 10, 10);
    _floatStyleWidth = 200;
    _canDragWhenFloat = YES;
}

/** 强制处理背景颜色*/
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:[UIColor blackColor]];
}

- (void)dealloc {
    [self removeObserverBlocks];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self clearPlayer];
    NSLog(@"%s", __FUNCTION__);
}

- (void)setUrl:(NSURL *)url {
    [self clearPlayer];
    if (_url==url || (![url.scheme isEqualToString:@"file"] && url.host.length==0)) {
        return;
    }
    
    _url = url;
    _canPlay = YES;

    // 初始化playerItem
    _playerItem  = [AVPlayerItem playerItemWithURL:url];
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:_playerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActiveNotification)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForegroundNotification)
                                                 name:UIApplicationWillEnterForegroundNotification object:nil];
    
    // 每次都重新创建Player，替换replaceCurrentItemWithPlayerItem:，该方法阻塞线程
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    @weakify(self);
    _playerObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) usingBlock:^(CMTime time) {
        Float64 current = CMTimeGetSeconds(time);
        Float64 duration = CMTimeGetSeconds([weak_self.player.currentItem duration]);
        if (isnan(current)||isnan(duration)) {
            return;
        }
        CGFloat progress = current/duration;
        
        /*
         #if DEBUG
         NSLog(@"current:%@   duration:%@   progress:%@", @(current), @(duration), @(progress));
         #endif
         */
        
        if (![NSThread isMainThread]) {

            dispatch_async(dispatch_get_main_queue(), ^{
                weak_self.controlView.current = current;
                weak_self.controlView.duration = duration;
                weak_self.controlView.progress = progress;
                
                if ([weak_self.delegate respondsToSelector:@selector(playerView:currentTime:duration:progress:)]) {
                    [weak_self.delegate playerView:weak_self currentTime:current duration:duration progress:progress];
                }
            });
        }
        else {
            weak_self.controlView.current = current;
            weak_self.controlView.duration = duration;
            weak_self.controlView.progress = progress;

            if ([weak_self.delegate respondsToSelector:@selector(playerView:currentTime:duration:progress:)]) {
                [weak_self.delegate playerView:weak_self currentTime:current duration:duration progress:progress];
            }
        }
    }];
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    // AVLayerVideoGravityResizeAspectFill
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _playerLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.layer insertSublayer:_playerLayer atIndex:0];
    _playerLayer.frame = self.bounds;
}

- (void)setFrame:(CGRect)frame {
    CGSize size = self.size;
    [super setFrame:frame];
    if (!CGSizeEqualToSize(size, self.size)) {
        [CATransaction begin];
        [CATransaction setDisableActions:NO];
        CGFloat duration = 0.25;
        if ([UIView resolveClassMethod:@selector(inheritedAnimationDuration)]) {
            duration = [UIView inheritedAnimationDuration];
        }
        [CATransaction setAnimationDuration:duration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        _playerLayer.frame = self.bounds;
        [CATransaction commit];

        _controlView.frame = self.bounds;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

#pragma mark - public methods
- (void)setControlView:(UIView<UTAPlayerProtocol> *)controlView {
    if (_controlView==controlView) return;

    if (_controlView) {
        [_controlView removeFromSuperview];
        _controlView = nil;
    }

    _controlView = controlView;
    _controlView.playerView = self;
    controlView.frame = self.bounds;
    [self addSubview:controlView];
}

- (void)play {
    if (!_playerItem) return;

    if (_controlView.playEnd) {
        [self seekToTime:0];
    }
    else {
        [_player play];
    }
    _isPlaying = YES;
    _controlView.isPlaying = _isPlaying;
    _controlView.imageViewPlaceholder.hidden = YES;

    if (_callbackPlayStateChanged) {
        _callbackPlayStateChanged(_isPlaying);
    }
}

- (void)pause {
    [_player pause];
    _isPlaying = NO;
    _controlView.isPlaying = _isPlaying;

    if (_callbackPlayStateChanged) {
        _callbackPlayStateChanged(_isPlaying);
    }
}

- (void)seekToTime:(NSInteger)time {
    _controlView.playEnd = NO;
    [self pause];
    @weakify(self);
    [_player seekToTime:CMTimeMake(time, 1) toleranceBefore:CMTimeMake(1, 30) toleranceAfter:CMTimeMake(1, 30) completionHandler:^(BOOL finished) {
        [weak_self play];
    }];
}

- (void)replay {
    if (!_playerItem) return;

    if (_controlView.playEnd) {
        [self seekToTime:0];
    }
    else {
        [_player play];
    }
    _isPlaying = YES;
    _controlView.isPlaying = _isPlaying;
    _controlView.imageViewPlaceholder.hidden = YES;

    if (_callbackPlayStateChanged) {
        _callbackPlayStateChanged(_isPlaying);
    }
}

- (void)resetPlayer {
    [self clearPlayer];
}

- (void)playerItemDidPlayToEndTime:(AVPlayerItem *)item {
    Float64 current = CMTimeGetSeconds([self.player currentTime]);
    Float64 duration = CMTimeGetSeconds([self.player.currentItem duration]);
    if (isnan(current)||isnan(duration)) {
        return;
    }
    CGFloat progress = current/duration;

    [self pause];
    _controlView.current = current;
    _controlView.duration = duration;
    _controlView.progress = progress;
    _controlView.playEnd = YES;

    @weakify(self);
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([weak_self.delegate respondsToSelector:@selector(playerView:currentTime:duration:progress:)]) {
                [weak_self.delegate playerView:weak_self currentTime:current duration:duration progress:progress];
            }
        });
    }
    else {
        if ([weak_self.delegate respondsToSelector:@selector(playerView:currentTime:duration:progress:)]) {
            [weak_self.delegate playerView:weak_self currentTime:current duration:duration progress:progress];
        }
    }
}

- (void)fullscreenWithOrientation:(UIInterfaceOrientation)orientation animated:(BOOL)animated {
    if (_isRotationAnimating || !self.superview || UIInterfaceOrientationUnknown==orientation || UTAPlayerStyleFloat==_style) return;

    if (!_controlView.isFullscreen) {
        _beforeFullscreenInfo.orientation = [[UIApplication sharedApplication] statusBarOrientation];
        _beforeFullscreenInfo.style = _controlView.style;
        _beforeFullscreenInfo.superview = self.superview;
        _beforeFullscreenInfo.frameInSuperview = self.frame;
    }

    UIView *afterSuperview = [UIApplication sharedApplication].keyWindow;
    CGRect rcIntersection = CGRectIntersection(afterSuperview.frame, [self convertRect:self.bounds toView:afterSuperview]);
    if (CGRectIsNull(rcIntersection)) {
        return;
    }
    CGRect afterFrame = [self screenBoundsForOrientation:orientation];
    CGPoint center = afterSuperview.center;
    afterFrame.origin.x = center.x-afterFrame.size.width*0.5;
    afterFrame.origin.y = center.y-afterFrame.size.height*0.5;

    CGFloat duration = 0.3;
    if (!_controlView.isFullscreen) {
        // 非全屏状态，需要动画切换到全屏状态
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _backgroundView = [UIView new];
            _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            _backgroundView.backgroundColor = [UIColor blackColor];
            _backgroundView.alpha = 0;
        });
        [afterSuperview addSubview:_backgroundView];
        _backgroundView.frame = afterSuperview.bounds;
        [afterSuperview addSubview:self];
        if (animated) {
            CGRect rcInitAfterSuperview = [_beforeFullscreenInfo.superview convertRect:_beforeFullscreenInfo.frameInSuperview toView:afterSuperview];
            self.frame = rcInitAfterSuperview;
        }
    }
    else {
        // 已经是全屏状态，切换设备方向，判断旧的全屏切换到新的全屏方向是否为180角度，如果是，需要更长的动画时间
        if ([self angleFromOrientation:_afterFullscreenInfo.orientation toOrientation:orientation]>(M_PI_2+0.1)) {
            duration+=0.2;
        }
    }

    _isRotationAnimating = YES;
    // 角度永远是最初的屏幕方向到新的方向的差值
    CGFloat angle = [self angleFromOrientation:_beforeFullscreenInfo.orientation toOrientation:orientation];
    if (animated) {
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            if (!_controlView.isFullscreen) {
                // 非全屏切入全屏，需要动画调整frame
                self.frame = afterFrame;
            }
            else if (!CGRectEqualToRect(_afterFullscreenInfo.frameInSuperview, afterFrame)) {
                // 新的全屏frame和上一次全屏的frame不同，需要动画调整
                self.frame = afterFrame;
            }
            self.transform = CGAffineTransformMakeRotation(angle);
            _backgroundView.alpha = 1;
        } completion:^(BOOL finished) {
            _isRotationAnimating = NO;
        }];
    }
    else {
        if (!_controlView.isFullscreen) {
            // 非全屏切入全屏，需要动画调整frame
            self.frame = afterFrame;
        }
        else if (!CGRectEqualToRect(_afterFullscreenInfo.frameInSuperview, afterFrame)) {
            // 新的全屏frame和上一次全屏的frame不同，需要动画调整
            self.frame = afterFrame;
        }
        self.transform = CGAffineTransformMakeRotation(angle);
        _backgroundView.alpha = 1;
        _isRotationAnimating = NO;
    }

    _afterFullscreenInfo.frameInSuperview = afterFrame;
    _afterFullscreenInfo.style = UTAPlayerStyleFullscreen;
    _afterFullscreenInfo.superview = afterSuperview;
    _afterFullscreenInfo.orientation = orientation;

    _controlView.style = UTAPlayerStyleFullscreen;
    _style = _controlView.style;
}

- (void)exitFullscreenWithAnimated:(BOOL)animated {
    if (_isRotationAnimating || !self.superview || !_controlView.isFullscreen) return;

    _isRotationAnimating = YES;
    CGRect rcFinalAfterSuperview = [_beforeFullscreenInfo.superview convertRect:_beforeFullscreenInfo.frameInSuperview toView:_afterFullscreenInfo.superview];
    CGFloat duration = 0.25;
    if ([self angleFromOrientation:_afterFullscreenInfo.orientation toOrientation:_beforeFullscreenInfo.orientation]>(M_PI_2+0.1)) {
        duration+=0.2;
    }
    if (animated) {
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            self.transform = CGAffineTransformIdentity;
            self.frame = rcFinalAfterSuperview;
            _backgroundView.alpha = 0;
        } completion:^(BOOL finished) {
            [_beforeFullscreenInfo.superview addSubview:self];
            self.frame = _beforeFullscreenInfo.frameInSuperview;
            [_backgroundView removeFromSuperview];
            _isRotationAnimating = NO;

            // 还原状态
            _beforeFullscreenInfo.superview = nil;
            _beforeFullscreenInfo.frameInSuperview = CGRectZero;
            _beforeFullscreenInfo.orientation = UIInterfaceOrientationUnknown;
        }];
    }
    else {
        self.transform = CGAffineTransformIdentity;
        _backgroundView.alpha = 0;
        [_beforeFullscreenInfo.superview addSubview:self];
        self.frame = _beforeFullscreenInfo.frameInSuperview;
        [_backgroundView removeFromSuperview];
        _isRotationAnimating = NO;

        // 还原状态
        _beforeFullscreenInfo.superview = nil;
        _beforeFullscreenInfo.frameInSuperview = CGRectZero;
        _beforeFullscreenInfo.orientation = UIInterfaceOrientationUnknown;
    }

    _controlView.style = _beforeFullscreenInfo.style;
    _style = _controlView.style;

    // 还原状态
    _beforeFullscreenInfo.style = UTAPlayerStyleUnknow;
    _afterFullscreenInfo.superview = nil;
    _afterFullscreenInfo.frameInSuperview = CGRectZero;
    _afterFullscreenInfo.orientation = UIInterfaceOrientationUnknown;
    _afterFullscreenInfo.style = UTAPlayerStyleUnknow;
}

- (CGFloat)angleFromOrientation:(UIInterfaceOrientation)from toOrientation:(UIInterfaceOrientation)to {
    CGFloat angle = 0;
    switch (from) {
        case UIInterfaceOrientationPortrait: {
            switch (to) {
                case UIInterfaceOrientationPortrait: angle = 0; break;
                case UIInterfaceOrientationPortraitUpsideDown: angle = M_PI; break;
                case UIInterfaceOrientationLandscapeLeft: angle = -M_PI_2; break;
                case UIInterfaceOrientationLandscapeRight: angle = M_PI_2; break;
                default:break;
            }
            break;
        }
        case UIInterfaceOrientationPortraitUpsideDown: {
            switch (to) {
                case UIInterfaceOrientationPortrait: angle = M_PI; break;
                case UIInterfaceOrientationPortraitUpsideDown: angle = 0; break;
                case UIInterfaceOrientationLandscapeLeft: angle = M_PI_2; break;
                case UIInterfaceOrientationLandscapeRight: angle = -M_PI_2; break;
                default:break;
            }
            break;
        }
        case UIInterfaceOrientationLandscapeLeft: {
            switch (to) {
                case UIInterfaceOrientationPortrait: angle = M_PI_2; break;
                case UIInterfaceOrientationPortraitUpsideDown: angle = -M_PI_2; break;
                case UIInterfaceOrientationLandscapeLeft: angle = 0; break;
                case UIInterfaceOrientationLandscapeRight: angle = M_PI; break;
                default:break;
            }
            break;
        }
        case UIInterfaceOrientationLandscapeRight: {
            switch (to) {
                case UIInterfaceOrientationPortrait: angle = -M_PI_2; break;
                case UIInterfaceOrientationPortraitUpsideDown: angle = M_PI_2; break;
                case UIInterfaceOrientationLandscapeLeft: angle = M_PI; break;
                case UIInterfaceOrientationLandscapeRight: angle = 0; break;
                default:break;
            }
            break;
        }
        default:break;
    }
    return angle;
}

- (void)switchToFloatStyle {
    if (UTAPlayerStyleFullscreen==_style || !self.superview || _isRotationAnimating) {
        return;
    }

    _beforeFullscreenInfo.orientation = [[UIApplication sharedApplication] statusBarOrientation];
    _beforeFullscreenInfo.style = _controlView.style;
    _beforeFullscreenInfo.superview = self.superview;
    _beforeFullscreenInfo.frameInSuperview = self.frame;

    UIView *afterSuperview = _superViewOfFloatStyle?:[UIApplication sharedApplication].keyWindow.rootViewController.view;
    CGRect rcInSuperView = [self convertRect:self.bounds toView:afterSuperview];

    CGRect rcIntersection = CGRectIntersection(afterSuperview.frame, [self convertRect:self.bounds toView:afterSuperview]);
    if (CGRectIsNull(rcIntersection)) {
        return;
    }
    [afterSuperview addSubview:self];
    self.frame = rcInSuperView;

    CGFloat width = _floatStyleWidth;
    CGRect rcAfter = CGRectMake(0, 0, width, width*9.0/16.0);
    rcAfter.origin.x = afterSuperview.width-rcAfter.size.width-_floatStyleInsetsInSuperView.right;
    rcAfter.origin.y = afterSuperview.height-rcAfter.size.height-_floatStyleInsetsInSuperView.bottom;

    _afterFullscreenInfo.orientation = _beforeFullscreenInfo.orientation;
    _afterFullscreenInfo.style = UTAPlayerStyleFloat;
    _afterFullscreenInfo.superview = afterSuperview;
    _afterFullscreenInfo.frameInSuperview = rcAfter;
    _isRotationAnimating = YES;
    [UIView animateWithDuration:0.25 animations:^{
        self.frame = _afterFullscreenInfo.frameInSuperview;
    } completion:^(BOOL finished) {
        _isRotationAnimating = NO;
    }];

    _controlView.style = UTAPlayerStyleFloat;
    _style = UTAPlayerStyleFloat;

    [self setCanDragWhenFloat:_canDragWhenFloat];
}

- (void)panGesture:(UIPanGestureRecognizer *)panGesture {
    CGPoint trans = [panGesture translationInView:self];
    self.center = CGPointMake(self.centerX+trans.x, self.centerY+trans.y);
    [panGesture setTranslation:CGPointZero inView:self];

    if (panGesture.state==UIGestureRecognizerStateEnded || panGesture.state==UIGestureRecognizerStateCancelled) {
        CGPoint centerFixed = self.center;
        if (self.centerX>self.superview.width*0.5) {
            centerFixed.x = self.superview.width-_floatStyleInsetsInSuperView.right-self.width*0.5;
        }
        else {
            centerFixed.x = _floatStyleInsetsInSuperView.left+self.width*0.5;
        }

        if (self.top<_floatStyleInsetsInSuperView.top) {
            centerFixed.y = _floatStyleInsetsInSuperView.top+self.height*0.5;
        }
        else if (self.bottom>self.superview.height-_floatStyleInsetsInSuperView.bottom) {
            centerFixed.y = self.superview.height-_floatStyleInsetsInSuperView.bottom-self.height*0.5;
        }

        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:1 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.center = centerFixed;
        } completion:nil];
    }
}

- (void)setCanDragWhenFloat:(BOOL)canDragWhenFloat {
    _canDragWhenFloat = canDragWhenFloat;
    if (_canDragWhenFloat) {
        if (!_floatPanGesture) {
            _floatPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
            [self addGestureRecognizer:_floatPanGesture];

            _floatPanGesture.enabled = _style==UTAPlayerStyleFloat;
        }
    }
    else {
        if (_floatPanGesture) {
            [self removeGestureRecognizer:_floatPanGesture];
        }
    }
}

- (CGRect)screenBoundsForOrientation:(UIInterfaceOrientation)orientation {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGRect bounds = screenBounds;
    if (UIInterfaceOrientationIsLandscape(orientation)) {
        bounds.size.width = MAX(screenBounds.size.height, screenBounds.size.width);
        bounds.size.height = MIN(screenBounds.size.height, screenBounds.size.width);
    }
    else {
        bounds.size.width = MIN(screenBounds.size.height, screenBounds.size.width);
        bounds.size.height = MAX(screenBounds.size.height, screenBounds.size.width);
    }
    return bounds;
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.player.currentItem) {
        if ([keyPath isEqualToString:@"status"]) {
            if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                
            }
            else if (self.player.currentItem.status == AVPlayerItemStatusFailed){
                NSError *error = [self.player.currentItem error];
                NSLog(@"%@", error);
                [self pause];
            }
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            // 缓冲进度
            if (self.player.currentItem.duration.timescale==0) return;
            
            NSArray *loadedTimeRanges = [[_player currentItem] loadedTimeRanges];
            CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue]; // 获取缓冲区域
            
            CGFloat bufferTime = CMTimeGetSeconds(timeRange.start)+CMTimeGetSeconds(timeRange.duration);
            CGFloat currentTime = CMTimeGetSeconds([self.playerItem currentTime]);
            CGFloat duration = CMTimeGetSeconds([self.player.currentItem duration]);
            if (!isnan(duration) && duration>0) {
                if (duration-bufferTime<=1.5) {
                    self.controlView.bufferProgress = 1;
                }
                else {
                    self.controlView.bufferProgress = bufferTime/duration;
                }
            }
            
            // 缓存时间大于当前时间1.5s再继续播放
            BOOL shouldPlay = (bufferTime-currentTime)>=1.5;
            if (shouldPlay) {
                // [self play];
            }
        } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            // 空缓存
        } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            // 当前区域已缓冲
        }
    }
}

- (void)applicationWillResignActiveNotification {
    if (_isPlaying) {
        [self pause];
    }
}

- (void)applicationWillEnterForegroundNotification {
    
}
/** 清空播放器内容 */
- (void)clearPlayer {
    if (_playerItem) {
        if (_isPlaying) {
            [self pause];
        }

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:_playerItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIApplicationWillResignActiveNotification
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIApplicationWillEnterForegroundNotification
                                                      object:nil];
        [_playerItem removeObserver:self forKeyPath:@"status"];
        [_playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [_playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        
        [_playerLayer removeFromSuperlayer];
        [_player removeTimeObserver:_playerObserver];
        
        _player = nil;
        _playerObserver = nil;
        _playerLayer = nil;
        _playerItem = nil;
        
        _url = nil;
        _controlView.imageViewPlaceholder.hidden = NO;
        _controlView.playEnd = NO;
        _canPlay = NO;

        _controlView.current = 0;
        _controlView.duration = 0;
        _controlView.progress = 0;
    }
}

- (void)setStyle:(UTAPlayerStyle)style {
    if (style==_style || UTAPlayerStyleFullscreen==_style|| _isRotationAnimating) return;

    _floatPanGesture.enabled = UTAPlayerStyleFloat==style;

    switch (style) {
        case UTAPlayerStyleNormal:
        case UTAPlayerStyleEmbed:{
            if (UTAPlayerStyleFloat==_style) {
                _isRotationAnimating = YES;
                [_beforeFullscreenInfo.superview addSubview:self];
                self.frame = [_afterFullscreenInfo.superview convertRect:self.frame toView:_beforeFullscreenInfo.superview];
                [UIView animateWithDuration:0.25 animations:^{
                    self.frame = _beforeFullscreenInfo.frameInSuperview;
                } completion:^(BOOL finished) {
                    _beforeFullscreenInfo.superview = nil;
                    _beforeFullscreenInfo.frameInSuperview = CGRectZero;
                    _beforeFullscreenInfo.style = UTAPlayerStyleUnknow;
                    _beforeFullscreenInfo.orientation = UIInterfaceOrientationUnknown;

                    _afterFullscreenInfo.superview = nil;
                    _afterFullscreenInfo.frameInSuperview = CGRectZero;
                    _afterFullscreenInfo.style = UTAPlayerStyleUnknow;
                    _afterFullscreenInfo.orientation = UIInterfaceOrientationUnknown;
                    _isRotationAnimating = NO;
                }];
            }

            _controlView.style = style;
            _style = style;
        }break;
        case UTAPlayerStyleFloat:{
            [self switchToFloatStyle];
        }break;
        case UTAPlayerStyleFullscreen:{
            [self fullscreenWithOrientation:UIInterfaceOrientationLandscapeRight animated:YES];
        }break;

        default:
            break;
    }
}

- (BOOL)isFullscreen {
    return UTAPlayerStyleFullscreen==_style;
}

// -------------------------- ShareUTAPlayerView
- (void)setCollectionView:(UICollectionView *)collectionView {
    if (_collectionView!=collectionView) {
        [ShareUTAPlayerView resetPlayer];
        [ShareUTAPlayerView removeFromSuperview];

        [_collectionView removeObserverBlocks];
    }
    if (_tableView) {
        [_tableView removeObserverBlocks];
        _tableView = nil;
    }
    _collectionView = collectionView;
    [_collectionView addObserverBlockForKeyPath:@"contentOffset" block:^(UICollectionView * _Nonnull collectionView, id  _Nullable oldVal, id  _Nullable newVal) {
        NSArray<NSIndexPath*> *arrIndexPath = [collectionView indexPathsForVisibleItems];
        if ([arrIndexPath containsObject:ShareUTAPlayerView.indexPath] && ShareUTAPlayerView.canPlay) {
            if (ShareUTAPlayerView.playerMoveToCellBlock) {
                ShareUTAPlayerView.playerMoveToCellBlock();
            }
        }
        else {
            if (ShareUTAPlayerView.superview) {
                [ShareUTAPlayerView removeFromSuperview];
            }
            if (ShareUTAPlayerView.isPlaying) {
                [ShareUTAPlayerView pause];
            }
        }
    }];
}

- (void)setTableView:(UITableView *)tableView {
    if (_tableView!=tableView) {
        [ShareUTAPlayerView resetPlayer];
        [ShareUTAPlayerView removeFromSuperview];

        [_tableView removeObserverBlocks];
    }
    if (_collectionView) {
        [_collectionView removeObserverBlocks];
        _collectionView = nil;
    }

    _tableView = tableView;
    [_tableView addObserverBlockForKeyPath:@"contentOffset" block:^(UITableView * _Nonnull tableView, id  _Nullable oldVal, id  _Nullable newVal) {
        NSArray<NSIndexPath*> *arrIndexPath = [tableView indexPathsForVisibleRows];
        if ([arrIndexPath containsObject:ShareUTAPlayerView.indexPath] && ShareUTAPlayerView.canPlay) {
            if (ShareUTAPlayerView.playerMoveToCellBlock) {
                ShareUTAPlayerView.playerMoveToCellBlock();
            }
        }
        else {
            [ShareUTAPlayerView pause];
            [ShareUTAPlayerView removeFromSuperview];
        }
    }];
}

- (void)setIndexPath:(NSIndexPath *)indexPath {
    _indexPath = [indexPath copy];
    if (_tableView) {
        [_tableView setContentOffset:_tableView.contentOffset];
    }
    if (_collectionView) {
        [_collectionView setContentOffset:_collectionView.contentOffset];
    }
}

@end

@implementation UTAPlayerView (Share)

+ (instancetype)sharePlayerView {
    static UTAPlayerView *sharePlayView;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharePlayView = [[UTAPlayerView alloc] initWithFrame:CGRectMake(0, 0, 320, 160)];
    });
    return sharePlayView;
}

@end
