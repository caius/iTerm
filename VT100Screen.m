// -*- mode:objc -*-
// $Id: VT100Screen.m,v 1.171 2004-01-21 21:51:17 ujwal Exp $
//
/*
 **  VT100Screen.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the VT100 screen.
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

#import <iTerm/iTerm.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/VT100Typesetter.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYTextView.h>
#import <iTerm/PTYScrollView.h>
#import <iTerm/charmaps.h>
#import <iTerm/PTYSession.h>
#import <iTerm/PTYTask.h>
#import <iTerm/PreferencePanel.h>

@implementation VT100Screen

#define DEFAULT_WIDTH     80
#define DEFAULT_HEIGHT    25
#define DEFAULT_FONTSIZE  14
#define DEFAULT_SCROLLBACK 1000

#define MIN_WIDTH     10
#define MIN_HEIGHT    3

#define TABSIZE     8

#define WIDTH_REAL   (WIDTH + 1)

//#define ISDOUBLEWIDTHCHARACTER(c) ((c)>=0x1000)
#define ISDOUBLEWIDTHCHARACTER(idx) ([SESSION doubleWidth]&&[[BUFFER attribute:NSCharWidthAttributeName atIndex:(idx) effectiveRange:nil] intValue]==2)

#define ISDOUBLEWIDTHCHARACTERINLINE(idx, line) ([SESSION doubleWidth]&&[[line attribute:NSCharWidthAttributeName atIndex:(idx) effectiveRange:nil] intValue]==2)

#if USE_CUSTOM_DRAWING
#else
static NSString *NSBlinkAttributeName=@"NSBlinkAttributeName";
static NSString *NSBlinkForegroundColorAttributeName=@"NSBlinkForegroundColorAttributeName";
static NSString *NSBlinkBackgroundColorAttributeName=@"NSBlinkBackgroundColorAttributeName";
#endif

static NSString *NSCharWidthAttributeName=@"NSCharWidthAttributeName";

static unichar spaces[300]={0};

static BOOL PLAYBELL = YES;

+ (NSSize) fontSize:(NSFont *)font
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen fontSize:%@]",
          __FILE__, __LINE__, font);
#endif
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSSize sz;
    [dic setObject:font forKey:NSFontAttributeName];
    sz = [@"A" sizeWithAttributes:dic];

//    NSLog(@"%@\n\tdefaultLineHeight:%f\n\tHieght of 'A':%f\n\txHeight:%f\n\tcapHeight:%f\n\tunderlinePosition:%f\n\tascender:%f\n\tdescender:%f",font,[font defaultLineHeightForFont],sz.height,[font xHeight],[font capHeight],[font underlinePosition], [font ascender], [font descender]);
#if DEBUG_USE_BUFFER
    return NSMakeSize(sz.width,[font defaultLineHeightForFont]);
#else
//    return NSMakeSize(sz.width, sz.height);
    return NSMakeSize(sz.width,[font defaultLineHeightForFont]-1);
#endif
}

+ (NSSize)requireSizeWithFont:(NSFont *)font
			width:(int)width
		       height:(int)height
{
    NSSize sz;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen requireSizeWithFont:%@ width:%d height:%d]",
	  __FILE__, __LINE__, font, width, height);
#endif    
    sz = [VT100Screen fontSize:font];
//    NSLog(@"--------fontsize:%f,%f, %f,%f",sz.width,sz.height);
#if USE_CUSTOM_LAYOUT
    return NSMakeSize((sz.width * width) + 2*[VT100Typesetter lineFragmentPadding], (float) height * sz.height);
#else
    return NSMakeSize(sz.width * (width +2), (float) height * sz.height);
#endif
}

+ (NSSize)requireSizeWithFont:(NSFont *)font
{
    NSSize sz;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen requireSizeWithFont:%@]",
	  __FILE__, __LINE__, font);
#endif
    sz = [VT100Screen fontSize:font];

    return sz;
}

+ (NSSize)screenSizeInFrame:(NSRect)frame
		       font:(NSFont *)font
{
    NSSize sz;
    int w, h;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen screenSizeInFrame:(%f,%f,%f,%f) font:%@]",
	  __FILE__, __LINE__, 
	  frame.origin.x, frame.origin.y,
	  frame.size.width, frame.size.height,
	  font);
#endif
    sz = [VT100Screen fontSize:font];
#if USE_CUSTOM_LAYOUT
    w = (int)(frame.size.width  - 2*[VT100Typesetter lineFragmentPadding])/sz.width;
#else
    w = (int)(frame.size.width / sz.width + 0.5) - 2;
#endif
    h = (int)(frame.size.height / sz.height) ;
    //NSLog(@"w = %d; h = %d", w, h);

    return NSMakeSize(w, h);
}

+ (void)setPlayBellFlag:(BOOL)flag
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[VT100Screen setPlayBellFlag:%s]",
	  __FILE__, __LINE__, flag == YES ? "YES" : "NO");
#endif
    PLAYBELL = flag;
}

- (id)init
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[VT100Screen init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
	return nil;

    WIDTH = DEFAULT_WIDTH;
    HEIGHT = DEFAULT_HEIGHT;

    CURSOR_X = CURSOR_Y = 0;
    SAVE_CURSOR_X = SAVE_CURSOR_Y = 0;
    SCROLL_TOP = 0;
    SCROLL_BOTTOM = HEIGHT - 1;

    STORAGE = nil;
    FONT = [[NSFont userFixedPitchFontOfSize:0] retain];
    TERMINAL = nil;
    SHELL = nil;

    TOP_LINE  = 0;
    scrollbackLines = DEFAULT_SCROLLBACK;
    OLD_CURSOR_INDEX=-1;
    [self clearTabStop];
    
    // set initial tabs
    int i;
    for(i = TABSIZE; i < TABWINDOW; i += TABSIZE)
        tabStop[i] = YES;

    for(i=0;i<300;i++) spaces[i]=' ';
    for(i=0;i<4;i++) saveCharset[i]=charset[i]=0;

    BUFFER=[[NSMutableAttributedString alloc] init];
    screenLines = [[NSMutableArray alloc] init];
    newLineString=nil;

    updateIndex=minIndex=0;
    screenLock= [[NSLock alloc] init];
    screenIsLocked = NO;
    
    return self;
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[VT100Screen dealloc]", __FILE__, __LINE__);
#endif

    if([self screenIsLocked])
	[self removeScreenLock];
    [screenLock release];
    screenLock = nil;
    
    [FONT release];
    [NAFONT release];

    [display release];
    [BUFFER release];
    [savedBuffer release];

    [screenLines autorelease];

    [STORAGE release];
    [SHELL release];
    [TERMINAL release];
    [SESSION release];
    [newLineString release];
    
    [super dealloc];
}

- (NSString *)description
{
    NSString *basestr;
    NSString *colstr;
    NSString *result;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen description]", __FILE__, __LINE__);
#endif
    basestr = [NSString stringWithFormat:@"WIDTH %d, HEIGHT %d, CURSOR (%d,%d)",
		   WIDTH, HEIGHT, CURSOR_X, CURSOR_Y];
    colstr = [STORAGE string];
    result = [NSString stringWithFormat:@"%@\n%@", basestr, colstr];

    return result;
}

- (void)setWidth:(int)width height:(int)height
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen resizeWidth:%d height:%d]",
          __FILE__, __LINE__, width, height);
#endif

    if (width >= MIN_WIDTH && height >= MIN_HEIGHT) {

        WIDTH = width;
        HEIGHT = height;


        CURSOR_X = CURSOR_Y = 0;
        SAVE_CURSOR_X = SAVE_CURSOR_Y = 0;
        SCROLL_TOP = 0;
        SCROLL_BOTTOM = HEIGHT - 1;

    }
}

- (void)resizeWidth:(int)width height:(int)height
{
    int i;

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
#endif
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen resizeWidth:%d height:%d]",
	  __FILE__, __LINE__, width, height);
#endif

    if (width >= MIN_WIDTH && height >= MIN_HEIGHT) {
        if (height>=HEIGHT) {
            [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];
            for(i=HEIGHT;i<height;i++){

#if DEBUG_USE_BUFFER
                [BUFFER appendAttributedString:newLineString];
#endif

#if DEBUG_USE_ARRAY
		aLine = [[NSMutableAttributedString alloc] init];
		[screenLines addObject: aLine];
		[aLine release];
#endif
	    }
        }
        else {
            TOP_LINE+=HEIGHT-height;
            // NSLog(@"topline += %d-->%d",HEIGHT-height,TOP_LINE);
            CURSOR_Y-=HEIGHT-height;
            if (CURSOR_Y<0) CURSOR_Y=0;
            SAVE_CURSOR_Y-=HEIGHT-height;
            if (SAVE_CURSOR_Y<0) SAVE_CURSOR_Y=0;
        }
        
        if (width>=WIDTH) {
            HEIGHT=height;
	    WIDTH=width;
            SCROLL_TOP = 0;
            SCROLL_BOTTOM = HEIGHT - 1;
        }
        else {
            WIDTH = width;
            HEIGHT = height;
            for(i=0;i<height;i++) [self trimLine:i];
            if (CURSOR_X>=width) CURSOR_X=width-1;
            if (SAVE_CURSOR_X>=width) SAVE_CURSOR_X=width-1;
            SCROLL_TOP = 0;
            SCROLL_BOTTOM = HEIGHT - 1;
        }
    }
    //[[SESSION TEXTVIEW] scrollEnd];
    
}

- (int)width
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen width]", __FILE__, __LINE__);
#endif
    return WIDTH;
}

- (int)height
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen height]", __FILE__, __LINE__);
#endif
    return HEIGHT;
}

- (unsigned int)scrollbackLines
{
    return scrollbackLines;
}

- (void)setScrollback:(unsigned int)lines;
{
//    NSLog(@"Scrollback set: %d", lines);
    scrollbackLines=lines;
}

- (PTYSession *) session
{
    return (SESSION);
}

- (void)setSession:(PTYSession *)session
{
    [SESSION release];
    [session retain];
    SESSION=session;
}

- (void)setTerminal:(VT100Terminal *)terminal
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTerminal:%@]",
	  __FILE__, __LINE__, terminal);
#endif
    [TERMINAL release];
    [terminal retain];
    TERMINAL = terminal;
    
}

- (VT100Terminal *)terminal
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen terminal]", __FILE__, __LINE__);
#endif
    return TERMINAL;
}

- (void)setShellTask:(PTYTask *)shell
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setShellTask:%@]",
	  __FILE__, __LINE__, shell);
#endif
    [SHELL release];
    [shell retain];
    SHELL = shell;
}

- (PTYTask *)shellTask
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen shellTask]", __FILE__, __LINE__);
#endif
    return SHELL;
}

- (void)setTextStorage:(NSTextStorage *)storage
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTextStorage:%@]",
	  __FILE__, __LINE__, storage);
#endif
    if(STORAGE != nil)
    {
	[STORAGE release];
	STORAGE = nil;
    }
    if(storage != nil){
	[storage retain];
	STORAGE = storage;
    }
}

- (NSTextStorage *)textStorage
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen textStorage]", __FILE__, __LINE__ );
#endif
    return STORAGE;
}

- (NSView *) display
{
    return (display);
}

- (void) setDisplay: (NSView *) aDisplay
{
    [display release];
    if(aDisplay != nil)
    {
	[aDisplay retain];
	display = aDisplay;
    }
}

- (BOOL) blinkingCursor
{
    return (blinkingCursor);
}

- (void) setBlinkingCursor: (BOOL) flag
{
    blinkingCursor = flag;
}

-(void) initScreen
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen initScreen]", __FILE__, __LINE__ );
#endif

    int i;
#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
#endif

#if DEBUG_USE_BUFFER
    if([BUFFER length] > 0)
    {
	[BUFFER deleteCharactersInRange: NSMakeRange(0, [BUFFER length])];
    }
#endif

    [TERMINAL initDefaultCharacterAttributeDictionary];
    //STORAGE = [[NSTextStorage alloc] init];

    for(i=0;i<HEIGHT-1;i++) {
#if DEBUG_USE_BUFFER
        //[STORAGE appendAttributedString:[self defaultAttrString:@"\n"]];
        [BUFFER appendAttributedString:[self defaultAttrString:@"\n"]];
#endif

#if DEBUG_USE_ARRAY
        aLine = [[NSMutableAttributedString alloc] init];
	[screenLines addObject: aLine];
	[aLine release];
#endif
    }
    
#if DEBUG_USE_ARRAY
    aLine = [[NSMutableAttributedString alloc] init];
    [screenLines addObject: aLine];
    [aLine release];
#endif
    [newLineString release];
    newLineString = [[self attrString:@"\n" ascii:YES] retain];
    blinkShow=YES;
}
    
- (void)setFont:(NSFont *)font nafont:(NSFont *)nafont
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setFont:%@]", __FILE__, __LINE__, font );
#endif
	int index, length;
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	
	
#if DEBUG_USE_BUFFER
	// try to retain some font attributes
	length = [BUFFER length];
	for (index = 0; index < length;)
	{
		NSRange coverageRange;
		NSFont *oldFont = [BUFFER attribute: NSFontAttributeName atIndex: index effectiveRange: &coverageRange];
		NSFont *newFont;
				
		index = index + coverageRange.length;
		
		newFont = font;
		
		// check if we encountered bold fonts
		if([fontManager fontNamed: [oldFont fontName] hasTraits: NSBoldFontMask] == YES)
		{
			NSFont *aFont;
			
			// use the appropriate new font
			if(oldFont == NAFONT)
				aFont = nafont;
			else
				aFont = font;
			
			newFont = [fontManager convertFont: aFont toHaveTrait: NSBoldFontMask];
			if([newFont isFixedPitch] == NO)
			{
				newFont = aFont;
			}
			
		}
		
		// check if we encountered graphical characters, for which we use FreeMonoBold
		if([[oldFont fontName] isEqualToString: @"FreeMonoBold"] == YES)
		{
			newFont = [NSFont fontWithName: @"FreeMonoBold" size: [font pointSize]];
			if(newFont == nil)
				newFont = oldFont;
		}
		
		[BUFFER removeAttribute: NSFontAttributeName range: coverageRange];
		[BUFFER addAttribute:NSFontAttributeName
					   value:newFont
					   range:coverageRange];			
		
		
	}	    
	
#endif
	
    [FONT release];
    [font retain];
    FONT = font;
    [NAFONT release];
    [nafont retain];
    NAFONT = nafont;
    FONT_SIZE = [VT100Screen fontSize:FONT];
	
    [TERMINAL initDefaultCharacterAttributeDictionary];


}

- (NSFont *)font
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen font]",__FILE__, __LINE__);
#endif
    return FONT;
}

- (NSFont *)nafont
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen font]",__FILE__, __LINE__);
#endif
    return NAFONT;
}

- (NSFont *) tallerFont
{
#if DEBUG_USE_ARRAY
    float a=[VT100Screen fontSize:FONT].height;
    float b=[VT100Screen fontSize:NAFONT].height;

    return (a>b)?FONT:NAFONT;
#else
    return FONT;
#endif
}

- (NSSize) characterSize
{
    return [VT100Screen requireSizeWithFont: [self tallerFont]];
}

- (void)putToken:(VT100TCC)token
{
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen putToken:%d]",__FILE__, __LINE__, token);
#endif
    static unichar s[300]={0};
    int i;
    NSString *str;
#if USE_CUSTOM_DRAWING
    NSMutableAttributedString *aLine;
#endif

    // If we are in print mode, send to printer.
    if([TERMINAL printToAnsi] == YES && token.type != ANSICSI_PRINT)
    {
	[TERMINAL printToken: token];
	return;
    }
    
    switch (token.type) {
    // our special code
    case VT100_STRING:
        if ([SESSION doubleWidth]) [self setDoubleWidthString:token.u.string];
        else [self setASCIIString:token.u.string];
	break;
    case VT100_ASCIISTRING:
        [self setASCIIString:token.u.string];
        break;
    case VT100_UNKNOWNCHAR: break;
    case VT100_NOTSUPPORT: break;

    //  VT100 CC
    case VT100CC_ENQ: break;
    case VT100CC_BEL: [self playBell]; break;
    case VT100CC_BS:  [self backSpace]; break;
    case VT100CC_HT:  [self setTab]; break;
    case VT100CC_LF:
    case VT100CC_VT:
    case VT100CC_FF:
#if USE_CUSTOM_DRAWING
        aLine=[screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
        if ([aLine length]<=0||[[aLine string] characterAtIndex:[aLine length]-1]!='\n') {
            [aLine appendAttributedString:[self attrString:@"\n"  ascii:YES]];
        }
#endif
        [self setNewLine]; break;
    case VT100CC_CR:  CURSOR_X = 0; break;
    case VT100CC_SO:  break;
    case VT100CC_SI:  break;
    case VT100CC_DC1: break;
    case VT100CC_DC3: break;
    case VT100CC_CAN:
    case VT100CC_SUB: break;
    case VT100CC_DEL: [self deleteCharacters:1];break;

    // VT100 CSI
    case VT100CSI_CPR: break;
    case VT100CSI_CUB: [self cursorLeft:token.u.csi.p[0]]; break;
    case VT100CSI_CUD: [self cursorDown:token.u.csi.p[0]]; break;
    case VT100CSI_CUF: [self cursorRight:token.u.csi.p[0]]; break;
    case VT100CSI_CUP: [self cursorToX:token.u.csi.p[1]
                                     Y:token.u.csi.p[0]];
        break;
    case VT100CSI_CUU: [self cursorUp:token.u.csi.p[0]]; break;
    case VT100CSI_DA:   [self deviceAttribute:token]; break;
    case VT100CSI_DECALN:
        if (!s[0]) {
            for (i=0;i<300;i++) s[i]='E';
        }
        str=[NSString stringWithCharacters:s length:WIDTH];
        for(i=0;i<HEIGHT;i++)
            [self setASCIIStringToX:0 Y:i string:str];
        break;
    case VT100CSI_DECDHL: break;
    case VT100CSI_DECDWL: break;
    case VT100CSI_DECID: break;
    case VT100CSI_DECKPAM: break;
    case VT100CSI_DECKPNM: break;
    case VT100CSI_DECLL: break;
    case VT100CSI_DECRC: [self restoreCursorPosition]; break;
    case VT100CSI_DECREPTPARM: break;
    case VT100CSI_DECREQTPARM: break;
    case VT100CSI_DECSC: [self saveCursorPosition]; break;
    case VT100CSI_DECSTBM: [self setTopBottom:token]; break;
    case VT100CSI_DECSWL: break;
    case VT100CSI_DECTST: break;
    case VT100CSI_DSR:  [self deviceReport:token]; break;
    case VT100CSI_ED:   [self eraseInDisplay:token]; break;
    case VT100CSI_EL:   [self eraseInLine:token]; break;
    case VT100CSI_HTS: tabStop[CURSOR_X]=YES; break;
    case VT100CSI_HVP: [self cursorToX:token.u.csi.p[1]
                                     Y:token.u.csi.p[0]];
        break;
    case VT100CSI_NEL:
        CURSOR_X=0;
    case VT100CSI_IND:
	if(CURSOR_Y == SCROLL_BOTTOM)
	{
	    [self scrollUp];
	}
	else
	{
	    CURSOR_Y++;
	    if (CURSOR_Y>=HEIGHT) {
		CURSOR_Y=HEIGHT-1;
	    }
	}
        break;
    case VT100CSI_RI:
	if(CURSOR_Y == SCROLL_TOP)
	{
	    [self scrollDown];
	}
	else
	{
	    CURSOR_Y--;
	    if (CURSOR_Y<0) {
		CURSOR_Y=0;
	    }	    
	}
	break;
    case VT100CSI_RIS: break;
    case VT100CSI_RM: break;
    case VT100CSI_SCS0: charset[0]=(token.u.code=='0'); break;
    case VT100CSI_SCS1: charset[1]=(token.u.code=='0'); break;
    case VT100CSI_SCS2: charset[2]=(token.u.code=='0'); break;
    case VT100CSI_SCS3: charset[3]=(token.u.code=='0'); break;
    case VT100CSI_SGR:  [self selectGraphicRendition:token]; break;
    case VT100CSI_SM: break;
    case VT100CSI_TBC:
        switch (token.u.csi.p[0]) {
            case 3: [self clearTabStop]; break;
            case 0: tabStop[CURSOR_X]=NO;
        }
        break;

    case VT100CSI_DECSET:
    case VT100CSI_DECRST:
        if (token.u.csi.p[0]==3 && [TERMINAL allowColumnMode] == YES) {	// set the column
//            [STORAGE endEditing];
            [[SESSION parent] resizeWindow:([TERMINAL columnMode]?132:80)
                                    height:HEIGHT];
            [[SESSION TEXTVIEW] scrollEnd];
//            [STORAGE beginEditing];
        }
        break;

    // ANSI CSI
    case ANSICSI_CHA:
        [self cursorToX: token.u.csi.p[0]];
	break;
    case ANSICSI_VPA:
        [self cursorToX: CURSOR_X Y: token.u.csi.p[0]];
        break;
    case ANSICSI_VPR:
        [self cursorToX: CURSOR_X Y: token.u.csi.p[0]+CURSOR_Y];
        break;
    case ANSICSI_ECH:
        i=CURSOR_X;
        [self setASCIIString:[NSString stringWithCharacters:spaces length:token.u.csi.p[0]<=WIDTH?token.u.csi.p[0]:WIDTH]];
        CURSOR_X=i;
        break;
        
    case STRICT_ANSI_MODE:
	[TERMINAL setStrictAnsiMode: ![TERMINAL strictAnsiMode]];
	break;

    case ANSICSI_PRINT:
	if(token.u.csi.p[0] == 4)
	    [TERMINAL setPrintToAnsi: NO];
	else if (token.u.csi.p[0] == 5)
	    [TERMINAL setPrintToAnsi: YES];
	break;
	
    // XTERM extensions
    case XTERMCC_WIN_TITLE:
    case XTERMCC_WINICON_TITLE:
    case XTERMCC_ICON_TITLE:
        //[SESSION setName:token.u.string];
        if (token.type==XTERMCC_WIN_TITLE||token.type==XTERMCC_WINICON_TITLE) 
        {
	    //NSLog(@"setting window title to %@", token.u.string);
	    [SESSION setWindowTitle: token.u.string];
        }
        if (token.type==XTERMCC_ICON_TITLE||token.type==XTERMCC_WINICON_TITLE)
	{
	    //NSLog(@"setting session title to %@", token.u.string);
	    [SESSION setName:token.u.string];
	}
        break;
    case XTERMCC_INSBLNK: [self insertBlank:token.u.csi.p[0]]; break;
    case XTERMCC_INSLN: [self insertLines:token.u.csi.p[0]]; break;
    case XTERMCC_DELCH: [self deleteCharacters:token.u.csi.p[0]]; break;
    case XTERMCC_DELLN: [self deleteLines:token.u.csi.p[0]]; break;
        

    default:
	NSLog(@"%s(%d): bug?? token.type = %d", 
	      __FILE__, __LINE__, token.type);
	break;
    }
//    NSLog(@"Done");
    
}

- (void)clearBuffer
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen clearBuffer]",  __FILE__, __LINE__ );
#endif
    NSMutableAttributedString *aLine;
    int idx, idx2;
    int cursor_x = CURSOR_X;

    [self setScreenLock];

    NS_DURING
	idx = [self getIndexAtX: 0 Y: CURSOR_Y withPadding: YES];
	if(CURSOR_Y == HEIGHT - 1)
	    idx2 = [BUFFER length] - 1;
	else
	    idx2 = [self getIndexAtX: 0 Y: CURSOR_Y+1 withPadding: YES];
	if(idx2 > idx)
	{
	    aLine = [[NSMutableAttributedString alloc] initWithAttributedString: [BUFFER attributedSubstringFromRange: NSMakeRange(idx, idx2-idx)]];
	}
	else
	{
	    aLine = nil;
	    NSLog(@"VT100Screen: clearBuffer: could not get last line!; idx = %d; idx2 = %d; CURSOR_Y = %d", idx, idx2, CURSOR_Y);
	}

	// append a new line if we are at the end of the buffer
	if(idx2 == [BUFFER length] - 1)
	{
            [aLine appendAttributedString:[self attrString:@"\n"  ascii:YES]];
	}

	// clear everything
    #if DEBUG_USE_BUFFER
	[STORAGE deleteCharactersInRange:NSMakeRange(0, [STORAGE length])];
	[BUFFER deleteCharactersInRange:NSMakeRange(0, [BUFFER length])];
	updateIndex=0;
	minIndex=0;
    #endif
    
    #if DEBUG_USE_ARRAY
	[screenLines removeAllObjects];
    #endif
    
	[self clearScreen];
	[self initScreen];
	CURSOR_X = CURSOR_Y = 0;
	if([aLine length] > 0)
	{
	    [BUFFER replaceCharactersInRange: NSMakeRange(0, 1) withAttributedString: aLine];
	    [aLine release];
	    CURSOR_X = cursor_x;
	}

	// reset top line
	TOP_LINE = 0;
	
    NS_HANDLER
	NSLog(@"VT100Screen: clearBuffer: Exception: %@", localException);
    NS_ENDHANDLER
    
    [self removeScreenLock];
    [self forceUpdateScreen];
}

- (void)clearScrollbackBuffer
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen clearScrollbackBuffer]",  __FILE__, __LINE__ );
#endif

#if DEBUG_USE_BUFFER
    int idx=[self getIndexAtX:0 Y:0 withPadding:NO];
    
    [STORAGE deleteCharactersInRange:NSMakeRange(0, idx+updateIndex)];
    [BUFFER deleteCharactersInRange:NSMakeRange(0, idx)];
    updateIndex=0;
    minIndex=0;
#endif

#if DEBUG_USE_ARRAY
    int i;
    
    for(i = 0; i < TOP_LINE; i++)
        [screenLines removeObjectAtIndex: 0];
#endif
    TOP_LINE = 0;
    
}

- (void) saveBuffer
{
    [savedBuffer release];
    [self updateScreen];
    savedBuffer = [[NSAttributedString alloc] initWithAttributedString: BUFFER];
}

- (void) restoreBuffer
{

    [self updateScreen];
    if([savedBuffer length] > 0)
    {
	[BUFFER setAttributedString: savedBuffer];
    }
    [savedBuffer release];
    savedBuffer = nil;
    //updateIndex=0;
}

- (int) getIndexAtX:(int)x Y:(int)y withPadding:(BOOL)padding
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen getIndexAtX]:(%d,%d)",  __FILE__, __LINE__ , x, y );
#endif


#if DEBUG_USE_BUFFER
    NSString *s=[BUFFER string];
    int len=[s length];
    int idx=len-1;
    
    if (x>=WIDTH||y>=HEIGHT||x<0||y<0) {
        NSLog(@"getIndexAtX: out of bound: x = %d; y = %d, WIDTH = %d; HEIGHT = %d", x, y, WIDTH, HEIGHT);
        return -1;
    }
    for(;y<HEIGHT&&idx>=0;idx--) {
        if ([s characterAtIndex:idx]=='\n') y++;
    }
    if (y<HEIGHT) idx++; else idx+=2;
    
    for(;x>0&&idx<len&&[s characterAtIndex:idx]!='\n';idx++) {
//        if (ISDOUBLEWIDTHCHARACTER([s characterAtIndex:idx])) {
        if (ISDOUBLEWIDTHCHARACTER(idx)) {
//            NSLog(@"X");
            x-=2;
        }
        else x--;
    }
    if (x>0) {
//        NSLog(@"%d blanks inserted",x);
        [BUFFER insertAttributedString:[self defaultAttrString:[NSString stringWithCharacters:spaces length:x]] atIndex:idx];
        if (idx<minIndex) minIndex=idx;
        idx+=x;
    }

    if (x<0) {
        CURSOR_IN_MIDDLE=YES;
        idx--;
//        NSLog(@"cursor in middle!");
    }
    else CURSOR_IN_MIDDLE=NO;
    
    if (idx<0) {
        NSLog(@"getIndexAtX Error! x:%d, y:%d",x,y);
    }
//    NSLog(@"index:%d[%d] (CURSOR_IN_MIDDLE:%d)",idx,[s length],CURSOR_IN_MIDDLE);
    if (idx<minIndex) minIndex=idx;
    
#else

    if (x>=WIDTH||y>=HEIGHT||x<0||y+TOP_LINE<0) {
        NSLog(@"getIndexAtX: out of bound: x = %d; y = %d, WIDTH = %d; HEIGHT = %d, TOP_LINE=%d", x, y, WIDTH, HEIGHT, TOP_LINE);
        return -1;
    }
    
    NSMutableAttributedString *aLine= [screenLines objectAtIndex: TOP_LINE + y];
    NSString *s=[aLine string];
    int len=[s length];
    int idx=0;
    
    for(;x>0&&idx<len&&[s characterAtIndex:idx]!='\n';idx++) {
        //        if (ISDOUBLEWIDTHCHARACTER([s characterAtIndex:idx])) {
        if (ISDOUBLEWIDTHCHARACTERINLINE(idx,aLine)) {
            //            NSLog(@"X");
            x-=2;
        }
        else x--;
    }
    if (x>0&&padding) {
        //        NSLog(@"%d blanks inserted",x);
        [aLine appendAttributedString:[self defaultAttrString:[NSString stringWithCharacters:spaces length:x]]];
        idx+=x;
    }

    if (x<0) {
        CURSOR_IN_MIDDLE=YES;
        idx--;
        //        NSLog(@"cursor in middle!");
    }
    else CURSOR_IN_MIDDLE=NO;

    if (idx<0) {
        NSLog(@"getIndexAtX Error! x:%d, y:%d",x,y);
    }
    //[(PTYTextView*)display setDirtyLine:TOP_LINE+y];
#endif

//    NSLog(@"index:%d[%d] (CURSOR_IN_MIDDLE:%d)",idx,[s length],CURSOR_IN_MIDDLE);

    return idx;
}

- (int) getTVIndex:(int)x y:(int)y
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen getTVIndex]:(%d,%d)",  __FILE__, __LINE__ , x, y );
#endif

    return [self getIndexAtX:x Y:y withPadding:YES] + updateIndex;
}

- (void)setASCIIString:(NSString *)string
{
    int i,idx,x2;
    BOOL doubleWidth=[SESSION doubleWidth];
    int j, idx2, len, x;

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
#endif
    
    NSString *s=(charset[[TERMINAL charset]]?[self translate:string]:string);
//    NSLog(@"%d(%d):%@",[TERMINAL charset],charset[[TERMINAL charset]],string);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setASCIIString:%@(%@)]",
          __FILE__, __LINE__, string, s);
#endif

    if (s==nil) return;
    len = [s length];
    if (len<1) return;

    NSString *store=[BUFFER string];

    for(idx2=0;idx2<len;) {
         store=[BUFFER string];
        if (CURSOR_X>=WIDTH) {
            if ([TERMINAL wraparoundMode]) {
#if USE_CUSTOM_DRAWING
                aLine=[screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
                if ([[aLine string] characterAtIndex:[aLine length]-1]=='\n')
                    [aLine deleteCharactersInRange:NSMakeRange([aLine length]-1,1)];
#else
		//[BUFFER addAttribute: @"VT100LineWrap" value: @"YES" range: NSMakeRange([self getIndexAtX:WIDTH-1 Y:CURSOR_Y withPadding:NO],1)];
		
#endif
                [self setNewLine];
                CURSOR_X=0;
#if DEBUG_USE_BUFFER
		// mark the position
		NSRange searchRange, aRange;

		if(CURSOR_X >= WIDTH || CURSOR_Y >= HEIGHT)
		{
		    searchRange.location = [[BUFFER string] length] - 10;
		}
		else
		{
		    searchRange.location = [self getIndexAtX: CURSOR_X Y: CURSOR_Y withPadding: NO] - 10;
		}
		searchRange.length = 10;

		aRange = [[BUFFER string] rangeOfString: @"\n" options: NSBackwardsSearch range: searchRange];

		if(aRange.length > 0)
		{
		    [BUFFER addAttribute: @"VT100LineWrap" value: @"YES" range: aRange];
		}		
#endif
                
            }
            else {
                CURSOR_X=WIDTH-1;
                idx2=len-1;
            }
        }
        if ([TERMINAL insertMode]) {
            if(WIDTH-CURSOR_X<=len-idx2) x=WIDTH;
            else x=CURSOR_X+len-idx2;
            j=x-CURSOR_X;
            if (j<=0) {
                //NSLog(@"setASCIIString: output length=0?(%d+%d)%d+%d",CURSOR_X,j,idx2,len);
                break;
            }
            [self insertBlank:j];
            idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];

#if DEBUG_USE_BUFFER
            [BUFFER replaceCharactersInRange:NSMakeRange(idx,j)
                         withAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)] ascii:YES]];
#endif

#if DEBUG_USE_ARRAY
	    // do the same on our line array
	    aLine = [screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
	    [aLine replaceCharactersInRange:NSMakeRange(idx,j)
			      withAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)] ascii:YES]];
            [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];

#endif
	    
            CURSOR_X=x;
            idx2+=j;
        }
        else {
            idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];
            if(WIDTH-CURSOR_X<=len-idx2) x=WIDTH;
            else x=CURSOR_X+len-idx2;
            j=x-CURSOR_X;
            if (j<=0) {
                //NSLog(@"setASCIIString1: output length=0?(%d+%d)%d+%d",CURSOR_X,j,idx2,len);
                break;
            }
#if DEBUG_USE_BUFFER
            if (idx>=[store length]) {
                //NSLog(@"setASCIIString: About to append [%@](%d+%d),  (%d)",
                //      [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]);
                [BUFFER appendAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)]  ascii:YES]];
		
            }
            else if ([store characterAtIndex:idx]=='\n') {
                //NSLog(@"setASCIIString: About to insert [%@](%d+%d),  (%d)",
                //      [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]);
                [BUFFER insertAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)]  ascii:YES] atIndex:idx];
		
            }
            else {
                if (CURSOR_IN_MIDDLE) {
                    //NSLog(@"setASCIIString: Start from middle of a hanzi");
                    [BUFFER replaceCharactersInRange:NSMakeRange(idx,1)
                                 withAttributedString:[self attrString:@"??"  ascii:YES]];
		    
                    store=[BUFFER string];
                    idx++;
                }
                //            NSLog(@"index {%d,%d]->%d",CURSOR_X,CURSOR_Y,idx);
                //NSLog(@"%d+%d->%d",idx2,j,len);
                for(i=0,x2=CURSOR_X;x2<x&&idx+i<[store length]&&[store characterAtIndex:idx+i]!='\n';x2++,i++)
                    if (doubleWidth&&[[BUFFER attribute:NSCharWidthAttributeName atIndex:(idx+i) effectiveRange:nil] intValue]==2)  x2++;
                if (x2>x) {
                    //NSLog(@"setASCIIString: End in the middle of a hanzi");
                    [BUFFER replaceCharactersInRange:NSMakeRange(idx+i-1,1)
                                 withAttributedString:[self attrString:@"??" ascii:YES]];
		    
                    store=[BUFFER string];
                }
                
                //NSLog(@"setASCIIString: About to change [%@](%d+%d) ==> [%@](%d+%d)  (%d)",
                //      [store substringWithRange:NSMakeRange(idx,i)],idx,i,
                //      [s substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]);
                [BUFFER replaceCharactersInRange:NSMakeRange(idx,i)
                             withAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)]  ascii:YES]];
				
            }
#endif

#if DEBUG_USE_ARRAY
	    // Do the same for our line array
	    aLine = [screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
	    if(idx >= [aLine length])
	    {
                [aLine appendAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)]  ascii:YES]];
	    }
	    else
	    {
                NSString *linestr=[aLine string];

                if (CURSOR_IN_MIDDLE) {
                    //NSLog(@"setASCIIString: Start from middle of a hanzi");
                    [aLine replaceCharactersInRange:NSMakeRange(idx,1)
                                withAttributedString:[self attrString:@"??"  ascii:YES]];

                    linestr=[aLine string];
                    idx++;
                }
                //            NSLog(@"index {%d,%d]->%d",CURSOR_X,CURSOR_Y,idx);
                //NSLog(@"%d+%d->%d",idx2,j,len);
                for(i=0,x2=CURSOR_X;x2<x&&idx+i<[linestr length]&&[linestr characterAtIndex:idx+i]!='\n';x2++,i++)
                    if (doubleWidth&&[[aLine attribute:NSCharWidthAttributeName atIndex:(idx+i) effectiveRange:nil] intValue]==2)  x2++;
                if (x2>x) {
                    //NSLog(@"setASCIIString: End in the middle of a hanzi");
                    [aLine replaceCharactersInRange:NSMakeRange(idx+i-1,1)
                                withAttributedString:[self attrString:@"??" ascii:YES]];

                }

                //NSLog(@"setASCIIString: About to change [%@](%d+%d) ==> [%@](%d+%d)  (%d)",
                //      [store substringWithRange:NSMakeRange(idx,i)],idx,i,
                //      [s substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]);
                [aLine replaceCharactersInRange:NSMakeRange(idx,i)
                            withAttributedString:[self attrString:[s substringWithRange:NSMakeRange(idx2,j)]  ascii:YES]];
	    }
            [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];
#endif
	    
            CURSOR_X=x;
            idx2+=j;
        }
    }
}

- (void)setDoubleWidthString:(NSString *)string
{
    int i,idx,x2;
    int j, idx2, len, x;

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
    BOOL doubleWidth=[SESSION doubleWidth];
#endif

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setDoubleWidthString:%@]",
          __FILE__, __LINE__, string);
#endif


    if (string==nil) return;
    len = [string length];
    if (len<1) return;

    NSString *store;

    for(idx2=0;idx2<len;) {
        store=[BUFFER string];
        if (CURSOR_X>=WIDTH) {
            if ([TERMINAL wraparoundMode]) {
#if USE_CUSTOM_DRAWING
                aLine=[screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
                if ([[aLine string] characterAtIndex:[aLine length]-1]=='\n')
                    [aLine deleteCharactersInRange:NSMakeRange([aLine length]-1,1)];
#else
                [BUFFER addAttribute: @"VT100LineWrap" value: @"YES" range: NSMakeRange([self getIndexAtX:WIDTH-1 Y:CURSOR_Y withPadding:NO],1)];
#endif
                [self setNewLine];
                CURSOR_X=0;
            }
            else {
                CURSOR_X=WIDTH-2;
                idx2=len-1;
            }
        }
        if ([TERMINAL insertMode]) {
            if(WIDTH-CURSOR_X<=(len-idx2)*2) x=WIDTH;
            else x=CURSOR_X+(len-idx2)*2;
            j=(x-CURSOR_X+1)/2;
            if (j<=0) {
                //NSLog(@"setDoubleWidthString: output length=0?(%d+%d)%d+%d",CURSOR_X,j,idx2,len);
                break;
            }
            [self insertBlank:x-CURSOR_X];
            idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];
#if DEBUG_USE_BUFFER
            [BUFFER replaceCharactersInRange:NSMakeRange(idx,x-CURSOR_X)
                         withAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO]];
#endif

#if DEBUG_USE_ARRAY
	    // do the same on our line array
	    aLine = [screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
	    [aLine replaceCharactersInRange:NSMakeRange(idx,x-idx)
		    withAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO]];
            [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];
#endif
	    
            CURSOR_X=x;
            idx2+=j;
        }
        else {
            idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];
            if(WIDTH-CURSOR_X<=(len-idx2)*2) x=WIDTH;
            else x=CURSOR_X+(len-idx2)*2;
            j=(x-CURSOR_X+1)/2;
            if (j<=0) {
                //NSLog(@"setDoubleWidthString:1: output length=0?(%d+%d)%d+%d",CURSOR_X,j,idx2,len);
                break;
            }
#if DEBUG_USE_BUFFER
            if (idx>=[store length]) {
                //NSLog(@"setDoubleWidthString: About to append [%@](%d+%d),(%d)",
                //      [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]);

                [BUFFER appendAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO]];
		
            }
            else if ([store characterAtIndex:idx]=='\n') {
                //NSLog(@"setDoubleWidthString: About to insert [%@](%d+%d),  (%d)",
                //      [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]);
                [BUFFER insertAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO] atIndex:idx];
		
            }
            else {
            if (CURSOR_IN_MIDDLE) {
                //NSLog(@"setDoubleWidthString: Start from middle of a hanzi");
                [BUFFER replaceCharactersInRange:NSMakeRange(idx,1)
                             withAttributedString:[self attrString:@"??"  ascii:YES]];		
		
                store=[BUFFER string];
                idx++;
            }
            for(i=0,x2=CURSOR_X;x2<x&&idx+i<[store length]&&[store characterAtIndex:idx+i]!='\n';x2++,i++)
                if (ISDOUBLEWIDTHCHARACTER(idx+i)) x2++;
            if (x2>x) {
                //NSLog(@"setDoubleWidthString: End in the middle of a hanzi");
                [BUFFER replaceCharactersInRange:NSMakeRange(idx+i-1,1)
                             withAttributedString:[self attrString:@"??"  ascii:YES]];		
		
                store=[BUFFER string];
            }
//            NSLog(@"%d,%d(%d)->(%d,%d)",idx,i,[store length],idx2,j);

            //NSLog(@"setDoubleWidthString: About to change [%@](%d+%d) ==> [%@](%d+%d)  (%d)",
                //      [store substringWithRange:NSMakeRange(idx,i)],idx,i,
                //      [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]); 
                [BUFFER replaceCharactersInRange:NSMakeRange(idx,i)
                             withAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO]];	    
	    
            }
#endif

#if DEBUG_USE_ARRAY
	    // Do the same for our line array
	    aLine = [screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
	    if(idx >= [aLine length])
	    {
                [aLine appendAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO]];
	    }
	    else
	    {
                NSString *linestr=[aLine string];
                if (CURSOR_IN_MIDDLE) {
                //NSLog(@"setDoubleWidthString: Start from middle of a hanzi");
                    [aLine replaceCharactersInRange:NSMakeRange(idx,1)
                               withAttributedString:[self attrString:@"??"  ascii:YES]];		
		
                    linestr=[aLine string];
                    idx++;
                }
                for(i=0,x2=CURSOR_X;x2<x&&idx+i<[linestr length]&&[linestr characterAtIndex:idx+i]!='\n';x2++,i++)
                    if (doubleWidth&&[[aLine attribute:NSCharWidthAttributeName atIndex:(idx+i) effectiveRange:nil] intValue]==2) x2++;
                if (x2>x) {
                    //NSLog(@"setDoubleWidthString: End in the middle of a hanzi");
                    [aLine replaceCharactersInRange:NSMakeRange(idx+i-1,1)
                               withAttributedString:[self attrString:@"??"  ascii:YES]];		
		
                }
//            NSLog(@"%d,%d(%d)->(%d,%d)",idx,i,[store length],idx2,j);

            //NSLog(@"setDoubleWidthString: About to change [%@](%d+%d) ==> [%@](%d+%d)  (%d)",
                //      [store substringWithRange:NSMakeRange(idx,i)],idx,i,
                //      [string substringWithRange:NSMakeRange(idx2,j)],idx2,j,[store length]); 
                [aLine replaceCharactersInRange:NSMakeRange(idx,i)
                        withAttributedString:[self attrString:[string substringWithRange:NSMakeRange(idx2,j)]  ascii:NO]];	    
	    }
            [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];

#endif
	    
	    
            CURSOR_X=x;
            idx2+=j;
        }
    }

//    NSLog(@"setDoubleWidthString: done");
}
        
            
- (void)setASCIIStringToX:(int)x
		   Y:(int)y
	      string:(NSString *)string 
{
    int sx, sy;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setASCIIStringToX:%d Y:%d string:%@]",
          __FILE__, __LINE__, x, y, string);
#endif

    sx = CURSOR_X;
    sy = CURSOR_Y;
    CURSOR_X = x;
    CURSOR_Y = y;
    [self setASCIIString:string]; 
    CURSOR_X = sx;
    CURSOR_Y = sy;
}

- (void)setNewLine
{
    int idx;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setNewLine](%d,%d)-[%d,%d]", __FILE__, __LINE__, CURSOR_X, CURSOR_Y, SCROLL_TOP, SCROLL_BOTTOM);
#endif

    if (CURSOR_Y  < SCROLL_BOTTOM || (CURSOR_Y < (HEIGHT - 1) && CURSOR_Y > SCROLL_BOTTOM)) {
        CURSOR_Y++;
        idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:NO];
    }
    // if top of scrolling area is the same as the screen, add a new line at the bottom of the scrolling area so that
    // the top line goes into the scrollback buffer.
    else if (SCROLL_TOP == 0 && SCROLL_BOTTOM == HEIGHT - 1) {
#if DEBUG_USE_BUFFER
        [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];
	[BUFFER appendAttributedString:newLineString];
#endif

#if DEBUG_USE_ARRAY
	// add a line to our array
	NSMutableAttributedString *aLine;
        aLine = [[NSMutableAttributedString alloc] init];
	[screenLines addObject: aLine];
	[aLine release];
#endif
        TOP_LINE++;
	
    }
    else {
        [self scrollUp];
    }
}

- (int) topLines
{
    return TOP_LINE;
}

- (void)showCursor
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen showCursor (%d,%d)]", __FILE__, __LINE__, CURSOR_X, CURSOR_Y);
#endif

    // grab the lock on the screen
    [self setScreenLock];

#if DEBUG_USE_BUFFER
    NSMutableDictionary *dic;
    
    // Show cursor at new position by reversing foreground/background colors
    if (CURSOR_X >= 0 && CURSOR_X < WIDTH &&
        CURSOR_Y >= 0 && CURSOR_Y < HEIGHT)
    {
	int idx;
        idx = [self getTVIndex:CURSOR_X y:CURSOR_Y];
	if(idx > [[STORAGE string] length])
	{
	    [self removeScreenLock];
	    return;
	}
        //NSLog(@"showCursor: %d(%d)(%d)(%d)",idx,[[STORAGE string] length],[self getTVIndex:CURSOR_X y:CURSOR_Y],[BUFFER length]);
	NS_DURING
	    if (idx>=[[STORAGE string] length])
		[STORAGE appendAttributedString:[self defaultAttrString:@" "]];
	    else if ([[STORAGE string] characterAtIndex:idx]=='\n') 
		[STORAGE insertAttributedString:[self defaultAttrString:@" "] atIndex:idx];
    
	    // reverse the video on the position where the cursor is supposed to be shown.
	    dic=[NSMutableDictionary dictionaryWithDictionary: [STORAGE attributesAtIndex:idx effectiveRange:nil]];
	    if([[[SESSION parent] window] isKeyWindow] == YES)
	    {
		[dic setObject:[TERMINAL defaultFGColor] forKey:NSBackgroundColorAttributeName];
		[dic setObject:[TERMINAL defaultBGColor] forKey:NSForegroundColorAttributeName];
	    }
	    else
	    {
		NSColor *aColor = [[TERMINAL defaultBGColor] blendedColorWithFraction: 0.5 ofColor: [TERMINAL defaultFGColor]];
		if(aColor != nil)
		{
		    [dic setObject: aColor forKey:NSBackgroundColorAttributeName];
		    //[dic setObject:[TERMINAL defaultBGColor] forKey:NSForegroundColorAttributeName];
		}
		else
		{
		    [dic setObject:[TERMINAL defaultFGColor] forKey:NSBackgroundColorAttributeName];
		    [dic setObject:[TERMINAL defaultBGColor] forKey:NSForegroundColorAttributeName];
		}
	    }
	    //NSLog(@"----showCursor: (%d,%d):[%d|%c]",CURSOR_X,CURSOR_Y,[[STORAGE string] characterAtIndex:idx],[[STORAGE string] characterAtIndex:idx]);
	    [STORAGE setAttributes:dic range:NSMakeRange(idx,1)];
	NS_HANDLER
	    NSLog(@"%s: showCursor: Exception: %@", __FILE__, localException);
	NS_ENDHANDLER
    }
    
#endif

    // release the screen lock
    [self removeScreenLock];	
}

- (void)deleteCharacters:(int) n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deleteCharacter]: %d", __FILE__, __LINE__, n);
#endif
    int width;

    if (CURSOR_X >= 0 && CURSOR_X < WIDTH &&
        CURSOR_Y >= 0 && CURSOR_Y < HEIGHT)
    {
        for(;n>0;n--) {
#if DEBUG_USE_ARRAY
	    NSMutableAttributedString *aLine;
#endif

	    int idx = [self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];

#if DEBUG_USE_BUFFER	    
            if (idx<[BUFFER length]&&[[BUFFER string] characterAtIndex:idx]!='\n') {
                width = [[BUFFER attribute:NSCharWidthAttributeName atIndex:(idx) effectiveRange:nil] intValue];
                [BUFFER deleteCharactersInRange:NSMakeRange(idx, 1)];
                if (width==2)  [BUFFER insertAttributedString:[self attrString:@"?" ascii:YES] atIndex:idx];
            }
            else  break;
#endif

#if DEBUG_USE_ARRAY
	    // delete from line
	    aLine = [screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
            if(idx < [aLine length]&&[[aLine string] characterAtIndex:idx]!='\n') {
                width = [[aLine attribute:NSCharWidthAttributeName atIndex:(idx) effectiveRange:nil] intValue];
                [aLine deleteCharactersInRange:NSMakeRange(idx, 1)];
                if(width == 2)
                    [aLine insertAttributedString:[self attrString:@"?" ascii:YES] atIndex:idx];
            }
            else break;
#endif
        }
    }
#if DEBUG_USE_ARRAY
    [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];
#endif

}

- (void)backSpace
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen backSpace]", __FILE__, __LINE__);
#endif
    if (CURSOR_X > 0) 
        CURSOR_X--;
}

- (void)setTab
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTab]", __FILE__, __LINE__);
#endif

    CURSOR_X++; // ensure we go to the next tab in case we are already on one
    for(;!tabStop[CURSOR_X]&&CURSOR_X<WIDTH; CURSOR_X++);
}

- (void)clearScreen
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen clearScreen]", __FILE__, __LINE__);
#endif
    [self resizeWidth:WIDTH height:HEIGHT];
/*    int i;

    for (i=0;i<HEIGHT;i++)
        [BUFFER appendAttributedString:[self attrString:@"\n" ascii:YES]]; */
}

- (void)eraseInDisplay:(VT100TCC)token
{
    int x1, y1, x2, y2;
    int y;
    int idx,i;

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
#endif

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen eraseInDisplay:(param=%d)]",
          __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    switch (token.u.csi.p[0]) {
    case 1:
        x1 = 0;
        y1 = 0;
        x2 = CURSOR_X;
        y2 = CURSOR_Y;
        break;

    case 2:
        x1 = 0;
        y1 = 0;
        x2 = WIDTH - 1;
        y2 = HEIGHT - 1;
	
        break;

    case 0:
    default:
        x1 = CURSOR_X;
        y1 = CURSOR_Y;
        x2 = WIDTH - 1;
        y2 = HEIGHT - 1;
        break;
    }

#if DEBUG_USE_BUFFER    
    // if we are clearing the entire screen, move the current screen into the scrollback buffer
    [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];
    if(x1 == 0 && y1 == 0 && x2 == (WIDTH -1 ) && y2 == (HEIGHT - 1))
    {
	
	// update TOP_LINE
        for(i=0;i<HEIGHT;i++) [BUFFER appendAttributedString:newLineString];
        TOP_LINE += HEIGHT; 
        return;
	
    }
#endif

    if (y1 == y2) {
        //            NSLog(@"%d->%d,%d",x1,x2,y);
        if (x2 - x1 > 0)
            [self setASCIIStringToX:x1  Y:y1  string:[NSString stringWithCharacters:spaces length:x2 - x1+1]];
    }
    else {
#if DEBUG_USE_BUFFER
        idx=[self getIndexAtX:x1 Y:y1 withPadding:YES];
        i=[self getIndexAtX:0 Y:y2 withPadding:NO];
        [BUFFER deleteCharactersInRange:NSMakeRange(idx,i-idx)];
        for(y=y1;y<y2;y++)
            [BUFFER insertAttributedString:newLineString atIndex:idx];
#endif

#if DEBUG_USE_ARRAY
        // erase in our lines
        for(y=y1;y<y2;y++) {
            aLine = [screenLines objectAtIndex: TOP_LINE  + y];
            idx=y==y1?[self getIndexAtX:x1 Y:y withPadding:NO]:0;
            if (idx<[aLine length]) [aLine deleteCharactersInRange:NSMakeRange(idx,[aLine length]-idx)];
            [(PTYTextView*)display setDirtyLine:TOP_LINE+y];
        }
#endif

        [self setASCIIStringToX:0  Y:y2  string:[NSString stringWithCharacters:spaces length:x2+1]];

    }
}

- (void)eraseInLine:(VT100TCC)token
{
    int i, idx;

#if DEBUG_USE_BUFFER
    NSString *s;
#endif

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
#endif
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen eraseInLine:(param=%d)]",
          __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    switch (token.u.csi.p[0]) {
    case 1:
        [self setASCIIStringToX:0  Y:CURSOR_Y  string:[NSString stringWithCharacters:spaces length:CURSOR_X+1]];
        break;
    case 2:
	CURSOR_X = 0;
	// continue, next case....

    case 0:
        i=idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];
#if DEBUG_USE_BUFFER
        s=[BUFFER string];
        for(;i<[s length]&&[s characterAtIndex:i]!='\n';i++);
        if (i>idx) [BUFFER deleteCharactersInRange:NSMakeRange(idx,i-idx)];
        if (idx<[BUFFER length]) [BUFFER setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(idx,1)];
#endif

#if DEBUG_USE_ARRAY
	// erase in our line
	aLine = [screenLines objectAtIndex: TOP_LINE  + CURSOR_Y];
        idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];
        if (idx<[aLine length]) [aLine deleteCharactersInRange:NSMakeRange(idx,[aLine length] - idx)];
        [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];
#endif
	    
        
        break;
    default:
        ;
    }
}

- (void)selectGraphicRendition:(VT100TCC)token
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen selectGraphicRendition:...]",
	  __FILE__, __LINE__);
#endif
}

- (void)cursorLeft:(int)n
{
    int x = CURSOR_X - (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorLeft:%d]", 
	  __FILE__, __LINE__, n);
#endif
    if (x < 0)
	x = 0;
    if (x >= 0 && x < WIDTH)
	CURSOR_X = x;
}

- (void)cursorRight:(int)n
{
    int x = CURSOR_X + (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorRight:%d]", 
	  __FILE__, __LINE__, n);
#endif
    if (x >= WIDTH)
	x =  WIDTH - 1;
    if (x >= 0 && x < WIDTH)
	CURSOR_X = x;
}

- (void)cursorUp:(int)n
{
    int y = CURSOR_Y - (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorUp:%d]", 
	  __FILE__, __LINE__, n);
#endif
    if(CURSOR_Y >= SCROLL_TOP)
	CURSOR_Y=y<SCROLL_TOP?SCROLL_TOP:y;
    else
	CURSOR_Y = y;
}

- (void)cursorDown:(int)n
{
    int y = CURSOR_Y + (n>0?n:1);

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorDown:%d, Y = %d; SCROLL_BOTTOM = %d]", 
	  __FILE__, __LINE__, n, CURSOR_Y, SCROLL_BOTTOM);
#endif
    if(CURSOR_Y <= SCROLL_BOTTOM)
	CURSOR_Y=y>SCROLL_BOTTOM?SCROLL_BOTTOM:y;
    else
	CURSOR_Y = y;
}

- (void) cursorToX: (int) x
{
    int x_pos;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorToX:%d]",
	  __FILE__, __LINE__, x);
#endif
    x_pos = (x-1);

    if(x_pos < 0)
	x_pos = 0;
    else if(x_pos >= WIDTH)
	x_pos = WIDTH - 1;

    CURSOR_X = x_pos;
	
}

- (void)cursorToX:(int)x Y:(int)y
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen cursorToX:%d Y:%d]", 
	  __FILE__, __LINE__, x, y);
#endif
    int x_pos, y_pos;


    x_pos = x - 1;
    y_pos = y - 1;

    if ([TERMINAL originMode]) y_pos += SCROLL_TOP;

    if(x_pos < 0)
	x_pos = 0;
    else if(x_pos >= WIDTH)
	x_pos = WIDTH - 1;
    if(y_pos < 0)
	y_pos = 0;
    else if(y_pos >= HEIGHT)
	y_pos = HEIGHT - 1;

    CURSOR_X = x_pos;
    CURSOR_Y = y_pos;

    
//    NSParameterAssert(CURSOR_X >= 0 && CURSOR_X < WIDTH);

}

- (void)saveCursorPosition
{
    int i;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen saveCursorPosition]", 
	  __FILE__, __LINE__);
#endif

    if(CURSOR_X < 0)
	CURSOR_X = 0;
    if(CURSOR_X >= WIDTH)
	CURSOR_X = WIDTH-1;
    if(CURSOR_Y < 0)
	CURSOR_Y = 0;
    if(CURSOR_Y >= HEIGHT)
	CURSOR_Y = HEIGHT;
        
    SAVE_CURSOR_X = CURSOR_X;
    SAVE_CURSOR_Y = CURSOR_Y;

    for(i=0;i<4;i++) saveCharset[i]=charset[i];

}

- (void)restoreCursorPosition
{
    int i;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen restoreCursorPosition]", 
	  __FILE__, __LINE__);
#endif
    CURSOR_X = SAVE_CURSOR_X;
    CURSOR_Y = SAVE_CURSOR_Y;

    for(i=0;i<4;i++) charset[i]=saveCharset[i];
    
    NSParameterAssert(CURSOR_X >= 0 && CURSOR_X < WIDTH);
    NSParameterAssert(CURSOR_Y >= 0 && CURSOR_Y < HEIGHT);
}

- (void)setTopBottom:(VT100TCC)token
{
    int top, bottom;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setTopBottom:(%d,%d)]", 
	  __FILE__, __LINE__, token.u.csi.p[0], token.u.csi.p[1]);
#endif

    top = token.u.csi.p[0] == 0 ? 0 : token.u.csi.p[0] - 1;
    bottom = token.u.csi.p[1] == 0 ? HEIGHT - 1 : token.u.csi.p[1] - 1;
    if (top >= 0 && top < HEIGHT &&
        bottom >= 0 && bottom < HEIGHT &&
        bottom >= top)
    {
        SCROLL_TOP = top;
        SCROLL_BOTTOM = bottom;

	if ([TERMINAL originMode]) {
	    CURSOR_X = 0;
	    CURSOR_Y = SCROLL_TOP;
	}
	else {
	    CURSOR_X = 0;
	    CURSOR_Y = 0;
	}
    }
}

- (void)scrollUp
{
#if DEBUG_USE_BUFFER
    int idx, idx2;
    NSRange aRange;
#endif

#if DEBUG_USE_ARRAY
    int y;
    NSMutableAttributedString *aLine;
#endif

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen scrollUp]", __FILE__, __LINE__);
#endif

    NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM );

#if DEBUG_USE_BUFFER
    
    //NSLog(@"SCROLL-UP[%d-%d]; Y = %d",SCROLL_TOP,SCROLL_BOTTOM, CURSOR_Y);
    idx=[self getIndexAtX:0 Y:SCROLL_TOP withPadding:YES];
    if (SCROLL_TOP==HEIGHT-1) idx2=[BUFFER length];
    else idx2=[self getIndexAtX:0 Y:SCROLL_TOP+1 withPadding:YES];
    aRange = NSMakeRange(idx,idx2-idx);
    if(aRange.length <= 0)
        aRange.length = 1;

    // if we are at the top of the screen, save the line in the scrollback buffer, otherwise delete it.
    if(SCROLL_TOP != 0)
    {
	[BUFFER deleteCharactersInRange:aRange];
    }
    else
    {
	TOP_LINE++;
    }
    
#endif

#if DEBUG_USE_ARRAY
    // delete from our line array
    [screenLines removeObjectAtIndex: TOP_LINE + SCROLL_TOP];
#endif

    [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];

    if (SCROLL_BOTTOM>=HEIGHT-1) {
#if DEBUG_USE_BUFFER
        [BUFFER appendAttributedString:newLineString];
#endif

#if DEBUG_USE_ARRAY
	// add a new line to our line array
	aLine = [[NSMutableAttributedString alloc] init];
	[screenLines addObject: aLine];
	[aLine release];
#endif
    }
    else if(CURSOR_Y <= SCROLL_BOTTOM) {
#if DEBUG_USE_BUFFER
        idx=[self getIndexAtX:0 Y:SCROLL_BOTTOM+1 withPadding:YES];
        [BUFFER insertAttributedString:newLineString atIndex:idx];
#endif

#if DEBUG_USE_ARRAY
	// insert a line into our array
	aLine = [[NSMutableAttributedString alloc] init];
	[screenLines insertObject: aLine atIndex:TOP_LINE + SCROLL_BOTTOM];
	[aLine release];
#endif
    }
#if DEBUG_USE_ARRAY
    for(y=SCROLL_TOP;y<=SCROLL_BOTTOM; y++) [(PTYTextView*)display setDirtyLine:TOP_LINE+y];
#endif
}

- (void)scrollDown
{
#if DEBUG_USE_BUFFER
    int idx, idx2;
    NSRange aRange;
#endif

#if DEBUG_USE_ARRAY
    int y;
    NSMutableAttributedString *aLine;
#endif
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen scrollDown]", __FILE__, __LINE__);
#endif
    NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM );

#if DEBUG_USE_BUFFER
    //NSLog(@"SCROLL-DOWN[%d-%d]",SCROLL_TOP,SCROLL_BOTTOM);
    idx=[self getIndexAtX:0 Y:SCROLL_TOP withPadding:YES];
    [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];
    [BUFFER insertAttributedString: newLineString atIndex:idx];
#endif

#if DEBUG_USE_ARRAY
    // insert a line into our array
    aLine = [[NSMutableAttributedString alloc] init];
    [screenLines insertObject: aLine atIndex:TOP_LINE + SCROLL_TOP];
    [aLine release];
#endif
    
    if (SCROLL_BOTTOM>=HEIGHT-1) {
#if DEBUG_USE_BUFFER
        idx=[self getIndexAtX:0 Y:SCROLL_BOTTOM withPadding:YES];
        aRange = NSMakeRange(idx-1, [BUFFER length]-idx);
        if(aRange.length <= 0)
            aRange.length = 1;
#endif

#if DEBUG_USE_ARRAY
	// delete from our line array
        [screenLines removeObjectAtIndex: [screenLines count]];
#endif
	
    }
    else {
#if DEBUG_USE_BUFFER
        idx=[self getIndexAtX:0 Y:SCROLL_BOTTOM withPadding:YES];
        idx2=[self getIndexAtX:0 Y:SCROLL_BOTTOM+1 withPadding:YES];
        aRange = NSMakeRange(idx,idx2-idx);
        if(aRange.length <= 0)
            aRange.length = 1;
#endif

#if DEBUG_USE_ARRAY
	// delete from our line array
        [screenLines removeObjectAtIndex: TOP_LINE + SCROLL_BOTTOM+1];
#endif
	
    }
    
#if USE_CUSTOM_DRAWING
    for(y=SCROLL_TOP;y<=SCROLL_BOTTOM; y++) [(PTYTextView*)display setDirtyLine:TOP_LINE+y];
#else
    [BUFFER deleteCharactersInRange:aRange];
#endif
    
}

- (void) trimLine: (int) y
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen trimLine; %d]", __FILE__, __LINE__, y);
#endif

    int idx,x;
#if DEBUG_USE_BUFFER
    int i;
    NSString *store=[BUFFER string];
#endif

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine;
#endif

#if DEBUG_USE_BUFFER
    idx=[self getIndexAtX:0 Y:y withPadding:YES];
    for(x=0;x<WIDTH&&idx<[store length]&&[store characterAtIndex:idx]!='\n';idx++,x++)
//        if (ISDOUBLEWIDTHCHARACTER([store characterAtIndex:idx])) x++;
        if (ISDOUBLEWIDTHCHARACTER(idx)) x++;
    for(i=idx;i<[store length]&&[store characterAtIndex:i]!='\n';i++);
    if (i>idx) [BUFFER deleteCharactersInRange:NSMakeRange(idx,i-idx)];
#endif

#if DEBUG_USE_ARRAY   
    // delete from line
    aLine = [screenLines objectAtIndex: TOP_LINE + y];
    for(x=0, idx=0;x<WIDTH&&idx<[aLine length]&&[[aLine string] characterAtIndex:idx]!='\n';idx++,x++)
        if (ISDOUBLEWIDTHCHARACTERINLINE(idx, aLine)) x++;
    if (idx < [aLine length]) {
	if ([[aLine string] characterAtIndex:idx]=='\n')
            [aLine deleteCharactersInRange:NSMakeRange(idx,[aLine length] - idx -1)];
        else
            [aLine deleteCharactersInRange:NSMakeRange(idx,[aLine length] - idx)];
    }
#endif
    
}    
    


- (void) insertBlank: (int)n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen insertBlank; %d]", __FILE__, __LINE__, n);
#endif
    int idx;

#if DEBUG_USE_ARRAY
    NSMutableAttributedString *aLine = [screenLines objectAtIndex: TOP_LINE + CURSOR_Y];
#endif

//    NSLog(@"insertBlank[%d@(%d,%d)]",n,CURSOR_X,CURSOR_Y);
    idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];

    if (CURSOR_IN_MIDDLE) {
#if DEBUG_USE_BUFFER
        [BUFFER replaceCharactersInRange:NSMakeRange(idx,1)
                     withAttributedString:[self defaultAttrString:@"??"]];
        idx++;
#endif

#if DEBUG_USE_ARRAY
	// do the same in the line array.
	[aLine replaceCharactersInRange:NSMakeRange(idx,1)
	    withAttributedString:[self defaultAttrString:@"??"]];
	idx++;
#endif

    }

#if DEBUG_USE_BUFFER
    if (idx<[BUFFER length])
        [BUFFER insertAttributedString:[self attrString:[NSString stringWithCharacters:spaces length:n] ascii:YES] atIndex:idx];
    else
        [BUFFER appendAttributedString:[self attrString:[NSString stringWithCharacters:spaces length:n] ascii:YES]];
#endif

#if DEBUG_USE_ARRAY
    // do the same in the line array
    if (idx<[aLine length])
    {
        [aLine insertAttributedString:[self defaultAttrString:[NSString stringWithCharacters:spaces length:n]] atIndex:idx];
    }
    else
    {
	[aLine appendAttributedString:[self defaultAttrString:[NSString stringWithCharacters:spaces length:n]]];
    }
#endif
    
    [self trimLine:CURSOR_Y];
#if USE_CUSTOM_DRAWING
    [(PTYTextView*)display setDirtyLine:TOP_LINE+CURSOR_Y];
#endif

}

- (void) insertLines: (int)n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen insertLines; %d]", __FILE__, __LINE__, n);
#endif
    
#if DEBUG_USE_BUFFER
    int idx, idx2;
    NSRange aRange;
#endif

#if DEBUG_USE_ARRAY
    int y,y2;
    NSMutableAttributedString *aLine;
#endif
    
//    NSLog(@"insertLines %d[%d,%d]",n, CURSOR_X,CURSOR_Y);
    [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];
    for(;n>0;n--) {
#if DEBUG_USE_BUFFER
        idx=[self getIndexAtX:0 Y:CURSOR_Y withPadding:YES];
        [BUFFER insertAttributedString:newLineString atIndex:idx];
#endif

#if DEBUG_USE_ARRAY
        aLine=[[NSMutableAttributedString alloc] init];
	[screenLines insertObject: aLine atIndex: TOP_LINE + CURSOR_Y];
        [aLine release];
#endif
        if (SCROLL_BOTTOM<CURSOR_Y||SCROLL_BOTTOM>=HEIGHT-1) {
#if DEBUG_USE_BUFFER
            idx=[self getIndexAtX:0 Y:SCROLL_BOTTOM withPadding:YES];
            aRange = NSMakeRange(idx-1,[BUFFER length]-idx);
            if(aRange.length <= 0)
                aRange.length = 1;
#endif

#if DEBUG_USE_ARRAY
	    // delete from our line array
            [screenLines removeObjectAtIndex: [screenLines count] - 1];
#endif
	    
        }
        else {
#if DEBUG_USE_BUFFER
            idx=[self getIndexAtX:0 Y:SCROLL_BOTTOM withPadding:YES];
            idx2=[self getIndexAtX:0 Y:SCROLL_BOTTOM+1 withPadding:YES];
            aRange = NSMakeRange(idx,idx2-idx);
            if(aRange.length <= 0)
                aRange.length = 1;
#endif

#if DEBUG_USE_ARRAY
	    // delete from our line array
            [screenLines removeObjectAtIndex: TOP_LINE + SCROLL_BOTTOM + 1];
#endif
	    
        }
	
#if DEBUG_USE_BUFFER
        [BUFFER deleteCharactersInRange: aRange];
#endif
	
    }
#if DEBUG_USE_ARRAY
    y2=SCROLL_BOTTOM<CURSOR_Y||SCROLL_BOTTOM>=HEIGHT-1?SCROLL_BOTTOM:HEIGHT-1;
    for(y=CURSOR_Y;y<=y2;y++)     [(PTYTextView*)display setDirtyLine:TOP_LINE+y];
#endif
}

- (void) deleteLines: (int)n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deleteLines; %d]", __FILE__, __LINE__, n);
#endif

#if DEBUG_USE_BUFFER
    int idx, idx2;
    NSRange aRange;
#endif

#if DEBUG_USE_ARRAY
    int y,y2;
    NSMutableAttributedString *aLine;
#endif

    //NSLog(@"deleteLines %d[%d,%d]",n, CURSOR_X,CURSOR_Y);
    [newLineString setAttributes:[TERMINAL characterAttributeDictionary:YES] range:NSMakeRange(0,1)];
    for(;n>0;n--) {
#if DEBUG_USE_BUFFER
        idx=[self getIndexAtX:0 Y:CURSOR_Y withPadding:YES];
        idx2=[self getIndexAtX:0 Y:CURSOR_Y+1 withPadding:YES];
	if(idx < 0 || idx >= [BUFFER length])
	    idx = [BUFFER length] - 1;
	if(idx2 < 0 || idx >= [BUFFER length])
	{
	    if([[BUFFER string] characterAtIndex: idx] != '\n')
		idx--; // include the last '\n' in the buffer
	    idx2 = [BUFFER length];
	}
	//NSLog(@"idx = %d; idx2 = %d", idx, idx2);
        aRange = NSMakeRange(idx, idx2-idx);
        if(aRange.length <= 0)
            aRange.length = 1;
        [BUFFER deleteCharactersInRange:aRange];
#endif

#if DEBUG_USE_ARRAY
	[screenLines removeObjectAtIndex: TOP_LINE + CURSOR_Y];

	aLine = [[NSMutableAttributedString alloc] init];
#endif

        if (SCROLL_BOTTOM<CURSOR_Y||SCROLL_BOTTOM>=HEIGHT-1) {
#if DEBUG_USE_BUFFER
            [BUFFER appendAttributedString:newLineString];
#endif
#if DEBUG_USE_ARRAY
	    [screenLines addObject: aLine];
#endif
        }
        else {
#if DEBUG_USE_BUFFER
            idx=[self getIndexAtX:0 Y:SCROLL_BOTTOM+1 withPadding:YES];
            [BUFFER insertAttributedString:newLineString atIndex:idx];
#endif
#if DEBUG_USE_ARRAY
	    [screenLines insertObject: aLine atIndex: SCROLL_BOTTOM];
#endif
        }
#if DEBUG_USE_ARRAY
        [aLine release];
        y2=SCROLL_BOTTOM<CURSOR_Y||SCROLL_BOTTOM>=HEIGHT-1?SCROLL_BOTTOM:HEIGHT-1;
        for(y=CURSOR_Y;y<=y2;y++)     [(PTYTextView*)display setDirtyLine:TOP_LINE+y];
#endif

    }
    //NSLog(@"Exiting deleteLines...");
}

- (void)playBell
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen playBell]",  __FILE__, __LINE__);
#endif
    if (PLAYBELL) {
	NSBeep();
        [SESSION setBell];
    }
}

- (void)removeOverLine
{
  
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen removeOverLine (%d, %d)]:%p",  __FILE__, __LINE__, TOP_LINE, scrollbackLines);
#endif

    if ([[SESSION TEXTVIEW] hasMarkedText]) return;

    [self updateScreen];	// make sure STORAGE and BUFFER is synchronized
    [self setScreenLock];

    if (TOP_LINE > scrollbackLines) {
#if DEBUG_USE_BUFFER
	int idx;
	NSString *s=[STORAGE string];
        int len=[s length];
#endif
	int over = TOP_LINE - scrollbackLines;
        int i;
        
#if DEBUG_USE_BUFFER
        for(i=0,idx=0;i<over&&idx<len;idx++)
            if ([s characterAtIndex:idx]=='\n') i++;
        if (idx>=len) {
            NSLog(@"!!!removeOverLine overflow!!!");
            [self removeScreenLock];
            return;
        }

	NS_DURING
	    [STORAGE beginEditing];
	    [STORAGE deleteCharactersInRange:NSMakeRange(0, idx)];
	    [STORAGE endEditing];
	    if (idx<=updateIndex) updateIndex-=idx;
	    else {
		[BUFFER deleteCharactersInRange:NSMakeRange(0,idx-updateIndex)];
		updateIndex=0;
	    }        
        NS_HANDLER
	    NSLog(@"%s: removeOverLine: Exception: %@", __FILE__, localException);
	NS_ENDHANDLER
    #endif
	    
    
    #if DEBUG_USE_ARRAY
	    for(i = 0; i < over; i++)
		[screenLines removeObjectAtIndex: 0];
    #endif
	    TOP_LINE -= over;
    
	    NSParameterAssert(TOP_LINE >= 0);
    }

    cursorIndex = [self getTVIndex:CURSOR_X y:CURSOR_Y];
    [[SESSION TEXTVIEW] setCursorIndex: cursorIndex];

    [self removeScreenLock];
    
}

- (void)deviceReport:(VT100TCC)token
{
    NSData *report = nil;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deviceReport:%d]", 
	  __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    if (SHELL == nil)
	return;

    switch (token.u.csi.p[0]) {
    case 3: // response from VT100 -- Malfunction -- retry
	break;

    case 5: // Command from host -- Please report status
	report = [TERMINAL reportStatus];
	break;

    case 6: // Command from host -- Please report active position
        {
	    int x, y;

	    if ([TERMINAL originMode]) {
		x = CURSOR_X + 1;
		y = CURSOR_Y - SCROLL_TOP + 1;
	    }
	    else {
		x = CURSOR_X + 1;
		y = CURSOR_Y + 1;
	    }
	    report = [TERMINAL reportActivePositionWithX:x Y:y];
	}
	break;

    case 0: // Response from VT100 -- Ready, No malfuctions detected
    default:
	break;
    }

    if (report != nil) {
	[SHELL writeTask:report];
    }
}

- (void)deviceAttribute:(VT100TCC)token
{
    NSData *report = nil;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deviceAttribute:%d]", 
	  __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    if (SHELL == nil)
	return;

    report = [TERMINAL reportDeviceAttribute];

    if (report != nil) {
	[SHELL writeTask:report];
    }
}

- (NSAttributedString *)attrString:(NSString *)str ascii:(BOOL)asc
{
    NSMutableAttributedString *attr;

    if (str==nil) {
        NSLog(@"attrString: nil received!");
        str=@"";
    }

    attr = [[NSMutableAttributedString alloc]
               initWithString:str
                   attributes:[TERMINAL characterAttributeDictionary:asc]];

    // Mark graphical characters and use our embedded font that has the necessary glyphs
    if(charset[[TERMINAL charset]] && [[PreferencePanel sharedInstance] enforceCharacterAlignment])
    {
	[attr addAttribute: NSFontAttributeName value: [NSFont fontWithName:@"FreeMonoBold" size:[[self font] pointSize]] range: NSMakeRange(0, [attr length])];
	[attr addAttribute: @"VT100GraphicalCharacter" value: [NSNumber numberWithInt:1] range: NSMakeRange(0, [attr length])];
    }
    
    [attr autorelease];
    
    return attr;
}

- (NSAttributedString *)defaultAttrString:(NSString *)str
{
    NSMutableAttributedString *attr;

    if (str==nil) {
        NSLog(@"defaultAttrString: nil received!");
        str=@"";
    }
    
    attr = [[NSAttributedString alloc]
               initWithString:str
                   attributes:[TERMINAL defaultCharacterAttributeDictionary:YES]];

    [attr autorelease];

    return attr;
}


- (BOOL) isDoubleWidthCharacter:(unichar)code
{
    BOOL result = NO;

    return (code>=0x1000)?YES:NO; //[NSString isDoubleWidthCharacter:code];

    return result;
}

- (void)blink
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen blink]", __FILE__, __LINE__);
#endif

#if USE_CUSTOM_DRAWING
#else
    int blinkType;
    NSColor *fg, *bg,*fgBlink, *bgBlink;
    NSDictionary *dic;
    NSRange range;
    int len;
    int idx;

    if ([self screenIsLocked]) return;

    [self setScreenLock];

    len=[[STORAGE string] length];
    idx=len-1;
    
//    NSLog(@"blink!!");
    
    [STORAGE beginEditing];

    NS_DURING
	for(idx=updateIndex;idx<len;) {
	    blinkType = [[STORAGE attribute:NSBlinkAttributeName atIndex:idx effectiveRange:&range] intValue];
	    if (blinkType > 0) {
    //            NSLog(@"true blink!!");
		for(;idx<range.length+range.location;idx++) {
		    fg=[STORAGE attribute:NSForegroundColorAttributeName atIndex:idx effectiveRange:nil];
		    bg=[STORAGE attribute:NSBackgroundColorAttributeName atIndex:idx effectiveRange:nil];
		    fgBlink=[STORAGE attribute:NSBlinkForegroundColorAttributeName atIndex:idx effectiveRange:nil];
		    if (fgBlink==nil) {
			fgBlink=fg;
		    }
    
		    dic=[NSDictionary dictionaryWithObjectsAndKeys:
			bg,NSBackgroundColorAttributeName,
			(blinkShow?fgBlink:bg),NSForegroundColorAttributeName,
			fgBlink,NSBlinkForegroundColorAttributeName,
			[NSNumber numberWithInt:1],NSBlinkAttributeName,
			nil];
		    [STORAGE addAttributes:dic range:NSMakeRange(idx,1)];
		    
		}
    //            NSLog(@"true blink end!!");
	    }
	    else idx+=range.length;
	}
    
	// Check if the cursor needs to blink
	if([self blinkingCursor] == YES && [SESSION isActiveSession] == YES && [[[SESSION parent] window] isKeyWindow])
	{
	    idx = [self getTVIndex: CURSOR_X y: CURSOR_Y];
	    if(idx < len)
	    {
		fg=[STORAGE attribute:NSForegroundColorAttributeName atIndex:idx effectiveRange:nil];
		bg=[STORAGE attribute:NSBackgroundColorAttributeName atIndex:idx effectiveRange:nil];
		fgBlink=[STORAGE attribute:NSBlinkForegroundColorAttributeName atIndex:idx effectiveRange:nil];
		bgBlink=[STORAGE attribute:NSBlinkBackgroundColorAttributeName atIndex:idx effectiveRange:nil];
		if (fgBlink==nil) {
		    fgBlink=fg;
		}
		if (bgBlink==nil) {
		    bgBlink=bg;
		}	    
    
		if([[self session] image] != nil)
		{
		    dic=[NSDictionary dictionaryWithObjectsAndKeys:
			(blinkShow?bgBlink:fgBlink),NSForegroundColorAttributeName,
			(blinkShow?fgBlink:bgBlink),NSBackgroundColorAttributeName,
			fgBlink,NSBlinkForegroundColorAttributeName,
			bgBlink,NSBlinkBackgroundColorAttributeName,
			nil];
		    [STORAGE addAttributes:dic range:NSMakeRange(idx,1)];
		    if(blinkShow)
			[STORAGE removeAttribute: NSBackgroundColorAttributeName range: NSMakeRange(idx,1)];
		}
		else
		{
		    dic=[NSDictionary dictionaryWithObjectsAndKeys:
			(blinkShow?fg:bg),NSBackgroundColorAttributeName,
			(blinkShow?bg:fg),NSForegroundColorAttributeName,
			fgBlink,NSBlinkForegroundColorAttributeName,
			bgBlink,NSBlinkBackgroundColorAttributeName,
			nil];
		    [STORAGE addAttributes:dic range:NSMakeRange(idx,1)];
		}
	    }
	}
    NS_HANDLER
	NSLog(@"%s: blink: Exception: %@", __FILE__, localException);
    NS_ENDHANDLER
    
    [STORAGE endEditing];
    blinkShow=!blinkShow;
    [self removeScreenLock];
#endif
}

- (int) cursorX
{
    return CURSOR_X+1;
}

- (int) cursorY
{
    return CURSOR_Y+1;
}

- (void) clearTabStop
{
    int i;
    for(i=0;i<300;i++) tabStop[i]=NO;
}

- (NSString *)translate: (NSString *)s
{
    unichar t[3000]; //=malloc(sizeof(char)*[s length]);
    const char *sc=[s cString];
    NSString *ts;
    int i;

    for(i=0;i<strlen(sc);i++) t[i]=charmap[(int)sc[i]];
    ts=[NSString stringWithCharacters:t length:strlen(sc)];

    return ts;
   
}

- (NSMutableAttributedString *) buffer
{
    return BUFFER;
}


- (int) numberOfLines
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen numberOfLines]",  __FILE__, __LINE__ );
#endif
    
#if DEBUG_USE_BUFFER
    int i, len;
    int lineCount = 0;
    NSString *store = [STORAGE string];

    len = [store length];
    if([store length] <= 0)
	return (0);

    lineCount = 1;
    for (i=0; i < len; i++)
    {
	if([store characterAtIndex: i] == '\n')
	    lineCount++;
    }

    return (lineCount);
    
#elif DEBUG_USE_ARRAY
   
    return ([screenLines count]);
#else
    return (0);
#endif
}


- (void) renewBuffer
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen renewBuffer]",  __FILE__, __LINE__ );
#endif

#if DEBUG_USE_BUFFER
    NSString *s=[BUFFER string];
    int len=[s length];
    int idx=len-1;
    int y=0;
    
    for(;y<HEIGHT&&idx>=0;idx--) {
        if ([s characterAtIndex:idx]=='\n') y++;
    }
    if (y<HEIGHT) idx++; else idx+=2;
//    NSLog(@"renew: %d, %d",updateIndex, idx);

    if (idx) {
        [BUFFER deleteCharactersInRange:NSMakeRange(0,idx)];
        updateIndex+=idx;
    }

    minIndex=[BUFFER length];
#endif
}

- (void) forceUpdateScreen
{
    minIndex=0;
    [self updateScreen];
}

- (void) updateScreen
{
    
#if DEBUG_USE_BUFFER
    int len, slen;
    int idx;
    
    idx=[self getIndexAtX:CURSOR_X Y:CURSOR_Y withPadding:YES];
    if ([[SESSION TEXTVIEW] hasMarkedText]) {
        len=idx;
        slen=[[SESSION TEXTVIEW] markedRange].location;
    }
    else {
        len=[BUFFER length];
        slen=[STORAGE length];
    }
    if (len<=0||minIndex>len) return;

    // acquire lock
    [self setScreenLock];


    //NSLog(@"updating: %d, %d, %d, %d",updateIndex,minIndex,[STORAGE length],[BUFFER length]);

    [STORAGE beginEditing];
    
    NS_DURING
	if((updateIndex+minIndex) < [STORAGE length])
	{
	    [STORAGE replaceCharactersInRange:NSMakeRange(updateIndex+minIndex,slen-updateIndex-minIndex)
			withAttributedString:[BUFFER attributedSubstringFromRange:NSMakeRange(minIndex,len-minIndex)]];
	}
	else
	{
	    [STORAGE appendAttributedString:[BUFFER attributedSubstringFromRange:NSMakeRange(minIndex,len-minIndex)]];
	}
	//NSLog(@"updated: %d, %d, %d, %d",updateIndex,minIndex,[STORAGE length],[BUFFER length]);
	//if ([BUFFER length]>[STORAGE length]) NSLog(@"%@",BUFFER);
	[self renewBuffer];
	//NSLog(@"renewed: %d, %d, %d, %d",updateIndex,minIndex,[STORAGE length],[BUFFER length]);
	cursorIndex = [self getTVIndex:CURSOR_X y:CURSOR_Y];
	[[SESSION TEXTVIEW] setCursorIndex: cursorIndex];
    NS_HANDLER
	NSLog(@"%s: updateScreen: Exception: %@", __FILE__, localException);
    NS_ENDHANDLER
    
    
    [STORAGE endEditing];
    // release lock
    [self removeScreenLock];

    //NSLog(@"showCursor");
    [self showCursor];
    //NSLog(@"shown");    
#endif

#if DEBUG_USE_ARRAY
    [(PTYTextView *)display refresh];
#endif

}

- (void) setScreenAttributes
{
    NSColor *fg, *bg;
   // Change the attributes for the current stuff in the text storage
    if ([TERMINAL screenMode]) {
        bg=[TERMINAL defaultFGColor];
        fg=[TERMINAL defaultBGColor];
    }else {
        fg=[TERMINAL defaultFGColor];
        bg=[TERMINAL defaultBGColor];
    }

    bg = [bg colorWithAlphaComponent: [[SESSION backgroundColor] alphaComponent]];
    fg = [fg colorWithAlphaComponent: [[SESSION foregroundColor] alphaComponent]];
    
    [BUFFER removeAttribute: NSForegroundColorAttributeName
                       range: NSMakeRange(0, [BUFFER length])];
    [BUFFER addAttribute: NSForegroundColorAttributeName
                    value: fg
                    range: NSMakeRange(0, [BUFFER length])];
    [BUFFER removeAttribute: NSBackgroundColorAttributeName
                       range: NSMakeRange(0, [BUFFER length])];
    [BUFFER addAttribute:  NSBackgroundColorAttributeName
                            value: bg
                            range: NSMakeRange(0, [BUFFER length])];
    [self forceUpdateScreen];
    [[SESSION SCROLLVIEW] setBackgroundColor: bg];
    [[SESSION SCROLLVIEW] setNeedsDisplay: YES];

}

- (void) setScreenLock
{
    [screenLock lock];
    screenIsLocked = YES;
}

- (void) removeScreenLock
{
    [screenLock unlock];
    screenIsLocked = NO;
}

- (BOOL) screenIsLocked
{
    return screenIsLocked;
}

#if USE_CUSTOM_DRAWING
- (NSArray *) screenLines
{
    return (screenLines);
}

- (NSMutableAttributedString *)stringAtLine: (int) n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen stringAtLine: %d]",  __FILE__, __LINE__, n );
#endif

    if(n>=0&&n < [screenLines count])
        return ([screenLines objectAtIndex: n]);
    else
        return (nil);
    
}


#else
#endif

@end

