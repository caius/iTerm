/*
 **  PTYTabViewItem.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: NSTabViewItem subclass. Implements attributes for label.
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

#import "PTYTabViewItem.h"

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0


@implementation PTYTabViewItem

- (id) initWithIdentifier: (id) anIdentifier
{
#if DEBUG_ALLOC
    NSLog(@"PTYTabViewItem: -initWithIdentifier");
#endif

    dragTarget = NO;

    return([super initWithIdentifier: anIdentifier]);
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"PTYTabViewItem: -dealloc");
#endif

    if(labelAttributes != nil)
    {
        [labelAttributes release];
        labelAttributes = nil;
    }

    [super dealloc];
}

// Override this to be able to customize the label attributes
- (void)drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)tabRect
{
#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabViewItem: -drawLabel");
#endif

    if(labelAttributes != nil)
    {
        NSMutableAttributedString *attributedLabel;

        attributedLabel = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat: @"%d: %@",
	    [[self tabView] indexOfTabViewItem: self] + 1, [self label]] attributes: labelAttributes];
	// If we are a current drag target, add foreground and background colors
	if(dragTarget)
	{
	    [attributedLabel addAttribute: NSForegroundColorAttributeName value: [NSColor greenColor]
								    range: NSMakeRange(0, [attributedLabel length])];
	    [attributedLabel addAttribute: NSBackgroundColorAttributeName value: [NSColor blackColor]
								    range: NSMakeRange(0, [attributedLabel length])];
	}	
        [attributedLabel drawAtPoint:tabRect.origin];
        [attributedLabel release];
        
    }
    else
    {
        // No attributed label, so just call the parent method.
        [super drawLabel: shouldTruncateLabel inRect: tabRect];
    }
    
}

- (NSSize) sizeOfLabel:(BOOL)shouldTruncateLabel
{
    NSSize aSize;
    NSMutableAttributedString *attributedLabel;

#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabViewItem: -sizeOfLabel");
#endif

        
    if(labelAttributes != nil)
    {
        attributedLabel = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat: @"%d: %@",
	    [[self tabView] indexOfTabViewItem: self] + 1, [self label]] attributes: labelAttributes];
	// If we are a current drag target, add foreground and background colors
	if(dragTarget)
	{
	    [attributedLabel addAttribute: NSForegroundColorAttributeName value: [NSColor greenColor]
								range: NSMakeRange(0, [attributedLabel length])];
	    [attributedLabel addAttribute: NSBackgroundColorAttributeName value: [NSColor blackColor]
								    range: NSMakeRange(0, [attributedLabel length])];

	}
        aSize = [attributedLabel size];
        [attributedLabel release];
    }
    else
    {
        aSize = [super sizeOfLabel: shouldTruncateLabel];
    }
    
    return (aSize);
}

// set/get custom label
- (NSDictionary *) labelAttributes
{
    return (labelAttributes);
}

- (void) setLabelAttributes: (NSDictionary *) theLabelAttributes
{
#if DEBUG_METHOD_TRACE
    NSLog(@"PTYTabViewItem: -setLabelAttributes");
#endif

    // Do this only if there is a change
    if([labelAttributes isEqualToDictionary: theLabelAttributes])
        return;
    
    if(labelAttributes != nil)
    {
        [labelAttributes release];
        labelAttributes = nil;
    }
    if(theLabelAttributes != nil)
    {
        [theLabelAttributes retain];
        labelAttributes = theLabelAttributes;
    }
    
    // redraw the label
    NSString *theLabel = [[self label] copy];
    [self setLabel: theLabel];
    [theLabel release];
    
}

// Called when when another tab is being dragged over this one
- (void) becomeDragTarget
{
    dragTarget = YES;

    // redraw the label
    NSString *theLabel = [[self label] copy];
    [self setLabel: theLabel];
    [theLabel release];
    
}

// Called when another tab is moved away from this one
- (void) resignDragTarget
{
    dragTarget = NO;
    
    // redraw the label
    NSString *theLabel = [[self label] copy];
    [self setLabel: theLabel];
    [theLabel release];    
}


@end
