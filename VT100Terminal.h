// -*- mode:objc -*-
// $Id: VT100Terminal.h,v 1.1.1.1 2002-11-26 04:56:51 ujwal Exp $
//
//  VT100Terminal.h
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// VT100TCC types
#define VT100TCC_NULL        0
#define VT100TCC_WAIT        1
#define VT100TCC_NOTSUPPORT  2
#define VT100TCC_SKIP        3

#define VT100TCC_STRING      10       // ascii string
#define VT100TCC_UNKNOWNCHAR 13

#define VT100TCC_CPR         30       // Cursor Position Report
#define VT100TCC_CUB         31       // Cursor Backward
#define VT100TCC_CUD         32       // Cursor Down
#define VT100TCC_CUF         33       // Cursor Forward
#define VT100TCC_CUP         34       // Cursor Position
#define VT100TCC_CUU         35       // Cursor Up
#define VT100TCC_DA          36       // Device Attributes
#define VT100TCC_DECDHL      43       // Double Height Line
#define VT100TCC_DECDWL      44       // Double Width Line
#define VT100TCC_DECID       45       // Identify Terminal
#define VT100TCC_DECKPAM     47       // Keypad Application Mode
#define VT100TCC_DECKPNM     48       // Keypad Numeric Mode
#define VT100TCC_DECLL       49       // Load LEDS
#define VT100TCC_DECRC       51       // Restore Cursor
#define VT100TCC_DECREPTPARM 52       // Report Terminal Parameters
#define VT100TCC_DECREQTPARM 53       // Request Terminal Parameters
#define VT100TCC_DECSC       54       // Save Cursor
#define VT100TCC_DECSTBM     57       // Set Top and Bottom Margins
#define VT100TCC_DECSWL      58       // Single-width Line
#define VT100TCC_DECTST      59       // Invoke Confidence Test
#define VT100TCC_DSR         60       // Device Status Report
#define VT100TCC_ED          61       // Erase In Display
#define VT100TCC_EL          62       // Erase In Line
#define VT100TCC_HTS         63       // Horizontal Tabulation Set
#define VT100TCC_HVP         64       // Horizontal and Vertical Position
#define VT100TCC_IND         65       // Index
#define VT100TCC_NEL         67       // Next Line
#define VT100TCC_RI          68       // Reverse Index
#define VT100TCC_RIS         69       // Reset To Initial State
#define VT100TCC_RM          70       // Reset Mode
#define VT100TCC_SCS         71       // Select Character Set
#define VT100TCC_SGR         72       // Select Graphic Rendition
#define VT100TCC_SM          73       // Set Mode
#define VT100TCC_TBC         74       // Tabulation Clear

#define VT100TCC_TAB         80       // TAB
#define VT100TCC_CR          81       // CR
#define VT100TCC_LF          82       // LF
#define VT100TCC_DEL         83       // DELETE
#define VT100TCC_BS          84       // BACKSPACE
#define VT100TCC_BELL        85       // BELL

// some xterm extension
#define XTERMCC_TITLE	     86	      // Set window title
#define XTERMCC_INSBLNK	     87       // Insert blank
#define XTERMCC_INSLN	     88	      // Insert lines
#define XTERMCC_DELCH	     89       // delete blank
#define XTERMCC_DELLN	     90	      // delete lines
#define VT100TCC_DECSET	     91
#define VT100TCC_DECRST	     92

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
    BOOL COLUMN_MODE;		// YES=132 Column, NO=80 Column
    BOOL SCROLL_MODE;		// YES=Smooth, NO=Jump
    BOOL SCREEN_MODE;		// YES=Reverse, NO=Normal
    BOOL ORIGIN_MODE;		// YES=Relative, NO=Absolute
    BOOL WRAPAROUND_MODE;	// YES=On, NO=Off
    BOOL AUTOREPEAT_MODE;	// YES=On, NO=Off
    BOOL INTERLACE_MODE;	// YES=On, NO=Off
    BOOL KEYPAD_MODE;		// YES=Application, NO=Numeric
    BOOL INSERT_MODE;		// YES=Insert, NO=Replace

    unsigned int CHARATTR;
    int FG_COLORCODE;
    int BG_COLORCODE;

    NSColor *DefaultFG;
    NSColor *DefaultBG;
    
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

@end

