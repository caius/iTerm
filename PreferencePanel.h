/*
 **  PreferencePanel.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Implements the model and controller for the preference panel.
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

#define OPT_NORMAL 0
#define OPT_META   1
#define OPT_ESC    2

@interface PreferencePanel : NSResponder
{
    IBOutlet id ansiBlack;
    IBOutlet id ansiBlue;
    IBOutlet id ansiCyan;
    IBOutlet id ansiGreen;
    IBOutlet id ansiHiBlack;
    IBOutlet id ansiHiBlue;
    IBOutlet id ansiHiCyan;
    IBOutlet id ansiHiGreen;
    IBOutlet id ansiHiMagenta;
    IBOutlet id ansiHiRed;
    IBOutlet id ansiHiWhite;
    IBOutlet id ansiHiYellow;
    IBOutlet id ansiMagenta;
    IBOutlet id ansiRed;
    IBOutlet id ansiWhite;
    IBOutlet id ansiYellow;
    IBOutlet id antiAlias;
    IBOutlet id autoclose;
    IBOutlet id background;
    IBOutlet id col;
    IBOutlet id colorScheme;
    IBOutlet id copySelection;
    IBOutlet id doubleWidth;
    IBOutlet id encoding;
    IBOutlet id fontExample;
    IBOutlet id foreground;
    IBOutlet id hideTab;
    IBOutlet id nafontExample;
    IBOutlet id openAddressBook;
    IBOutlet id optionKey;
    IBOutlet id macnavkeys;
    IBOutlet id prefPanel;
    IBOutlet id prefTab;
    IBOutlet id promptOnClose;
    IBOutlet id remapDeleteKey;
    IBOutlet id row;
    IBOutlet id scrollbackLines;
    IBOutlet id selectionColor;
    IBOutlet id shell;
    IBOutlet id silenceBell;
    IBOutlet id tabSelector;
    IBOutlet id tabViewType;
    IBOutlet id terminal;
    IBOutlet id transparency;
    IBOutlet id transparency_control;
    IBOutlet id boldColor;
    
    NSUserDefaults *prefs;

    int defaultColorScheme;
    NSColor* defaultBackground;
    NSColor* defaultForeground;
    NSColor* defaultSelectionColor;
    NSColor* defaultBoldColor;
    NSColor* defaultColorTable[2][8];
    
    int defaultCol;
    int defaultRow;
    unsigned int defaultScrollback;
    
    NSStringEncoding defaultEncoding;
    NSString* defaultShell;
    NSString* defaultTerminal;
    
    NSFont* defaultFont;
    NSFont* defaultNAFont;
    float defaultTransparency;

    BOOL defaultAutoclose;
    int defaultOption;
    BOOL defaultMacNavKeys;
    BOOL defaultAntiAlias;
    BOOL defaultCopySelection;
    BOOL defaultHideTab;
    BOOL defaultSilenceBell;
    BOOL changingNA;
    BOOL defaultDoubleWidth;
    int defaultTabViewType;
    BOOL defaultRemapDeleteKey;
    BOOL defaultOpenAddressBook;
    BOOL defaultPromptOnClose;

}

+ (void)initialize;
+ (NSColor *) highlightColor:(NSColor *)color;

- (id)init;
- (void)dealloc;

- (void) readPreferences;

- (IBAction)changeBackground:(id)sender;
- (IBAction)changeColorScheme:(id)sender;
- (IBAction)editColorScheme: (id) sender;
- (IBAction)changeFontButton:(id)sender;
- (IBAction)changeForeground:(id)sender;
- (IBAction)changeNAFontButton:(id)sender;
- (IBAction)changeTab:(id)sender;
- (IBAction)ok:(id)sender;
- (IBAction)restore:(id)sender;
- (void)changeFont:(id)fontManager;

- (void)run;

- (NSColor*) background;
- (NSColor*) foreground;
- (int) col;
- (int) row;
- (unsigned int) scrollbackLines;
- (NSStringEncoding) encoding;
- (NSString*) shell;
- (NSString*) terminalType;
- (int) transparency;
- (NSFont*) font;
- (NSFont*) nafont;
- (BOOL) antiAlias;
- (BOOL) ai;
- (int) aiCode;
- (BOOL) autoclose;
- (int) option;
- (BOOL) macnavkeys;
- (BOOL) copySelection;
- (BOOL) hideTab;
- (BOOL) silenceBell;
- (BOOL) doubleWidth;
- (NSColor *) selectionColor;
- (NSColor *) colorFromTable:(int)index highLight:(BOOL)hili;
- (NSTabViewType) tabViewType;
- (BOOL)remapDeleteKey;
- (BOOL)openAddressBook;
- (BOOL) promptOnClose;
- (NSColor *) boldColor;

@end
