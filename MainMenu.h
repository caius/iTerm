// -*- mode:objc -*-
// $Id: MainMenu.h,v 1.15 2003-03-13 20:10:49 yfabian Exp $
/*
 **  MainMenu.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the main application delegate and handles the addressbook functions.
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

@interface MainMenu : NSObject
{
   
    // address book window
    IBOutlet id AB_PANEL;
    IBOutlet id openInNewWindow;
    IBOutlet NSTableView *adTable;

    // address entry window
    IBOutlet id AE_PANEL;
    IBOutlet NSColorWell *adBackground;
    IBOutlet NSTextField *adCommand;
    IBOutlet NSComboBox *adEncoding;
    IBOutlet NSColorWell *adForeground;
    IBOutlet NSTextField *adName;
    IBOutlet NSTextField *adTextExample;
    IBOutlet id adRow;
    IBOutlet id adCol;
    IBOutlet id adTransparency;
    IBOutlet id adTransparency2;
    IBOutlet id adTermType;
    IBOutlet id adDir;
    IBOutlet id adNewWindow;
    IBOutlet id adAI;
    IBOutlet id adAICode;
    IBOutlet id adClose;
    IBOutlet id adDoubleWidth;
    IBOutlet NSTextField *adNATextExample;
    IBOutlet NSColorWell *adSelection;
    
    NSFont *aeFont, *aeNAFont;
    BOOL changingNA;
    
    // preference window
    IBOutlet id PREF_PANEL;

    // about window
    IBOutlet id ABOUT;
    IBOutlet NSTextView *AUTHORS;
    // address book data
    NSMutableArray *addressBook;

    // PseudoTerminal objects
    NSMutableArray *terminalWindows;
    id FRONT;
    
}

// NSApplication Delegate methods
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification;
- (BOOL) applicationShouldTerminate: (NSNotification *) theNotification;
- (BOOL)applicationOpenUntitledFile:(NSApplication *)app;
- (NSMenu *)applicationDockMenu:(NSApplication *)sender;

- (IBAction)newWindow:(id)sender;
- (IBAction)newSession:(id)sender;

// Address book window
- (IBAction)showABWindow:(id)sender;
- (IBAction)adbAddEntry:(id)sender;
- (IBAction)adbCancel:(id)sender;
- (IBAction)adbEditEntry:(id)sender;
- (IBAction)adbOk:(id)sender;
- (IBAction) executeABCommand: (id) sender;

// Address entry window
- (IBAction)adbRemoveEntry:(id)sender;
- (IBAction)adEditBackground:(id)sender;
- (IBAction)adEditCancel:(id)sender;
- (IBAction)adEditFont:(id)sender;
- (IBAction)adEditNAFont:(id)sender;
- (IBAction)adEditForeground:(id)sender;
- (IBAction)adEditOK:(id)sender;
- (void)changeFont:(id)fontManager;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
// About window
- (IBAction)showAbout:(id)sender;
- (IBAction)aboutOK:(id)sender;

// Utility methods
+ (void) breakDown:(NSString *)cmdl cmdPath: (NSString **) cmd cmdArgs: (NSArray **) path;
- (void) initAddressBook;
- (void) saveAddressBook;
- (void) setFrontPseudoTerminal: (PseudoTerminal *) thePseudoTerminal;
- (PseudoTerminal *) frontPseudoTerminal;
- (void) addTerminalWindow: (PseudoTerminal *) theTerminalWindow;
- (void) removeTerminalWindow: (PseudoTerminal *) theTerminalWindow;
- (NSStringEncoding const*) encodingList;
- (NSArray *)addressBookNames;
- (NSDictionary *)addressBookEntry: (int) entryIndex;
- (void) addAddressBookEntry: (NSDictionary *) entry;
- (void) replaceAddressBookEntry:(NSDictionary *) old with:(NSDictionary *)new;
- (void) buildAddressBookMenu: (NSMenu *) abMenu forTerminal: (id) sender;
- (void) executeABCommandAtIndex: (int) theIndex inTerminal: (PseudoTerminal *) theTerm;

// Preference Panel
- (IBAction)showPrefWindow:(id)sender;

@end

// Private interface
@interface MainMenu (Private)

- (void) _executeABMenuCommandInNewTab: (id) sender;
- (void) _executeABMenuCommandInNewWindow: (id) sender;

@end
