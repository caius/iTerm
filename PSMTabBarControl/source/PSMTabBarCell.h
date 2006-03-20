//
//  PSMTabBarCell.h
//  PSMTabBarControl
//
//  Created by John Pannell on 10/13/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMTabBarControl.h"

#define kPSMTabDragAnimationSteps 6
// an old friend
#define PI 3.1417

@class PSMTabBarControl;
@class PSMProgressIndicator;

@interface PSMTabBarCell : NSActionCell {
    // sizing
    NSRect              _frame;
    NSSize              _stringSize;
    NSMutableArray      *_sineCurveWidths;
    int                 _currentStep;
    
    // state
    int                 _tabState;
    NSTrackingRectTag   _closeButtonTrackingTag;    // left side tracking, if dragging
    NSTrackingRectTag   _cellTrackingTag;           // right side tracking, if dragging
    BOOL                _closeButtonOver;
    BOOL                _closeButtonPressed;
    PSMProgressIndicator *_indicator;
    BOOL                _isInOverflowMenu;
    BOOL                _hasCloseButton;
    BOOL                _isCloseButtonSuppressed;
    BOOL                _hasIcon;
    int                 _count;
    BOOL                _isPlaceholder;
    BOOL                _isShrinking;
}

// creation/destruction
- (id)initWithControlView:(PSMTabBarControl *)controlView;
- (id)initPlaceholderWithFrame:(NSRect)frame isShrinking:(BOOL)value inControlView:(PSMTabBarControl *)controlView;
- (void)dealloc;

// accessors
- (id)controlView;
- (NSTrackingRectTag)closeButtonTrackingTag;
- (void)setCloseButtonTrackingTag:(NSTrackingRectTag)tag;
- (NSTrackingRectTag)cellTrackingTag;
- (void)setCellTrackingTag:(NSTrackingRectTag)tag;
- (float)width;
- (NSRect)frame;
- (void)setFrame:(NSRect)rect;
- (void)setStringValue:(NSString *)aString;
- (NSSize)stringSize;
- (NSAttributedString *)attributedStringValue;
- (int)tabState;
- (void)setTabState:(int)state;
- (NSProgressIndicator *)indicator;
- (BOOL)isInOverflowMenu;
- (void)setIsInOverflowMenu:(BOOL)value;
- (BOOL)closeButtonPressed;
- (void)setCloseButtonPressed:(BOOL)value;
- (BOOL)closeButtonOver;
- (void)setCloseButtonOver:(BOOL)value;
- (BOOL)hasCloseButton;
- (void)setHasCloseButton:(BOOL)set;
- (void)setCloseButtonSuppressed:(BOOL)suppress;
- (BOOL)isCloseButtonSuppressed;
- (BOOL)hasIcon;
- (void)setHasIcon:(BOOL)value;
- (int)count;
- (void)setCount:(int)value;
- (BOOL)isPlaceholder;
- (void)setIsPlaceholder:(BOOL)value;
- (BOOL)isShrinking;
- (void)setIsShrinking:(BOOL)value;
- (int)currentStep;
- (void)setCurrentStep:(int)value;

// component attributes
- (NSRect)indicatorRectForFrame:(NSRect)cellFrame;
- (NSRect)closeButtonRectForFrame:(NSRect)cellFrame;
- (float)minimumWidthOfCell;
- (float)desiredWidthOfCell;

// drawing
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;

// tracking the mouse
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;

// drag support
- (NSImage*)dragImageForRect:(NSRect)cellFrame;

// archiving
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end

@interface PSMTabBarControl (CellAccessors)

- (id<PSMTabStyle>)style;

@end
