// -*- mode:objc -*-
// $Id: PTYTextView.h,v 1.22 2004-02-26 08:18:26 yfabian Exp $
//
/*
 **  PTYTextView.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: NSTextView subclass. The view object for the VT100 screen.
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

#import <Cocoa/Cocoa.h>
#import <iTerm/iTerm.h>

@class VT100Screen;

typedef struct 
{
	unichar code;
	unsigned char color;
	NSImage *image;
	int count;
} CharCache;
	
#define CACHESIZE 2048

@interface PTYTextView : NSView <NSTextInput>
{
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

    // dead key support
    BOOL deadkey;
	
	// NSTextInput support
    BOOL IM_INPUT_INSERT;
    NSRange IM_INPUT_SELRANGE;
    NSRange IM_INPUT_MARKEDRANGE;
    NSDictionary *markedTextAttributes;
    NSAttributedString *markedText;
	
    BOOL CURSOR;
	BOOL forceUpdate;
	
    // geometry
	float lineHeight;
    float lineWidth;
	float charWidth;
	int numberOfLines;
    
    NSFont *font;
    NSFont *nafont;
    NSColor* colorTable[16];
    NSColor* defaultFGColor;
    NSColor* defaultBGColor;
    NSColor* defaultBoldColor;
	NSColor* defaultCursorColor;
	NSColor* selectionColor;
	
    // data source
    VT100Screen *dataSource;
    id _delegate;
	
    //selection
    int startX, startY, endX, endY;
	int pre_x1, pre_x2, pre_y1, pre_y2;

	
	//find support
	int lastFindX, lastFindY;
	
	//cache
	CharCache	charImages[CACHESIZE];
	
	// blinking cursor
	BOOL showCursor;
	
	// trackingRect tab
	NSTrackingRectTag trackingRectTag;
}

- (id)initWithFrame: (NSRect) aRect;
- (void)dealloc;
- (BOOL) becomeFirstResponder;
- (BOOL) resignFirstResponder;
- (BOOL)isFlipped;
- (BOOL)isOpaque;
- (BOOL)shouldDrawInsertionPoint;
- (void)drawRect:(NSRect)rect;
- (void)keyDown:(NSEvent *)event;
- (void)mouseExited:(NSEvent *)event;
- (void)mouseEntered:(NSEvent *)event;
- (void)mouseDown:(NSEvent *)event;
- (void)mouseUp:(NSEvent *)event;
- (void)mouseDragged:(NSEvent *)event;
- (void) otherMouseDown: (NSEvent *) event;
- (NSString *) contentFromX:(int)startx Y:(int)starty ToX:(int)endx Y:(int)endy;
- (NSString *) selectedText;
- (NSString *) content;
- (void)copy: (id) sender;
- (void)paste:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
- (void)changeFont:(id)sender;
- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
- (void) browse:(id)sender;
- (void) mail:(id)sender;
- (void) findString: (NSString *) aString forwardDirection: (BOOL) direction ignoringCase: (BOOL) caseCheck;

//get/set methods
- (NSFont *)font;
- (NSFont *)nafont;
- (void) setFont:(NSFont*)aFont nafont:(NSFont*)naFont;
- (BOOL) antiAlias;
- (void) setAntiAlias: (BOOL) antiAliasFlag;

//color stuff
- (NSColor *) defaultFGColor;
- (NSColor *) defaultBGColor;
- (NSColor *) defaultBoldColor;
- (NSColor *) colorForCode:(int) index;
- (NSColor *) selectionColor;
- (NSColor *) defaultCursorColor;
- (void) setFGColor:(NSColor*)color;
- (void) setBGColor:(NSColor*)color;
- (void) setBoldColor:(NSColor*)color;
- (void) setColorTable:(int) index highLight:(BOOL)hili color:(NSColor *) c;
- (void) setSelectionColor: (NSColor *) aColor;
- (void)setCursorColor:(NSColor*) color;


- (NSDictionary*) markedTextAttributes;
- (void) setMarkedTextAttributes: (NSDictionary *) attr;

- (id) dataSource;
- (void) setDataSource: (id) aDataSource;
- (id) delegate;
- (void) setDelegate: (id) delegate;
- (float) lineHeight;
- (void) setLineHeight: (float) aLineHeight;
- (float) lineWidth;
- (void) setLineWidth: (float) aLineWidth;
- (float) charWidth;
- (void) setCharWidth: (float) width;

- (void) refresh;
- (void) setFrameSize: (NSSize) aSize;
- (void) setForceUpdate: (BOOL) flag;
- (void) showCursor;
- (void) hideCursor;

// selection
- (IBAction) selectAll: (id) sender;

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

// Scrolling control
- (NSRect)adjustScroll:(NSRect)proposedVisibleRect;
- (void) scrollLineUp: (id) sender;
- (void) scrollLineDown: (id) sender;
- (void) scrollPageUp: (id) sender;
- (void) scrollPageDown: (id) sender;
- (void) scrollHome;
- (void) scrollEnd;
- (void) scrollToSelection;
- (void) adjustSelection: (int) lines;

    // Save method
- (void) saveDocumentAs: (id) sender;
- (void) print:(id)sender;

// Find method
- (void) findString: (NSString *) aString forwardDirection: (BOOL) direction ignoringCase: (BOOL) caseCheck;

// NSTextInput
- (void)insertText:(id)aString;
- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange;
- (void)unmarkText;
- (BOOL)hasMarkedText;
- (NSRange)markedRange;
- (NSRange)selectedRange;
- (NSArray *)validAttributesForMarkedText;
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)theRange;
- (void)doCommandBySelector:(SEL)aSelector;
- (unsigned int)characterIndexForPoint:(NSPoint)thePoint;
- (long)conversationIdentifier;
- (NSRect)firstRectForCharacterRange:(NSRange)theRange;

- (void)resetCharCache;

@end

//
// private methods
//
@interface PTYTextView (Private)

- (unsigned int) _checkForSupportedDragTypes:(id <NSDraggingInfo>) sender;
- (void) _savePanelDidEnd: (NSSavePanel *) theSavePanel returnCode: (int) theReturnCode contextInfo: (void *) theContextInfo;

- (void) _scrollToLine:(int)line;

- (void) _renderChar:(NSImage *)image withChar:(unichar) carac withColor:(NSColor*)color withFont:(NSFont*)aFont bold:(int)bold;
- (NSImage *) _getCharImage:(unichar) code color:(int)fg doubleWidth:(BOOL) dw;
- (void) _drawCharacter:(unichar)c fgColor:(int)fg AtX:(float)X Y:(float)Y doubleWidth:(BOOL) dw;

@end

