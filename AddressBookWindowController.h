/*
 **  AddressBookWindowController.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the addressbook functions.
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


@interface AddressBookWindowController : NSWindowController {

    // address book window
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
    IBOutlet id adShortcut;
    IBOutlet NSTextField *adNATextExample;
    IBOutlet NSColorWell *adSelection;

    NSFont *aeFont, *aeNAFont;
    BOOL changingNA;

    // address book data
    NSMutableArray *addressBook;

}

// get/set methods
- (NSMutableArray *) addressBook;
- (void) setAddressBook: (NSMutableArray *) anAddressBook;

// Address book window
- (IBAction)adbAddEntry:(id)sender;
- (IBAction)adbRemoveEntry:(id)sender;
- (IBAction)adbCancel:(id)sender;
- (IBAction)adbEditEntry:(id)sender;
- (IBAction)adbOk:(id)sender;
- (IBAction) executeABCommand: (id) sender;

// Address entry window
- (IBAction)adEditBackground:(id)sender;
- (IBAction)adEditCancel:(id)sender;
- (IBAction)adEditFont:(id)sender;
- (IBAction)adEditNAFont:(id)sender;
- (IBAction)adEditForeground:(id)sender;
- (IBAction)adEditOK:(id)sender;

// misc
- (void) run;

@end
