// -*- mode:objc -*-
// $Id: PTYTextView.m,v 1.3 2002-12-08 20:22:34 ujwal Exp $
//
//  PTYTextView.m
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0
#define GREED_KEYDOWN         0

#import "PTYTextView.h"


@implementation PTYTextView

- (id)init
{
#if DEBUG_ALLOC
    NSLog(@"PTYTextView: -init");
#endif

    return [super init];
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"PTYTextView: -dealloc");
#endif
    
    if(cMenu != nil)
        [cMenu release];
    cMenu = nil;
    
    [super dealloc];
}

- (BOOL)shouldDrawInsertionPoint
{
#if 0 // DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView shouldDrawInsertionPoint]",
	  __FILE__, __LINE__);
#endif
    return NO;
}

- (void)drawRect:(NSRect)rect
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView drawRect:(%f,%f,%f,%f)]",
	  __FILE__, __LINE__,
	  rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
#endif
    [super drawRect:rect];
}


- (void)keyDown:(NSEvent *)event
{
    NSInputManager *imana = [NSInputManager currentInputManager];
    BOOL IMEnable = [imana wantsToInterpretAllKeystrokes];
    id delegate = [self delegate];
    BOOL put;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView keyDown:%@]",
	  __FILE__, __LINE__, event );
#endif
    
    if (IMEnable) {
	//BOOL prev = [self hasMarkedText];
	IM_INPUT_INSERT = NO;

	[self interpretKeyEvents:[NSArray arrayWithObject:event]];

#if GREED_KEYDOWN
	if (prev == NO && 
	    IM_INPUT_INSERT == NO && 
	    [self hasMarkedText] == NO) 
	{
	    put = YES;
	}
	else
	    put = NO;
#else
	put = NO;
#endif
    }
    else
	put = YES;

    if (put == YES) {
	if ([delegate respondsToSelector:@selector(keyDown:)])
	    [delegate keyDown:event];
	else
	    [super keyDown:event];
    }
}

- (void)doCommandBySelector:(SEL)aSelector
{
    id delegate = [self delegate];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView doCommandBySelector:...]",
	  __FILE__, __LINE__);
#endif

#if GREED_KEYDOWN == 0
    if ([delegate respondsToSelector:aSelector]) {
	[delegate performSelector:aSelector withObject:nil];
    }
#endif
}

- (void)insertText:(id)aString
{
    id delegate = [self delegate];
    NSTextStorage *storage = [self textStorage];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView insertText:%@]",
	  __FILE__, __LINE__, aString);
#endif
    IM_INPUT_INSERT = YES;

    [storage beginEditing];
    [storage deleteCharactersInRange:[self markedRange]];
    [storage endEditing];
    IM_INPUT_MARKEDRANGE = NSMakeRange(0, 0);

    if ([delegate respondsToSelector:@selector(insertText:)])
	[delegate insertText:aString];
    else
	[super insertText:aString];
}

- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange
{
    NSRange repRange;
    NSTextStorage *storage = [self textStorage];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setMarkedText:%@ selectedRange:(%d,%d)]",
	  __FILE__, __LINE__, aString, selRange.location, selRange.length);
#endif
    
    if ([self hasMarkedText]) {
	repRange = [self markedRange];
    }
    else {
	repRange = NSMakeRange([storage length], 0);
    }
    [storage beginEditing];
    if ([aString isKindOfClass:[NSAttributedString class]]) {
	[storage replaceCharactersInRange:repRange 
		     withAttributedString:aString];
	IM_INPUT_MARKEDRANGE = NSMakeRange(0, 
					   [(NSAttributedString *)aString length]);
    }
    else {
	[storage replaceCharactersInRange:repRange
			       withString:aString];
	IM_INPUT_MARKEDRANGE = NSMakeRange(0,
					   [(NSString *)aString length]);
    }
    IM_INPUT_SELRANGE = selRange;
    [storage endEditing];

    [self setNeedsDisplay:YES];
}

- (void)unmarkText
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView unmarkText]", __FILE__, __LINE__ );
#endif
    IM_INPUT_MARKEDRANGE = NSMakeRange(0, 0);
}

- (BOOL)hasMarkedText
{
    BOOL result;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView hasMarkedText]", __FILE__, __LINE__ );
#endif
    if (IM_INPUT_MARKEDRANGE.length > 0)
	result = YES;
    else
	result = NO;

    return result;
}

- (NSRange)markedRange 
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView markedRange]", __FILE__, __LINE__);
#endif

    //return IM_INPUT_MARKEDRANGE;
    if (IM_INPUT_MARKEDRANGE.length > 0) {
	NSTextStorage *storage = [self textStorage];
	int len = [storage length];
	int toploc;

	toploc = len - IM_INPUT_MARKEDRANGE.length;
	return NSMakeRange(toploc, IM_INPUT_MARKEDRANGE.length);
    }
    else
	return NSMakeRange(0, 0);
}

- (void)paste:(id)sender
{
    id delegate = [self delegate];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView paste:%@]", __FILE__, __LINE__, sender );
#endif

    if ([delegate respondsToSelector:@selector(paste:)])
	[delegate paste:sender];
    else
	[super paste:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView validateMenuItem:%@]", __FILE__, __LINE__, item );
#endif

    if ([item action] == @selector(paste:))
        return YES;
    else if ([item action ] == @selector(cut:))
        return NO;
    else if ([item action]==@selector(mail:)||[item action]==@selector(browse:)) {
//        NSLog(@"selected range:%d",[self selectedRange].length);
	return ([self selectedRange].length>0);
    }
    else
        return [super validateMenuItem:item];
}

- (void)changeFont:(id)sender
{
    id delegate = [self delegate];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView changeFont:%@]", __FILE__, __LINE__, sender );
#endif

    if ([delegate respondsToSelector:@selector(changeFont:)])
	[delegate changeFont:sender];
    else
	[super changeFont:sender];

}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    if (!cMenu) {
        cMenu = [[[NSMenu alloc] initWithTitle:@"test"] retain];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"-> Browser",@"iTerm",@"Context menu")
                         action:@selector(browse:) keyEquivalent:@""];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"-> Mail",@"iTerm",@"Context menu")
                         action:@selector(mail:) keyEquivalent:@""];
        [cMenu addItem:[NSMenuItem separatorItem]];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"Copy",@"iTerm",@"Context menu")
                         action:@selector(copy:) keyEquivalent:@""];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"Paste",@"iTerm",@"Context menu")
                         action:@selector(paste:) keyEquivalent:@""];
        [cMenu addItem:[NSMenuItem separatorItem]];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"Select All",@"iTerm",@"Context menu")
                         action:@selector(selectAll:) keyEquivalent:@""];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"Clear Buffer",@"iTerm",@"Context menu")
                         action:@selector(clearBuffer:) keyEquivalent:@""];
        [cMenu addItem:[NSMenuItem separatorItem]];
        [cMenu addItemWithTitle:NSLocalizedStringFromTable(@"Configure...",@"iTerm",@"Context menu")
                         action:@selector(showConfigWindow:) keyEquivalent:@""];
    }
    
    return cMenu;
}

- (void) mail:(id)sender
{
    NSString *s=[[[self string] substringWithRange:[self selectedRange]] copy];
    NSMutableString *s1;

    if (![s hasPrefix:@"mailto://"]) {
        s1=[[NSMutableString alloc] initWithString:@"open \"mailto://"];
        [s1 appendString:s];
        [s1 appendString:@"\""];
    }
    else {
        s1=[[NSMutableString alloc] initWithString:@"open \""];
        [s1 appendString:s];
        [s1 appendString:@"\""];
    }
    system([s1 cString]);
    [s1 release];
}

- (void) browse:(id)sender
{
    NSString *s=[[[self string] substringWithRange:[self selectedRange]] copy];
    NSMutableString *s1;

    if (![s hasPrefix:@"http://"]) {
        s1=[[NSMutableString alloc] initWithString:@"open \"http://"];
        [s1 appendString:s];
        [s1 appendString:@"\""];
    }
    else {
        s1=[[NSMutableString alloc] initWithString:@"open \""];
        [s1 appendString:s];
        [s1 appendString:@"\""];
    }
    system([s1 cString]);
    [s1 release];
}

@end
