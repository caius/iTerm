/*
 **  iTermProfileWindowController.h
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Header file for profile window controller.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#define KEYBOARD_PROFILE_TAB		0
#define TERMINAL_PROFILE_TAB		1
#define DISPLAY_PROFILE_TAB			2

@interface iTermProfileWindowController : NSWindowController 
{
	IBOutlet NSTabView *profileTabView;
	
	// Profile editing
	IBOutlet NSPanel *addProfile;
	IBOutlet NSPanel *deleteProfile;

	// Keybinding profile UI
	IBOutlet NSPopUpButton *kbProfileSelector;
	IBOutlet NSTextField *kbProfileName;
	IBOutlet NSPanel *addKBEntry;
	IBOutlet NSPopUpButton *kbEntryKey;
	IBOutlet NSButton *kbEntryKeyModifierOption;
	IBOutlet NSButton *kbEntryKeyModifierControl;
	IBOutlet NSButton *kbEntryKeyModifierShift;
	IBOutlet NSButton *kbEntryKeyModifierCommand;
	IBOutlet NSPopUpButton *kbEntryAction;
	IBOutlet NSTextField *kbEntryText;
	IBOutlet NSTextField *kbEntryKeyCode;
	IBOutlet NSTableView *kbEntryTableView;
	IBOutlet NSButton *kbProfileDeleteButton;
	IBOutlet NSButton *kbEntryDeleteButton;
	IBOutlet NSMatrix *kbOptionKey;
	
	// Display profile UI
	IBOutlet NSColorWell *displayFGColor;
	IBOutlet NSColorWell *displayBGColor;
	IBOutlet NSColorWell *displayBoldColor;
	IBOutlet NSColorWell *displaySelectionColor;
	IBOutlet NSColorWell *displaySelectedTextColor;
	IBOutlet NSColorWell *displayCursorColor;
	IBOutlet NSColorWell *displayCursorTextColor;
	IBOutlet NSColorWell *displayAnsi0Color;
	IBOutlet NSColorWell *displayAnsi1Color;
	IBOutlet NSColorWell *displayAnsi2Color;
	IBOutlet NSColorWell *displayAnsi3Color;
	IBOutlet NSColorWell *displayAnsi4Color;
	IBOutlet NSColorWell *displayAnsi5Color;
	IBOutlet NSColorWell *displayAnsi6Color;
	IBOutlet NSColorWell *displayAnsi7Color;
	IBOutlet NSColorWell *displayAnsi0HColor;
	IBOutlet NSColorWell *displayAnsi1HColor;
	IBOutlet NSColorWell *displayAnsi2HColor;
	IBOutlet NSColorWell *displayAnsi3HColor;
	IBOutlet NSColorWell *displayAnsi4HColor;
	IBOutlet NSColorWell *displayAnsi5HColor;
	IBOutlet NSColorWell *displayAnsi6HColor;
	IBOutlet NSColorWell *displayAnsi7HColor;
	IBOutlet NSButton *displayUseBackgroundImage;
    IBOutlet NSImageView *displayBackgroundImage;
	IBOutlet NSTextField *displayColTextField;
	IBOutlet NSTextField *displayRowTextField;
	IBOutlet NSTextField *displayFontTextField;
	IBOutlet NSTextField *displayNAFontTextField;
	IBOutlet NSSlider *displayFontSpacingWidth;
	IBOutlet NSSlider *displayFontSpacingHeight;
	IBOutlet NSButton *displayAntiAlias;
	
}

- (IBAction) showProfilesWindow: (id) sender;

// profile editing
- (IBAction) profileAdd: (id) sender;
- (IBAction) profileDelete: (id) sender;
- (IBAction) profileAddConfirm: (id) sender;
- (IBAction) profileAddCancel: (id) sender;
- (IBAction) profileDeleteConfirm: (id) sender;
- (IBAction) profileDeleteCancel: (id) sender;


// Keybinding profile UI
- (void) kbOptionKeyChanged: (id) sender;
- (IBAction) kbProfileChanged: (id) sender;
- (IBAction) kbEntryAdd: (id) sender;
- (IBAction) kbEntryAddConfirm: (id) sender;
- (IBAction) kbEntryAddCancel: (id) sender;
- (IBAction) kbEntryDelete: (id) sender;
- (IBAction) kbEntrySelectorChanged: (id) sender;

// Display profile UI
- (IBAction) displayProfileChanged: (id) sender;
- (IBAction) displaySetAntiAlias: (id) sender;
- (IBAction) displayChangeColor: (id) sender;
- (IBAction) displaySelectFont: (id) sender;
- (IBAction) displaySelectNAFont: (id) sender;


@end

@interface iTermProfileWindowController (Private)

- (void)_addKBEntrySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_addKBProfileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_deleteKBProfileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end

