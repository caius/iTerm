/*
 **  PTYTabView.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: NSTabView subclass. Implements drag and drop.
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface PTYTabView : NSTabView {
    NSEvent *mouseEvent;
    int dragTargetTabViewItemIndex;
    BOOL dragSessionInProgress;
}

// Class methods that Apple should have provided
+ (NSSize) contentSizeForFrameSize: (NSSize) frameSize tabViewType: (NSTabViewType) type controlSize: (NSControlSize) controlSize;
+ (NSSize) frameSizeForContentSize: (NSSize) contentSize tabViewType: (NSTabViewType) type controlSize: (NSControlSize) controlSize;

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
