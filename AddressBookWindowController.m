/*
 **  AddressBookWindowController.m
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

#import "AddressBookWindowController.h"
#import "PreferencePanel.h"
#import "MainMenu.h"

static NSStringEncoding const *encodingList=nil;
static AddressBookWindowController *singleInstance = nil;

// comaparator function for addressbook entries
static NSComparisonResult addressBookComparator (NSDictionary *entry1, NSDictionary *entry2, void *context)
{
    return ([(NSString *)[entry1 objectForKey: @"Name"] caseInsensitiveCompare: (NSString *)[entry2 objectForKey: @"Name"]]);
}

@implementation AddressBookWindowController

//
// class methods
//
+ (id) singleInstance
{
    if ( !singleInstance )
    {
	singleInstance = [[self alloc] initWithWindowNibName: @"AddressBook"];
    }

    return singleInstance;
}

- (id) initWithWindowNibName: (NSString *) windowNibName
{
    self = [super initWithWindowNibName: windowNibName];
    encodingList=[NSString availableStringEncodings];

    // We finally set our autosave window frame name and restore the one from the user's defaults.
    [[self window] setFrameAutosaveName: @"AddressBook"];
    [[self window] setFrameUsingName: @"AddressBook"];    

    return (self);
}

- (void) awakeFromNib
{
    //    NSLog(@ "initAddressBook: %d\n%@",[addressBook count], addressBook);
    // Tell the addressbook table in the gui that number of rows have changed.
    // Other the scrollview is not activated for large addressbooks.
    // Cocoa bug?
    [adTable noteNumberOfRowsChanged];
    
}

// get/set methods
- (NSMutableArray *) addressBook
{
    return (addressBook);
}

- (void) setAddressBook: (NSMutableArray *) anAddressBook
{
    addressBook = anAddressBook;
}

- (PreferencePanel *) preferences
{
    return (preferences);
}

- (void) setPreferences: (PreferencePanel *) thePreferences
{
    preferences = thePreferences;
}


// Action methods

- (IBAction)adbAddEntry:(id)sender
{
    int r;
    NSStringEncoding const *p=encodingList;

    [AE_PANEL center];
    [adName setStringValue:@""];
    [adCommand setStringValue:[[self preferences] shell]];
    [adEncoding removeAllItems];
    r=0;
    while (*p) {
	//        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [adEncoding addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[[self preferences] encoding]) r=p-encodingList;
        p++;
    }
    [adEncoding selectItemAtIndex:r];
    [adTermType selectItemAtIndex:0];
    [adShortcut selectItemAtIndex:0];
    [adRow setIntValue:[[self preferences] row]];
    [adCol setIntValue:[[self preferences] col]];
    [adForeground setColor:[[self preferences] foreground]];
    [adBackground setColor:[[self preferences] background]];
    [adSelection setColor:[[self preferences] selectionColor]];
    [adDir setStringValue:[@"~"  stringByExpandingTildeInPath]];

    aeFont=[[[self preferences] font] copy];
    [adTextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeFont fontName], [aeFont pointSize]]];
    [adTextExample setFont:aeFont];
    [adTextExample setTextColor:[[self preferences] foreground]];
    [adTextExample setBackgroundColor:[[self preferences] background]];

    aeNAFont=[[[self preferences] nafont] copy];
    [adNATextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeNAFont fontName], [aeNAFont pointSize]]];
    [adNATextExample setTextColor:[[self preferences] foreground]];
    [adNATextExample setBackgroundColor:[[self preferences] background]];
    [adNATextExample setFont:aeNAFont];
    [adAI setState:[[self preferences] ai]?NSOnState:NSOffState];
    [adAICode setIntValue:[[self preferences] aiCode]];
    [adClose setState:[[self preferences] autoclose]?NSOnState:NSOffState];
    [adDoubleWidth setState:[[self preferences] doubleWidth]?NSOnState:NSOffState];

    [adTransparency setIntValue:[[self preferences] transparency]];
    [adTransparency2 setIntValue:[[self preferences] transparency]];

    r= [NSApp runModalForWindow:AE_PANEL];
    [AE_PANEL close];
    if (r == NSRunStoppedResponse) {
        NSDictionary *ae;

        ae=[[NSDictionary alloc] initWithObjectsAndKeys:
            [adName stringValue],@"Name",
            [adCommand stringValue],@"Command",
            [NSNumber numberWithUnsignedInt:encodingList[[adEncoding indexOfSelectedItem]]],@"Encoding",
            [adForeground color],@"Foreground",
            [adBackground color],@"Background",
            [adSelection color],@"SelectionColor",
            [adRow stringValue],@"Row",
            [adCol stringValue],@"Col",
            [NSNumber numberWithInt:[adTransparency intValue]],@"Transparency",
            [adTermType stringValue],@"Term Type",
            [adDir stringValue],@"Directory",
            aeFont,@"Font",
            aeNAFont,@"NAFont",
            [NSNumber numberWithBool:[adAI state]],@"AntiIdle",
            [NSNumber numberWithUnsignedInt:[adAICode intValue]],@"AICode",
            [NSNumber numberWithBool:[adClose state]],@"AutoClose",
            [NSNumber numberWithBool:[adDoubleWidth state]],@"DoubleWidth",
            [NSNumber numberWithUnsignedInt:[adShortcut indexOfSelectedItem]?[[adShortcut stringValue] characterAtIndex:0]:0],@"Shortcut",
            NULL];
        [[self addressBook] addObject:ae];
	[[self addressBook] sortUsingFunction: addressBookComparator context: nil];
	//        NSLog(@"%s(%d):-[Address entry added:%@]",
 //              __FILE__, __LINE__, ae );
        [adTable reloadData];
        [ae release];

    }

}

- (IBAction)adbCancel:(id)sender
{
    [[self window] close];
}

- (IBAction)adbEditEntry:(id)sender
{
    int r;
    NSStringEncoding const *p=encodingList;
    id entry;

    if ([adTable selectedRow]<0) return
	[AE_PANEL center];
    entry=[[self addressBook] objectAtIndex:[adTable selectedRow]];
    [adName setStringValue:[entry objectForKey:@"Name"]];
    [adCommand setStringValue:[entry objectForKey:@"Command"]];
    [adEncoding removeAllItems];
    r=0;
    while (*p) {
        //        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [adEncoding addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[[entry objectForKey:@"Encoding"] unsignedIntValue]) r=p-encodingList;
        p++;
    }
    [adEncoding selectItemAtIndex:r];
    if ([entry objectForKey:@"Term Type"])
        [adTermType setStringValue:[entry objectForKey:@"Term Type"]];
    else
        [adTermType selectItemAtIndex:0];
    if ([entry objectForKey:@"Shortcut"]&&[[entry objectForKey:@"Shortcut"] intValue]) {
        [adShortcut setStringValue:[NSString stringWithFormat:@"%c",[[entry  objectForKey:@"Shortcut"] intValue]]];
    }
    else
        [adShortcut selectItemAtIndex:0];

    [adForeground setColor:[entry objectForKey:@"Foreground"]];
    [adBackground setColor:[entry objectForKey:@"Background"]];
    if([entry objectForKey:@"SelectionColor"])
        [adSelection setColor:[entry objectForKey:@"SelectionColor"]];
    else
        [adSelection setColor: [[self preferences] selectionColor]];
    [adRow setStringValue:[entry objectForKey:@"Row"]];
    [adCol setStringValue:[entry objectForKey:@"Col"]];
    if ([entry objectForKey:@"Transparency"]) {
        [adTransparency setIntValue:[[entry objectForKey:@"Transparency"] intValue]];
        [adTransparency2 setIntValue:[[entry objectForKey:@"Transparency"] intValue]];
    }
    else {
        [adTransparency setIntValue:[[self preferences] transparency]];
        [adTransparency2 setIntValue:[[self preferences] transparency]];
    }
    if ([entry objectForKey:@"Directory"]) {
        [adDir setStringValue:[entry objectForKey:@"Directory"]];
    }
    else {
        [adDir setStringValue:[@"~"  stringByExpandingTildeInPath]];
    }

    aeFont=[entry objectForKey:@"Font"];
    [adTextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeFont fontName], [aeFont pointSize]]];
    [adTextExample setTextColor:[entry objectForKey:@"Foreground"]];
    [adTextExample setBackgroundColor:[entry objectForKey:@"Background"]];
    [adTextExample setFont:aeFont];

    aeNAFont=[entry objectForKey:@"NAFont"];
    if (aeNAFont==nil) aeNAFont=[aeFont copy];
    [adNATextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeNAFont fontName], [aeNAFont pointSize]]];
    [adNATextExample setTextColor:[entry objectForKey:@"Foreground"]];
    [adNATextExample setBackgroundColor:[entry objectForKey:@"Background"]];
    [adNATextExample setFont:aeNAFont];
    [adAI setState:([entry objectForKey:@"AntiIdle"]==nil?[[self preferences] ai]:[[entry objectForKey:@"AntiIdle"] boolValue])?NSOnState:NSOffState];
    [adAICode setIntValue:[entry objectForKey:@"AICode"]==nil?[[self preferences] aiCode]:[[entry objectForKey:@"AICode"] intValue]];
    [adClose setState:([entry objectForKey:@"AutoClose"]==nil?[[self preferences] autoclose]:[[entry objectForKey:@"AutoClose"] boolValue])?NSOnState:NSOffState];
    [adDoubleWidth setState:([entry objectForKey:@"DoubleWidth"]==nil?[[self preferences] doubleWidth]:[[entry objectForKey:@"DoubleWidth"] boolValue])?NSOnState:NSOffState];

    r= [NSApp runModalForWindow:AE_PANEL];
    [AE_PANEL close];
    if (r == NSRunStoppedResponse) {
        NSDictionary *ae;

        ae=[[NSDictionary alloc] initWithObjectsAndKeys:
            [adName stringValue],@"Name",
            [adCommand stringValue],@"Command",
            [NSNumber numberWithUnsignedInt:encodingList[[adEncoding indexOfSelectedItem]]],@"Encoding",
            [adForeground color],@"Foreground",
            [adBackground color],@"Background",
            [adSelection color],@"SelectionColor",
            [adRow stringValue],@"Row",
            [adCol stringValue],@"Col",
            [NSNumber numberWithInt:[adTransparency intValue]],@"Transparency",
            [adTermType stringValue],@"Term Type",
            [adDir stringValue],@"Directory",
            aeFont,@"Font",
            aeNAFont,@"NAFont",
            [NSNumber numberWithBool:[adAI state]],@"AntiIdle",
            [NSNumber numberWithUnsignedInt:[adAICode intValue]],@"AICode",
            [NSNumber numberWithBool:[adClose state]],@"AutoClose",
            [NSNumber numberWithBool:[adDoubleWidth state]],@"DoubleWidth",
            [NSNumber numberWithUnsignedInt:[adShortcut indexOfSelectedItem]?[[adShortcut stringValue] characterAtIndex:0]:0],@"Shortcut",
            NULL];
        [[self addressBook] replaceObjectAtIndex:[adTable selectedRow] withObject:ae];
	[[self addressBook] sortUsingFunction: addressBookComparator context: nil];
	//        NSLog(@"%s(%d):-[Address entry replaced:%@]",
 //              __FILE__, __LINE__, ae );
        [adTable reloadData];
        [ae release];
    }
}

- (IBAction)adbOk:(id)sender
{

    // Save the address book.
    [[NSApp delegate] saveAddressBook];

    // Post a notification to all open terminals to reload their addressbooks into the shortcut menu
    [[NSNotificationCenter defaultCenter]
    postNotificationName: @"Reload AddressBook"
		  object: nil
		userInfo: nil];

    [[self window] close];

}

- (IBAction)adbRemoveEntry:(id)sender
{
    NSBeginAlertSheet(
                      NSLocalizedStringFromTableInBundle(@"Do you really want to remove this item?",@"iTerm", [NSBundle bundleForClass: [self class]], @"Removal Alert"),
                      NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel"),
                      NSLocalizedStringFromTableInBundle(@"Remove",@"iTerm", [NSBundle bundleForClass: [self class]], @"Remove"),
                      nil,
                      [self window],               // window sheet is attached to
                      self,                   // we'll be our own delegate
                      @selector(sheetDidEnd:returnCode:contextInfo:),     // did-end selector
                      NULL,                   // no need for did-dismiss selector
                      sender,                 // context info
                      NSLocalizedStringFromTableInBundle(@"There is no undo for this operation.",@"iTerm", [NSBundle bundleForClass: [self class]], @"Removal Alert"),
                      nil);                   // no parameters in message
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if ( returnCode == NSAlertAlternateReturn) {
        [[self addressBook] removeObjectAtIndex:[adTable selectedRow]];
	[[self addressBook] sortUsingFunction: addressBookComparator context: nil];
        [adTable reloadData];
    }
}

// address entry window
- (IBAction)adEditBackground:(id)sender
{
    [adTextExample setBackgroundColor:[adBackground color]];
    //    [[NSColorPanel sharedColorPanel] close];
}

- (IBAction)adEditCancel:(id)sender
{
    [NSApp abortModal];
    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];
}

- (IBAction)adEditFont:(id)sender
{
    changingNA=NO;
    [[adTextExample window] makeFirstResponder:[adTextExample window]];
    [[NSFontManager sharedFontManager] setSelectedFont:aeFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)adEditNAFont:(id)sender
{
    changingNA=YES;
    [[adNATextExample window] makeFirstResponder:[adNATextExample window]];
    [[NSFontManager sharedFontManager] setSelectedFont:aeNAFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)adEditForeground:(id)sender
{
    [adTextExample setTextColor:[sender color]];
    //    [[NSColorPanel sharedColorPanel] close];
}

- (IBAction)adEditOK:(id)sender
{
    if ([adCol intValue]<1||[adRow intValue]<1) {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Wrong Input",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"Please enter a valid window size",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
    }
    else {
        [NSApp stopModal];
        [[NSColorPanel sharedColorPanel] close];
        [[NSFontPanel sharedFontPanel] close];
    }
}

- (IBAction) executeABCommand: (id) sender
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu executeABCommand:%@]",
          __FILE__, __LINE__, sender);
#endif


    if(([adTable selectedRow] < 0) || ([adTable numberOfRows] == 0))
	return;

    [NSApp stopModal];

    if([openInNewWindow state]==NSOnState)
        [[NSApp delegate] executeABCommandAtIndex: [adTable selectedRow] inTerminal: nil];
    else
        [[NSApp delegate] executeABCommandAtIndex: [adTable selectedRow] inTerminal: [[NSApp delegate] frontPseudoTerminal]];
}


// misc
- (void) run;
{
    int r;

    [[self window] center];
    [adTable setDataSource: [NSApp delegate]];
    if([adTable numberOfRows] > 0){
	[adTable selectRow: 0 byExtendingSelection: NO];
	[[self window] makeFirstResponder: adTable];
    }
    [adTable setDoubleAction: @selector(executeABCommand:)];
    //r= [NSApp runModalForWindow:[self window]];
    //[[self window] close];
    [self showWindow: self];
}


@end
