//
//  SLRecordingToolbar.m
//  Subliminal
//
//  Created by Jeffrey Wear on 12/17/13.
//  Copyright (c) 2013 Inkling. All rights reserved.
//

#import "SLGestureRecordingToolbar.h"

#import "SLLogger.h"

#import <QuartzCore/QuartzCore.h>

// `UIBarButtonItem` to display a "record" image,
// because there's no `UIBarButtonSystemItemRecord`
@interface SLRecordingToolbarRecordItem : UIBarButtonItem

+ (instancetype)item;

@end

// `UIBarButtonItem` to display a "stop" image,
// because `UIBarButtonSystemItemStop` displays an image appropriate to accompany
// `UIBarButtonSystemItemRefresh` rather than playback controls
@interface SLRecordingToolbarStopItem : UIBarButtonItem

@property (nonatomic, getter = isPulsing) BOOL pulsing;

+ (instancetype)item;

@end

static const CGFloat kHandleBarDiameter = 6.0f;
static const CGFloat kHandleWidth = 10.0f;

@interface SLGestureRecordingToolbar () <UIGestureRecognizerDelegate>
@end

@implementation SLGestureRecordingToolbar {
    SLRecordingToolbarRecordItem *_recordButtonItem;
    SLRecordingToolbarStopItem *_stopButtonItem;
    UIBarButtonItem *_leftHandleSpacerItem, *_recordingAndDoneSpacerItem, *_rightHandleSpacerItem;

    UIPanGestureRecognizer *_dragRecognizer;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // for the handles--see `-drawRect:`
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        self.barStyle = UIBarStyleBlack;
        // add a border in case we're displayed against dark content
        self.layer.borderWidth = 1.0f;
        self.layer.borderColor = [UIColor whiteColor].CGColor;

        _leftHandleSpacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];

        _playButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:nil action:NULL];
        _recordButtonItem = [SLRecordingToolbarRecordItem item];
        _stopButtonItem = [SLRecordingToolbarStopItem item];
        _recordingAndDoneSpacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL];
        _recordingAndDoneSpacerItem.width = 20.0f;
        _doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:NULL];

        _rightHandleSpacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];

        [self updateItems];

        _dragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        // see comment above `-gestureRecognizer:shouldReceiveTouch:`
        _dragRecognizer.delaysTouchesBegan = YES;
        _dragRecognizer.delegate = self;
        [self addGestureRecognizer:_dragRecognizer];
    }
    return self;
}

- (UIBarButtonItem *)recordButtonItem {
    return _recordButtonItem;
}

- (UIBarButtonItem *)stopButtonItem {
    return _stopButtonItem;
}

- (void)updateItems {
    UIBarButtonItem *middleItem = (self.showsRecordButton ? self.recordButtonItem : self.stopButtonItem);
    [self setItems:@[ _leftHandleSpacerItem, self.playButtonItem, middleItem, _recordingAndDoneSpacerItem, self.doneButtonItem, _rightHandleSpacerItem ]];
}

- (void)setShowsRecordButton:(BOOL)showsRecordButton {
    if (showsRecordButton != _showsRecordButton) {
        _showsRecordButton = showsRecordButton;
        [self updateItems];
        // stop the stop button from pulsing when it is hidden
        // so that it always begins from white when it is shown
        [_stopButtonItem setPulsing:!_showsRecordButton];
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize sizeThatFits = [super sizeThatFits:size];
    sizeThatFits.width = 200.0f;
    return sizeThatFits;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    // draw handles (by filling their inner space clear) at the left and right of the toolbar
    // (occupied by the left and right handle spacer items)
    CGRect leftHandleSpace, rightHandleSpace;
    CGRect innerSpace = CGRectInset(self.bounds, kHandleBarDiameter, kHandleBarDiameter);
    [[UIColor clearColor] setFill];

    CGRectDivide(innerSpace, &leftHandleSpace, &innerSpace, kHandleWidth, CGRectMinXEdge);
    UIRectFill(leftHandleSpace);

    CGRectDivide(innerSpace, &rightHandleSpace, &innerSpace, kHandleWidth, CGRectMaxXEdge);
    UIRectFill(rightHandleSpace);
}

#pragma mark - Dragging

// the "Done" button has some crazy wide hit-testing
// which we override by setting `_dragRecognizer.delaysTouchesBegan = YES` above
// and then re-implement in a saner way below
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL gestureRecognizerShouldReceiveTouch = YES;
    for (UIView *view in self.subviews) {
        // prevent the toolbar drag recognizer from receiving touches inside the toolbar button items
        if ([view isKindOfClass:[UIControl class]] &&
            CGRectContainsPoint(view.bounds, [touch locationInView:view])) {
            gestureRecognizerShouldReceiveTouch = NO;
            break;
        }
    }
    return gestureRecognizerShouldReceiveTouch;
}

- (void)drag:(UIPanGestureRecognizer *)gestureRecognizer {
    UIView *superview = self.superview;
    CGPoint translation = [gestureRecognizer translationInView:superview];
    self.frame = CGRectOffset(self.frame, translation.x, translation.y);
    [gestureRecognizer setTranslation:CGPointZero inView:superview];
}

@end


@implementation SLRecordingToolbarRecordItem {
    UIButton *_button;
}

+ (UIColor *)buttonColor:(BOOL)enabled {
    return (enabled ? [UIColor redColor] : [UIColor darkGrayColor]);
}

// displays a red circle
+ (instancetype)item {
    UIButton *recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    // height chosen to match that of the system items
    recordButton.frame = (CGRect){ .size = CGSizeMake(19.0f, 19.0f) };
    recordButton.backgroundColor = [[self class] buttonColor:YES];
    recordButton.layer.cornerRadius = CGRectGetHeight(recordButton.frame) / 2.0f;
    recordButton.showsTouchWhenHighlighted = YES;   // to match the behavior of the system "play" item

    SLRecordingToolbarRecordItem *item = [[self alloc] initWithCustomView:recordButton];
    if (item) {
        // an item initialized with a custom view does not call its target's action method,
        // so we must invoke it manually
        [recordButton addTarget:item action:@selector(record:) forControlEvents:UIControlEventTouchUpInside];
        item->_button = recordButton;
    }
    return item;
}

- (void)record:(id)sender {
    if (!self.enabled) return;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.action withObject:self];
#pragma clang diagnostic pop
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];

    // because we draw the button ourselves, we must change its background color
    _button.backgroundColor = [[self class] buttonColor:enabled];
}

@end

@implementation SLRecordingToolbarStopItem {
    UIButton *_button;
}

+ (UIColor *)buttonColor:(BOOL)enabled {
    return (enabled ? [UIColor whiteColor] : [UIColor darkGrayColor]);
}

// displays a white/red pulsing square
+ (instancetype)item {
    UIButton *stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
    // height chosen to match that of the system items
    stopButton.frame = (CGRect){ .size = CGSizeMake(19.0f, 19.0f) };
    // use the layer's background color for the benefit of the pulsing animation
    stopButton.layer.backgroundColor = [UIColor whiteColor].CGColor;
    stopButton.showsTouchWhenHighlighted = YES;   // to match the behavior of the system "play" item

    SLRecordingToolbarStopItem *item = [[self alloc] initWithCustomView:stopButton];
    if (item) {
        // an item initialized with a custom view does not call its target's action method,
        // so we must invoke it manually
        [stopButton addTarget:item action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
        item->_button = stopButton;
    }
    return item;
}

- (void)setPulsing:(BOOL)pulsing {
    if (pulsing != _pulsing) {
        NSString *animationKey = @"backgroundColor";
        if (pulsing) {
            // pulse red and back
            CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:animationKey];
            pulseAnimation.toValue = (id)[UIColor redColor].CGColor;
            pulseAnimation.duration = 1.5;
            pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            pulseAnimation.autoreverses = YES;
            pulseAnimation.repeatCount = HUGE_VALF; // repeat forever
            [_button.layer addAnimation:pulseAnimation forKey:animationKey];
        } else {
            [_button.layer removeAnimationForKey:animationKey];
        }

        _pulsing = pulsing;
    }
}

- (void)stop:(id)sender {
    if (!self.enabled) return;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.action withObject:self];
#pragma clang diagnostic pop
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];

    // because we draw the button ourselves, we must change its background color
    _button.backgroundColor = [[self class] buttonColor:enabled];
}

@end
