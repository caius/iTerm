// -*- mode:objc -*-
// $Id: PTYTextView.m,v 1.6 2002-12-20 15:55:47 ujwal Exp $
//
//  PTYTextView.m
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0
#define GREED_KEYDOWN         1

#import "PTYTextView.h"
#import "PTYSession.h"


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
	BOOL prev = [self hasMarkedText];
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

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView doCommandBySelector:...]",
	  __FILE__, __LINE__);
#endif

#if GREED_KEYDOWN == 0
    id delegate = [self delegate];

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


//
// Drag and Drop methods for our text view
//

//
// Called when our drop area is entered
//
- (unsigned int) draggingEntered:(id <NSDraggingInfo>)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView draggingEntered:%@]", __FILE__, __LINE__, sender );
#endif
    
    // Always say YES; handle failure later.
    bExtendedDragNDrop = YES;
    
    
    return bExtendedDragNDrop;
}


//
// Called when the dragged object is moved within our drop area
//
- (unsigned int) draggingUpdated:(id <NSDraggingInfo>)sender
{
    unsigned int iResult;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView draggingUpdated:%@]", __FILE__, __LINE__, sender );
#endif
    
    // Let's see if our parent NSTextView knows what to do
    iResult = [super draggingUpdated: sender];
    
    // If parent class does not know how to deal with this drag type, check if we do.
    if (iResult == NSDragOperationNone) // Parent NSTextView does not support this drag type.
    {
        return [self _checkForSupportedDragTypes: sender];
    }
    
    return iResult;
}


//
// Called when the dragged object leaves our drop area
//
- (void) draggingExited:(id <NSDraggingInfo>)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView draggingExited:%@]", __FILE__, __LINE__, sender );
#endif
    
    // We don't do anything special, so let the parent NSTextView handle this.
    [super draggingExited: sender];
    
    // Reset our handler flag
    bExtendedDragNDrop = NO;
}


//
// Called when the dragged item is about to be released in our drop area.
//
- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    BOOL bResult;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView prepareForDragOperation:%@]", __FILE__, __LINE__, sender );
#endif
    
    // Check if parent NSTextView knows how to handle this.
    bResult = [super prepareForDragOperation: sender];
    
    // If parent class does not know how to deal with this drag type, check if we do.
    if ( bResult != YES && 
        [self _checkForSupportedDragTypes: sender] != NSDragOperationNone )
    {
        bResult = YES;
    }
    
    return bResult;
}


//
// Called when the dragged item is released in our drop area.
//
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
    unsigned int dragOperation;
    BOOL bResult = NO;
    PTYSession *delegate = [self delegate];
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView performDragOperation:%@]", __FILE__, __LINE__, sender );
#endif
    
    
    // If parent class does not know how to deal with this drag type, check if we do.
    if (bExtendedDragNDrop)
    {
        NSPasteboard *pb = [sender draggingPasteboard];
        NSArray *propertyList;
        NSString *aString;
        int i;
        
        dragOperation = [self _checkForSupportedDragTypes: sender];
        
        switch (dragOperation)
        {
            case NSDragOperationCopy:
                // Check for simple strings first
                aString = [pb stringForType:NSStringPboardType];
                if (aString != nil)
                {
                    if ([delegate respondsToSelector:@selector(pasteString:)])
                        [delegate pasteString: aString];
                    else
                        [super paste:sender];
                }
                // Check for file names
                propertyList = [pb propertyListForType: NSFilenamesPboardType];
                for(i = 0; i < [propertyList count]; i++)
                {
                    // Just paste the file names into the shell.
                    if ([delegate respondsToSelector:@selector(pasteString:)])
                    {
                        [delegate pasteString: (NSString*)[propertyList objectAtIndex: i]];
                        [delegate pasteString: @" "];
                    }

                }
                bResult = YES;
                break;				
        }
        
    }
    
    return bResult;
}


//
//
//
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView concludeDragOperation:%@]", __FILE__, __LINE__, sender );
#endif
    
    // If we did no handle the drag'n'drop, ask our parent to clean up
    // I really wish the concludeDragOperation would have a useful exit value.
    if (!bExtendedDragNDrop)
    {
        [super concludeDragOperation: sender];
    }
    
    bExtendedDragNDrop = NO;
}


@end

//
// private methods
//
@implementation PTYTextView (Private)

- (unsigned int) _checkForSupportedDragTypes:(id <NSDraggingInfo>) sender
{
  NSString *sourceType;
  BOOL iResult;
  
  iResult = NSDragOperationNone;
  
  // We support the FileName drag type for attching files
  sourceType = [[sender draggingPasteboard] availableTypeFromArray: [NSArray arrayWithObjects: 
									       NSFilenamesPboardType, 
									     NSStringPboardType, 
									     nil]];
  
  if (sourceType)
    {
      iResult = NSDragOperationCopy;
    }
  
  return iResult;
}

@end

