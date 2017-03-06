//
//  UTAPlayerControlView.m
//  UTADigest
//
//  Created by David on 16/9/24.
//  Copyright © 2016年 UTA. All rights reserved.
//

#import "UTAPlayerControlView.h"
#import "UIView+YYAdd.h"
#import "UIImage+YYAdd.h"
#import "UTAPlayerView.h"
#import "UIGestureRecognizer+YYAdd.h"
#import "YYGestureRecognizer.h"
#import "UIColor+YYAdd.h"

@interface UTAPlayerControlView ()

@property (nonatomic, strong) UITapGestureRecognizer *doubleTap;
@property (nonatomic, strong) UITapGestureRecognizer *singleTap;

@property (nonatomic, strong) UILabel *labelCurrentTime;
@property (nonatomic, strong) UILabel *labelDurationTime;
@property (nonatomic, strong) UIProgressView *miniPlayProgressView;
@property (nonatomic, strong) UISlider *sliderBuffering;
@property (nonatomic, strong) UISlider *sliderPlaying;

@end

@implementation UTAPlayerControlView {

    UIEdgeInsets _subViewEdgeInsets;

    UIView *_contentView;
    UIView *_backgroundView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;

        _imageViewPlaceholder = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:_imageViewPlaceholder];
        _imageViewPlaceholder.contentMode = UIViewContentModeScaleAspectFill;
        _imageViewPlaceholder.clipsToBounds = YES;
        _imageViewPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

        _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        _backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self addSubview:_backgroundView];

        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self addSubview:_contentView];

        _btnPlayPause = [UIButton buttonWithType:UIButtonTypeSystem];
        [_btnPlayPause setImage:UTAPlayerImage(UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad?@"btn_play_iPad":@"btn_play") forState:UIControlStateNormal];
        [_btnPlayPause sizeToFit];
        _btnPlayPause.tintColor = [UIColor whiteColor];
        _btnPlayPause.center = CGPointMake(self.width*0.5, self.height*0.5);
        _btnPlayPause.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        [_contentView addSubview:_btnPlayPause];

        _btnBack = [UIButton buttonWithType:UIButtonTypeSystem];
        [_btnBack setImage:[UTAPlayerImage(@"btn_back") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _btnBack.size = CGSizeMake(30, 30);
        _btnBack.origin = CGPointMake(15, 15);
        _btnBack.tintColor = [UIColor whiteColor];
        [_contentView addSubview:_btnBack];

        _sliderPlaying = [[UISlider alloc] initWithFrame:CGRectMake(10, self.height-20-14, self.width-20, 20)];
        _sliderPlaying.minimumTrackTintColor = [UIColor colorWithRGB:0xf64a4a];
        _sliderPlaying.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0];
        UIImage *imageThumb = [[UIImage imageWithColor:[UIColor whiteColor] size:CGSizeMake(14, 14)] imageByRoundCornerRadius:20];
        [_sliderPlaying setThumbImage:imageThumb forState:UIControlStateNormal];
        _sliderPlaying.minimumValue = 0;
        _sliderPlaying.maximumValue = 1;
        _sliderPlaying.value = 0;
        _sliderPlaying.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
        [_sliderPlaying addTarget:self action:@selector(onTouchSlide) forControlEvents:UIControlEventTouchDown];
        [_sliderPlaying addTarget:self action:@selector(UIControlEventTouchCancel) forControlEvents:UIControlEventTouchCancel];
        [_sliderPlaying addTarget:self action:@selector(UIControlEventTouchDragInside) forControlEvents:UIControlEventTouchUpInside];
        [_sliderPlaying addTarget:self action:@selector(onSlideValueChanged) forControlEvents:UIControlEventValueChanged];
        _sliderPlaying.exclusiveTouch = YES;
        [_contentView addSubview:_sliderPlaying];

        _sliderBuffering = [[UISlider alloc] initWithFrame:_sliderPlaying.frame];
        _sliderBuffering.enabled = NO;
        _sliderBuffering.userInteractionEnabled = NO;
        _sliderBuffering.thumbTintColor = [UIColor clearColor];
        [_sliderBuffering setThumbImage:[UIImage imageWithColor:[UIColor colorWithWhite:1 alpha:0.9] size:CGSizeMake(0.1, 0.1)] forState:UIControlStateNormal];
        _sliderBuffering.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.3];
        _sliderBuffering.minimumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.95];
        _sliderBuffering.frame = _sliderPlaying.frame;
        _sliderBuffering.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
        [_contentView insertSubview:_sliderBuffering belowSubview:_sliderPlaying];

        _btnFullscreen = [UIButton buttonWithType:UIButtonTypeSystem];
        [_btnFullscreen setImage:[UTAPlayerImage(@"btn_fullscreen") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _btnFullscreen.size = CGSizeMake(30, 30);
        _btnFullscreen.right = self.width-5;
        _btnFullscreen.centerY = self.height-_btnFullscreen.height*0.5-5;
        _btnFullscreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin;
        _btnFullscreen.tintColor = [UIColor whiteColor];
        [_contentView addSubview:_btnFullscreen];

        _labelCurrentTime = [UILabel new];
        _labelCurrentTime.textColor = [UIColor whiteColor];
        _labelCurrentTime.font = [UIFont boldSystemFontOfSize:14];
        _labelCurrentTime.text = @"00:00:00";
        _labelCurrentTime.textAlignment = NSTextAlignmentCenter;
        _labelCurrentTime.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        [_labelCurrentTime sizeToFit];
        _labelCurrentTime.centerY = _btnFullscreen.centerY;
        _labelCurrentTime.left = 5;
        [_contentView addSubview:_labelCurrentTime];

        _labelDurationTime = [UILabel new];
        _labelDurationTime.textColor = _labelCurrentTime.textColor;
        _labelDurationTime.font = _labelCurrentTime.font;
        _labelDurationTime.text = @"00:00:00";
        _labelDurationTime.textAlignment = NSTextAlignmentCenter;
        _labelDurationTime.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin;
        _labelDurationTime.size = _labelCurrentTime.size;
        _labelDurationTime.right = _btnFullscreen.left;
        _labelDurationTime.centerY = _btnFullscreen.centerY;
        [_contentView addSubview:_labelDurationTime];

        _sliderBuffering.left = _labelCurrentTime.right+2;
        _sliderBuffering.width = _labelDurationTime.left-_labelCurrentTime.right-4;
        _sliderBuffering.centerY = _btnFullscreen.centerY;
        _sliderPlaying.frame = _sliderBuffering.frame;

        _btnReplay = [UIButton buttonWithType:UIButtonTypeCustom];
        [_btnReplay setImage:UTAPlayerImage(@"replay") forState:UIControlStateNormal];
        [_btnReplay sizeToFit];
        _btnReplay.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;

        _miniPlayProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        _miniPlayProgressView.trackTintColor = [UIColor clearColor];
        _miniPlayProgressView.progressTintColor = [UIColor colorWithRGB:0xf64a4a];
        _miniPlayProgressView.frame = CGRectMake(0, self.height-1, self.width, 1);
        _miniPlayProgressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
        _miniPlayProgressView.progress = 0;
        [self addSubview:_miniPlayProgressView];

        _miniPlayProgressView.hidden = YES;
        _sliderBuffering.hidden = YES;
        _btnFullscreen.hidden = YES;
        _sliderPlaying.hidden = YES;
        _miniPlayProgressView.alpha = 1-_contentView.alpha;
        _labelCurrentTime.hidden = _labelDurationTime.hidden = YES;
        _labelCurrentTime.text = _labelDurationTime.text = @"00:00";

        [self _setup];

        self.clipsToBounds = YES;
    }
    return self;
}

- (void)_setup {
    _isPlaying = NO;
    _playEnd = NO;
    _current = 0;
    _duration = 0;
    _progress = 0;
    _bufferProgress = 0;
    [self setStyle:UTAPlayerStyleNormal];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapGesture:)];
    doubleTap.numberOfTapsRequired = 2;
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];

    [self addGestureRecognizer:singleTap];
    [self addGestureRecognizer:doubleTap];

    self.singleTap = singleTap;
    self.doubleTap = doubleTap;


    self.exclusiveTouch = YES;
    _contentView.exclusiveTouch = YES;
    _sliderPlaying.exclusiveTouch = YES;
}

- (void)setFrame:(CGRect)frame {
    CGSize size = self.size;
    [super setFrame:frame];
    if (!CGSizeEqualToSize(size, self.size)) {

    }
}

#pragma mark - private show/hidden
- (void)fadeoutControls {
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        _contentView.alpha = 0;
        _backgroundView.alpha = 0;
        _miniPlayProgressView.alpha = 1-_contentView.alpha;
    } completion:nil];
}

- (void)fadeinControls {
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        _contentView.alpha = 1;
        _backgroundView.alpha = 1;
        _miniPlayProgressView.alpha = 1-_contentView.alpha;
    } completion:nil];
}

#pragma mark - public

#pragma mark - gesture
- (void)tapGesture:(UITapGestureRecognizer *)tap {
    if (!_playerView.canPlay) {
        return;	
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeoutControls) object:nil];
    if (_backgroundView.alpha) {
        [self fadeoutControls];
    }
    else {
        [self fadeinControls];
        if (_isPlaying) {
            [self performSelector:@selector(fadeoutControls) withObject:nil afterDelay:5];
        }
    }
}

- (void)doubleTapGesture:(UITapGestureRecognizer *)doubleTap {
    if (_playEnd) {
        return;
    }

    if (_isPlaying) {
        [_playerView pause];
    }
    else {
        [_playerView play];
    }
}

- (void)onTouchSlide {
    [_playerView pause];
}

- (void)UIControlEventTouchDragInside {
    [_playerView seekToTime:_sliderPlaying.value];
    [_playerView play];
}

- (void)UIControlEventTouchCancel {
    [_playerView seekToTime:_sliderPlaying.value];
    [_playerView play];
}

- (void)onSlideValueChanged {
    CGFloat current = _sliderPlaying.value;
    _labelCurrentTime.text = [self stringWithTime:current];
}

- (NSString *)stringWithTime:(CGFloat)time {
    if (time>3600) {
        // 大于一小时
        return [NSString stringWithFormat:@"%zd:%02zd:%02zd", time/3600, (NSInteger)time%3600/60, (NSInteger)time%60];
    }
    else {
        return [NSString stringWithFormat:@"%02zd:%02zd", (NSInteger)time/60, (NSInteger)time%60];
    }
}

#pragma mark - UTAPlayerProtocol
- (void)setCurrent:(CGFloat)current {
    if (_current==current) return;
    _current = current;
    _labelCurrentTime.text = [self stringWithTime:current];
    _sliderPlaying.value = current;
}

- (void)setDuration:(CGFloat)duration {
    if (_duration==duration) return;
    _duration = duration;
    _labelDurationTime.text = [self stringWithTime:duration];
    _sliderPlaying.maximumValue = _duration;
}

- (void)setProgress:(CGFloat)progress {
    _progress = progress;
    _miniPlayProgressView.progress = _progress;
}

- (void)setBufferProgress:(CGFloat)bufferProgress {
    _bufferProgress = bufferProgress;
    _sliderBuffering.value = bufferProgress;
}

- (BOOL)isFullscreen {
    return UTAPlayerStyleFullscreen==_style;
}

- (void)setIsFullscreen:(BOOL)isFullscreen {
    if (isFullscreen) {
        [_btnFullscreen setImage:UTAPlayerImage(@"btn_unfullscreen") forState:UIControlStateNormal];
    }
    else {
        [_btnFullscreen setImage:UTAPlayerImage(@"btn_fullscreen") forState:UIControlStateNormal];
    }
}

- (void)setTitle:(NSString *)title {
    _title = [title copy];
}

- (void)setIsPlaying:(BOOL)isPlaying {
    _isPlaying = isPlaying;
    if (_isPlaying) {
        _sliderBuffering.hidden = NO;
        _miniPlayProgressView.hidden = NO;
        _btnFullscreen.hidden = NO;
        _sliderPlaying.hidden = NO;
        _labelCurrentTime.hidden =
        _labelDurationTime.hidden = NO;
    }

    [_btnPlayPause setImage:UTAPlayerImage([isPlaying?@"btn_pause":@"btn_play" stringByAppendingString:UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad?@"_iPad":@""]) forState:UIControlStateNormal];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeoutControls) object:nil];
    if (_isPlaying) {
        [self performSelector:@selector(fadeoutControls) withObject:nil afterDelay:5];
    }
    else {
        _contentView.alpha = 1;
        _backgroundView.alpha = 1;
        _miniPlayProgressView.alpha = 1-_contentView.alpha;
    }
}

- (void)setPlayEnd:(BOOL)playEnd {
    _playEnd = playEnd;

    _singleTap.enabled =
    _doubleTap.enabled = !_playEnd;
    _btnPlayPause.alpha = _playEnd?0:1;

    if (_playEnd) {
        _contentView.alpha = 1;
        _backgroundView.alpha = 1;
        _miniPlayProgressView.alpha = 1-_contentView.alpha;
        _btnReplay.center = self.center;
        [self addSubview:_btnReplay];
    }
    else {
        [_btnReplay removeFromSuperview];
        [self fadeoutControls];
    }
}

- (void)setStyle:(UTAPlayerStyle)style {
    if (_style==style) return;

    _style = style;
    [self setIsFullscreen:UTAPlayerStyleFullscreen==_style];
    _btnBack.alpha = UTAPlayerStyleFullscreen==_style?1:0;

    [UIView animateWithDuration:0.25 animations:^{
        if (UTAPlayerStyleFloat==style) {
            _labelDurationTime.right = self.width-5;
        }
        else {
            _labelDurationTime.right = _btnFullscreen.left;
        }

        CGFloat alpha = UTAPlayerStyleFloat!=style;
        _btnFullscreen.alpha = alpha;
        _labelDurationTime.alpha = alpha;
        _labelCurrentTime.alpha = alpha;
        _sliderBuffering.alpha = alpha;
        _sliderPlaying.alpha = alpha;

        _sliderPlaying.width = _sliderBuffering.width = _labelDurationTime.left-_labelCurrentTime.right-4;
    }];

    switch (style) {
        case UTAPlayerStyleNormal: {

        }break;
        case UTAPlayerStyleFullscreen:{

        }break;
        case UTAPlayerStyleEmbed:{

        }break;
        case UTAPlayerStyleFloat:{

        }break;
        default:break;
    }
}

@end
