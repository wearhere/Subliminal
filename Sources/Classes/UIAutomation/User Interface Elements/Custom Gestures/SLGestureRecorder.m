//
//  SLGestureRecorder.m
//  Subliminal
//
//  Created by Jeffrey Wear on 10/3/13.
//  Copyright (c) 2013 Inkling. All rights reserved.
//

#import "SLGestureRecorder.h"

#import <UIKit/UIGestureRecognizerSubclass.h>
#import <objc/runtime.h>

#import "SLGesture.h"
#import "SLGesture+Recording.h"

static const NSUInteger kDefaultExpectedNumberOfTouches = 1;

@interface SLGestureRecorderRecognizer : UIGestureRecognizer

@property (nonatomic) CGRect rect;
@property (nonatomic) NSUInteger expectedNumberOfTouches;
@property (nonatomic, readonly, strong) SLGesture *gesture;

- (instancetype)initWithTarget:(id)target action:(SEL)action rect:(CGRect)rect;

@end


@interface SLGestureRecorder () <UIGestureRecognizerDelegate>
@end

@implementation SLGestureRecorder {
    CGRect _rect;

    SLGestureRecorderRecognizer *_gestureRecognizer;
}

- (instancetype)initWithRect:(CGRect)rect {
    self = [super init];
    if (self) {
        _rect = rect;

        // a gesture recognizer must be initialized with a target in order to receive touches
        // but the recorder never recognizes (finishes evaluating) a gesture,
        // as we wish to receive all touches until we're directed to stop recording
        _gestureRecognizer = [[SLGestureRecorderRecognizer alloc] initWithTarget:self
                                                                          action:@selector(didFinishRecognition:)
                                                                            rect:rect];
        _gestureRecognizer.expectedNumberOfTouches = kDefaultExpectedNumberOfTouches;

        // in order to freely manipulate the app, the recognizer must not cancel nor delay touches
        _gestureRecognizer.cancelsTouchesInView = NO;
        _gestureRecognizer.delaysTouchesEnded = NO;
        _gestureRecognizer.delegate = self;
    }
    return self;
}

- (void)dealloc {
    NSAssert(![self isRecording],
             @"%@ was freed without recording having been stopped.", self);
}

- (void)setRect:(CGRect)rect {
    NSAssert(![self isRecording],
             @"%@ must be stopped before its observed rect can be changed.", self);
    _rect = rect;
    _gestureRecognizer.rect = _rect;
}

- (void)setExpectedNumberOfTouches:(NSUInteger)expectedNumberOfTouches {
    NSAssert(![self isRecording],
             @"%@ must be stopped before the number of touches it expects can be changed.", self);
    _expectedNumberOfTouches = expectedNumberOfTouches;
    _gestureRecognizer.expectedNumberOfTouches = _expectedNumberOfTouches;
}

- (void)setRecording:(BOOL)recording {
    NSAssert([NSThread isMainThread], @"Gesture recording must start and stop on the main thread.");

    if (recording != _recording) {
        if (recording) {
            _recordedGesture = nil;

            [[[UIApplication sharedApplication] keyWindow] addGestureRecognizer:_gestureRecognizer];
            _gestureRecognizer.enabled = YES;
        } else {
            SLGesture *gestureInProgress = [_gestureRecognizer.gesture copy];

            // disable before removing to cancel recognition in the approved way
            _gestureRecognizer.enabled = NO;
            [_gestureRecognizer.view removeGestureRecognizer:_gestureRecognizer];

            BOOL touchesWereRecorded = ([gestureInProgress.stateSequences count] &&
                                        [[gestureInProgress.stateSequences[0] states] count]);
            _recordedGesture = touchesWereRecorded ? gestureInProgress : nil;
        }
        _recording = recording;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL gestureRecognizerShouldReceiveTouch = YES;
    if ([self.delegate respondsToSelector:@selector(gestureRecorder:shouldReceiveTouch:)]) {
        gestureRecognizerShouldReceiveTouch = [self.delegate gestureRecorder:self shouldReceiveTouch:touch];
    }
    return gestureRecognizerShouldReceiveTouch;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)didFinishRecognition:(SLGestureRecorderRecognizer *)recognizer {
    // nothing to do here; we don't expect this to be called anyway
}

@end


#pragma mark -


@implementation SLGestureRecorderRecognizer {
    CGRect _rect;
    NSDate *_gestureStartDate, *_touchSequenceStartDate;
    SLMutableGesture *_gesture;
    SLMutableTouchStateSequence *_currentStateSequence;
    NSMutableArray *_currentTouches;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action rect:(CGRect)rect {
    self = [self initWithTarget:target action:action];
    if (self) {
        _rect = rect;
        _expectedNumberOfTouches = kDefaultExpectedNumberOfTouches;
        _currentTouches = [[NSMutableArray alloc] init];
        [self reset];
    }
    return self;
}

- (void)setRect:(CGRect)rect {
    // cancel any recognition in process
    self.enabled = NO;
    _rect = rect;
    self.enabled = YES;
}

- (void)reset {
    _gestureStartDate = nil, _touchSequenceStartDate = nil;
    _gesture = [[SLMutableGesture alloc] init];
    [_currentTouches removeAllObjects];
}

- (SLGesture *)gesture {
    return [_gesture copy];
}

- (void)recordTouches:(NSArray *)touches {
    NSDate *touchDate = [NSDate date];

    if (!_gestureStartDate) _gestureStartDate = touchDate;
    if (!_currentStateSequence) {
        _touchSequenceStartDate = touchDate;

        NSTimeInterval sequenceTime = [touchDate timeIntervalSinceDate:_gestureStartDate];
        _currentStateSequence = [[SLMutableTouchStateSequence alloc] initAtTime:sequenceTime];
    }

    NSTimeInterval touchTime = [touchDate timeIntervalSinceDate:_touchSequenceStartDate];
    [_currentStateSequence addState:[SLTouchState stateAtTime:touchTime withUITouches:touches rect:_rect]];
}

/*
 NOTE: All touches (`_currentTouches`) are recorded at each state,
 rather than just the touches that have been mutated (`touches`),
 because UIAutomation must simulate the location of all touches involved
 in a gesture at each touch state.
 
 Also note that `_currentTouches`, being an array rather than a set like `touches`,
 maintains a consistent order of touches between states.
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // only track and record these touches if we haven't already begun recording touches:
    // UIAutomation can't simulate touches beginning at offset times
    if ([_currentStateSequence.states count]) return;

    [_currentTouches addObjectsFromArray:[touches allObjects]];

    // wait to record any touches until the expected number have begun
    if ([_currentTouches count] < self.expectedNumberOfTouches) return;

    [self recordTouches:_currentTouches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    // wait to record any touches until the expected number have begun
    if ([_currentTouches count] < self.expectedNumberOfTouches) return;

    [self recordTouches:_currentTouches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // only record the touches if we are currently recording a sequence
    // (we might not be recording here if a touch has begun and ended
    // before the expected number of touches has begun)
    if (!_currentStateSequence) return;

    [self recordTouches:_currentTouches];

    // when any touch ends, freeze the state sequence and cease tracking all touches:
    // UIAutomation can't simulate touches ending at offset times
    [_currentTouches removeAllObjects];
    [_gesture addStateSequence:_currentStateSequence];
    _currentStateSequence = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateCancelled;
}

@end
