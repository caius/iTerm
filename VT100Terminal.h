// -*- mode:objc -*-
// $Id: VT100Terminal.h,v 1.2 2002-12-19 21:02:22 yfabian Exp $
//
//  VT100Terminal.h
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

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
#define VT100_STRING      	1003       // ascii string
#define VT100_UNKNOWNCHAR 	1004
#define VT100CSI_DECSET		1005
#define VT100CSI_DECRST		1006

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
#define VT100CSI_SCS         2041       // Select Character Set
#define VT100CSI_SGR         2042       // Select Graphic Rendition
#define VT100CSI_SM          2043       // Set Mode
#define VT100CSI_TBC         2044       // Tabulation Clear


// some xterm extension
#define XTERMCC_TITLE	     86	      // Set window title
#define XTERMCC_INSBLNK	     87       // Insert blank
#define XTERMCC_INSLN	     88	      // Insert lines
#define XTERMCC_DELCH	     89       // delete blank
#define XTERMCC_DELLN	     90	      // delete lines

#define VT100CSIPARAM_MAX    16

typedef struct {
    int type;
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

#define VT100CHARATTR_BOLDMASK    (1)
#define VT100CHARATTR_UNDERMASK   (1<<1)
#define VT100CHARATTR_BLINKMASK   (1<<2)
#define VT100CHARATTR_REVERSEMASK (1<<3)

#define COLORCODE_BLACK   0
#define COLORCODE_RED     1
#define COLORCODE_GREEN   2
#define COLORCODE_YELLOW  3
#define COLORCODE_BLUE    4
#define COLORCODE_PURPLE  5
#define COLORCODE_WATER   6
#define COLORCODE_WHITE   7
#define COLORCODE_FG_DEFAULT -2
#define COLORCODE_BG_DEFAULT -1

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



@interface VT100Terminal : NSObject
{
    NSStringEncoding  ENCODING;
    NSMutableData     *STREAM;
    VT100Screen       *SCREEN;

    NSColor *COLOR_BLACK;
    NSColor *COLOR_RED;
    NSColor *COLOR_GREEN;
    NSColor *COLOR_YELLOW;
    NSColor *COLOR_BLUE;
    NSColor *COLOR_PURPLE;
    NSColor *COLOR_WATER;
    NSColor *COLOR_WHITE;
    
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
    BOOL CHARSET;		// YES=G1, NO=G0
    BOOL XON;			// YES=XON, NO=XOFF
    
    unsigned int CHARATTR;
    int FG_COLORCODE;
    int BG_COLORCODE;

    NSColor *DefaultFG;
    NSColor *DefaultBG;

    unsigned int saveCHARATTR;
    BOOL saveCHARSET;
    
    BOOL TRACE;
}

+ (void)initialize;

- (id)init;
- (void)dealloc;

- (BOOL)trace;
- (void)setTrace:(BOOL)flag;

- (NSStringEncoding)encoding;
- (void)setEncoding:(NSStringEncoding)encoding;

- (void)cleanStream;
- (void)putStreamData:(NSData *)data;
- (VT100TCC)getNextToken;

- (NSData *)keyArrowUp;
- (NSData *)keyArrowDown;
- (NSData *)keyArrowLeft;
- (NSData *)keyArrowRight;
- (NSData *)keyInsert;
- (NSData *)keyHome;
- (NSData *)keyDelete;
- (NSData *)keyEnd;
- (NSData *)keyPageUp;
- (NSData *)keyPageDown;
- (NSData *)keyFunction:(int)no;

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
- (BOOL)charset;
- (BOOL)xon;

- (int)foregroundColorCode;
- (int)backgroundColorCode;
- (NSColor *)blackColor;
- (NSColor *)redColor;
- (NSColor *)greenColor;
- (NSColor *)yellowColor;
- (NSColor *)blueColor;
- (NSColor *)purpleColor;
- (NSColor *)waterColor;
- (NSColor *)whiteColor;
- (NSColor *)colorWithCode:(int)code;
- (void) setFGColor:(NSColor*)color;
- (void) setBGColor:(NSColor*)color;
- (NSColor *) defaultFGColor;
- (NSColor *) defaultBGColor;

- (NSData *)reportActivePositionWithX:(int)x Y:(int)y;
- (NSData *)reportStatus;
- (NSData *)reportDeviceAttribute;

- (unsigned int)characterAttribute;
- (NSMutableDictionary *)characterAttributeDictionary;

- (void)_setMode:(VT100TCC)token;
- (void)_setCharAttr:(VT100TCC)token;

- (void) setScreen:(VT100Screen *)sc;

@end

