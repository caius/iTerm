// -*- mode:objc -*-
// $Id: VT100Terminal.h,v 1.28 2003-04-29 00:22:39 yfabian Exp $
/*
 **  VT100Terminal.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the model class VT100 terminal.
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

@class VT100Screen;

// VT100TCC types
#define VT100CC_NULL        0
#define VT100CC_ENQ         5    // Transmit ANSWERBACK message
#define VT100CC_BEL         7    // Sound bell
#define VT100CC_BS          8    // Move cursor to the left
#define VT100CC_HT          9    // Move cursor to the next tab stop
#define VT100CC_LF         10    // line feed or new line operation
#define VT100CC_VT         11    // Same as <LF>.
#define VT100CC_FF         12	 // Same as <LF>.
#define VT100CC_CR         13    // Move the cursor to the left margin
#define VT100CC_SO         14    // Invoke the G1 character set
#define VT100CC_SI         15    // Invoke the G0 character set
#define VT100CC_DC1        17    // Causes terminal to resume transmission (XON).
#define VT100CC_DC3        19    // Causes terminal to stop transmitting all codes except XOFF and XON (XOFF).
#define VT100CC_CAN        24    // Cancel a control sequence
#define VT100CC_SUB        26    // Same as <CAN>.
#define VT100CC_ESC        27    // Introduces a control sequence.
#define VT100CC_DEL       255    // Ignored on input; not stored in buffer.
                                                                              
#define VT100_WAIT        	1000
#define VT100_NOTSUPPORT  	1001
#define VT100_SKIP        	1002
#define VT100_STRING      	1003       // string
#define VT100_ASCIISTRING	1004	   // ASCII string
#define VT100_UNKNOWNCHAR 	1005
#define VT100CSI_DECSET		1006
#define VT100CSI_DECRST		1007

#define VT100CSI_CPR         2000       // Cursor Position Report
#define VT100CSI_CUB         2001       // Cursor Backward
#define VT100CSI_CUD         2002       // Cursor Down
#define VT100CSI_CUF         2003       // Cursor Forward
#define VT100CSI_CUP         2004       // Cursor Position
#define VT100CSI_CUU         2005       // Cursor Up
#define VT100CSI_DA          2006       // Device Attributes
#define VT100CSI_DECALN	     2007	// Screen Alignment Display
#define VT100CSI_DECDHL      2013       // Double Height Line
#define VT100CSI_DECDWL      2014       // Double Width Line
#define VT100CSI_DECID       2015       // Identify Terminal
#define VT100CSI_DECKPAM     2017       // Keypad Application Mode
#define VT100CSI_DECKPNM     2018       // Keypad Numeric Mode
#define VT100CSI_DECLL       2019       // Load LEDS
#define VT100CSI_DECRC       2021       // Restore Cursor
#define VT100CSI_DECREPTPARM 2022       // Report Terminal Parameters
#define VT100CSI_DECREQTPARM 2023       // Request Terminal Parameters
#define VT100CSI_DECSC       2024       // Save Cursor
#define VT100CSI_DECSTBM     2027       // Set Top and Bottom Margins
#define VT100CSI_DECSWL      2028       // Single-width Line
#define VT100CSI_DECTST      2029       // Invoke Confidence Test
#define VT100CSI_DSR         2030       // Device Status Report
#define VT100CSI_ED          2031       // Erase In Display
#define VT100CSI_EL          2032       // Erase In Line
#define VT100CSI_HTS         2033       // Horizontal Tabulation Set
#define VT100CSI_HVP         2034       // Horizontal and Vertical Position
#define VT100CSI_IND         2035       // Index
#define VT100CSI_NEL         2037       // Next Line
#define VT100CSI_RI          2038       // Reverse Index
#define VT100CSI_RIS         2039       // Reset To Initial State
#define VT100CSI_RM          2040       // Reset Mode
#define VT100CSI_SCS         2041
#define VT100CSI_SCS0        2041       // Select Character Set 0
#define VT100CSI_SCS1        2042       // Select Character Set 1
#define VT100CSI_SCS2        2043       // Select Character Set 2
#define VT100CSI_SCS3        2044       // Select Character Set 3
#define VT100CSI_SGR         2045       // Select Graphic Rendition
#define VT100CSI_SM          2046       // Set Mode
#define VT100CSI_TBC         2047       // Tabulation Clear

// some xterm extension
#define XTERMCC_WIN_TITLE	     86	      // Set window title
#define XTERMCC_ICON_TITLE	     91
#define XTERMCC_WINICON_TITLE	     92
#define XTERMCC_INSBLNK	     87       // Insert blank
#define XTERMCC_INSLN	     88	      // Insert lines
#define XTERMCC_DELCH	     89       // delete blank
#define XTERMCC_DELLN	     90	      // delete lines

// Some ansi stuff
#define ANSICSI_CHA	     3000	// Cursor Horizontal Absolute
#define ANSICSI_VPA	     3001	// Vert Position Absolute
#define ANSICSI_VPR	     3002	// Vert Position Relative
#define ANSICSI_ECH	     3003	// Erase Character
#define ANSICSI_PRINT	     3004	// Print to Ansi

// Toggle between ansi/vt52
#define STRICT_ANSI_MODE		4000


#define VT100CSIPARAM_MAX    16

typedef struct {
    int type;
    unsigned char *position;
    int length;
    union {
	NSString *string;
	unsigned char code;
	struct {
	    int p[VT100CSIPARAM_MAX];
	    int count;
	    BOOL question;
	} csi;
    } u;
} VT100TCC;

// character attributes
#define VT100CHARATTR_ALLOFF   0
#define VT100CHARATTR_BOLD     1
#define VT100CHARATTR_UNDER    4
#define VT100CHARATTR_BLINK    5
#define VT100CHARATTR_REVERSE  7

// xterm additions
#define VT100CHARATTR_NORMAL  		22
#define VT100CHARATTR_NOT_UNDER  	24
#define VT100CHARATTR_STEADY	  	25
#define VT100CHARATTR_POSITIVE  	27

typedef enum {
    COLORCODE_BLACK=0,
    COLORCODE_RED=1,
    COLORCODE_GREEN=2,
    COLORCODE_YELLOW=3,
    COLORCODE_BLUE=4,
    COLORCODE_PURPLE=5,
    COLORCODE_WATER=6,
    COLORCODE_WHITE=7,
    COLORS
} colorCode;

#define VT100CHARATTR_FG_BASE  30
#define VT100CHARATTR_BG_BASE  40

#define VT100CHARATTR_FG_BLACK     (VT100CHARATTR_FG_BASE + COLORCODE_BLACK)
#define VT100CHARATTR_FG_RED       (VT100CHARATTR_FG_BASE + COLORCODE_RED)
#define VT100CHARATTR_FG_GREEN     (VT100CHARATTR_FG_BASE + COLORCODE_GREEN)
#define VT100CHARATTR_FG_YELLOW    (VT100CHARATTR_FG_BASE + COLORCODE_YELLOW)
#define VT100CHARATTR_FG_BLUE      (VT100CHARATTR_FG_BASE + COLORCODE_BLUE)
#define VT100CHARATTR_FG_PURPLE    (VT100CHARATTR_FG_BASE + COLORCODE_PURPLE)
#define VT100CHARATTR_FG_WATER     (VT100CHARATTR_FG_BASE + COLORCODE_WATER)
#define VT100CHARATTR_FG_WHITE     (VT100CHARATTR_FG_BASE + COLORCODE_WHITE)
#define VT100CHARATTR_FG_DEFAULT   (VT100CHARATTR_FG_BASE + 9)

#define VT100CHARATTR_BG_BLACK     (VT100CHARATTR_BG_BASE + COLORCODE_BLACK)
#define VT100CHARATTR_BG_RED       (VT100CHARATTR_BG_BASE + COLORCODE_RED)
#define VT100CHARATTR_BG_GREEN     (VT100CHARATTR_BG_BASE + COLORCODE_GREEN)
#define VT100CHARATTR_BG_YELLOW    (VT100CHARATTR_BG_BASE + COLORCODE_YELLOW)
#define VT100CHARATTR_BG_BLUE      (VT100CHARATTR_BG_BASE + COLORCODE_BLUE)
#define VT100CHARATTR_BG_PURPLE    (VT100CHARATTR_BG_BASE + COLORCODE_PURPLE)
#define VT100CHARATTR_BG_WATER     (VT100CHARATTR_BG_BASE + COLORCODE_WATER)
#define VT100CHARATTR_BG_WHITE     (VT100CHARATTR_BG_BASE + COLORCODE_WHITE)
#define VT100CHARATTR_BG_DEFAULT   (VT100CHARATTR_BG_BASE + 9)

#define DEFAULT_FG_COLOR_CODE	-1
#define DEFAULT_BG_COLOR_CODE	-2

@interface VT100Terminal : NSObject
{
    NSStringEncoding  ENCODING;
    NSMutableData     *STREAM;
    VT100Screen       *SCREEN;

    BOOL LINE_MODE;		// YES=Newline, NO=Line feed
    BOOL CURSOR_MODE;		// YES=Application, NO=Cursor
    BOOL ANSI_MODE;		// YES=ANSI, NO=VT52
    BOOL COLUMN_MODE;		// YES=132 Column, NO=80 Column
    BOOL SCROLL_MODE;		// YES=Smooth, NO=Jump
    BOOL SCREEN_MODE;		// YES=Reverse, NO=Normal
    BOOL ORIGIN_MODE;		// YES=Relative, NO=Absolute
    BOOL WRAPAROUND_MODE;	// YES=On, NO=Off
    BOOL AUTOREPEAT_MODE;	// YES=On, NO=Off
    BOOL INTERLACE_MODE;	// YES=On, NO=Off
    BOOL KEYPAD_MODE;		// YES=Application, NO=Numeric
    BOOL INSERT_MODE;		// YES=Insert, NO=Replace
    int  CHARSET;		// G0...G3
    BOOL XON;			// YES=XON, NO=XOFF
    BOOL numLock;		// YES=ON, NO=OFF, default=YES;
    BOOL printToAnsi;		// YES=ON, NO=OFF, default=NO;
    
    int FG_COLORCODE;
    int BG_COLORCODE;
    float alpha;
    NSColor* colorTable[2][8];
    NSColor* defaultFGColor;
    NSColor* defaultBGColor;
    NSColor* defaultBoldColor;
    int	bold, under, blink, reversed;

    int saveBold, saveUnder, saveBlink, saveReversed;
    int saveCHARSET;
    
    BOOL TRACE;

    BOOL strictAnsiMode;
    BOOL allowColumnMode;
    
    NSMutableDictionary *characterAttributeDictionary[2];
    NSMutableDictionary *defaultCharacterAttributeDictionary[2];

    unsigned int streamOffset;

    // for interprocess communication
    FILE *pipeFile;
}

+ (void)initialize;

- (id)init;
- (void)dealloc;

- (BOOL)trace;
- (void)setTrace:(BOOL)flag;

- (BOOL)strictAnsiMode;
- (void)setStrictAnsiMode: (BOOL)flag;

- (BOOL)allowColumnMode;
- (void)setAllowColumnMode: (BOOL)flag;

- (BOOL)printToAnsi;
- (void)setPrintToAnsi: (BOOL)flag;

- (NSStringEncoding)encoding;
- (void)setEncoding:(NSStringEncoding)encoding;

- (void)cleanStream;
- (void)putStreamData:(NSData *)data;
- (VT100TCC)getNextToken;
- (void) printToken: (VT100TCC) token;

- (void) toggleNumLock;
- (BOOL) numLock;

- (NSData *)keyArrowUp:(unsigned int)modflag;
- (NSData *)keyArrowDown:(unsigned int)modflag;
- (NSData *)keyArrowLeft:(unsigned int)modflag;
- (NSData *)keyArrowRight:(unsigned int)modflag;
- (NSData *)keyInsert;
- (NSData *)keyHome;
- (NSData *)keyDelete;
- (NSData *)keyBackspace;
- (NSData *)keyEnd;
- (NSData *)keyPageUp;
- (NSData *)keyPageDown;
- (NSData *)keyFunction:(int)no;
- (NSData *)keyPFn: (int) n;
- (NSData *)keypadData: (unichar) unicode keystr: (NSString *) keystr;

- (BOOL)lineMode;
- (BOOL)cursorMode;
- (BOOL)columnMode;
- (BOOL)scrollMode;
- (BOOL)screenMode;
- (BOOL)originMode;
- (BOOL)wraparoundMode;
- (BOOL)autorepeatMode;
- (BOOL)interlaceMode;
- (BOOL)keypadMode;
- (BOOL)insertMode;
- (int)charset;
- (BOOL)xon;

- (int)foregroundColorCode;
- (int)backgroundColorCode;
- (void) setFGColor:(NSColor*)color;
- (void) setBGColor:(NSColor*)color;
- (void) setBoldColor:(NSColor*)color;
- (void) setColorTable:(int) index highLight:(BOOL)hili color:(NSColor *) c;
- (NSColor *) defaultFGColor;
- (NSColor *) defaultBGColor;
- (NSColor *) defaultBoldColor;
- (NSColor *) colorFromTable:(int) index bold:(BOOL) b;

- (NSData *)reportActivePositionWithX:(int)x Y:(int)y;
- (NSData *)reportStatus;
- (NSData *)reportDeviceAttribute;

- (NSMutableDictionary *)characterAttributeDictionary: (BOOL) asc;
- (NSMutableDictionary *)defaultCharacterAttributeDictionary:  (BOOL) asc;
- (void) initDefaultCharacterAttributeDictionary;
- (void) setCharacterAttributeDictionary;

- (void)_setMode:(VT100TCC)token;
- (void)_setCharAttr:(VT100TCC)token;

- (void) setScreen:(VT100Screen *)sc;

@end

