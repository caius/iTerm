//
//  PTYTabView.h
//  iTerm
//
//  Created by Ujwal Sathyam on Thu Dec 19 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface PTYTabView : NSTabView {
    NSEvent *mouseEvent;
    int dragTargetTabViewItemIndex;
    BOOL dragSessionInProgress;
}

- (id)initWithFrame: (NSRect) aFrame;
- (void) dealloc;

// contextual menu
- (NSMenu *) menuForEvent: (NSEvent *) theEvent;
- (void) selectTab: (id) sender;

// NSTabView methods overridden
- (void) addTabViewItem: (NSTabViewItem *) aTabViewItem;
- (void) removeTabViewItem: (NSTabViewItem *) aTabViewItem;
- (void) insertTabViewItem: (NSTabViewItem *) tabViewItem atIndex: (int) index;

// drag and drop
// NSDraggingSource protocol
- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL)flag;
- (void) mouseDown: (NSEvent *)theEvent;
- (void) mouseUp: (NSEvent *)theEvent;
- (void) mouseDragged: (NSEvent *)theEvent;
- (BOOL) shouldDelayWindowOrderingForEvent: (NSEvent *) theEvent;
// NSDraggingDestination protocol
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>) sender;
- (void) draggingExited: (id <NSDraggingInfo>) sender;
- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>) sender;
- (BOOL) prepareForDragOperation: (id <NSDraggingInfo>) sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>) sender;
- (void) concludeDragOperation: (id <NSDraggingInfo>) sender;



@end
