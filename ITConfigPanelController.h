/*
 **  ITConfigPanelController.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: controls the config sheet.
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

@class PseudoTerminal;

@interface ITConfigPanelController : NSWindowController 
{
    PseudoTerminal* _pseudoTerminal;
    
    IBOutlet id CONFIG_COL;
    IBOutlet id CONFIG_ROW;
    IBOutlet NSPopUpButton *CONFIG_ENCODING;
    IBOutlet id CONFIG_BACKGROUND;
    IBOutlet id CONFIG_FOREGROUND;
    IBOutlet id CONFIG_EXAMPLE;
    IBOutlet id CONFIG_NAEXAMPLE;
    IBOutlet id CONFIG_TRANSPARENCY;
    IBOutlet id CONFIG_TRANS2;
    IBOutlet id CONFIG_NAME;
    IBOutlet id CONFIG_ANTIALIAS;
    IBOutlet id CONFIG_SELECTION;
    IBOutlet id CONFIG_BOLD;
	IBOutlet NSColorWell *CONFIG_CURSOR;
    
    // anti-idle
    IBOutlet id AI_CODE;
    IBOutlet id AI_ON;
    char ai_code;    
    
    NSFont *configFont, *configNAFont;
    BOOL changingNA;

    // background image
    IBOutlet NSButton *useBackgroundImage;
    IBOutlet NSImageView *backgroundImage;
    NSString *backgroundImagePath;
}

+ (void)show:(PseudoTerminal*)pseudoTerminal parentWindow:(NSWindow*)parentWindow;

- (void)showConfigWindow:(PseudoTerminal*)pseudoTerminal parentWindow:(NSWindow*)parentWindow;
- (IBAction) chooseBackgroundImage: (id) sender;
- (IBAction)windowConfigOk:(id)sender;
- (IBAction)windowConfigCancel:(id)sender;
- (IBAction)windowConfigFont:(id)sender;
- (IBAction)windowConfigNAFont:(id)sender;
- (IBAction)windowConfigForeground:(id)sender;
- (IBAction)windowConfigBackground:(id)sender;
- (IBAction) useBackgroundImage: (id) sender;

@end
