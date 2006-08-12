//
//  PSMTabBarControl.h
//  PSMTabBarControl
//
//  Created by John Pannell on 10/13/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

/*
 This view provides a control interface to manage a regular NSTabView.  It looks and works like the tabbed browsing interface of many popular browsers.
 */

#import <Cocoa/Cocoa.h>

#define kPSMTabBarControlHeight 22
// internal cell border
#define MARGIN_X        6
#define MARGIN_Y        3
// padding between objects
#define kPSMTabBarCellPadding 4
// fixed size objects
#define kPSMMinimumTitleWidth 30
#define kPSMTabBarIndicatorWidth 16
#define kPSMTabBarIconWidth 16
#define kPSMHideAnimationSteps 2.0

@class PSMOverflowPopUpButton;
@class PSMRolloverButton;
@class PSMTabBarCell;
@protocol PSMTabStyle;
@protocol PTYTabViewDelegateProtocol;

enum {
    PSMTab_SelectedMask                 = 1 << 1,
    PSMTab_LeftIsSelectedMask		= 1 << 2,
    PSMTab_RightIsSelectedMask          = 1 << 3,
    PSMTab_PositionLeftMask		= 1 << 4,
    PSMTab_PositionMiddleMask		= 1 << 5,
    PSMTab_PositionRightMask		= 1 << 6,
    PSMTab_PositionSingleMask		= 1 << 7
};

@interface PSMTabBarControl : NSControl <PTYTabViewDelegateProtocol>
{
    
    // control basics
    NSMutableArray              *_cells;                    // the cells that draw the tabs
    IBOutlet NSTabView          *tabView;                   // the tab view being navigated
    PSMOverflowPopUpButton      *_overflowPopUpButton;      // for too many tabs
    PSMRolloverButton           *_addTabButton;
    
    // drawing style
    id<PSMTabStyle>             style;
    BOOL                        _canCloseOnlyTab;
    BOOL                        _hideForSingleTab;
    BOOL                        _showAddTabButton;
    BOOL                        _sizeCellsToFit;
    
    // cell width
    int                         _cellMinWidth;
    int                         _cellMaxWidth;
    int                         _cellOptimumWidth;
    
    // animation for hide/show
    int                         _currentStep;
    BOOL                        _isHidden;
    IBOutlet id                 partnerView;                // gets resized when hide/show
    BOOL                        _awakenedFromNib;
    
    // drag and drop
    PSMTabBarCell               *_draggedCell;
    PSMTabBarCell               *_draggedCellPlaceholder;
    NSEvent                     *_lastMouseDownEvent;      // keep this for dragging reference      
    BOOL                        _drawForDrop;              // alter drawing if about to get dropped on
    NSTimer                     *_animationTimer;
    
    // MVC help
    IBOutlet id                 delegate;
	
	// what to do when close button is pressed
	id closeTarget;
	SEL closeAction;
}

// control characteristics
+ (NSBundle *)bundle;

// control configuration
- (BOOL)canCloseOnlyTab;
- (void)setCanCloseOnlyTab:(BOOL)value;
- (NSString *)styleName;
- (void)setStyleNamed:(NSString *)name;
- (BOOL)hideForSingleTab;
- (void)setHideForSingleTab:(BOOL)value;
- (BOOL)showAddTabButton;
- (void)setShowAddTabButton:(BOOL)value;
- (int)cellMinWidth;
- (void)setCellMinWidth:(int)value;
- (int)cellMaxWidth;
- (void)setCellMaxWidth:(int)value;
- (int)cellOptimumWidth;
- (void)setCellOptimumWidth:(int)value;
- (BOOL)sizeCellsToFit;
- (void)setSizeCellsToFit:(BOOL)value;

// accessors
- (NSTabView *)tabView;
- (void)setTabView:(NSTabView *)view;
- (id)delegate;
- (void)setDelegate:(id)object;
- (id)partnerView;
- (void)setPartnerView:(id)view;

// the add tab button
- (PSMRolloverButton *)addTabButton;

// special effects
- (void)hideTabBar:(BOOL)hide animate:(BOOL)animate;

@end