// -*- mode:objc -*-
// $Id: VT100Screen.h,v 1.1.1.1 2002-11-26 04:56:50 ujwal Exp $
//
//  VT100Screen.h
//  JTerminal
//
//  Created by kuma on Thu Jan 24 2002.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VT100Terminal.h"
#import "PTYTask.h"
#import "PTYSession.h"

@interface VT100Screen : NSObject
{
    int WIDTH;
    int HEIGHT;
    int CURSOR_X;
    int CURSOR_Y;
    int SAVE_CURSOR_X;
    int SAVE_CURSOR_Y;
    int SCROLL_TOP;
    int SCROLL_BOTTOM;
    BOOL CURSOR_IN_MIDDLE;

    NSTextStorage *STORAGE;
    NSFont *FONT;
    NSSize FONT_SIZE;
    VT100Terminal *TERMINAL;
    PTYTask *SHELL;
    PTYSession *SESSION;
    NSWindow *WINDOW; 

    unsigned int  TOP_LINE;
    unsigned int  LINE_LIMIT;
    unsigned int  OLD_CURSOR_INDEX;
}

+ (NSSize)requireSizeWithFont:(NSFont *)font
			width:(int)width
		       height:(int)height;
+ (NSSize)requireSizeWithFont:(NSFont *)font;
+ (NSSize)screenSizeInFrame:(NSRect)frame  font:(NSFont *)font;
+ (void)setPlayBellFlag:(BOOL)flag;

- (id)init;
- (void)dealloc;

- (NSString *)description;

- (void)initScreen;
- (void)setWidth:(int)width height:(int)height;
- (void)resizeWidth:(int)width height:(int)height;
- (int)width;
- (int)height;

- (void)setTerminal:(VT100Terminal *)terminal;
- (VT100Terminal *)terminal;
- (void)setShellTask:(PTYTask *)shell;
- (PTYTask *)shellTask;
- (NSWindow *) window;
- (void)setWindow:(NSWindow *)window;
- (void)setSession:(PTYSession *)session;

- (void)setTextStorage:(NSTextStorage *)storage;
- (NSTextStorage *)textStorage;
- (void)beginEditing;
- (void)endEditing;
- (void)setFont:(NSFont *)font;
- (NSFont *)font;
- (void)setLineLimit:(unsigned int)maxline;

// edit screen buffer
- (void)putToken:(VT100TCC)token;
- (void)clearBuffer;

// internal
- (void)setString:(NSString *)s;
- (void)setStringToX:(int)x
                   Y:(int)y
                     string:(NSString *)string;
- (void)setStringSpaceToX:(int)x Y:(int)y length:(int)len;
- (void)setNewLine;
- (void)deleteCharacters:(int)n;
- (void)backSpace;
- (void)setTab;
- (void)clearScreen;
- (void)eraseInDisplay:(VT100TCC)token;
- (void)eraseInLine:(VT100TCC)token;
- (void)selectGraphicRendition:(VT100TCC)token;
- (void)cursorLeft:(int)n;
- (void)cursorRight:(int)n;
- (void)cursorUp:(int)n;
- (void)cursorDown:(int)n;
- (void)cursorToX:(int)x Y:(int)y; 
- (void)saveCursorPosition;
- (void)restoreCursorPosition;
- (void)setTopBottom:(VT100TCC)token;
- (void)scrollUp;
- (void)scrollDown;
- (void)playBell;
- (void)removeOverLine;
- (void)deviceReport:(VT100TCC)token;
- (void)deviceAttribute:(VT100TCC)token;
- (void)insertBlank: (int)n;
- (void)insertLines: (int)n;
- (void)deleteLines: (int)n;

- (void)showCursor;
- (void)showCursor:(BOOL)show;
- (void)blink;

- (NSMutableDictionary *)characterAttributeDictionary;
- (NSAttributedString *)attrStringFromChar:(unichar) c;
- (NSAttributedString *)attrString:(NSString *)str;
- (NSString *)fullLine;
- (int) getIndex:(int)x y:(int)y;
- (BOOL) isDoubleWidthCharacter:(unichar)code;


@end
