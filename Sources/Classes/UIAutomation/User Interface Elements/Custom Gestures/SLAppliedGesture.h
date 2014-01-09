//
//  SLAppliedGesture.h
//  Subliminal
//
//  Created by Jeffrey Wear on 12/17/13.
//  Copyright (c) 2013 Inkling. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SLGesture;
@interface SLAppliedGesture : NSObject

@property (nonatomic, strong, readonly) NSArray *stateSequences;

- (instancetype)initWithGesture:(SLGesture *)gesture inRect:(CGRect)rect;

@end


@interface SLAppliedTouchStateSequence : NSObject

@property (nonatomic, readonly) NSTimeInterval time;
@property (nonatomic, strong, readonly) NSArray *states;

+ (instancetype)sequenceAtTime:(NSTimeInterval)time withStates:(NSArray *)states;

@end


@interface SLAppliedTouchState : NSObject

@property (nonatomic, readonly) NSTimeInterval time;
@property (nonatomic, strong, readonly) NSArray *touches;

+ (instancetype)stateAtTime:(NSTimeInterval)time withTouches:(NSArray *)touches;

@end


@interface SLAppliedTouch : NSObject

@property (nonatomic, readonly) CGPoint location;

+ (instancetype)touchAtPoint:(CGPoint)point;

@end