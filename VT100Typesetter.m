/*
 **  VT100Typesetter.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Custom typesetter for VT100 terminal layout.
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

#import "iTerm.h"
#import "VT100Typesetter.h"
#import "VT100Screen.h"

#define DEBUG_METHOD_TRACE    0
#if DEBUG_METHOD_TRACE
static unsigned int invocationId = 0;
#endif

#define ISDOUBLEWIDTHCHARACTER(idx) ([[textStorage attribute:@"NSCharWidthAttributeName" atIndex:(idx) effectiveRange:nil] intValue]==2)
#define ISGRAPHICALCHARACTER(idx) ([[textStorage attribute:@"VT100GraphicalCharacter" atIndex:(idx) effectiveRange:nil] boolValue])


@implementation VT100Typesetter

// we should really be asking the NSTextContainer, butit may not exist yet, and there is no class method.
+ (float) lineFragmentPadding
{
    return (5);
}


- (float)baselineOffsetInLayoutManager:(NSLayoutManager *)layoutMgr glyphIndex:(unsigned)glyphIndex
{
    return (BASELINE_OFFSET);    
}

- (void)layoutGlyphsInLayoutManager:(NSLayoutManager *)layoutMgr startingAtGlyphIndex:(unsigned)startGlyphIndex maxNumberOfLineFragments:(unsigned)maxNumLines nextGlyphIndex:(unsigned *)nextGlyph
{

#if DEBUG_METHOD_TRACE
    unsigned int callId = invocationId++;
    
    NSLog(@"VT100Typesetter (%d): layoutGlyphsInLayoutManager: startGlyphIndex = %d; maxNumberOfLineFragments = %d",
	  callId, startGlyphIndex, maxNumLines);
#endif
    
    NSRect lineRect;
    unsigned int glyphIndex, charIndex, lineStartIndex, lineEndIndex;
    int numLines, j, length;
    BOOL atEnd, isValidIndex, lineEndCharExists;
    NSString *theString;
    NSRange characterRange, glyphRange;
    NSTextStorage *textStorage;
    NSRect previousRect;


    // grab the text container; we should have only one
    if(textContainer == nil)
    {
	textContainer = [[layoutMgr firstTextView] textContainer];
	lineFragmentPadding = [textContainer lineFragmentPadding];
    }

    // grab the textView; there should be only one
    if(textView == nil)
	textView = [layoutMgr firstTextView];

    textStorage = [layoutMgr textStorage];


    // grab the string; there should be only one
    theString = [textStorage string];
    //NSLog(@"theString = \n'%@'\n", theString);

    // grab the font; there should be only one
    if(font != [textView font])
    {
	font = [textView font];
	if(font != nil)
	    charWidth = [VT100Screen fontSize: font].width;
    }

    length = [theString length];
    if(length <= 0)
    {
	*nextGlyph = 0;
	return;
    }

    // process lines
    glyphIndex = startGlyphIndex;

    previousRect = NSZeroRect;
    for(numLines = 0; numLines < maxNumLines; numLines++)
    {
	atEnd = NO;
	lineEndCharExists = NO;

	// sanity check
	[layoutMgr glyphAtIndex: glyphIndex isValidIndex: &isValidIndex];
	if(isValidIndex == NO)
	{
	    return;
	}
	

	// get the corresponding character index
	charIndex = [layoutMgr characterIndexForGlyphAtIndex: glyphIndex];
	
	// go to the beginning of the line
	j = charIndex;
	while (j >= 0)
	{
	    if([theString characterAtIndex: j] == '\n')
		break;
	    j--;
	}
	lineStartIndex = j + 1;
	if(lineStartIndex  > charIndex)
	    lineStartIndex = charIndex;
	

	// go to the end of the line
	j = charIndex;
	while (j < length)
	{
	    
	    if([theString characterAtIndex: j] == '\n')
	    {
		lineEndCharExists = YES;
		break;
	    }
	    j++;
	}
	// Check if we reached the end of the text
	if(j == length)
	{
	    j--;
	    atEnd = YES;
	    lineEndCharExists = NO;
	}
	lineEndIndex = j;

	// build the line
	characterRange = NSMakeRange(lineStartIndex, lineEndIndex-lineStartIndex+1);
	glyphRange = [layoutMgr glyphRangeForCharacterRange: characterRange actualCharacterRange: nil];

	// calculate line width accounting for double width characters
	NSRange doubleWidthCharacterRange;
	id doubleWidthCharacterAttribute;
	float lineWidth = characterRange.length * charWidth;
	doubleWidthCharacterAttribute = [textStorage attribute:@"NSCharWidthAttributeName" atIndex:lineStartIndex longestEffectiveRange:&doubleWidthCharacterRange inRange:characterRange];
	if(doubleWidthCharacterAttribute != nil || doubleWidthCharacterRange.length != characterRange.length)
	{
	    lineWidth = 0;
	    for (j = lineStartIndex; j < lineEndIndex + 1; j++)
	    {
		lineWidth += ISDOUBLEWIDTHCHARACTER(j)?charWidth*2:charWidth;
	    }
	}

	// calculate the line fragment rectangle
	if(lineStartIndex == 0)
	{
	    lineRect = NSMakeRect(0, 0, [textContainer containerSize].width, [font defaultLineHeightForFont]);
	}
	else
	{
	    NSRect lastGlyphRect;
	    // check if we just processed the previous line, otherwise ask the layout manager.
	    if(previousRect.size.width > 0)
		lastGlyphRect = previousRect;
	    else
		lastGlyphRect = [layoutMgr lineFragmentRectForGlyphAtIndex: lineStartIndex-1 effectiveRange: nil];
	    // calculate next line based on previous line rectangle
	    lineRect = NSMakeRect(0, lastGlyphRect.origin.y + [font defaultLineHeightForFont], [textContainer containerSize].width, [font defaultLineHeightForFont]);
	}
#if DEBUG_METHOD_TRACE
	NSLog(@"(%d) Laying out line %f; numLines = %d", callId, lineRect.origin.y/[font defaultLineHeightForFont] + 1, numLines);
	NSLog(@"(%d) Line = '%@'", callId, [theString substringWithRange: characterRange]);
#endif
	// cache the rect for the next run, if any.
	previousRect = lineRect;
	
	
	// Now fill the line
	NSRect usedRect = lineRect;
	usedRect.size.width = lineWidth + 2*lineFragmentPadding;
	if(usedRect.size.width > lineRect.size.width)
	    usedRect.size.width = lineRect.size.width;
	[layoutMgr setTextContainer: textContainer forGlyphRange: glyphRange];
	[layoutMgr setLineFragmentRect: lineRect forGlyphRange: glyphRange usedRect: usedRect];
	[layoutMgr setLocation: NSMakePoint(lineFragmentPadding, [font defaultLineHeightForFont] - BASELINE_OFFSET) forStartOfGlyphRange: glyphRange];

	// If we encountered graphical characters, we need to lay out each glyph; EXPENSIVE
	NSRange graphicalCharacterRange;
	id graphicalCharacterAttribute;
	graphicalCharacterAttribute = [textStorage attribute:@"VT100GraphicalCharacter" atIndex:lineStartIndex longestEffectiveRange:&graphicalCharacterRange inRange:characterRange];
	if(graphicalCharacterAttribute != nil || graphicalCharacterRange.length != characterRange.length)
	{
	    NSRange singleGlyphRange;
	    float x = 0;
	    float theWidth;

	    //NSLog(@"Laying out each glyph...");
	    for (j = lineStartIndex; j <= lineEndIndex; j++)
	    {
		singleGlyphRange = [layoutMgr glyphRangeForCharacterRange: NSMakeRange(j, 1) actualCharacterRange: nil];
		theWidth = ISDOUBLEWIDTHCHARACTER(j)?charWidth*2:charWidth;

		[layoutMgr setLocation: NSMakePoint(lineFragmentPadding+x, [font defaultLineHeightForFont] - BASELINE_OFFSET) forStartOfGlyphRange: singleGlyphRange];
		x+=theWidth;
	    }
	}
	
	// hide new line glyphs
	if(lineEndCharExists == YES)
	{
	    [layoutMgr setNotShownAttribute: YES forGlyphAtIndex: glyphRange.location + glyphRange.length - 1];
	}
	

	// set the glyphIndex for the next run
	glyphIndex = glyphRange.location + glyphRange.length;

	// check if the last character on the last line is a new lince char; we have to add an extra line fragment.
	if((lineEndIndex > lineStartIndex) && (lineEndIndex == [theString length] - 1) &&
    ([theString characterAtIndex: lineEndIndex] == '\n'))
	{
	    lineRect.origin.y += [font defaultLineHeightForFont];
	    [layoutMgr setExtraLineFragmentRect:lineRect usedRect:lineRect textContainer: textContainer];
	}
	
	
	// if we are at the end of the text, get out
	[layoutMgr glyphAtIndex: glyphIndex isValidIndex: &isValidIndex];
	if(atEnd == YES || isValidIndex == NO)
	{
	    
	    // pad with empty lines if we need to
	    float displayHeight = [textView frame].size.height;

	    // if our content size has decreased, we should not be padding so that the layout manager
	    // can resize the textview.
	    if(length < previousLength)
		break;

	    if (lineRect.origin.y + lineRect.size.height < displayHeight)
	    {
		lineRect.origin.y += [font defaultLineHeightForFont];
		lineRect.size.height = displayHeight - lineRect.origin.y;
		// coercing to multiple of line height.
		lineRect.size.height = floor(lineRect.size.height/[font defaultLineHeightForFont]) * [font defaultLineHeightForFont];
		[layoutMgr setExtraLineFragmentRect:lineRect usedRect:lineRect textContainer: textContainer];
	    }
	    break;
	}
	
    }

    // cache the current for the next run
    previousLength = length;

    // set the next glyph to be laid out
    if(nextGlyph)
	*nextGlyph = glyphIndex;

}


@end
