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

#define ISDOUBLEWIDTHCHARACTER(idx) ([[[layoutMgr textStorage] attribute:@"NSCharWidthAttributeName" atIndex:(idx) effectiveRange:nil] intValue]==2)

@implementation VT100Typesetter


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
    float x, y, w;


    // grab the text container; we should have only one
    if(textContainer == nil)
    {
	textContainer = [[layoutMgr firstTextView] textContainer];
	lineFragmentPadding = [textContainer lineFragmentPadding];
    }

    // grab the textView; there should be only one
    if(textView == nil)
	textView = [layoutMgr firstTextView];

    // grab the string; there should be only one
    theString = [[layoutMgr textStorage] string];

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
        if (charIndex==0) {
            x=0;
            y=0;
        }
        else {
            NSRect lastGlyphRect = [layoutMgr lineFragmentRectForGlyphAtIndex: charIndex-1 effectiveRange: nil];
            if ([theString characterAtIndex: charIndex-1] == '\n') {
                x=0;
                y=lastGlyphRect.origin.y + [font defaultLineHeightForFont];
            }
            else {
                x = lastGlyphRect.origin.x + ISDOUBLEWIDTHCHARACTER(charIndex-1)?charWidth*2:charWidth;
                y = lastGlyphRect.origin.y;
            }
        }
        
	lineStartIndex = charIndex;
	

	// go to the end of the line
	j = charIndex;
        w=0;
	while (j < length)
	{
	    if([theString characterAtIndex: j] == '\n')
	    {
		lineEndCharExists = YES;
		break;
	    }
            w+=ISDOUBLEWIDTHCHARACTER(j)?charWidth*2:charWidth;
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
        lineRect = NSMakeRect(x, y, [textContainer containerSize].width - x, [font defaultLineHeightForFont]);	
	glyphRange = [layoutMgr glyphRangeForCharacterRange: characterRange actualCharacterRange: nil];


	// Now fill the line
	NSRect usedRect = lineRect;
	usedRect.size.width = w;
	if(usedRect.size.width > lineRect.size.width)
	    usedRect.size.width = lineRect.size.width;
	[layoutMgr setTextContainer: textContainer forGlyphRange: glyphRange];
	[layoutMgr setLineFragmentRect: lineRect forGlyphRange: glyphRange usedRect: usedRect];
        glyphRange=NSMakeRange(glyphRange.location,1);
        for(j=lineStartIndex;j<=lineEndIndex;j++) {
            [layoutMgr setLocation: NSMakePoint(lineFragmentPadding+x, [font defaultLineHeightForFont] - BASELINE_OFFSET) forStartOfGlyphRange: glyphRange];
            glyphRange.location++;
            x+=ISDOUBLEWIDTHCHARACTER(j)?charWidth*2:charWidth;
        }
        
	if(lineEndCharExists == YES)
	{
	    [layoutMgr setNotShownAttribute: YES forGlyphAtIndex: glyphRange.location  - 1];
	}

	// set the glyphIndex for the next run
	glyphIndex = glyphRange.location;
	
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
    *nextGlyph = glyphIndex;
    
}


@end
