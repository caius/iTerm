// -*- mode:objc -*-
// $Id: VT100Screen.h,v 1.10 2004-03-14 06:05:38 ujwal Exp $
/*
 **  VT100Screen.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
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

#import <Cocoa/Cocoa.h>
#import <iTerm/VT100Terminal.h>

#define ISDOUBLEWIDTHCHARACTER(c) ((c)>=0x1000)

@class PTYTask;
@class PTYSession;
@class PTYTextView;

#define TABWINDOW	300

@interface VT100Screen : NSObject
{
    int WIDTH;
    int HEIGHT;
    int CURSOR_X;
    int CURSOR_Y;
    int SAVE_CURSOR_X;
    int SAVE_CURSOR_Y;
    int cursorIndex;
    int SCROLL_TOP;
    int SCROLL_BOTTOM;
    BOOL tabStop[TABWINDOW];
    BOOL CURSOR_IN_MIDDLE;

    VT100Terminal *TERMINAL;
    PTYTask *SHELL;
    PTYSession *SESSION;
    int charset[4], saveCharset[4];
    BOOL blinkShow;

    
    BOOL blinkingCursor;
    PTYTextView *display;
	
	unichar *screenLines;
	char	*screenBGColor;
	char	*screenFGColor;
	char	*dirty;

	unichar *bufferLines;
	char	*bufferBGColor;
	char	*bufferFGColor;
    unsigned int  scrollbackLines;
	
	int		bufferWrapped, lastBufferLineIndex;
	
	char *tempBuffer;
}

+ (void)setPlayBellFlag:(BOOL)flag;

- (id)init;
- (void)dealloc;

- (NSString *)description;

- (void)initScreenWithWidth:(int)width Height:(int)height;
- (void)resizeWidth:(int)width height:(int)height;
- (void)setWidth:(int)width height:(int)height;
- (int)width;
- (int)height;
- (unsigned int)scrollbackLines;
- (void)setScrollback:(unsigned int)lines;
- (void)setTerminal:(VT100Terminal *)terminal;
- (VT100Terminal *)terminal;
- (void)setShellTask:(PTYTask *)shell;
- (PTYTask *)shellTask;
- (PTYSession *) session;
- (void)setSession:(PTYSession *)session;

- (PTYTextView *) display;
- (void) setDisplay: (PTYTextView *) aDisplay;

- (BOOL) blinkingCursor;
- (void) setBlinkingCursor: (BOOL) flag;


// edit screen buffer
- (void)putToken:(VT100TCC)token;
- (void)clearBuffer;
- (void)clearScrollbackBuffer;
- (void)saveBuffer;
- (void)restoreBuffer;

// internal
- (void)setString:(NSString *)s;
- (void)setStringToX:(int)x
				   Y:(int)y
			  string:(NSString *)string;
- (void)setNewLine;
- (void)deleteCharacters:(int)n;
- (void)backSpace;
- (void)setTab;
- (void)clearTabStop;
- (void)clearScreen;
- (void)eraseInDisplay:(VT100TCC)token;
- (void)eraseInLine:(VT100TCC)token;
- (void)selectGraphicRendition:(VT100TCC)token;
- (void)cursorLeft:(int)n;
- (void)cursorRight:(int)n;
- (void)cursorUp:(int)n;
- (void)cursorDown:(int)n;
- (void)cursorToX: (int) x;
- (void)cursorToX:(int)x Y:(int)y; 
- (void)saveCursorPosition;
- (void)restoreCursorPosition;
- (void)setTopBottom:(VT100TCC)token;
- (void)scrollUp;
- (void)scrollDown;
- (void)playBell;
- (void)deviceReport:(VT100TCC)token;
- (void)deviceAttribute:(VT100TCC)token;
- (void)insertBlank: (int)n;
- (void)insertLines: (int)n;
- (void)deleteLines: (int)n;
- (void)blink;
- (int) cursorX;
- (int) cursorY;

- (void)updateScreen;
- (int) numberOfLines;
- (int) lastBufferLineIndex;

- (unichar *)screenLines;
- (char *)screenBGColor;
- (char	*)screenFGColor;
- (char	*)dirty;

- (unichar *)bufferLines;
- (char *)bufferBGColor;
- (char	*)bufferFGColor;

- (void)resetDirty;
- (void)setDirty;

@end
