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
    NSLog(@"PTYTypesetter: layoutGlyphsInLayoutManager: startGlyphIndex = %d; maxNumberOfLineFragments = %d",
	  startGlyphIndex, maxNumLines);
#endif
    
    NSRect lineRect;
    unsigned int glyphIndex, charIndex, lineStartIndex, lineEndIndex;
    int i, j, length;
    BOOL atEnd, isValidIndex, lineEndCharExists;
    NSString *theString;
    NSRange characterRange, glyphRange;
    BOOL hasGraphicalCharacters;
    NSTextStorage *textStorage;


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

    // grab the font; there should be only one
    if(font != [textView font])
    {
	font = [textView font];
	if(font != nil)
	    charWidth = [VT100Screen fontSize: font].width;
    }

    length = [theString length];
#if DEBUG_METHOD_TRACE
    NSLog(@"length = %d", length);
#endif
    if(length <= 0)
    {
	*nextGlyph = 0;
	return;
    }

    // process lines
    glyphIndex = startGlyphIndex;
    
    for(i = 0; i< maxNumLines; i++)
    {
	atEnd = NO;
	lineEndCharExists = NO;
	hasGraphicalCharacters = NO;

	// sanity check
	[layoutMgr glyphAtIndex: glyphIndex isValidIndex: &isValidIndex];
	if(isValidIndex == NO)
	{
#if DEBUG_METHOD_TRACE
	    NSLog(@"Invalid glyph index %d", glyphIndex);
#endif
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
	
	
	// did we encounter a graphical character?
	NSRange graphicalCharacterRange;
	id graphicalCharacterAttribute;
	graphicalCharacterAttribute = [textStorage attribute:@"VT100GraphicalCharacter" atIndex:lineStartIndex longestEffectiveRange:&graphicalCharacterRange inRange:characterRange];
	if(graphicalCharacterAttribute != nil || graphicalCharacterRange.length != characterRange.length)
	{
	    hasGraphicalCharacters = YES;
	}



	// calculate the line fragment rectangle
	if(lineStartIndex == 0)
	{
	    lineRect = NSMakeRect(0, 0, [textContainer containerSize].width, [font defaultLineHeightForFont]);
	}
	else
	{
	    NSRect lastGlyphRect = [layoutMgr lineFragmentRectForGlyphAtIndex: lineStartIndex-1 effectiveRange: nil];
	    lineRect = NSMakeRect(0, lastGlyphRect.origin.y + [font defaultLineHeightForFont], [textContainer containerSize].width, [font defaultLineHeightForFont]);
	}
	
	// Now fill the line
	NSRect usedRect = lineRect;
	usedRect.size.width = lineWidth + 2*lineFragmentPadding;
	if(usedRect.size.width > lineRect.size.width)
	    usedRect.size.width = lineRect.size.width;
	[layoutMgr setTextContainer: textContainer forGlyphRange: glyphRange];
	[layoutMgr setLineFragmentRect: lineRect forGlyphRange: glyphRange usedRect: usedRect];
	[layoutMgr setLocation: NSMakePoint(lineFragmentPadding, [font defaultLineHeightForFont] - BASELINE_OFFSET) forStartOfGlyphRange: glyphRange];

	// If we encountered graphical characters, we need to lay out each glyph; EXPENSIVE
	if(hasGraphicalCharacters == YES)
	{
	    NSRange singleGlyphRange;
	    float x = 0;
	    float theWidth;

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
	
	// if we are at the end of the text, get out
	[layoutMgr glyphAtIndex: glyphIndex isValidIndex: &isValidIndex];
	if(atEnd == YES || isValidIndex == NO)
	{
	    // pad with empty lines if we need to
	    float displayHeight = [textView frame].size.height;

	    if (lineRect.origin.y + lineRect.size.height < displayHeight)
	    {
		lineRect.origin.y += [font defaultLineHeightForFont];
		lineRect.size.height = displayHeight - lineRect.origin.y;
		[layoutMgr setExtraLineFragmentRect:lineRect usedRect:lineRect textContainer: textContainer];
	    }
	    break;
	}
	
    }

    // set the next glyph to be laid out
    if(nextGlyph)
	*nextGlyph = glyphIndex;
    
}


@end
