// -*- mode:objc -*-
// $Id: PTYScrollView.m,v 1.13 2004-02-18 00:56:53 ujwal Exp $
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

- (void) mouseDown: (NSEvent *)theEvent
{
    //NSLog(@"PTYScroller: mouseDown");
    
    [super mouseDown: theEvent];
    
    if([self floatValue] != 1)
	userScroll=YES;
    else
	userScroll = NO;    
}

- (void)trackScrollButtons:(NSEvent *)theEvent
{
    [super trackScrollButtons:theEvent];

    //NSLog(@"scrollbutton");
    if([self floatValue] != 1)
	userScroll=YES;
    else
	userScroll = NO;
}

- (void)trackKnob:(NSEvent *)theEvent
{
    [super trackKnob:theEvent];

    //NSLog(@"trackKnob: %f", [self floatValue]);
    if([self floatValue] != 1)
	userScroll=YES;
    else
	userScroll = NO;
}

- (BOOL)userScroll
{
    return userScroll;
}

- (void)setUserScroll: (BOOL) scroll
{
    userScroll=scroll;
}

@end

@implementation PTYScrollView

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYScrollView dealloc]", __FILE__, __LINE__);
#endif
	
	[backgroundImage release];
    
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
    [aScroller release];
		
    return self;
}

- (void) drawBackgroundImageRect: (NSRect) rect
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);	
	
	NSRect srcRect;
	
	//NSLogRect([self frame]);
	
	// resize image if we need to
	if([backgroundImage size].width != [self documentVisibleRect].size.width ||
       [backgroundImage size].height != [self documentVisibleRect].size.height)
	{
		[backgroundImage setSize: [self documentVisibleRect].size];
	}	
	
	srcRect = rect;
	srcRect.origin.y -= [self documentVisibleRect].origin.y;
	[[self backgroundImage] drawInRect: rect fromRect: srcRect operation: NSCompositeSourceOver fraction: (1.0 - [self transparency])];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    PTYScroller *verticalScroller = (PTYScroller *)[self verticalScroller];

    [super scrollWheel: theEvent];

    //NSLog(@"PTYScrollView: scrollWheel: %f", [verticalScroller floatValue]);
    if([verticalScroller floatValue] < 1.0)
	[verticalScroller setUserScroll: YES];
    else
	[verticalScroller setUserScroll: NO];
}

- (void)detectUserScroll
{
    PTYScroller *verticalScroller = (PTYScroller *)[self verticalScroller];

    //NSLog(@"PTYScrollView: detectUserScroll: %f", [verticalScroller floatValue]);
    
    if([verticalScroller floatValue] < 1.0)
	[verticalScroller setUserScroll: YES];
    else
	[verticalScroller setUserScroll: NO];
}

// background image
- (NSImage *) backgroundImage
{
	return (backgroundImage);
}

- (void) setBackgroundImage: (NSImage *) anImage
{
	if(anImage != nil)
	{
		// rotate the image 180 degrees
		NSImage *targetImage = [[NSImage alloc] initWithSize: [anImage size]];
		NSAffineTransform *trans = [NSAffineTransform transform];
		
		[targetImage lockFocus];
		[trans translateXBy:[anImage size].width/2 yBy:[anImage size].height/2];
		[trans rotateByDegrees: 180];
		[trans translateXBy:-[anImage size].width/2 yBy:-[anImage size].height/2];
		[trans set];
		[anImage drawInRect:NSMakeRect(0,0,[anImage size].width,[anImage size].height) 
				   fromRect:NSMakeRect(0,0,[anImage size].width,[anImage size].height) 
				  operation:NSCompositeSourceOver
				   fraction:1];
		[targetImage unlockFocus];
		[targetImage setScalesWhenResized: YES];
		[targetImage setSize: [self documentVisibleRect].size];
		// set the image
		[backgroundImage release];
		backgroundImage = targetImage;		
	}
	else
	{
		[backgroundImage release];
		backgroundImage = nil;
	}
	
}

- (float) transparency
{
    return (transparency);
}

- (void) setTransparency: (float) theTransparency
{
    if(theTransparency >= 0 && theTransparency <= 1)
    {
		transparency = theTransparency;
		[self setNeedsDisplay: YES];
    }
}

@end
