// -*- mode:objc -*-
// $Id: PTYTextView.m,v 1.189 2004-03-29 00:42:44 ujwal Exp $
/*
 **  PTYTextView.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: NSTextView subclass. The view object for the VT100 screen.
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

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0
#define GREED_KEYDOWN         1

#import <iTerm/iTerm.h>
#import <iTerm/PTYTextView.h>
#import <iTerm/PTYSession.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/FindPanelWindowController.h>
#import <iTerm/PreferencePanel.h>
#import <iTerm/PTYScrollView.h>

static SInt32 systemVersion;


@implementation PTYTextView

+ (void) initialize
{
	// get system version number
	// get the system version since there is a useful call in 10.3 and up for getting a blod stroke
	Gestalt(gestaltSystemVersion,&systemVersion);
}

- (id)initWithFrame: (NSRect) aRect
{
#if DEBUG_ALLOC
    NSLog(@"%s 0x%x", __PRETTY_FUNCTION__, self);
#endif
    	
    self = [super initWithFrame: aRect];
    dataSource=_delegate=markedTextAttributes=NULL;
    
    [self setMarkedTextAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor yellowColor], NSBackgroundColorAttributeName,
            [NSColor blackColor], NSForegroundColorAttributeName,
            font, NSFontAttributeName,
            [NSNumber numberWithInt:2],NSUnderlineStyleAttributeName,
            NULL]];
    deadkey = NO;
	CURSOR=YES;
	lastFindX = startX = -1;
    markedText=nil;
	[[self window] useOptimizedDrawing:YES];
    
	// register for some notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameChanged:)
                                                 name:NSWindowDidResizeNotification
                                               object:nil];
	
	// register for drag and drop
	[self registerForDraggedTypes: [NSArray arrayWithObjects:
        NSFilenamesPboardType,
        NSStringPboardType,
        nil]];
	
	// init the cache
	memset(charImages, 0, CACHESIZE*sizeof(CharCache));	
    charWidth = 12;
		
	
    return (self);
}

- (BOOL) resignFirstResponder
{
	
	//NSLog(@"0x%x: %s", self, __PRETTY_FUNCTION__);
	if(trackingRectTag)
		[self removeTrackingRect:trackingRectTag];
	trackingRectTag = 0;
		
	return (YES);
}

- (BOOL) becomeFirstResponder
{
	
	//NSLog(@"0x%x: %s", self, __PRETTY_FUNCTION__);
	// reset tracking rect
	if(trackingRectTag)
		[self removeTrackingRect:trackingRectTag];
	trackingRectTag = [self addTrackingRect:[self frame] owner: self userData: nil assumeInside: NO];
		
	return (YES);
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"PTYTextView: -dealloc 0x%x", self);
#endif
	int i;
    
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];    
    for(i=0;i<16;i++) {
        [colorTable[i] release];
    }
    [defaultFGColor release];
    [defaultBGColor release];
    [defaultBoldColor release];
    [selectionColor release];
	[defaultCursorColor release];
	
    [dataSource release];
    [_delegate release];
    [font release];
	[nafont release];
    [markedTextAttributes release];
	[markedText release];
	
	
    [self resetCharCache];
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

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}


- (BOOL) antiAlias
{
    return (antiAlias);
}

- (void) setAntiAlias: (BOOL) antiAliasFlag
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setAntiAlias: %d]",
          __FILE__, __LINE__, antiAliasFlag);
#endif
    antiAlias = antiAliasFlag;
	[self resetCharCache];
}

- (BOOL) blinkingCursor
{
	return (blinkingCursor);
}

- (void) setBlinkingCursor: (BOOL) bFlag
{
	blinkingCursor = bFlag;
}


- (NSDictionary*) markedTextAttributes
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView selectedTextAttributes]",
          __FILE__, __LINE__);
#endif
    return markedTextAttributes;
}

- (void) setMarkedTextAttributes: (NSDictionary *) attr
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setSelectedTextAttributes:%@]",
          __FILE__, __LINE__,attr);
#endif
    [markedTextAttributes release];
    [attr retain];
    markedTextAttributes=attr;
}

- (void) setFGColor:(NSColor*)color
{
    [defaultFGColor release];
    [color retain];
    defaultFGColor=color;
	[self resetCharCache];
	[self setNeedsDisplay: YES];
	// reset our default character attributes    
}

- (void) setBGColor:(NSColor*)color
{
    [defaultBGColor release];
    [color retain];
    defaultBGColor=color;
	//    bg = [bg colorWithAlphaComponent: [[SESSION backgroundColor] alphaComponent]];
	//    fg = [fg colorWithAlphaComponent: [[SESSION foregroundColor] alphaComponent]];
	[self setNeedsDisplay: YES];
}

- (void) setBoldColor: (NSColor*)color
{
    [defaultBoldColor release];
    [color retain];
    defaultBoldColor=color;
	[self resetCharCache];
	[self setNeedsDisplay: YES];
}

- (void) setCursorColor: (NSColor*)color
{
    [defaultCursorColor release];
    [color retain];
    defaultCursorColor=color;
	[self setNeedsDisplay: YES];
}

- (void) setSelectedTextColor: (NSColor *) aColor
{
	[selectedTextColor release];
	[aColor retain];
	selectedTextColor = aColor;
	[self _clearCacheForColor: SELECTED_TEXT];
	[self setNeedsDisplay: YES];
}

- (void) setCursorTextColor:(NSColor*) aColor
{
	[cursorTextColor release];
	[aColor retain];
	cursorTextColor = aColor;
	[self _clearCacheForColor: CURSOR_TEXT];
	[self setNeedsDisplay: YES];
}

- (NSColor *) cursorTextColor
{
	return (cursorTextColor);
}

- (NSColor *) selectedTextColor
{
	return (selectedTextColor);
}

- (NSColor *) defaultFGColor
{
    return defaultFGColor;
}

- (NSColor *) defaultBGColor
{
	return defaultBGColor;
}

- (NSColor *) defaultBoldColor
{
    return defaultBoldColor;
}

- (NSColor *) defaultCursorColor
{
    return defaultCursorColor;
}

- (void) setColorTable:(int) index highLight:(BOOL)hili color:(NSColor *) c
{
	int idx=(hili?1:0)*8+index;
	
    [colorTable[idx] release];
    [c retain];
    colorTable[idx]=c;
	[self _clearCacheForColor: idx];
	[self _clearCacheForColor: (BOLD_MASK | idx)];
	
	[self setNeedsDisplay: YES];
}

- (NSColor *) colorForCode:(unsigned int) index 
{
    NSColor *color;
	int reversed;
	
	if(index & SELECTED_TEXT)
		return (selectedTextColor);
	
	if(index & CURSOR_TEXT)
		return (cursorTextColor);
	
	reversed = [[dataSource terminal] screenMode];
	
	if (index&DEFAULT_FG_COLOR_CODE)
    {
		if (index&1) // background color?
		{
			color=(reversed?defaultFGColor:defaultBGColor);
		}
		else if(index&BOLD_MASK)
		{
			color = (reversed?defaultBGColor:[self defaultBoldColor]);
		}
		else
		{
			color = (reversed?defaultBGColor:defaultFGColor);
		}
    }
    else
    {
        color=colorTable[index&15];
    }
	
    return color;
    
}

- (NSColor *) selectionColor
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView selectionColor]",
          __FILE__, __LINE__);
#endif
    
    return selectionColor;
}

- (void) setSelectionColor: (NSColor *) aColor
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setSelectionColor:%@]",
          __FILE__, __LINE__,aColor);
#endif
    
    [selectionColor release];
    [aColor retain];
    selectionColor=aColor;
	[self setNeedsDisplay: YES];
}


- (NSFont *)font
{
    return font;
}

- (NSFont *)nafont
{
    return nafont;
}

- (void) setFont:(NSFont*)aFont nafont:(NSFont *)naFont;
{    
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSSize sz;
	
    [dic setObject:aFont forKey:NSFontAttributeName];
    sz = [@"W" sizeWithAttributes:dic];
	
	charWidthWithoutSpacing = sz.width;
	charHeightWithoutSpacing = [aFont defaultLineHeightForFont];
	
    [font release];
    [aFont retain];
    font=aFont;
    [nafont release];
    [naFont retain];
    nafont=naFont;
	[self setNeedsDisplay: YES];
    [self setMarkedTextAttributes:
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor yellowColor], NSBackgroundColorAttributeName,
            [NSColor blackColor], NSForegroundColorAttributeName,
            font, NSFontAttributeName,
            [NSNumber numberWithInt:2],NSUnderlineStyleAttributeName,
            NULL]];
	[self resetCharCache];
}

- (void) resetCharCache
{
	int loop;
	for (loop=0;loop<CACHESIZE;loop++)
    {
		[charImages[loop].image release];
		charImages[loop].image=nil;
    }
}

- (id) dataSource
{
    return (dataSource);
}

- (void) setDataSource: (id) aDataSource
{
    [dataSource release];
    [aDataSource retain];
    dataSource = aDataSource;
}

- (id) delegate
{
    return _delegate;
}

- (void) setDelegate: (id) aDelegate
{
    [_delegate release];
    [aDelegate retain];
    _delegate = aDelegate;
}    

- (float) lineHeight
{
    return (lineHeight);
}

- (void) setLineHeight: (float) aLineHeight
{
    lineHeight = aLineHeight;
}

- (float) lineWidth
{
    return (lineWidth);
}

- (void) setLineWidth: (float) aLineWidth
{
    lineWidth = aLineWidth;
}

- (float) charWidth
{
	return (charWidth);
}

- (void) setCharWidth: (float) width
{
	charWidth = width;
}

- (void) setForceUpdate: (BOOL) flag
{
	forceUpdate = flag;
}


// We override this method since both refresh and window resize can conflict resulting in this happening twice
// So we do not allow the size to be set larger than what the data source can fill
- (void) setFrameSize: (NSSize) aSize
{
	//NSLog(@"%s (0x%x): setFrameSize to (%f,%f)", __PRETTY_FUNCTION__, self, aSize.width, aSize.height);

	NSSize anotherSize = aSize;
	
	anotherSize.height = [dataSource numberOfLines] * lineHeight;
	
	[super setFrameSize: anotherSize];
	
	// reset tracking rect
	if(trackingRectTag)
		[self removeTrackingRect:trackingRectTag];
	trackingRectTag = [self addTrackingRect:[self visibleRect] owner: self userData: nil assumeInside: NO];
}

- (void) refresh
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);

    NSSize aSize;
	int height;
    
    if(dataSource != nil)
    {
        numberOfLines = [dataSource numberOfLines];
        aSize = [self frame].size;
        height = numberOfLines * lineHeight;
        if(height != [self frame].size.height)
        {
            NSRect aFrame;
            
			//NSLog(@"%s: 0x%x; new number of lines = %d; resizing height from %f to %d", 
			//	  __PRETTY_FUNCTION__, self, numberOfLines, [self frame].size.height, height);
            aFrame = [self frame];
            aFrame.size.height = height;
            [self setFrame: aFrame];
			if (![(PTYScroller *)([[self enclosingScrollView] verticalScroller]) userScroll]) [self scrollEnd];
        }
    }
	
	[self setNeedsDisplay: YES];
	
}


- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
	forceUpdate = YES;
	proposedVisibleRect.origin.y=(int)(proposedVisibleRect.origin.y/lineHeight+0.5)*lineHeight;
	return proposedVisibleRect;
}

-(void) scrollLineUp: (id) sender
{
    NSRect scrollRect;
    
    scrollRect= [self visibleRect];
    scrollRect.origin.y-=[[self enclosingScrollView] verticalLineScroll];
	//forceUpdate = YES;
	//[self setNeedsDisplay: YES];
    //NSLog(@"%f/%f",[[self enclosingScrollView] verticalLineScroll],[[self enclosingScrollView] verticalPageScroll]);
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollLineDown: (id) sender
{
    NSRect scrollRect;
    
    scrollRect= [self visibleRect];
    scrollRect.origin.y+=[[self enclosingScrollView] verticalLineScroll];
	//forceUpdate = YES;
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollPageUp: (id) sender
{
    NSRect scrollRect;
	
    scrollRect= [self visibleRect];
    scrollRect.origin.y-=[[self enclosingScrollView] verticalPageScroll];
	//forceUpdate = YES;
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollPageDown: (id) sender
{
    NSRect scrollRect;
    
    scrollRect= [self visibleRect];
    scrollRect.origin.y+=[[self enclosingScrollView] verticalPageScroll];
	//forceUpdate = YES;
    [self scrollRectToVisible: scrollRect];
}

-(void) scrollHome
{
    NSRect scrollRect;
    
    scrollRect= [self visibleRect];
    scrollRect.origin.y = 0;
	//forceUpdate = YES;
    [self scrollRectToVisible: scrollRect];
}

- (void)scrollEnd
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView scrollEnd]", __FILE__, __LINE__ );
#endif
    
    if (numberOfLines > 0)
    {
        NSRect aFrame;
		aFrame.origin.x = 0;
		aFrame.origin.y = (numberOfLines - 1) * lineHeight;
		aFrame.size.width = [self frame].size.width;
		aFrame.size.height = lineHeight;
		//forceUpdate = YES;
		[self scrollRectToVisible: aFrame];
    }
}

- (void)scrollToSelection
{
	NSRect aFrame;
	aFrame.origin.x = 0;
	aFrame.origin.y = startY * lineHeight;
	aFrame.size.width = [self frame].size.width;
	aFrame.size.height = (endY - startY + 1) *lineHeight;
	//forceUpdate = YES;
	[self scrollRectToVisible: aFrame];
}

-(void) hideCursor
{
    CURSOR=NO;
}

-(void) showCursor
{
    CURSOR=YES;
}

-(void) forceUpdate
{
	forceUpdate = YES;
}

- (void)drawRect:(NSRect)rect
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(0x%x):-[PTYTextView drawRect:(%f,%f,%f,%f) frameRect: (%f,%f,%f,%f)]",
          __PRETTY_FUNCTION__, self,
          rect.origin.x, rect.origin.y, rect.size.width, rect.size.height,
		  [self frame].origin.x, [self frame].origin.y, [self frame].size.width, [self frame].size.height);
#endif
		
    int numLines, i, j, lineOffset, WIDTH;
	int startScreenLineIndex,line, lineIndex;
    unichar *buf;
	NSRect bgRect;
	NSColor *aColor;
	char  *fg, *bg, *dirty;
	BOOL need_draw;
	int bgstart, ulstart;
    float curX, curY;
	unsigned int bgcode, fgcode;
	int y1, x1;
	BOOL double_width;
	
    if(lineHeight <= 0 || lineWidth <= 0)
        return;
    
	// make sure margins are filled in
	if (forceUpdate) {
		if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil)
		{
			[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: rect];
		}
		else {
			aColor = [self colorForCode:DEFAULT_BG_COLOR_CODE];
			aColor = [aColor colorWithAlphaComponent: (1 - transparency)];
			[aColor set];
			NSRectFill(rect);
		}
	}
	WIDTH=[dataSource width];

	// Starting from which line?
	lineOffset = rect.origin.y/lineHeight;
    
	// How many lines do we need to draw?
	numLines = rect.size.height/lineHeight;

	// Which line is our screen start?
	startScreenLineIndex=[dataSource numberOfLines] - [dataSource height];
    //NSLog(@"%f+%f->%d+%d", rect.origin.y,rect.size.height,lineOffset,numLines);
		
	// [self adjustScroll] should've made sure we are at an integer multiple of a line
	curY=rect.origin.y +lineHeight;
	
	// redraw margins if we have a background image, otherwise we can still "see" the margin
	if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil)
	{
		bgRect = NSMakeRect(0, rect.origin.y, MARGIN, rect.size.height);
		[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
		bgRect = NSMakeRect(rect.size.width - MARGIN, rect.origin.y, MARGIN, rect.size.height);
		[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
	}
	
	
    for(i = 0; i < numLines; i++)
    {
		curX = MARGIN;
        line = i + lineOffset;
		
		if(line >= [dataSource numberOfLines])
		{
			NSLog(@"%s (0x%x): illegal line index %d >= %d", __PRETTY_FUNCTION__, self, line, [dataSource numberOfLines]);
			break;
		}
		
		// Check if we are drawing a line in buffer
		if (line < startScreenLineIndex) 
		{
			lineIndex=startScreenLineIndex-line;
			lineIndex=[dataSource lastBufferLineIndex]-lineIndex;
			if (lineIndex<0) lineIndex+=[dataSource scrollbackLines];
			buf=[dataSource bufferLines]+lineIndex*WIDTH;
			fg=[dataSource bufferFGColor]+lineIndex*WIDTH;
			bg=[dataSource bufferBGColor]+lineIndex*WIDTH;
		}
		else 
		{ // not in buffer
			lineIndex=line-startScreenLineIndex;
			buf=[dataSource screenLines]+lineIndex*WIDTH;
			fg=[dataSource screenFGColor]+lineIndex*WIDTH;
			bg=[dataSource screenBGColor]+lineIndex*WIDTH;
			dirty=[dataSource dirty]+lineIndex*WIDTH;
		}	
		
		//draw background and underline here
		bgstart=ulstart=-1;
		for(j=0;j<WIDTH;j++) {
			if (buf[j]==0xffff) continue;
			// Check if we need to redraw next char
			need_draw = line < startScreenLineIndex || forceUpdate || dirty[j] || (fg[j]&BLINK_MASK);

			// if we don't have to update next char, finish pending jobs
			if (!need_draw){
				if (bgstart>=0) {
					aColor = (bgcode & SELECTION_MASK) ? selectionColor : [self colorForCode:bgcode]; 
					aColor = [aColor colorWithAlphaComponent: (1 - transparency)];
					[aColor set];
					
					bgRect = NSMakeRect(curX+bgstart*charWidth,curY-lineHeight,(j-bgstart)*charWidth,lineHeight);
					NSRectFill(bgRect);
					// if we have a background image and we are using the background image, redraw image
					if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil && bgcode == DEFAULT_BG_COLOR_CODE)
					{
						[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
					}
					
				}						
				if (ulstart>=0) {
					[[self colorForCode:fgcode] set];
					NSRectFill(NSMakeRect(curX+ulstart*charWidth,curY-2,(j-ulstart)*charWidth,1));
				}
				bgstart=ulstart=-1;
			}
			else {
				// find out if the current char is being selected
				if (bgstart<0) {
					bgstart = j; 
					bgcode = bg[j] & 0xff; 
				}
				else if (bg[j]!=bgcode || (ulstart>=0 && (fg[j]!=fgcode || !buf[j]))) { //background or underline property change?
					aColor = (bgcode & SELECTION_MASK) ? selectionColor : [self colorForCode:bgcode]; 
					aColor = [aColor colorWithAlphaComponent: (1 - transparency)];
					[aColor set];
					
					bgRect = NSMakeRect(curX+bgstart*charWidth,curY-lineHeight,(j-bgstart)*charWidth,lineHeight);
					NSRectFill(bgRect);
					if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil && bgcode == DEFAULT_BG_COLOR_CODE)
					{
						[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
					}
					bgstart = j; 
					bgcode = bg[j] & 0xff; 
				}
				
				if (ulstart<0 && (fg[j]&UNDER_MASK) && buf[j]) { 
					ulstart = j;
					fgcode = fg[j] & 0xff; 
				}
				else if ( ulstart>=0 && (fg[j]!=fgcode || !buf[j])) { //underline or fg color property change?
					[[self colorForCode:fgcode] set];
					NSRectFill(NSMakeRect(curX+ulstart*charWidth,curY-2,(j-ulstart)*charWidth,1));
					fgcode=fg[j] & 0xff;
					ulstart=(fg[j]&UNDER_MASK && buf[j])?j:-1;
				}
			}
		}
		
		// finish pending jobs
		if (bgstart>=0) {
			aColor = (bgcode & SELECTION_MASK) ? selectionColor : [self colorForCode:bgcode]; 
			aColor = [aColor colorWithAlphaComponent: (1 - transparency)];
			[aColor set];
			
			bgRect = NSMakeRect(curX+bgstart*charWidth,curY-lineHeight,(j-bgstart)*charWidth,lineHeight);
			NSRectFill(bgRect);
			if([(PTYScrollView *)[self enclosingScrollView] backgroundImage] != nil && bgcode == DEFAULT_BG_COLOR_CODE)
			{
				[(PTYScrollView *)[self enclosingScrollView] drawBackgroundImageRect: bgRect];
			}
		}
		
		if (ulstart>=0) {
			[[self colorForCode:fgcode] set];
			NSRectFill(NSMakeRect(curX+ulstart*charWidth,curY-2,(j-ulstart)*charWidth,1));
		}
		
		//draw all char
		for(j=0;j<WIDTH;j++) {
			need_draw = (buf[j] && buf[j]!=0xffff) && (line < startScreenLineIndex || forceUpdate || dirty[j] || (fg[j]&BLINK_MASK));
			if (need_draw) { 
				double_width = (buf[j+1] == 0xffff);
				// switch colors if text is selected
				if((bg[j] & SELECTION_MASK) && ((fg[j] & 0x1f) == DEFAULT_FG_COLOR_CODE))
					fgcode = SELECTED_TEXT | ((fg[j] & BOLD_MASK) & 0xff); // check for bold
				else
					fgcode = fg[j] & 0xff;				
				if (fg[j]&BLINK_MASK) {
					if (blinkShow) {				
						[self _drawCharacter:buf[j] fgColor:fgcode AtX:curX Y:curY doubleWidth: double_width];
					}
				}
				else {
					[self _drawCharacter:buf[j] fgColor:fgcode AtX:curX Y:curY doubleWidth: double_width];
					if(line>=startScreenLineIndex) 
						dirty[j]=0;
				}
			}
			else if(line>=startScreenLineIndex) 
				dirty[j]=0;
			
			curX+=charWidth;
		}
		//if (line>=startScreenLineIndex) memset(dirty,0,WIDTH);
		curY+=lineHeight;
	}
	
	blinkShow = !blinkShow;
	x1=[dataSource cursorX]-1;
	y1=[dataSource cursorY]-1;
	//draw cursor
	if([self blinkingCursor])
		showCursor = !showCursor;
	else
		showCursor = YES;
	if([[self window] isKeyWindow] == NO)
		showCursor = YES;
	if (CURSOR) {
		i = y1*[dataSource width]+x1;
		fg=[dataSource screenFGColor]+y1*WIDTH;
		if(showCursor)
		{
			[[[self defaultCursorColor] colorWithAlphaComponent: (1 - transparency)] set];
						
			if([[self window] isKeyWindow])
			{
				NSRectFill(NSMakeRect(x1 * charWidth + MARGIN,
									  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight + (lineHeight - charHeightWithoutSpacing),
									  charWidthWithoutSpacing, charHeightWithoutSpacing));
			}
			else
			{
				NSFrameRect(NSMakeRect(x1 * charWidth + MARGIN,
									  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight + (lineHeight - charHeightWithoutSpacing),
									  charWidthWithoutSpacing, charHeightWithoutSpacing));
				
			}
			// draw any character on cursor if we need to
			unichar aChar = [dataSource screenLines][i];
			if (aChar)
			{
				if (aChar==0xffff && x1>0) {
					i--;
					x1--;
					aChar = [dataSource screenLines][i];
				}
				double_width = ([dataSource screenLines][i+1] == 0xffff);
				[self _drawCharacter: aChar 
							 fgColor: [[self window] isKeyWindow]?CURSOR_TEXT:(fg[x1] & 0xff)
								AtX: x1 * charWidth + MARGIN 
								  Y: (y1+[dataSource numberOfLines]-[dataSource height]+1)*lineHeight
						doubleWidth: double_width];
			}
		}
		[dataSource dirty][i] = 1; //cursor loc is dirty
		
	}
	
	// draw any text for NSTextInput
	if([self hasMarkedText]) {
		int len;
		
		len=[markedText length];
		if (len>[dataSource width]-x1) len=[dataSource width]-x1;
		[markedText drawInRect:NSMakeRect(x1 * charWidth + MARGIN,
										  (y1+[dataSource numberOfLines]-[dataSource height])*lineHeight,
										  (WIDTH-x1)*charWidth,lineHeight)];
		memset([dataSource dirty]+y1*[dataSource width]+x1, 1,len*2); //len*2 is an over-estimation, but safe
	}
	

	forceUpdate=NO;
}

- (void)keyDown:(NSEvent *)event
{
    NSInputManager *imana = [NSInputManager currentInputManager];
    BOOL IMEnable = [imana wantsToInterpretAllKeystrokes];
    BOOL put;
    id delegate = [self delegate];
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView keyDown:%@]",
          __FILE__, __LINE__, event );
#endif
    
    // Hide the cursor
    [NSCursor setHiddenUntilMouseMoves: YES];    
    
    // Check for dead keys
	if([[self delegate] optionKey] == OPT_NORMAL)
	{
		if (deadkey) {
			[self interpretKeyEvents:[NSArray arrayWithObject:event]];
			deadkey=[self hasMarkedText];
			return;
		}
		else if ([[event characters] length]<1) {
			deadkey=YES;
			[self interpretKeyEvents:[NSArray arrayWithObject:event]];
			return;
		}
	}
    
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

- (void) otherMouseDown: (NSEvent *) event
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: %@]", __PRETTY_FUNCTION__, sender );
#endif
    
	[self pasteSelection: nil];
}

- (void)mouseExited:(NSEvent *)event
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
	// no-op
}

- (void)mouseEntered:(NSEvent *)event
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
	
	if([[PreferencePanel sharedInstance] focusFollowsMouse])
		[[self window] makeKeyWindow];
}

- (void)mouseDown:(NSEvent *)event
{
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView mouseDown:%@]",
          __FILE__, __LINE__, event );
#endif
    
    NSPoint locationInWindow, locationInTextView;
    int x, y;
	
	mouseDragged = NO;
    
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil];
    
    x = (locationInTextView.x-MARGIN)/charWidth;
	if (x<0) x=0;
    y = locationInTextView.y/lineHeight;
	
    if (x>=[dataSource width]) x= [dataSource width] - 1;
	
	// if we are holding the shift key down, we are extending selection
	if (startX > -1 && ([event modifierFlags] & NSShiftKeyMask))
	{
		endX = x;
		endY = y;
	}
	else
	{
		endX = startX = x;
		endY = startY = y;
	}	
	    
    if([_delegate respondsToSelector: @selector(willHandleEvent:)] && [_delegate willHandleEvent: event])
        [_delegate handleEvent: event];
	[self setNeedsDisplay: YES];
}

- (void)mouseUp:(NSEvent *)event
{
	NSPoint locationInWindow, locationInTextView;
    int x, y, tmpX1, tmpY1, tmpX2, tmpY2;
	
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView mouseUp:%@]",
          __FILE__, __LINE__, event );
#endif
    
    locationInWindow = [event locationInWindow];
    locationInTextView = [self convertPoint: locationInWindow fromView: nil];
    
    x = (locationInTextView.x-MARGIN)/charWidth;
	if (x<0) x=0;
    if (x>=[dataSource width]) x=[dataSource width] - 1;
    y = locationInTextView.y/lineHeight;
	if(locationInTextView.x < MARGIN && startY < y)
	{
		// complete selection of previous line
		x = [dataSource width] - 1;
		y--;
	}	
    if (y<0) y=0;
    if (y>=[dataSource numberOfLines]) y=numberOfLines-1;
    endX=x;
    endY=y;
    if (startY>endY||(startY==endY&&startX>endX)) {
        y=startY; startY=endY; endY=y;
        y=startX; startX=endX; endX=y;
		x = endX; y = endY;
    }
    else if (startY==endY&&startX==endX&&!mouseDragged) startX=-1;
	
	// if we are on an empty line, we select the current line to the end
	if([self _isBlankLine: y] && y >= 0)
	  endX = [dataSource width] - 1;
	
	// handle command click on URL
	if([event modifierFlags] & NSCommandKeyMask)
	{
		NSString *aURL = [self _getWordForX: x y: y startX: NULL startY: NULL endX: NULL endY: NULL];
		[self _openURL: aURL];
	}
	
	// Handle double and triple click
	if([event clickCount] == 2)
	{
		// double-click; select word
		[self _getWordForX: x y: y startX: &tmpX1 startY: &tmpY1 endX: &tmpX2 endY: &tmpY2];
		startX = tmpX1;
		startY = tmpY1;
		endX = tmpX2;
		endY = tmpY2;		
	}
	else if ([event clickCount] >= 3)
	{
		// triple-click; select line
		startX = 0;
		endX = [dataSource width] - 1;
		startY = endY = y;
	}

	[self _selectFromX:startX Y:startY toX:endX Y:endY];
    if (startX!=-1&&_delegate) {
		// if we want to copy our selection, do so
        if([[PreferencePanel sharedInstance] copySelection])
            [self copy: self];
    }
	[self setNeedsDisplay: YES];
}

- (void)mouseDragged:(NSEvent *)event
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView mouseDragged:%@]",
          __FILE__, __LINE__, event );
#endif
    NSPoint locationInWindow = [event locationInWindow];
    NSPoint locationInTextView = [self convertPoint: locationInWindow fromView: nil];
    NSRect  rectInTextView = [self visibleRect];
    int x, y;
	
	mouseDragged = YES;
    
	// NSLog(@"(%f,%f)->(%f,%f)",locationInWindow.x,locationInWindow.y,locationInTextView.x,locationInTextView.y); 
    if (locationInTextView.y<rectInTextView.origin.y) {
        rectInTextView.origin.y=locationInTextView.y;
        [self scrollRectToVisible: rectInTextView];
    }
    else if (locationInTextView.y>rectInTextView.origin.y+rectInTextView.size.height) {
        rectInTextView.origin.y+=locationInTextView.y-rectInTextView.origin.y-rectInTextView.size.height;
        [self scrollRectToVisible: rectInTextView];
    }
    
    x = (locationInTextView.x - MARGIN) / charWidth;
	if (x < 0) x = 0;
	if (x>=[dataSource width]) x=[dataSource width] - 1;
	
    
	y = locationInTextView.y/lineHeight;
	
	// if we are on an empty line, we select the current line to the end
	if([self _isBlankLine: y] && y >= 0)
		x = [dataSource width] - 1;
	
	if(locationInTextView.x < MARGIN && startY < y)
	{
		// complete selection of previous line
		x = [dataSource width] - 1;
		y--;
	}
    if (y<0) y=0;
    if (y>=[dataSource numberOfLines]) y=numberOfLines - 1;
    endX=x;
    endY=y;
	[self _selectFromX:startX Y:startY toX:endX Y:endY];
	[self setNeedsDisplay: YES];
    //    NSLog(@"(%d,%d)-(%d,%d)",startX,startY,endX,endY);
}

- (NSString *) contentFromX:(int)startx Y:(int)starty ToX:(int)endx Y:(int)endy
{
	unichar *temp;
	int j, line, scline;
	int width, y, x1, x2;
	NSString *str;
	unichar *buf;
	BOOL endOfLine;
	int i;
	
	width = [dataSource width];
	scline = [dataSource numberOfLines]-[dataSource height];
	temp = (unichar *) malloc(((endy-starty+1)*(width+1)+(endx-startx+1))*sizeof(unichar));
	j=0;
	for (y=starty;y<=endy;y++) {
		if (y<scline) {
			line=[dataSource lastBufferLineIndex]-scline+y;
			if (line<0) line+=[dataSource scrollbackLines];
			buf=[dataSource bufferLines]+line*width;
		} else {
			line=y-scline;
			buf=[dataSource screenLines]+line*width;
		}
		x1=0; 
		x2=width - 1;
		if (y == starty) 
			x1 = startx;
		if (y == endy) 
			x2=endx;
		for(; x1 <= x2; x1++) 
		{
			if (buf[x1]!=0xffff) {
				temp[j]=buf[x1];
				if(buf[x1] == 0)
				{
					// if there is no text after this, insert a hard line break
					endOfLine = YES;
					for(i = x1+1; i <= x2; i++)
					{
						if(buf[i] != 0)
							endOfLine = NO;
					}
					if(endOfLine && y < endy)
					{
						temp[j] = '\n'; // hard break
						j++;
						break; // continue to next line
					}
					else
						temp[j] = ' '; // represent blank with space
				}
				j++;
			}
		}		
	}
	
	str=[NSString stringWithCharacters:temp length:j];
	free(temp);
	
	return str;
}

- (IBAction) selectAll: (id) sender
{
	// set the selection region for the whole text
	startX = startY = 0;
	endX = [dataSource width] - 1;
	endY = [dataSource numberOfLines] - 1;
	[self _selectFromX:startX Y:startY toX:endX Y:endY];
	[self setNeedsDisplay: YES];
}

- (NSString *) selectedText
{
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: insertLineBreaks = %d]", __PRETTY_FUNCTION__, insertLineBreaks );
#endif
	
	if (startX == -1) return nil;
	
	int line, bfHeight;
	int width, height, x, y;
	char *bg;
	unichar *buf;
	unichar *temp;
	NSString *str;
	int last = 0;
	BOOL keep_going = YES;
	BOOL endOfLine;
	int i;
	
	width = [dataSource width];
	height = [dataSource numberOfLines];
	bfHeight = height - [dataSource height];
	temp = (unichar *) malloc (height * (width+1) * sizeof(unichar));
	
	for (y=0; y<height && keep_going; y++) {
		if (y < bfHeight) {
			line = [dataSource lastBufferLineIndex] - bfHeight + y;
			if (line<0) line += [dataSource scrollbackLines];
			bg = [dataSource bufferBGColor] + line*width;
			buf = [dataSource bufferLines] + line*width;
		} 
		else {
			line = y - bfHeight;
			bg = [dataSource screenBGColor] + line * width;
			buf = [dataSource screenLines] + line*width;
		}
		for(x=0; x <width; x++) 
		{
			if (bg[x] & SELECTION_MASK) {
				if (buf[x] != 0xffff) 
				{
					temp[last] = buf[x]; 
					if(buf[x] == 0)
					{
						// if there is no text after this, insert a hard line break
						endOfLine = YES;
						for(i = x+1; i < width; i++)
						{
							if(buf[i] != 0)
								endOfLine = NO;
						}
						if(endOfLine)
						{
							temp[last] = '\n'; // hard break
							last++;
							break; // continue to next line
						}
						else
							temp[last] = ' '; // represent blank with space
					}
					last++;
				}
			}
			else if (last) {
				keep_going = NO;
				break;
			}
		}		
	}
	
	if (!last) {
		startX = -1;
		str = nil;
	}
	else
	{
		// strip trailing carriage return if there is one unless we selected the whole line
		if(temp[last-1] == '\n' && endX != ([dataSource width] - 1))
		{
			temp[last-1] = 0;
			last--;
		}
		str = [NSString stringWithCharacters:temp length:last];
	}
	
	free(temp);
	
	return str;
}

- (NSString *) content
{
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView copy:%@]", __FILE__, __LINE__, sender );
#endif
    	
	return [self contentFromX:0 Y:0 ToX:[dataSource width]-1 Y:[dataSource numberOfLines]-1];
}

- (void) copy: (id) sender
{
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSString *copyString;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView copy:%@]", __FILE__, __LINE__, sender );
#endif
    
    copyString=[self selectedText];
    
    if (copyString && [copyString length]>0) {
        [pboard declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: self];
        [pboard setString: copyString forType: NSStringPboardType];
    }
}

- (void)paste:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView paste:%@]", __FILE__, __LINE__, sender );
#endif
    
    if ([_delegate respondsToSelector:@selector(paste:)])
        [_delegate paste:sender];
}

- (void) pasteSelection: (id) sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: %@]", __PRETTY_FUNCTION__, sender );
#endif
    
    if (startX >= 0 && [_delegate respondsToSelector:@selector(pasteString:)])
        [_delegate pasteString:[self selectedText]];
	
}


- (BOOL)validateMenuItem:(NSMenuItem *)item
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView validateMenuItem:%@; supermenu = %@]", __FILE__, __LINE__, item, [[item menu] supermenu] );
#endif
    
    if ([item action] == @selector(paste:))
    {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        
        // Check if there is a string type on the pasteboard
        return ([pboard stringForType:NSStringPboardType] != nil);
    }
    else if ([item action ] == @selector(cut:))
        return NO;
    else if ([item action]==@selector(saveDocumentAs:) ||
			 [item action] == @selector(selectAll:) || 
			 [item action] == @selector(print:))
    {
        // We always validate the above commands
        return (YES);
    }
    else if ([item action]==@selector(mail:) ||
             [item action]==@selector(browse:) ||
             [item action]==@selector(copy:) ||
			 [item action]==@selector(pasteSelection:))
    {
        //        NSLog(@"selected range:%d",[self selectedRange].length);
        return (startX>=0);
    }
    else
        return NO;
}

- (void)changeFont:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView changeFont:%@]", __FILE__, __LINE__, sender );
#endif
    
    [super changeFont:sender];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    NSMenu *cMenu;
    
    // Allocate a menu
    cMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    
    // Menu items for acting on text selections
    [cMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"-> Browser",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu")
                     action:@selector(browse:) keyEquivalent:@""];
    [cMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"-> Mail",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu")
                     action:@selector(mail:) keyEquivalent:@""];
    
    // Separator
    [cMenu addItem:[NSMenuItem separatorItem]];
    
    // Copy,  paste, and save
    [cMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Copy",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu")
                     action:@selector(copy:) keyEquivalent:@""];
    [cMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Paste",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu")
                     action:@selector(paste:) keyEquivalent:@""];
    [cMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Save",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu")
                     action:@selector(saveDocumentAs:) keyEquivalent:@""];
    
    // Separator
    [cMenu addItem:[NSMenuItem separatorItem]];
    
    // Select all
    [cMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Select All",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu")
                     action:@selector(selectAll:) keyEquivalent:@""];
    
    
    // Ask the delegae if there is anything to be added
    if ([[self delegate] respondsToSelector:@selector(menuForEvent: menu:)])
        [[self delegate] menuForEvent:theEvent menu: cMenu];
    
    return [cMenu autorelease];
}

- (void) mail:(id)sender
{
	[self _openURL: [self selectedText]];
}

- (void) browse:(id)sender
{
	[self _openURL: [self selectedText]];
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
        return [self _checkForSupportedDragTypes: sender];
    
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
    if ( bResult != YES && [self _checkForSupportedDragTypes: sender] != NSDragOperationNone )
        bResult = YES;
    
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
                }
                    
                    // Check for file names
                    propertyList = [pb propertyListForType: NSFilenamesPboardType];
                for(i = 0; i < [propertyList count]; i++)
                {
                    
                    // Ignore text clippings
                    NSString *filename = (NSString*)[propertyList objectAtIndex: i]; // this contains the POSIX path to a file
                    NSDictionary *filenamesAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
                    if (([filenamesAttributes fileHFSTypeCode] == 'clpt' &&
                         [filenamesAttributes fileHFSCreatorCode] == 'MACS') ||
                        [[filename pathExtension] isEqualToString:@"textClipping"] == YES)
                    {
                        continue;
                    }
                    
                    // Just paste the file names into the shell after escaping special characters.
                    if ([delegate respondsToSelector:@selector(pasteString:)])
                    {
                        NSMutableString *aMutableString;
                        
                        aMutableString = [[NSMutableString alloc] initWithString: (NSString*)[propertyList objectAtIndex: i]];
                        // get rid of special characters
                        [aMutableString replaceOccurrencesOfString: @"\\" withString: @"\\\\" options: 0 range: NSMakeRange(0, [aMutableString length])];
                        [aMutableString replaceOccurrencesOfString: @" " withString: @"\\ " options: 0 range: NSMakeRange(0, [aMutableString length])];
                        [aMutableString replaceOccurrencesOfString: @"(" withString: @"\\(" options: 0 range: NSMakeRange(0, [aMutableString length])];
                        [aMutableString replaceOccurrencesOfString: @")" withString: @"\\)" options: 0 range: NSMakeRange(0, [aMutableString length])];
                        [aMutableString replaceOccurrencesOfString: @"\"" withString: @"\\\"" options: 0 range: NSMakeRange(0, [aMutableString length])];
    [aMutableString replaceOccurrencesOfString: @"&" withString: @"\\&" options: 0 range: NSMakeRange(0, [aMutableString length])];
    [aMutableString replaceOccurrencesOfString: @"'" withString: @"\\'" options: 0 range: NSMakeRange(0, [aMutableString length])];

    [delegate pasteString: aMutableString];
    [delegate pasteString: @" "];
    [aMutableString release];
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
        [super concludeDragOperation: sender];
    
    bExtendedDragNDrop = NO;
}

- (void)resetCursorRects
{
    static NSCursor *cursor=nil;
	//    NSLog(@"Setting mouse here");
    if (!cursor) cursor=[[NSCursor alloc] initWithImage:[[NSCursor arrowCursor] image] hotSpot:NSMakePoint(0,0)];
    [self addCursorRect:[self bounds] cursor:cursor];
    [cursor setOnMouseEntered:YES];
}

// Save method
- (void) saveDocumentAs: (id) sender
{
	
    NSData *aData;
    NSSavePanel *aSavePanel;
    NSString *aString;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView saveDocumentAs:%@]", __FILE__, __LINE__, sender );
#endif
    
    // We get our content of the textview or selection, if any
	aString = [self selectedText];
	if (!aString) aString = [self content];
    aData = [aString
            dataUsingEncoding: NSASCIIStringEncoding
         allowLossyConversion: YES];
    // retain here so that is does not go away...
    [aData retain];
    
    // initialize a save panel
    aSavePanel = [NSSavePanel savePanel];
    [aSavePanel setAccessoryView: nil];
    [aSavePanel setRequiredFileType: @""];
    
    // Run the save panel as a sheet
    [aSavePanel beginSheetForDirectory: @""
                                  file: @"Unknown"
                        modalForWindow: [self window]
                         modalDelegate: self
                        didEndSelector: @selector(_savePanelDidEnd: returnCode: contextInfo:)
                           contextInfo: aData];
}

// Print
- (void) print: (id) sender
{
    NSPrintInfo *aPrintInfo;
	    
    aPrintInfo = [NSPrintInfo sharedPrintInfo];
    [aPrintInfo setHorizontalPagination: NSFitPagination];
    [aPrintInfo setVerticalPagination: NSAutoPagination];
    [aPrintInfo setVerticallyCentered: NO];
	
    // create a temporary view with the contents, change to black on white, and print it
    NSTextView *tempView;
	NSString *aString;
    NSMutableAttributedString *theContents;
	
	// We get our content of the textview or selection, if any
	aString = [self selectedText];
	if (!aString) aString = [self content];

    tempView = [[NSTextView alloc] initWithFrame: [self frame]];
    theContents = [[NSMutableAttributedString alloc] initWithString: aString];
    [theContents addAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor textBackgroundColor], NSBackgroundColorAttributeName,
		[NSColor textColor], NSForegroundColorAttributeName, 
		[NSFont userFixedPitchFontOfSize: 0], NSFontAttributeName, NULL]
						 range: NSMakeRange(0, [theContents length])];
    [[tempView textStorage] setAttributedString: theContents];
    [theContents release];
	
    // now print the temporary view
    [[NSPrintOperation printOperationWithView: tempView  printInfo: aPrintInfo] runOperation];
    [tempView release];    
}

/// NSTextInput stuff
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
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView insertText:%@]",
          __FILE__, __LINE__, aString);
#endif
    IM_INPUT_INSERT = YES;
    
    if ([self hasMarkedText]) {
        IM_INPUT_MARKEDRANGE = NSMakeRange(0, 0);
        [markedText release];
		markedText=nil;
    }
    
    if ([_delegate respondsToSelector:@selector(insertText:)])
        [_delegate insertText:aString];
    else
        [super insertText:aString];
}

- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange
{
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView setMarkedText:%@ selectedRange:(%d,%d)]",
          __FILE__, __LINE__, aString, selRange.location, selRange.length);
#endif
	[markedText release];
    if ([aString isKindOfClass:[NSAttributedString class]]) {
        markedText=[[NSAttributedString alloc] initWithString:[aString string] attributes:[self markedTextAttributes]];
    }
    else {
        markedText=[[NSAttributedString alloc] initWithString:aString attributes:[self markedTextAttributes]];
    }
	IM_INPUT_MARKEDRANGE = NSMakeRange(0,[markedText length]);
    IM_INPUT_SELRANGE = selRange;
	[self setNeedsDisplay: YES];
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
        return NSMakeRange([dataSource cursorX]-1, IM_INPUT_MARKEDRANGE.length);
    }
    else
        return NSMakeRange([dataSource cursorX]-1, 0);
}

- (NSRange)selectedRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView selectedRange]", __FILE__, __LINE__);
#endif
    return NSMakeRange(NSNotFound, 0);
}

- (NSArray *)validAttributesForMarkedText
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView validAttributesForMarkedText]", __FILE__, __LINE__);
#endif
    return [NSArray arrayWithObjects:NSForegroundColorAttributeName,
        NSBackgroundColorAttributeName,
        NSUnderlineStyleAttributeName,
		NSFontAttributeName,
        nil];
}

- (NSAttributedString *)attributedSubstringFromRange:(NSRange)theRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView attributedSubstringFromRange:(%d,%d)]", __FILE__, __LINE__, theRange.location, theRange.length);
#endif
	
    return [markedText attributedSubstringFromRange:NSMakeRange(0,theRange.length)];
}

- (unsigned int)characterIndexForPoint:(NSPoint)thePoint
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView characterIndexForPoint:(%f,%f)]", __FILE__, __LINE__, thePoint.x, thePoint.y);
#endif
    
    return thePoint.x/charWidth;
}

- (long)conversationIdentifier
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView conversationIdentifier]", __FILE__, __LINE__);
#endif
    return [self hash]; //not sure about this
}

- (NSRect)firstRectForCharacterRange:(NSRange)theRange
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView firstRectForCharacterRange:(%d,%d)]", __FILE__, __LINE__, theRange.location, theRange.length);
#endif
    int y=[dataSource cursorY]-1;
    int x=[dataSource cursorX]-1;
    
    NSRect rect=NSMakeRect(x*charWidth+MARGIN,(y+[dataSource numberOfLines] - [dataSource height]+1)*lineHeight,charWidth*theRange.length,lineHeight);
    //NSLog(@"(%f,%f)",rect.origin.x,rect.origin.y);
    rect.origin=[[self window] convertBaseToScreen:[self convertPoint:rect.origin toView:nil]];
    //NSLog(@"(%f,%f)",rect.origin.x,rect.origin.y);
    
    return rect;
}

- (void)frameChanged:(NSNotification*)notification
{
	//NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
	//NSLogRect([self frame]);
    //if([notification object] == [self window] && [[self delegate] respondsToSelector: @selector(textViewResized:)])
    //    [[self delegate] textViewResized: self];
	//[self refresh];
}

- (void) findString: (NSString *) aString forwardDirection: (BOOL) direction ignoringCase: (BOOL) ignoreCase
{
	int j, line, scline;
	int startx, starty, endx, endy;
	int width, y, x1, x2;
	int first_match;
	int start, bound;
	int inc = direction ? 1: -1;
	unichar *buf;
		
	if ([aString length] <= 0)
	{
		NSBeep();
		return;
	}

	width = [dataSource width];
	scline = [dataSource numberOfLines]-[dataSource height];
	if (lastFindX==-1) {		// no previous match, starting from the beginning
		if (direction) {
			startx=0;
			starty=0;
			endx=[dataSource width];
			endy=[dataSource numberOfLines];
		}
		else {
			endx=0;
			endy=-1;
			startx=[dataSource width];
			starty=[dataSource numberOfLines]-1;
		}			
	}
	else if (direction) {		// starting from previous match, forwards search
		startx=lastFindX+1;
		starty=lastFindY;
		endx=[dataSource width];
		endy=[dataSource numberOfLines];
	}
	else {						// backwards search
		endx=0;
		endy=-1;
		startx=lastFindX-1;
		starty=lastFindY;
	}
	
	start = direction ? 0 : [aString length] - 1;
	bound = direction ? [aString length] : -1;
	for (y=starty;y!=endy;y+=inc) {
		if (y<scline) {
			line=[dataSource lastBufferLineIndex]-scline+y;
			if (line<0) line+=[dataSource scrollbackLines];
			buf=[dataSource bufferLines]+line*width;
		} else {
			line=y-scline;
			buf=[dataSource screenLines]+line*width;
		}
		/* by default, we search the whole line */
		if (direction ) { x1=0; x2=width; }
		else { x2=-1; x1=width-1; }
		/* not if when we are in the first/last line */
		if (y==starty) x1=startx;
		if (y==endy) x2=endx + direction ? 0 : -1;
		j=start;
		first_match=-1;
		for(;x1!=x2;x1+=inc) {
			if (buf[x1]!=0xffff) {
				if (buf[x1]==[aString characterAtIndex:j] ||
					(ignoreCase && toupper(buf[x1])==toupper([aString characterAtIndex:j]))) {
					j+=inc;
					if (first_match==-1) { first_match=x1; }
					if (j == bound) break;
				}
				else {
					if (j!=start) {
						j=start;
						x1=first_match;
						first_match=-1;
					}
				}
			}
		}		
		if (j == bound ) { // Found!
			lastFindX=startX=first_match;
			lastFindY=startY=y;
			endX=x1;
			endY=y;
			[self _selectFromX:startX Y:startY toX:endX Y:endY];
			[self setNeedsDisplay:YES];
			[self _scrollToLine:y];
			return;
		}
	}
	NSBeep();
}

// transparency
- (float) transparency
{
	return (transparency);
}

- (void) setTransparency: (float) fVal
{
	transparency = fVal;
}

@end

//
// private methods
//
@implementation PTYTextView (Private)

- (void) _renderChar:(NSImage *)image withChar:(unichar) carac withColor:(NSColor*)color withFont:(NSFont*)aFont bold:(int)bold
{
	NSAttributedString  *crap;
	NSDictionary *attrib;
		
	if (systemVersion >= 0x00001030)
	{
		attrib=[NSDictionary dictionaryWithObjectsAndKeys:
			aFont, NSFontAttributeName,
			color, NSForegroundColorAttributeName,
			[NSNumber numberWithFloat: (float)bold*(-0.1)], NSStrokeWidthAttributeName,
			nil];
	}
	else
	{
		attrib=[NSDictionary dictionaryWithObjectsAndKeys:
			aFont, NSFontAttributeName,
			color, NSForegroundColorAttributeName,
			nil];		
	}
	
	
	crap = [[[NSAttributedString alloc]initWithString:[NSString stringWithCharacters:&carac length:1]
										   attributes:attrib] autorelease];
	[image lockFocus];
	[[NSGraphicsContext currentContext] setShouldAntialias:(antiAlias || bold)];
	[crap drawAtPoint:NSMakePoint(0,0)];
	// on older systems, for bold, redraw the character
	if (bold && systemVersion < 0x00001030)
	{
		[crap drawAtPoint:NSMakePoint(0,0)];
	}
	[image unlockFocus];
} // renderChar

#define  CELLSIZE (CACHESIZE/256)
- (NSImage *) _getCharImage:(unichar) code color:(int)fg doubleWidth:(BOOL) dw
{
	int i;
	int j;
	NSImage *image;
	int width;
	unsigned int c = fg;
	int seed;
	
	if (fg & SELECTED_TEXT) {
		c = SELECTED_TEXT;
	}
	else if (fg & CURSOR_TEXT) {
		c = CURSOR_TEXT;
	}
	else {
		if ([[dataSource terminal] screenMode] && (fg&DEFAULT_FG_COLOR_CODE)) // reversed screen mode?
			c = DEFAULT_FG_COLOR_CODE | DEFAULT_BG_COLOR_CODE;
		c &= (BOLD_MASK|0x1f); // turn of all masks except for bold and default fg color
	}
	if (!code) return nil;
	width = dw?2:1;
	seed = code;
	seed <<= 8;
	srand( seed + c );
	i = rand() % (CACHESIZE-CELLSIZE);
	for(j = 0;(charImages[i].code!=code || charImages[i].color!=c) && charImages[i].image && j<CELLSIZE; i++, j++);
	if (!charImages[i].image) {
		//  NSLog(@"add into cache");
		image=charImages[i].image=[[NSImage alloc]initWithSize:NSMakeSize(charWidth*width, lineHeight)];
		charImages[i].code=code;
		charImages[i].color=c;
		charImages[i].count=1;
		[self _renderChar: image 
				withChar: code
			   withColor: [self colorForCode: c] 
				withFont: ISDOUBLEWIDTHCHARACTER(code)?nafont:font
					bold: c&BOLD_MASK];
		
		return image;
	}
	else if (j>=CELLSIZE) {
		NSLog(@"new char, but cache full (%d, %d, %d)", code, c, i);
		int t=1;
		for(j=2; j<=CELLSIZE; j++) {	//find a least used one, and replace it with new char
			if (charImages[i-j].count < charImages[i-t].count) t = j;
		}
		t = i - t;
		[charImages[t].image release];
		image=charImages[t].image=[[NSImage alloc]initWithSize:NSMakeSize(charWidth*width, lineHeight)];
		charImages[t].code=code;
		charImages[t].color=c;
		for(j=1; j<=CELLSIZE; j++) {	//reset the cache count
			charImages[i-j].count -= charImages[t].count;
		}
		charImages[t].count=1;
		
		[self _renderChar: image 
				withChar: code
			   withColor: [self colorForCode: c] 
				withFont: ISDOUBLEWIDTHCHARACTER(code)?nafont:font
					bold: c & BOLD_MASK];
		return image;
	}
	else {
		//		NSLog(@"already in cache");
		charImages[i].count++;
		return charImages[i].image;
	}
	
}

- (void) _drawCharacter:(unichar)c fgColor:(int)fg AtX:(float)X Y:(float)Y doubleWidth:(BOOL) dw
{
	NSImage *image;
	
	if (c) {
		//NSLog(@"%c(%d)",c,c);
		image=[self _getCharImage:c 
						   color:fg
					 doubleWidth:dw];
		[image compositeToPoint:NSMakePoint(X,Y) operation:NSCompositeSourceOver];
	}
}	

- (void) _scrollToLine:(int)line
{
	NSRect aFrame;
	aFrame.origin.x = 0;
	aFrame.origin.y = line * lineHeight;
	aFrame.size.width = [self frame].size.width;
	aFrame.size.height = lineHeight;
	//forceUpdate = YES;
	[self scrollRectToVisible: aFrame];
}


- (void) _selectFromX:(int)startx Y:(int)starty toX:(int)endx Y:(int)endy
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYTextView _selectFromX:%d Y:%d toX:%d Y:%d]", __FILE__, __LINE__, startx, starty, endx, endy);
#endif

	int line, bfHeight;
	int width, height, x, y, idx, startIdx, endIdx;
	char *bg, newbg;
	char *dirty;
	
	width = [dataSource width];
	height = [dataSource numberOfLines];
	bfHeight = height - [dataSource height];
	if (startX == -1) startIdx = width*height+1;
	else {
		startIdx = startx + starty * width;
		endIdx = endx + endy * width;
		if (startIdx > endIdx) {
			idx = startIdx;
			startIdx = endIdx;
			endIdx = idx;
		}
	}
	
	for (idx=y=0; y<height; y++) {
		if (y < bfHeight) {
			line = [dataSource lastBufferLineIndex] - bfHeight + y;
			if (line<0) line += [dataSource scrollbackLines];
			bg = [dataSource bufferBGColor] + line*width;
			dirty = NULL;
		} 
		else {
			line = y - bfHeight;
			bg = [dataSource screenBGColor] + line * width;
			dirty = [dataSource dirty] + line * width;
		}
		for(x=0; x <width; x++, idx++) 
		{
			if (idx>=startIdx && idx<=endIdx) newbg = bg[x] | SELECTION_MASK;
			else newbg = bg[x] & ~SELECTION_MASK;
			if (newbg != bg[x]) {
				bg[x] = newbg;
				if (dirty) dirty[x] = 1;
			}
		}		
	}
}

- (NSString *) _getWordForX: (int) x 
					y: (int) y 
			   startX: (int *) startx 
			   startY: (int *) starty 
				 endX: (int *) endx 
				 endY: (int *) endy
{
	NSString *aString,*wordChars;
	int tmpX, tmpY, x1, y1, x2, y2;

	// grab our preference for extra characters to be included in a word
	wordChars = [[PreferencePanel sharedInstance] wordChars];
	if(wordChars == nil)
		wordChars = @"";		
	// find the beginning of the word
	tmpX = x;
	tmpY = y;
	while(tmpX >= 0)
	{
		aString = [self contentFromX:tmpX Y:tmpY ToX:tmpX Y:tmpY];
		if(([aString length] == 0 || 
			[aString rangeOfCharacterFromSet: [NSCharacterSet alphanumericCharacterSet]].length == 0) &&
		   [wordChars rangeOfString: aString].length == 0)
			break;
		tmpX--;
		if(tmpX < 0 && tmpY > 0)
		{
			tmpY--;
			tmpX = [dataSource width] - 1;
		}
	}
	if(tmpX != x)
		tmpX++;
	
	if(tmpX < 0)
		tmpX = 0;
	if(tmpY < 0)
		tmpY = 0;
	if(tmpX >= [dataSource width])
	{
		tmpX = 0;
		tmpY++;
	}
	if(tmpY >= [dataSource numberOfLines])
		tmpY = [dataSource numberOfLines] - 1;	
	if(startx)
		*startx = tmpX;
	if(starty)
		*starty = tmpY;
	x1 = tmpX;
	y1 = tmpY;
	
	
	// find the end of the word
	tmpX = x;
	tmpY = y;
	while(tmpX < [dataSource width])
	{
		aString = [self contentFromX:tmpX Y:tmpY ToX:tmpX Y:tmpY];
		if(([aString length] == 0 || 
			[aString rangeOfCharacterFromSet: [NSCharacterSet alphanumericCharacterSet]].length == 0) &&
		   [wordChars rangeOfString: aString].length == 0)
			break;
		tmpX++;
		if(tmpX >= [dataSource width] && tmpY < [dataSource numberOfLines])
		{
			tmpY++;
			tmpX = 0;
		}
	}
	if(tmpX != x)
		tmpX--;
	
	if(tmpX < 0)
	{
		tmpX = [dataSource width] - 1;
		tmpY--;
	}
	if(tmpY < 0)
		tmpY = 0;		
	if(tmpX >= [dataSource width])
		tmpX = [dataSource width] - 1;
	if(tmpY >= [dataSource numberOfLines])
		tmpY = [dataSource numberOfLines] - 1;
	if(endx)
		*endx = tmpX;
	if(endy)
		*endy = tmpY;
	
	x2 = tmpX;
	y2 = tmpY;

	return ([self contentFromX:x1 Y:y1 ToX:x2 Y:y2]);
	
}

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
        iResult = NSDragOperationCopy;
    
    return iResult;
}

- (void) _savePanelDidEnd: (NSSavePanel *) theSavePanel
               returnCode: (int) theReturnCode
              contextInfo: (void *) theContextInfo
{
    // If successful, save file under designated name
    if (theReturnCode == NSOKButton)
    {
        if ( ![(NSData *)theContextInfo writeToFile: [theSavePanel filename] atomically: YES] )
            NSBeep();
    }
    // release our hold on the data
    [(NSData *)theContextInfo release];
}

- (BOOL) _isBlankLine: (int) y
{
	NSString *lineContents, *blankLine;
	char blankString[1024];	
	
	
	lineContents = [self contentFromX: 0 Y: y ToX: [dataSource width] - 1 Y: y];
	memset(blankString, ' ', 1024);
	blankString[[dataSource width]] = 0;
	blankLine = [NSString stringWithUTF8String: (const char*)blankString];
	
	return ([lineContents isEqualToString: blankLine]);
	
}

- (void) _openURL: (NSString *) aURLString
{
    NSURL *url;
	
	if([aURLString length] <= 0)
		return;
	    
    // Check for common types of URLs
    if ([aURLString hasPrefix:@"file://"])
        url = [NSURL URLWithString:aURLString];
    else if ([aURLString hasPrefix:@"ftp"])
    {
        if (![aURLString hasPrefix:@"ftp://"])
            url = [NSURL URLWithString:[@"ftp://" stringByAppendingString:aURLString]];
        else
            url = [NSURL URLWithString:aURLString];
    }
	else if ([aURLString hasPrefix:@"mailto:"])
        url = [NSURL URLWithString:aURLString];
	else if([aURLString rangeOfString: @"@"].location != NSNotFound)
		url = [NSURL URLWithString:[@"mailto:" stringByAppendingString:aURLString]];
	else if ([aURLString hasPrefix:@"https://"])
        url = [NSURL URLWithString:aURLString];
    else if (![aURLString hasPrefix:@"http"])
        url = [NSURL URLWithString:[@"http://" stringByAppendingString:aURLString]];
    else
        url = [NSURL URLWithString:aURLString];
    
    [[NSWorkspace sharedWorkspace] openURL:url];
	
}

- (void) _clearCacheForColor:(int)colorIndex
{
	int i;

	for ( i = 0 ; i < CACHESIZE; i++) {
		if (charImages[i].color == colorIndex) {
			[charImages[i].image release];
			charImages[i].image = nil;
		}
	}
}

@end
