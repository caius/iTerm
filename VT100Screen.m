// -*- mode:objc -*-
// $Id: VT100Screen.m,v 1.181 2004-02-15 08:59:16 ujwal Exp $
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
#import <iTerm/NSStringITerm.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYTextView.h>
#import <iTerm/PTYScrollView.h>
#import <iTerm/charmaps.h>
#import <iTerm/PTYSession.h>
#import <iTerm/PTYTask.h>
#import <iTerm/PreferencePanel.h>
#include <string.h>

/* translates normal char into graphics char */
void translate(unichar *s, int len)
{
    int i;
	
    for(i=0;i<len;i++) s[i]=charmap[(int)s[i]];	
}

/* pad the source string whenever double width character appears */
void padString(NSString *s, unichar *buf, char doubleWidth, int *len)
{
    static unichar sc[300]; 
	int l=[s length];
	int i,j;
	
	[s getCharacters:sc];
    for(i=j=0;i<l;i++,j++) {
		buf[j]=sc[i];
		if (doubleWidth&&ISDOUBLEWIDTHCHARACTER(sc[i])) buf[++j]=0xffff;
	}
	*len=j;
}

@implementation VT100Screen

#define DEFAULT_WIDTH     80
#define DEFAULT_HEIGHT    25
#define DEFAULT_FONTSIZE  14
#define DEFAULT_SCROLLBACK 1000

#define MIN_WIDTH     10
#define MIN_HEIGHT    3

#define TABSIZE     8

static BOOL PLAYBELL = YES;


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

    TERMINAL = nil;
    SHELL = nil;

	tempBuffer=NULL;

    scrollbackLines = DEFAULT_SCROLLBACK;
	bufferWrapped = lastBufferLineIndex = 0;
    [self clearTabStop];
    
    // set initial tabs
    int i;
    for(i = TABSIZE; i < TABWINDOW; i += TABSIZE)
        tabStop[i] = YES;

    for(i=0;i<4;i++) saveCharset[i]=charset[i]=0;
     
    return self;
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[VT100Screen dealloc]", __FILE__, __LINE__);
#endif
	free(screenLines);
	free(screenBGColor);
	free(screenFGColor);
	free(dirty);

	if (bufferLines) {
		free(bufferLines);
		free(bufferBGColor);
		free(bufferFGColor);
	}
	
	if (tempBuffer) free(tempBuffer);
	
    [display release];
	[SHELL release];
    [TERMINAL release];
    [SESSION release];
    
    [super dealloc];
}

- (NSString *)description
{
    NSString *basestr;
    //NSString *colstr;
    NSString *result;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen description]", __FILE__, __LINE__);
#endif
    basestr = [NSString stringWithFormat:@"WIDTH %d, HEIGHT %d, CURSOR (%d,%d)",
		   WIDTH, HEIGHT, CURSOR_X, CURSOR_Y];
    //colstr = [STORAGE string];
    result = [NSString stringWithFormat:@"%@\n%@", basestr, @""]; //colstr];

    return result;
}

- (void)setWidth:(int)width height:(int)height
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setWidth:%d height:%d]",
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
    int i, sw;
	unichar *sl, *bl;
	char *sfg, *sbg, *bfg, *bbg;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen resizeWidth:%d height:%d]",
	  __FILE__, __LINE__, width, height);
#endif
	
	if (width==WIDTH&&height==HEIGHT) return;
	
	if (width!=WIDTH&&bufferLines) {
		//copy the buffer over
		bl=(unichar*)malloc(scrollbackLines*width*sizeof(unichar));
		bfg=(char*)malloc(scrollbackLines*width*sizeof(char));
		bbg=(char*)malloc(scrollbackLines*width*sizeof(char));
		memset(bl, 0, width*scrollbackLines*sizeof(unichar));
		memset(bfg, DEFAULT_FG_COLOR_CODE, width*scrollbackLines*sizeof(char));
		memset(bbg, DEFAULT_BG_COLOR_CODE, width*scrollbackLines*sizeof(char));
		
		sw=width<WIDTH?width:WIDTH;
		for(i=0;i<scrollbackLines;i++) {
			memcpy(bl+width*i, bufferLines+WIDTH*i, sw*sizeof(unichar));
			memcpy(bfg+width*i, bufferFGColor+WIDTH*i, sw*sizeof(char));
			memcpy(bbg+width*i, bufferBGColor+WIDTH*i, sw*sizeof(char));
		}
		
		free(bufferLines);
		free(bufferFGColor);
		free(bufferBGColor);
		bufferLines=bl;
		bufferFGColor=bfg;
		bufferBGColor=bbg;
	}

	sl=(unichar*)malloc(height*width*sizeof(unichar));
	sfg=(char*)malloc(height*width*sizeof(char));
	sbg=(char*)malloc(height*width*sizeof(char));
	
	memset(sl, 0, width*height*sizeof(unichar));
	memset(sfg, DEFAULT_FG_COLOR_CODE, width*height*sizeof(char));
	memset(sbg, DEFAULT_BG_COLOR_CODE, width*height*sizeof(char));

	// copy the screen content
	sw=width<WIDTH?width:WIDTH;
	if (HEIGHT<=height) { //new screen is larger, so copy everything over
		for(i=0;i<HEIGHT;i++) {
			memcpy(sl+width*i, screenLines+WIDTH*i, sw*sizeof(unichar));
			memcpy(sfg+width*i, screenFGColor+WIDTH*i, sw*sizeof(char));
			memcpy(sbg+width*i, screenBGColor+WIDTH*i, sw*sizeof(char));
		}
	}
	else { //new screen smaller, so only copy the bottom part
		for(i=HEIGHT-height;i<height;i++) {
			memcpy(sl+width*(i-HEIGHT+height), screenLines+WIDTH*i, sw*sizeof(unichar));
			memcpy(sfg+width*(i-HEIGHT+height), screenFGColor+WIDTH*i, sw*sizeof(char));
			memcpy(sbg+width*(i-HEIGHT+height), screenBGColor+WIDTH*i, sw*sizeof(char));
		}
		if (bufferLines) { //the top part goes into buffer if we have one
			for(i=0;i<HEIGHT-height;i++) {
				memcpy(bufferLines+lastBufferLineIndex*width, screenLines+WIDTH*i, sw*sizeof(unichar));
				memcpy(bufferFGColor+lastBufferLineIndex*width, screenFGColor+WIDTH*i, sw*sizeof(char));
				memcpy(bufferBGColor+lastBufferLineIndex*width, screenBGColor+WIDTH*i, sw*sizeof(char));
				
				if (++lastBufferLineIndex>scrollbackLines) {
					lastBufferLineIndex=0;
					bufferWrapped=1;
				}
			}
		}
		CURSOR_Y-=HEIGHT-height;
		if (CURSOR_Y<0) CURSOR_Y=0;
		SAVE_CURSOR_Y-=HEIGHT-height;
		if (SAVE_CURSOR_Y<0) SAVE_CURSOR_Y=0;
	}
	
	free(screenLines);
	free(screenFGColor);
	free(screenBGColor);
	screenLines=sl;
	screenFGColor=sfg;
	screenBGColor=sbg;
	
	free(dirty);
	dirty=(char*)malloc(height*width*sizeof(char));
	memset(dirty, 1, width*height*sizeof(char));
	
	WIDTH = width;
	HEIGHT = height;
	if (CURSOR_X>=width) CURSOR_X=width-1;
	if (SAVE_CURSOR_X>=width) SAVE_CURSOR_X=width-1;
	SCROLL_TOP = 0;
	SCROLL_BOTTOM = HEIGHT - 1;
	if (tempBuffer) {
		free(tempBuffer);
		tempBuffer=NULL;
	}
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
	unichar *bl;
	char *bfg, *bbg;
	
//    NSLog(@"Scrollback set: %d", lines);
	if (lines) {
		bl=(unichar*)malloc(lines*WIDTH*sizeof(unichar));
		bfg=(char*)malloc(lines*WIDTH*sizeof(char));
		bbg=(char*)malloc(lines*WIDTH*sizeof(char));
		memset(bl, 0, WIDTH*lines*sizeof(unichar));
		memset(bfg, DEFAULT_FG_COLOR_CODE, WIDTH*lines*sizeof(char));
		memset(bbg, DEFAULT_BG_COLOR_CODE, WIDTH*lines*sizeof(char));
		
		if (bufferLines) {
			if (lines<scrollbackLines) { //new buffer smaller
				if (bufferWrapped) {
					if (lastBufferLineIndex<lines) {
						memcpy(bl+(lines-lastBufferLineIndex)*WIDTH,
							   bufferLines,lastBufferLineIndex*WIDTH*sizeof(unichar));
						memcpy(bfg+(lines-lastBufferLineIndex)*WIDTH,
							   bufferFGColor,lastBufferLineIndex*WIDTH*sizeof(char));
						memcpy(bbg+(lines-lastBufferLineIndex)*WIDTH,
							   bufferBGColor,lastBufferLineIndex*WIDTH*sizeof(char));
						memcpy(bl, bufferLines+(scrollbackLines-lines+lastBufferLineIndex)*WIDTH, 
							   (lines-lastBufferLineIndex)*WIDTH*sizeof(unichar));
						memcpy(bfg, bufferFGColor+(scrollbackLines-lines+lastBufferLineIndex)*WIDTH,
							   (lines-lastBufferLineIndex)*WIDTH*sizeof(char));
						memcpy(bbg, bufferBGColor+(scrollbackLines-lines+lastBufferLineIndex)*WIDTH,
							   (lines-lastBufferLineIndex)*WIDTH*sizeof(char));
					}
					else {
						memcpy(bl, bufferLines+(lastBufferLineIndex-lines)*WIDTH,(lastBufferLineIndex-lines)*WIDTH*sizeof(unichar));
						memcpy(bfg, bufferFGColor+(lastBufferLineIndex-lines)*WIDTH,(lastBufferLineIndex-lines)*WIDTH*sizeof(char));
						memcpy(bbg, bufferBGColor+(lastBufferLineIndex-lines)*WIDTH,(lastBufferLineIndex-lines)*WIDTH*sizeof(char));
					}				
					lastBufferLineIndex=0;
					bufferWrapped=1;
				}
				else {
					if (lastBufferLineIndex<lines) {
						memcpy(bl, bufferLines,lastBufferLineIndex*WIDTH*sizeof(unichar));
						memcpy(bfg, bufferFGColor,lastBufferLineIndex*WIDTH*sizeof(char));
						memcpy(bbg, bufferBGColor,lastBufferLineIndex*WIDTH*sizeof(char));
						bufferWrapped=0;
					}
					else {
						memcpy(bl, bufferLines,lines*WIDTH*sizeof(unichar));
						memcpy(bfg, bufferFGColor,lines*WIDTH*sizeof(char));
						memcpy(bbg, bufferBGColor,lines*WIDTH*sizeof(char));
						lastBufferLineIndex=0;
						bufferWrapped=1;
					}				
				}
			}
			else { //new buffer larger
				if (bufferWrapped) {
					memcpy(bl, bufferLines+(scrollbackLines-lastBufferLineIndex)*WIDTH,(scrollbackLines-lastBufferLineIndex)*WIDTH*sizeof(unichar));
					memcpy(bfg, bufferFGColor+(scrollbackLines-lastBufferLineIndex)*WIDTH,(scrollbackLines-lastBufferLineIndex)*WIDTH*sizeof(char));
					memcpy(bbg, bufferBGColor+(scrollbackLines-lastBufferLineIndex)*WIDTH,(scrollbackLines-lastBufferLineIndex)*WIDTH*sizeof(char));
					memcpy(bl+(scrollbackLines-lastBufferLineIndex)*WIDTH,bufferLines+WIDTH*lastBufferLineIndex,WIDTH*lastBufferLineIndex*sizeof(unichar));
					memcpy(bfg+(scrollbackLines-lastBufferLineIndex)*WIDTH,bufferFGColor+WIDTH*lastBufferLineIndex,WIDTH*lastBufferLineIndex*sizeof(char));
					memcpy(bbg+(scrollbackLines-lastBufferLineIndex)*WIDTH,bufferBGColor+WIDTH*lastBufferLineIndex,WIDTH*lastBufferLineIndex*sizeof(char));
					lastBufferLineIndex=scrollbackLines;
				}
				else {
					memcpy(bl, bufferLines,lastBufferLineIndex*WIDTH*sizeof(unichar));
					memcpy(bfg, bufferFGColor,lastBufferLineIndex*WIDTH*sizeof(char));
					memcpy(bbg, bufferBGColor,lastBufferLineIndex*WIDTH*sizeof(char));
				}
				bufferWrapped=0;
			}
					
			free(bufferLines);
			free(bufferFGColor);
			free(bufferBGColor);
		}
		bufferLines=bl;
		bufferFGColor=bfg;
		bufferBGColor=bbg;
	}
	else { // no buffer
		if (bufferLines) {
			free(bufferLines);
			free(bufferFGColor);
			free(bufferBGColor);
		}
		bufferLines=NULL;
	}
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

-(void) initScreenWithWidth:(int)width Height:(int)height
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen initScreenWithWidth:%d Height:%d]", __FILE__, __LINE__, width, height );
#endif

	WIDTH=width;
	HEIGHT=height;
	screenLines=(unichar*)malloc(HEIGHT*WIDTH*sizeof(unichar));
	screenFGColor=(char*)malloc(HEIGHT*WIDTH*sizeof(char));
	screenBGColor=(char*)malloc(HEIGHT*WIDTH*sizeof(char));
	dirty=(char*)malloc(HEIGHT*WIDTH*sizeof(char));

	if (scrollbackLines) {
		bufferLines=(unichar*)malloc(scrollbackLines*WIDTH*sizeof(unichar));
		bufferFGColor=(char*)malloc(scrollbackLines*WIDTH*sizeof(char));
		bufferBGColor=(char*)malloc(scrollbackLines*WIDTH*sizeof(char));
	}
	else bufferLines=NULL;
	
	[self clearBuffer];
    blinkShow=YES;
}

- (void)putToken:(VT100TCC)token
{
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen putToken:%d]",__FILE__, __LINE__, token);
#endif
    int i,j;

    // If we are in print mode, send to printer.
    if([TERMINAL printToAnsi] == YES && token.type != ANSICSI_PRINT)
    {
	[TERMINAL printToken: token];
	return;
    }
    
    switch (token.type) {
    // our special code
    case VT100_STRING:
        [self setString:token.u.string];
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
		for (i=0;i<HEIGHT*WIDTH;i++) {
				screenLines[i]='E';
		}
		memset(dirty,1,HEIGHT*WIDTH);
		memset(screenFGColor,DEFAULT_FG_COLOR_CODE,HEIGHT*WIDTH);
		memset(screenBGColor,DEFAULT_BG_COLOR_CODE,HEIGHT*WIDTH);
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
            [[SESSION parent] resizeWindow:([TERMINAL columnMode]?132:80)
                                    height:HEIGHT];
            [[SESSION TEXTVIEW] scrollEnd];
        }
        break;

    // ANSI CSI
    case ANSICSI_CHA:
        [self cursorToX: token.u.csi.p[0]];
	break;
    case ANSICSI_VPA:
        [self cursorToX: CURSOR_X+1 Y: token.u.csi.p[0]];
        break;
    case ANSICSI_VPR:
        [self cursorToX: CURSOR_X+1 Y: token.u.csi.p[0]+CURSOR_Y+1];
        break;
    case ANSICSI_ECH:
		i=WIDTH*CURSOR_Y+CURSOR_X;
		j=token.u.csi.p[0]<=WIDTH?token.u.csi.p[0]:WIDTH;
		memcpy(screenLines+i,0,j*sizeof(unichar));
		memset(screenFGColor+i,[TERMINAL foregroundColorCode],j);
		memset(screenBGColor+i,[TERMINAL backgroundColorCode],j);
		memset(dirty+i,1,j);
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
    
	[self clearScreen];
	[self clearScrollbackBuffer];
	
}

- (void)clearScrollbackBuffer
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen clearScrollbackBuffer]",  __FILE__, __LINE__ );
#endif

	if (bufferLines) {
		memset(bufferLines,0,scrollbackLines*WIDTH*sizeof(unichar));
		memset(bufferFGColor,DEFAULT_FG_COLOR_CODE,scrollbackLines*WIDTH*sizeof(char));
		memset(bufferBGColor,DEFAULT_BG_COLOR_CODE,scrollbackLines*WIDTH*sizeof(char));
	}
	
	bufferWrapped = lastBufferLineIndex = 0;
	[(PTYTextView *) display refresh];
}

- (void) saveBuffer
{	
	if (tempBuffer) free(tempBuffer);
	tempBuffer=(unichar*)malloc(WIDTH*HEIGHT*sizeof(unichar));
	memcpy(tempBuffer, screenLines, WIDTH*HEIGHT*sizeof(unichar));
}

- (void) restoreBuffer
{	
	if (!tempBuffer) return;
	memcpy(screenLines, tempBuffer, WIDTH*HEIGHT*sizeof(unichar));
	free(tempBuffer);
	tempBuffer=NULL;
}


- (void)setString:(NSString *)string
{
    int idx, screenIdx;
    int j, len, newx;
	unichar buffer[300];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setString:%@ at %d]",
          __FILE__, __LINE__, string, CURSOR_X);
#endif

	if ([string length] < 1 || !string || [string length] > 300) 
	{
		NSLog(@"%s: invalid string '%@'", __PRETTY_FUNCTION__, string);
		return;		
	}
	
	padString(string,buffer,[SESSION doubleWidth], &len);
	
	// check for graphical characters
	if (charset[[TERMINAL charset]]) 
		translate(buffer,len);
	//    NSLog(@"%d(%d):%@",[TERMINAL charset],charset[[TERMINAL charset]],string);
	//NSLog(@"string:%s",s);
	
    if (len < 1) 
		return;

    for(idx = 0; idx < len;) 
	{
        if (CURSOR_X >= WIDTH) 
		{
            if ([TERMINAL wraparoundMode]) 
			{
                CURSOR_X=0;    
				[self setNewLine];
				//break;
            }
            else 
			{
                CURSOR_X=WIDTH-1;
                idx=len-1;
            }
        }
		if(WIDTH - CURSOR_X <= len - idx) 
			newx = WIDTH;
		else 
			newx = CURSOR_X + len - idx;
		j = newx - CURSOR_X;

		if (j <= 0) {
			//NSLog(@"setASCIIString: output length=0?(%d+%d)%d+%d",CURSOR_X,j,idx2,len);
			break;
		}
		
		screenIdx = CURSOR_Y * WIDTH;
		
        if ([TERMINAL insertMode]) 
		{
			if (CURSOR_X + j < WIDTH) 
			{
				memmove(screenLines+screenIdx+CURSOR_X+j,screenLines+screenIdx+CURSOR_X,(WIDTH-CURSOR_X-j)*sizeof(unichar));
				memmove(screenFGColor+screenIdx+CURSOR_X+j,screenFGColor+screenIdx+CURSOR_X,(WIDTH-CURSOR_X-j)*sizeof(char));
				memmove(screenBGColor+screenIdx+CURSOR_X+j,screenBGColor+screenIdx+CURSOR_X,(WIDTH-CURSOR_X-j)*sizeof(char));
				memset(dirty+screenIdx+CURSOR_X,1,WIDTH-CURSOR_X);
			}
		}
		memcpy(screenLines + screenIdx + CURSOR_X, buffer + idx, j * sizeof(unichar));
		memset(screenFGColor + screenIdx + CURSOR_X, [TERMINAL foregroundColorCode], j);
		memset(screenBGColor + screenIdx + CURSOR_X, [TERMINAL backgroundColorCode], j);
		memset(dirty+screenIdx+CURSOR_X,1,j);
		
		CURSOR_X = newx;
		idx += j;
    }
#if DEBUG_METHOD_TRACE
    NSLog(@"setString done at %d", CURSOR_X);
#endif
}
        
- (void)setStringToX:(int)x
				   Y:(int)y
			  string:(NSString *)string 
{
    int sx, sy;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setStringToX:%d Y:%d string:%@]",
          __FILE__, __LINE__, x, y, string);
#endif

    sx = CURSOR_X;
    sy = CURSOR_Y;
    CURSOR_X = x;
    CURSOR_Y = y;
    [self setString:string]; 
    CURSOR_X = sx;
    CURSOR_Y = sy;
}

- (void)setNewLine
{
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen setNewLine](%d,%d)-[%d,%d]", __FILE__, __LINE__, CURSOR_X, CURSOR_Y, SCROLL_TOP, SCROLL_BOTTOM);
#endif

    if (CURSOR_Y  < SCROLL_BOTTOM || (CURSOR_Y < (HEIGHT - 1) && CURSOR_Y > SCROLL_BOTTOM)) {
        CURSOR_Y++;
    }
    else if (SCROLL_TOP == 0 && SCROLL_BOTTOM == HEIGHT - 1) {
		//move a line into buffer
		if (bufferLines) {
			memcpy(bufferLines+lastBufferLineIndex*WIDTH, screenLines, WIDTH*sizeof(unichar));
			memcpy(bufferFGColor+lastBufferLineIndex*WIDTH, screenFGColor, WIDTH*sizeof(char));
			memcpy(bufferBGColor+lastBufferLineIndex*WIDTH, screenBGColor, WIDTH*sizeof(char));
			lastBufferLineIndex++;
			if (lastBufferLineIndex>scrollbackLines) {
				lastBufferLineIndex=0;
				bufferWrapped=1;
			}
		}
		memmove(screenLines,screenLines+WIDTH,(HEIGHT-1)*WIDTH*sizeof(unichar));
		memset(screenLines+WIDTH*(HEIGHT-1),0,WIDTH*sizeof(unichar));
		memset(screenFGColor+WIDTH*(HEIGHT-1),DEFAULT_FG_COLOR_CODE,WIDTH*sizeof(char));
		memset(screenBGColor+WIDTH*(HEIGHT-1),DEFAULT_BG_COLOR_CODE,WIDTH*sizeof(char));
		memset(dirty,1,WIDTH*HEIGHT*sizeof(char));
    }
    else {
        [self scrollUp];
    }
}

- (void)deleteCharacters:(int) n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deleteCharacter]: %d", __FILE__, __LINE__, n);
#endif

    if (CURSOR_X >= 0 && CURSOR_X < WIDTH &&
        CURSOR_Y >= 0 && CURSOR_Y < HEIGHT)
    {
		int idx;
		
		idx=CURSOR_Y*WIDTH;		
		if (n+CURSOR_X>WIDTH) n=WIDTH-CURSOR_X;
		if (n<WIDTH) {
			memmove(screenLines+idx+CURSOR_X, screenLines+idx+CURSOR_X+n, (WIDTH-CURSOR_X-n)*sizeof(unichar));
			memmove(screenFGColor+idx+CURSOR_X, screenFGColor+idx+CURSOR_X+n, (WIDTH-CURSOR_X-n)*sizeof(char));
			memmove(screenBGColor+idx+CURSOR_X, screenBGColor+idx+CURSOR_X+n, (WIDTH-CURSOR_X-n)*sizeof(char));
		}
		memset(screenLines+idx+WIDTH-n,0,n*sizeof(unichar));
		memset(screenFGColor+idx+WIDTH-n,[TERMINAL foregroundColorCode],n*sizeof(char));
		memset(screenBGColor+idx+WIDTH-n,[TERMINAL backgroundColorCode],n*sizeof(char));
		memset(dirty+idx+CURSOR_X,1,WIDTH-CURSOR_X);
    }
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
	memset(screenLines,0,HEIGHT*WIDTH*sizeof(unichar));
	memset(screenFGColor,DEFAULT_FG_COLOR_CODE,HEIGHT*WIDTH*sizeof(char));
	memset(screenBGColor,DEFAULT_BG_COLOR_CODE,HEIGHT*WIDTH*sizeof(char));
	memset(dirty,1,HEIGHT*WIDTH*sizeof(char));

	CURSOR_X = CURSOR_Y = 0;

}

- (void)eraseInDisplay:(VT100TCC)token
{
    int x1, y1, x2, y2;	

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen eraseInDisplay:(param=%d)]",
          __FILE__, __LINE__, token.u.csi.p[0]);
#endif
    switch (token.u.csi.p[0]) {
    case 1:
        x1 = 0;
        y1 = 0;
        x2 = CURSOR_X+1;
        y2 = CURSOR_Y;
        break;

    case 2:
        x1 = 0;
        y1 = 0;
        x2 = WIDTH;
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
	

	int idx1, idx2;
	
	idx1=y1*WIDTH+x1;
	idx2=y2*WIDTH+x2;
	
	// If we are the top of the screen, move the contents to the scollback buffer
	if(y1 == 0 && bufferLines)
	{
		memcpy(bufferLines+lastBufferLineIndex*WIDTH, screenLines+idx1, (idx2-idx1)*sizeof(unichar));
		memcpy(bufferFGColor+lastBufferLineIndex*WIDTH, screenFGColor+idx1, (idx2-idx1)*sizeof(char));
		memcpy(bufferBGColor+lastBufferLineIndex*WIDTH, screenBGColor+idx1, (idx2-idx1)*sizeof(char));
		lastBufferLineIndex += (idx2-idx1)/WIDTH;
		if (lastBufferLineIndex>scrollbackLines) {
			lastBufferLineIndex=0;
			bufferWrapped=1;
		}		
	}
	
	memset(screenLines+idx1,0,(idx2-idx1)*sizeof(unichar));
	memset(screenFGColor+idx1,[TERMINAL foregroundColorCode],(idx2-idx1)*sizeof(char));
	memset(screenBGColor+idx1,[TERMINAL backgroundColorCode],(idx2-idx1)*sizeof(char));
	memset(dirty+idx1,1,(idx2-idx1)*sizeof(char));
}

- (void)eraseInLine:(VT100TCC)token
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen eraseInLine:(param=%d)]",
          __FILE__, __LINE__, token.u.csi.p[0]);
#endif

	int idx, x1 ,x2;
	
    switch (token.u.csi.p[0]) {
    case 1:
		x1=0;
		x2=CURSOR_X+1;
        break;
    case 2:
		x1 = 0;
		x2 = WIDTH;
		break;
    case 0:
		x1=CURSOR_X;
		x2=WIDTH;
		break;
	}
	idx=CURSOR_Y*WIDTH+x1;
	memset(screenLines+idx,0,(x2-x1)*sizeof(unichar));
	memset(screenFGColor+idx,[TERMINAL foregroundColorCode],(x2-x1)*sizeof(char));
	memset(screenBGColor+idx,[TERMINAL backgroundColorCode],(x2-x1)*sizeof(char));
	memset(dirty+idx,1,(x2-x1)*sizeof(char));
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
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen scrollUp]", __FILE__, __LINE__);
#endif

    NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM );

    if ((SCROLL_BOTTOM >= HEIGHT-1 || SCROLL_TOP == 0) && bufferLines) {
		// move a line to buffer
		memcpy(bufferLines+lastBufferLineIndex*WIDTH,screenLines+SCROLL_TOP*WIDTH,WIDTH*sizeof(unichar));
		memcpy(bufferFGColor+lastBufferLineIndex*WIDTH,screenFGColor+SCROLL_TOP*WIDTH,WIDTH*sizeof(char));
		memcpy(bufferBGColor+lastBufferLineIndex*WIDTH,screenBGColor+SCROLL_TOP*WIDTH,WIDTH*sizeof(char));
		if (++lastBufferLineIndex>scrollbackLines) {
			lastBufferLineIndex=0;
			bufferWrapped=1;
		}
	}
	
	if (SCROLL_TOP<SCROLL_BOTTOM) {
		memmove(screenLines+SCROLL_TOP*WIDTH, screenLines+(SCROLL_TOP+1)*WIDTH, (SCROLL_BOTTOM-SCROLL_TOP)*WIDTH*sizeof(unichar));
		memmove(screenFGColor+SCROLL_TOP*WIDTH, screenFGColor+(SCROLL_TOP+1)*WIDTH, (SCROLL_BOTTOM-SCROLL_TOP)*WIDTH*sizeof(char));
		memmove(screenBGColor+SCROLL_TOP*WIDTH, screenBGColor+(SCROLL_TOP+1)*WIDTH, (SCROLL_BOTTOM-SCROLL_TOP)*WIDTH*sizeof(char));
	}
	memset(screenLines+SCROLL_BOTTOM*WIDTH,0,WIDTH*sizeof(unichar));
	memset(screenFGColor+SCROLL_BOTTOM*WIDTH,[TERMINAL foregroundColorCode],WIDTH*sizeof(char));
	memset(screenBGColor+SCROLL_BOTTOM*WIDTH,[TERMINAL backgroundColorCode],WIDTH*sizeof(char));
	memset(dirty+SCROLL_TOP*WIDTH,1,(SCROLL_BOTTOM-SCROLL_TOP+1)*WIDTH*sizeof(char));
//    else if(CURSOR_Y <= SCROLL_BOTTOM) {
}

- (void)scrollDown
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen scrollDown]", __FILE__, __LINE__);
#endif
    NSParameterAssert(SCROLL_TOP >= 0 && SCROLL_TOP < HEIGHT);
    NSParameterAssert(SCROLL_BOTTOM >= 0 && SCROLL_BOTTOM < HEIGHT);
    NSParameterAssert(SCROLL_TOP <= SCROLL_BOTTOM );
	
	if (SCROLL_TOP<SCROLL_BOTTOM) {
		memmove(screenLines+(SCROLL_TOP+1)*WIDTH, screenLines+(SCROLL_TOP)*WIDTH, (SCROLL_BOTTOM-SCROLL_TOP)*WIDTH*sizeof(unichar));
		memmove(screenFGColor+(SCROLL_TOP+1)*WIDTH, screenFGColor+(SCROLL_TOP)*WIDTH, (SCROLL_BOTTOM-SCROLL_TOP)*WIDTH*sizeof(char));
		memmove(screenBGColor+(SCROLL_TOP+1)*WIDTH, screenBGColor+(SCROLL_TOP)*WIDTH, (SCROLL_BOTTOM-SCROLL_TOP)*WIDTH*sizeof(char));
	}
	memset(screenLines+SCROLL_TOP*WIDTH,0,WIDTH*sizeof(unichar));
	memset(screenFGColor+SCROLL_TOP*WIDTH,[TERMINAL foregroundColorCode],WIDTH*sizeof(char));
	memset(screenBGColor+SCROLL_TOP*WIDTH,[TERMINAL backgroundColorCode],WIDTH*sizeof(char));
	memset(dirty+SCROLL_TOP*WIDTH,1,(SCROLL_BOTTOM-SCROLL_TOP+1)*WIDTH*sizeof(char));    
}

- (void) insertBlank: (int)n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen insertBlank; %d]", __FILE__, __LINE__, n);
#endif

 
//    NSLog(@"insertBlank[%d@(%d,%d)]",n,CURSOR_X,CURSOR_Y);

	int screenIdx=CURSOR_Y*WIDTH+CURSOR_X;
	
	memmove(screenLines+screenIdx+n,screenLines+screenIdx,(WIDTH-CURSOR_X-n)*sizeof(unichar));
	memmove(screenFGColor+screenIdx+n,screenFGColor+screenIdx,(WIDTH-CURSOR_X-n)*sizeof(char));
	memmove(screenBGColor+screenIdx+n,screenBGColor+screenIdx,(WIDTH-CURSOR_X-n)*sizeof(char));

	memset(screenLines+screenIdx,0,n*sizeof(unichar));
	memset(screenFGColor+screenIdx,[TERMINAL foregroundColorCode],n);
	memset(screenBGColor+screenIdx,[TERMINAL backgroundColorCode],n);
	
	memset(dirty+screenIdx,1,WIDTH-CURSOR_X);
	
}

- (void) insertLines: (int)n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen insertLines; %d]", __FILE__, __LINE__, n);
#endif
    
    int idx1, idx2, len;
    
//    NSLog(@"insertLines %d[%d,%d]",n, CURSOR_X,CURSOR_Y);
	idx1=CURSOR_Y*WIDTH;
	if (n+CURSOR_Y<SCROLL_BOTTOM) {
		idx2=(CURSOR_Y+n)*WIDTH;
		len=(SCROLL_BOTTOM-n-CURSOR_Y+1)*WIDTH;
		memmove(screenLines+idx2, screenLines+idx1, len*sizeof(unichar));
		memmove(screenFGColor+idx2, screenFGColor+idx1, len*sizeof(char));
		memmove(screenBGColor+idx2, screenBGColor+idx1, len*sizeof(char));
	}
	if (n+CURSOR_Y>SCROLL_BOTTOM) n=SCROLL_BOTTOM-CURSOR_Y+1;
	len=n*WIDTH;
	memset(screenLines+idx1, 0, len*sizeof(unichar));
	memset(screenFGColor+idx1,[TERMINAL foregroundColorCode],len);
	memset(screenBGColor+idx1,[TERMINAL backgroundColorCode],len);
	
	memset(dirty+idx1,1,(SCROLL_BOTTOM-CURSOR_Y+1)*WIDTH);
}

- (void) deleteLines: (int)n
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen deleteLines; %d]", __FILE__, __LINE__, n);
#endif

	int idx1, idx2, len;
    
	//    NSLog(@"insertLines %d[%d,%d]",n, CURSOR_X,CURSOR_Y);
	idx1=CURSOR_Y*WIDTH;
	if (n+CURSOR_Y<SCROLL_BOTTOM) {
		idx2=(CURSOR_Y+n)*WIDTH;
		len=(SCROLL_BOTTOM-n-CURSOR_Y+1)*WIDTH;
		memmove(screenLines+idx1, screenLines+idx2, len*sizeof(unichar));
		memmove(screenFGColor+idx1, screenFGColor+idx2, len*sizeof(char));
		memmove(screenBGColor+idx1, screenBGColor+idx2, len*sizeof(char));
	}
	if (n+CURSOR_Y>SCROLL_BOTTOM) n=SCROLL_BOTTOM-CURSOR_Y+1;
	idx2=(SCROLL_BOTTOM-n+1)*WIDTH;
	len=n*WIDTH;
	memset(screenLines+idx2, 0, len*sizeof(unichar));
	memset(screenFGColor+idx2,[TERMINAL foregroundColorCode],len);
	memset(screenBGColor+idx2,[TERMINAL backgroundColorCode],len);
	
	memset(dirty+idx1,1,(SCROLL_BOTTOM-CURSOR_Y+1)*WIDTH);
	
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

- (void)blink
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen blink]", __FILE__, __LINE__);
#endif
	int i;
	BOOL b=NO;
	
	for (i=0; i<WIDTH*HEIGHT; i++) {
		if (screenFGColor[i]&BLINK_MASK) { dirty[i]=1; b=YES; }
	}
    if (b) [(PTYTextView *)display refresh];
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

- (int) numberOfLines
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[VT100Screen numberOfLines]",  __FILE__, __LINE__ );
#endif
        
    return ((bufferWrapped?scrollbackLines:lastBufferLineIndex)+HEIGHT);
}

- (int) lastBufferLineIndex;
{
	return lastBufferLineIndex;
}

- (void) updateScreen
{
    [(PTYTextView *)display refresh];
}

- (unichar *)screenLines{ return screenLines; }
- (char *)screenBGColor { return screenBGColor; }
- (char	*)screenFGColor { return screenFGColor; }
- (char	*)dirty			{ return dirty; }

- (unichar *)bufferLines{ return bufferLines; }
- (char *)bufferBGColor { return bufferBGColor; }
- (char	*)bufferFGColor { return bufferFGColor; }

- (void)resetDirty
{
	memset(dirty,0,WIDTH*HEIGHT*sizeof(char));
}

- (void)setDirty
{
	memset(dirty,1,WIDTH*HEIGHT*sizeof(char));
}

@end

