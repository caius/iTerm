// -*- mode:objc -*-
// $Id: PTYScrollView.m,v 1.9 2003-09-06 20:17:32 yfabian Exp $
/*
 **  PTYScrollView.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: NSScrollView subclass. Currently does not do anything special.
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

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import <iTerm/PTYScrollView.h>
#import <iTerm/PTYTextView.h>

@implementation PTYScroller

- (id)init
{
    userScroll=NO;
    return [super init];
}

- (void)trackScrollButtons:(NSEvent *)theEvent
{
//    NSLog(@"scrollbutton");
    userScroll=YES;
    [super trackScrollButtons:theEvent];
}

- (void)trackKnob:(NSEvent *)theEvent
{
//    NSLog(@"trackKnob");
    userScroll=YES;
    [super trackKnob:theEvent];
}

- (BOOL)userScroll
{
    return userScroll;
}

- (void)resetUserScroll
{
    userScroll=NO;
}

@end

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
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYScrollView initWithFrame:%d,%d,%d,%d]",
	  __FILE__, __LINE__, 
	  frame.origin.x, frame.origin.y, 
	  frame.size.width, frame.size.height);
#endif
    if ((self = [super initWithFrame:frame]) == nil)
	return nil;

    NSParameterAssert([self contentView] != nil);

    PTYScroller *aScroller;

    aScroller=[[PTYScroller alloc] init];
    [self setVerticalScroller: aScroller];
    return self;
}

@end
