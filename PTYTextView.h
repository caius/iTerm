// -*- mode:objc -*-
// $Id: PTYTextView.h,v 1.1.1.1 2002-11-26 04:56:49 ujwal Exp $
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
    NSMenu *cMenu;
    
    BOOL IM_INPUT_INSERT;
    NSRange IM_INPUT_SELRANGE;
    NSRange IM_INPUT_MARKEDRANGE;
}

- (id)init;
- (void) dealloc;
- (BOOL)shouldDrawInsertionPoint;
- (void)drawRect:(NSRect)rect;
- (void)keyDown:(NSEvent *)event;
- (void)doCommandBySelector:(SEL)aSelector;
- (void)insertText:(id)aString;
- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange;
- (void)unmarkText;
- (BOOL)hasMarkedText;
- (NSRange)markedRange;
- (void)paste:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
- (void)changeFont:(id)sender;
- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
- (void) browse:(id)sender;
- (void) mail:(id)sender;
@end
