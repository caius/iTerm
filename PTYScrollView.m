// -*- mode:objc -*-
// $Id: PTYScrollView.m,v 1.3 2003-02-05 01:11:36 ujwal Exp $
//
//  PTYScrollView.m
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import "PTYScrollView.h"
#import "PTYTextView.h"

@implementation PTYScrollView

- (void) dealloc
{

#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYScrollView dealloc", __FILE__, __LINE__);
#endif
    
    [super dealloc];

}

- (id)initWithFrame:(NSRect)frame
{
    //PTYTextView *textview;

#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYScrollView initWithFrame:%d,%d,%d,%d]",
	  __FILE__, __LINE__, 
	  frame.origin.x, frame.origin.y, 
	  frame.size.width, frame.size.height);
#endif
    if ((self = [super initWithFrame:frame]) == nil)
	return nil;

    //textview = [[PTYTextView alloc] initWithFrame:[self documentVisibleRect]];
    //[self setDocumentView:textview];
    //[self setNextResponder:textview];
    //[self setHasVerticalRuler:YES];
    //[self setRulersVisible:YES];
    [self setHasVerticalScroller:YES];

    //[textview setDrawsBackground:NO];
    //[textview setEditable:YES];
    //[textview setSelectable:YES];

    //NSParameterAssert(textview != nil);
    NSParameterAssert([self contentView] != nil);

    return self;
}

@end
