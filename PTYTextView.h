// -*- mode:objc -*-
// $Id: PTYTextView.h,v 1.11 2003-01-17 23:22:20 ujwal Exp $
//
//  PTYTextView.h
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PTYTextView : NSTextView
{
    
    BOOL IM_INPUT_INSERT;
    NSRange IM_INPUT_SELRANGE;
    NSRange IM_INPUT_MARKEDRANGE;
    
    // This is a flag to let us know whether we are handling this
    // particular drag and drop operation. We are using it because
    // the prepareDragOperation and performDragOperation of the
    // parent NSTextView class return "YES" even if the parent
    // cannot handle the drag type. To make matters worse, the
    // concludeDragOperation does not have any return value.
    // This all results in the inability to test whether the
    // parent could handle the drag type properly. Is this a Cocoa
    // implementation bug?
    // Fortunately, the draggingEntered and draggingUpdated methods
    // seem to return a real status, based on which we can set this flag.
    BOOL bExtendedDragNDrop;
    
    // anti-alias flag
    BOOL antiAlias;

}

- (id)init;
- (void) dealloc;
- (BOOL)shouldDrawInsertionPoint;
- (void)drawRect:(NSRect)rect;
- (void)keyDown:(NSEvent *)event;
- (void)otherMouseDown:(NSEvent *)theEvent;
- (void)doCommandBySelector:(SEL)aSelector;
- (void)insertText:(id)aString;
- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange;
- (void)unmarkText;
- (BOOL)hasMarkedText;
- (NSRange)markedRange;
- (void) copy: (id) sender;
- (void)paste:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
- (void)changeFont:(id)sender;
- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
- (void) browse:(id)sender;
- (void) mail:(id)sender;


// get/set methods
- (BOOL) antiAlias;
- (void) setAntiAlias: (BOOL) antiAliasFlag;
- (NSColor *) selectionColor;
- (void) setSelectionColor: (NSColor *) aColor;

//
// Drag and Drop methods for our text view
//
- (unsigned int) draggingEntered: (id<NSDraggingInfo>) sender;
- (unsigned int) draggingUpdated: (id<NSDraggingInfo>) sender;
- (void) draggingExited: (id<NSDraggingInfo>) sender;
- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>) sender;
- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender;
- (void) concludeDragOperation: (id<NSDraggingInfo>) sender;

// Cursor control
- (void)resetCursorRects;

// Save method
- (void) saveDocumentAs: (id) sender;

@end

//
// private methods
//
@interface PTYTextView (Private)

- (unsigned int) _checkForSupportedDragTypes:(id <NSDraggingInfo>) sender;
- (void) _savePanelDidEnd: (NSSavePanel *) theSavePanel returnCode: (int) theReturnCode contextInfo: (void *) theContextInfo;

@end

