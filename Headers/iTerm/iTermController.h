// -*- mode:objc -*-
// $Id: iTermController.h,v 1.3 2003-08-11 14:57:17 sgehrman Exp $
/*
 **  iTermController.h
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
@class PreferencePanel;
@class PTYTextView;

@interface iTermController : NSObject
{
    // preference window
    PreferencePanel *PREF_PANEL;

    // about window
    IBOutlet id ABOUT;
    IBOutlet NSTextView *AUTHORS;

    // Menu items
    IBOutlet NSMenuItem *selectTab;
    IBOutlet NSMenuItem *previousTerminal;
    IBOutlet NSMenuItem *nextTerminal;
    
    // bookmarks data
    NSMutableArray *addressBook;

    // PseudoTerminal objects
    NSMutableArray *terminalWindows;
    id FRONT;
    
}

+ (iTermController*)sharedInstance;

// NSApplication Delegate methods
- (BOOL) applicationShouldTerminate: (NSNotification *) theNotification;
- (BOOL)applicationOpenUntitledFile:(NSApplication *)app;
- (NSMenu *)applicationDockMenu:(NSApplication *)sender;
- (void)applicationDidUnhide:(NSNotification *)aNotification;

- (IBAction)newWindow:(id)sender;
- (IBAction)newSession:(id)sender;

// navigation
- (IBAction) previousTerminal: (id) sender;
- (IBAction) nextTerminal: (id) sender;

// Utility methods
+ (void) breakDown:(NSString *)cmdl cmdPath: (NSString **) cmd cmdArgs: (NSArray **) path;
- (void) setFrontPseudoTerminal: (PseudoTerminal *) thePseudoTerminal;
- (PseudoTerminal *) frontPseudoTerminal;
- (void) buildSessionSubmenu;
- (void) terminalWillClose: (PseudoTerminal *) theTerminalWindow;
- (NSStringEncoding const*) encodingList;
- (void) buildAddressBookMenu: (NSMenu *) abMenu forTerminal: (id) sender;
- (void) executeABCommandAtIndex: (int) theIndex inTerminal: (PseudoTerminal *) theTerm;
- (void) interpreteKey: (int) code newWindow:(BOOL) newWin;
- (PTYTextView *) frontTextView;

// Preference Panel
- (void) initPreferences;
- (IBAction)showPrefWindow:(id)sender;
- (PreferencePanel *) preferencePanel;

@end

@interface iTermController (AddressBook)

- (NSMutableArray *) addressBook;
- (IBAction)showABWindow:(id)sender;
- (void) initAddressBook;
- (void) saveAddressBook;
- (NSArray *)addressBookNames;
- (NSDictionary *)newDefaultAddressBookEntry;
- (NSMutableDictionary *) defaultAddressBookEntry;
- (NSMutableDictionary *)addressBookEntry: (int) entryIndex;
- (void) addAddressBookEntry: (NSDictionary *) entry;
- (void) replaceAddressBookEntry:(NSDictionary *) old with:(NSDictionary *)new;

@end

// Scripting support
@interface iTermController (KeyValueCoding)

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key;

// accessors for to-many relationships:
-(NSArray*)terminals;
-(void)setTerminals: (NSArray*)terminals;

-(id)valueInTerminalsAtIndex:(unsigned)index;
-(void)replaceInTerminals:(PseudoTerminal *)object atIndex:(unsigned)index;
- (void) addInTerminals: (PseudoTerminal *) object;
- (void) insertInTerminals: (PseudoTerminal *) object;
-(void)insertInTerminals:(PseudoTerminal *)object atIndex:(unsigned)index;
-(void)removeFromTerminalsAtIndex:(unsigned)index;

// a class method to provide the keys for KVC:
- (NSArray*)kvcKeys;

@end


// Private interface
@interface iTermController (Private)

- (void) _executeABMenuCommandInNewTab: (id) sender;
- (void) _executeABMenuCommandInNewWindow: (id) sender;
- (void) _selectSessionAtIndex: (id) sender;

@end
