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

@implementation VT100Typesetter


- (float)baselineOffsetInLayoutManager:(NSLayoutManager *)layoutMgr glyphIndex:(unsigned)glyphIndex
{
    return (3.0);    
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


    // grab the text container; we should have only one
    if(textContainer == nil)
	textContainer = [[layoutMgr firstTextView] textContainer];

    // grab the textView; there should be only one
    if(textView == nil)
	textView = [layoutMgr firstTextView];

    // grab the string; there should be only one
    theString = [[layoutMgr textStorage] string];

    // grab the font; there should be only one
    if(font == nil)
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
	//if(lineEndCharExists == NO)
	//    usedRect.size.width = glyphRange.length * charWidth;
	[layoutMgr setTextContainer: textContainer forGlyphRange: glyphRange];
	[layoutMgr setLineFragmentRect: lineRect forGlyphRange: glyphRange usedRect: usedRect];
	[layoutMgr setLocation: NSMakePoint(5.0, [font defaultLineHeightForFont] - 3.0) forStartOfGlyphRange: glyphRange];
	if(lineEndCharExists == YES)
	{
	    [layoutMgr setNotShownAttribute: YES forGlyphAtIndex: glyphRange.location + glyphRange.length - 1];
	}



	// set the glyphIndex for the next run
	glyphIndex = glyphRange.location + glyphRange.length;
	
	// if we are at the end of the text, get out
	[layoutMgr glyphAtIndex: glyphIndex isValidIndex: &isValidIndex];
	if(atEnd == YES || isValidIndex == NO)
	    break;
	
    }

    // set the next glyph to be laid out
    *nextGlyph = glyphIndex;
    
}


@end
