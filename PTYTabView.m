/*
 **  PTYTabView.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Ujwal S. Setlur
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

#import <iTerm/PTYTabView.h>

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

@implementation PTYTabView

// Class methods that Apple should have provided
+ (NSSize) contentSizeForFrameSize: (NSSize) frameSize tabViewType: (NSTabViewType) type controlSize: (NSControlSize) controlSize
{
    NSRect aRect, contentRect;
    NSTabView *aTabView;
    float widthOffset, heightOffset;

#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabView: -contentSizeForFrameSize");
#endif    

    // make a temporary tabview 
    aRect = NSMakeRect(0, 0, 200, 200);
    aTabView = [[NSTabView alloc] initWithFrame: aRect];
    [aTabView setTabViewType: type];
    [aTabView setControlSize: controlSize];

    // grab its content size
    contentRect = [aTabView contentRect];

    // calculate the offsets between total frame and content frame
    widthOffset = aRect.size.width - contentRect.size.width;
    heightOffset = aRect.size.height - contentRect.size.height;
    //NSLog(@"widthOffset = %f; heightOffset = %f", widthOffset, heightOffset);

    // release the temporary tabview
    [aTabView release];

    // Apply the offset to the given frame size
    return (NSMakeSize(frameSize.width - widthOffset, frameSize.height - heightOffset));
}

+ (NSSize) frameSizeForContentSize: (NSSize) contentSize tabViewType: (NSTabViewType) type controlSize: (NSControlSize) controlSize
{
    NSRect aRect, contentRect;
    NSTabView *aTabView;
    float widthOffset, heightOffset;

#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabView: -frameSizeForContentSize");
#endif

    // make a temporary tabview
    aRect = NSMakeRect(0, 0, 200, 200);
    aTabView = [[NSTabView alloc] initWithFrame: aRect];
    [aTabView setTabViewType: type];
    [aTabView setControlSize: controlSize];

    // grab its content size
    contentRect = [aTabView contentRect];

    // calculate the offsets between total frame and content frame
    widthOffset = aRect.size.width - contentRect.size.width;
    heightOffset = aRect.size.height - contentRect.size.height;
    //NSLog(@"widthOffset = %f; heightOffset = %f", widthOffset, heightOffset);

    // release the temporary tabview
    [aTabView release];

    // Apply the offset to the given content size
    return (NSMakeSize(contentSize.width + widthOffset, contentSize.height + heightOffset));
}


- (id)initWithFrame: (NSRect) aRect
{
#if DEBUG_ALLOC
    NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif

    self = [super initWithFrame: aRect];

    lock = [[NSLock alloc] init];
    
    return self;
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif

    [lock release];
        
    [super dealloc];
}

// we don't want this to be the first responder in the chain
- (BOOL)acceptsFirstResponder
{
    return (NO);
}

- (void) drawRect: (NSRect) rect
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"iTermTabViewWillRedraw" object: self];
	[super drawRect: rect];
	
}


// NSTabView methods overridden
- (void) addTabViewItem: (NSTabViewItem *) aTabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabView: -addTabViewItem");
#endif

    // Let our delegate know
    id delegate = [self delegate];

    [lock lock];
    if([delegate conformsToProtocol: @protocol(PTYTabViewDelegateProtocol)])
		[delegate tabView: self willAddTabViewItem: aTabViewItem];
    
    // add the item
    maxLabelSize=(([self tabViewType]==NSLeftTabsBezelBorder||[self tabViewType]==NSRightTabsBezelBorder)?[self frame].size.height-20:[self frame].size.width-20)/([self numberOfTabViewItems]+1)-17;
    if (maxLabelSize<20) 
        maxLabelSize=20;
    
    [super addTabViewItem: aTabViewItem];
    [lock unlock];
}

- (void) removeTabViewItem: (NSTabViewItem *) aTabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabView: -removeTabViewItem");
#endif

    // Let our delegate know
    id delegate = [self delegate];
    
    [lock lock];
    if([delegate conformsToProtocol: @protocol(PTYTabViewDelegateProtocol)])
		[delegate tabView: self willRemoveTabViewItem: aTabViewItem];
    
    // remove the item
    maxLabelSize=(([self tabViewType]==NSLeftTabsBezelBorder||[self tabViewType]==NSRightTabsBezelBorder)?[self frame].size.height-20:[self frame].size.width-20)/([self numberOfTabViewItems]-1)-17;
    if (maxLabelSize<20) 
        maxLabelSize=20;
    
    [super removeTabViewItem: aTabViewItem];
    [lock unlock];
}

- (void) insertTabViewItem: (NSTabViewItem *) tabViewItem atIndex: (int) index
{
#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabView: -insertTabViewItem atIndex: %d", index);
#endif

    // Let our delegate know
    id delegate = [self delegate];

    [lock lock];
    
    // Check the boundary
    if (index>[super numberOfTabViewItems]) {
        NSLog(@"Warning: index(%d) > numberOfTabViewItems(%d)", index, [super numberOfTabViewItems]);
        index = [super numberOfTabViewItems];
    }
    
    if([delegate conformsToProtocol: @protocol(PTYTabViewDelegateProtocol)])
        [delegate tabView: self willInsertTabViewItem: tabViewItem atIndex: index];    

    // insert the item
    maxLabelSize=(([self tabViewType]==NSLeftTabsBezelBorder||[self tabViewType]==NSRightTabsBezelBorder)?[self frame].size.height-20:[self frame].size.width-20)/([self numberOfTabViewItems]+1)-17;
    if (maxLabelSize<20) 
        maxLabelSize=20;
    
    [super insertTabViewItem: tabViewItem atIndex: index];
    [lock unlock];
#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabView: -insertTabViewItem atIndex: %d, done", index);
#endif
}


- (float) maxLabelSize
{
    return maxLabelSize;
}

@end
