/*
 **  AddressBookWindowController.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Ujwal S. Sathyam, Fabian
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

#define DEBUG_ALLOC	0

static NSStringEncoding const *encodingList=nil;
static AddressBookWindowController *singleInstance = nil;

static NSColor *iTermBackground;
static NSColor *iTermForeground;
static NSColor *iTermSelection;
static NSColor *iTermBold;
static NSColor* iTermColorTable[2][8];
static NSColor *xtermBackground;
static NSColor *xtermForeground;
static NSColor *xtermSelection;
static NSColor *xtermBold;
static NSColor* xtermColorTable[2][8];


// comaparator function for addressbook entries
BOOL isDefaultEntry( NSDictionary *entry )
{
    return [entry objectForKey: @"DefaultEntry"] && [[entry objectForKey: @"DefaultEntry"] boolValue];
}

NSString *entryVisibleName( NSDictionary *entry, id sender )
{
    if ( isDefaultEntry( entry ) ) {
        return NSLocalizedStringFromTableInBundle(@"Default Session",@"iTerm", [NSBundle bundleForClass: [sender class]], @"Default Session");
    } else {
        return [entry objectForKey:@"Name"];
    }
}

NSComparisonResult addressBookComparator (NSDictionary *entry1, NSDictionary *entry2, void *context)
{
    // Default entry is always first
    if ( isDefaultEntry( entry1 ) ) return -1;
    if ( isDefaultEntry( entry2 ) ) return 1;
    
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

+ (void)initialize
{
    int i;

    [super initialize];

    iTermBackground = [[NSColor blackColor] retain];
    iTermForeground = [[NSColor colorWithCalibratedRed:0.8f
						 green:0.8f
						  blue:0.8f
						 alpha:1.0f]
        retain];
    iTermSelection = [[NSColor colorWithCalibratedRed:0.45f
						green:0.5f
						 blue:0.55f
						alpha:1.0f]
        retain];

    iTermBold = [[NSColor redColor] retain];

    xtermBackground = [[NSColor whiteColor] retain];
    xtermForeground = [[NSColor blackColor] retain];
    xtermSelection = [NSColor selectedTextBackgroundColor];
    xtermBold = [[NSColor redColor] retain];

    xtermColorTable[0][0]  = [[NSColor blackColor] retain];
    xtermColorTable[0][1]  = [[NSColor redColor] retain];
    xtermColorTable[0][2]  = [[NSColor greenColor] retain];
    xtermColorTable[0][3] = [[NSColor yellowColor] retain];
    xtermColorTable[0][4] = [[NSColor blueColor] retain];
    xtermColorTable[0][5] = [[NSColor magentaColor] retain];
    xtermColorTable[0][6]  = [[NSColor cyanColor] retain];
    xtermColorTable[0][7]  = [[NSColor whiteColor] retain];
    iTermColorTable[0][0]  = [[NSColor colorWithCalibratedRed:0.0f
							green:0.0f
							 blue:0.0f
							alpha:1.0f]
        retain];
    iTermColorTable[0][1]  = [[NSColor colorWithCalibratedRed:0.7f
                                                        green:0.0f
                                                         blue:0.0f
                                                        alpha:1.0f]
        retain];
    iTermColorTable[0][2]  = [[NSColor colorWithCalibratedRed:0.0f
                                                        green:0.7f
                                                         blue:0.0f
                                                        alpha:1.0f]
        retain];
    iTermColorTable[0][3] = [[NSColor colorWithCalibratedRed:0.7f
                                                       green:0.7f
                                                        blue:0.0f
                                                       alpha:1.0f]
        retain];
    iTermColorTable[0][4] = [[NSColor colorWithCalibratedRed:0.0f
                                                       green:0.0f
                                                        blue:0.7f
                                                       alpha:1.0f]
        retain];
    iTermColorTable[0][5] = [[NSColor colorWithCalibratedRed:0.7f
                                                       green:0.0f
                                                        blue:0.7f
                                                       alpha:1.0f]
        retain];
    iTermColorTable[0][6]  = [[NSColor colorWithCalibratedRed:0.45f
                                                        green:0.45f
                                                         blue:0.7f
                                                        alpha:1.0f]
        retain];
    iTermColorTable[0][7]  = [[NSColor colorWithCalibratedRed:0.7f
                                                        green:0.7f
                                                         blue:0.7f
                                                        alpha:1.0f]
        retain];

    for (i=0;i<8;i++) {
        xtermColorTable[1][i]=[[AddressBookWindowController highlightColor:xtermColorTable[0][i]] retain];
        iTermColorTable[1][i]=[[AddressBookWindowController highlightColor:iTermColorTable[0][i]] retain];
    }

}

+ (NSColor *) highlightColor:(NSColor *)color
{

    color=[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    if ([color brightnessComponent]>0.5) {
        if ([color brightnessComponent]>0.81) {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]-0.3
                                            alpha:[color alphaComponent]];
            //                color=[color shadowWithLevel:0.2];
        }
        else {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]+0.3
                                            alpha:[color alphaComponent]];
        }
        //            color=[color highlightWithLevel:0.2];
    }
    else {
        if ([color brightnessComponent]>0.19) {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]-0.3
                                            alpha:[color alphaComponent]];
            //                color=[color shadowWithLevel:0.2];
        }
        else {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]+0.3
                                            alpha:[color alphaComponent]];
            //                color=[color highlightWithLevel:0.2];
        }
    }

    return color;
}


- (id) initWithWindowNibName: (NSString *) windowNibName
{
#if DEBUG_ALLOC
    NSLog(@"AddressBookWindowController: -initWithWindowNibName");
#endif
    
    self = [super initWithWindowNibName: windowNibName];
    encodingList=[NSString availableStringEncodings];

    // We finally set our autosave window frame name and restore the one from the user's defaults.
    [[self window] setFrameAutosaveName: @"AddressBook"];
    [[self window] setFrameUsingName: @"AddressBook"];

    [[self window] setDelegate: self];

    return (self);
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"AddressBookWindowController: -dealloc");
#endif

    singleInstance = nil;
    
}

+ (NSColor *) colorFromTable:(int)index highLight:(BOOL)hili
{    
    if(iTermColorTable[0][0] == nil)
	[self initialize];
    
    if (index<8)
        return iTermColorTable[hili?1:0][index];
    else return nil;    
}

+ (NSColor *) defaultSelectionColor
{
    if(iTermSelection == nil)
	[self initialize];
    return (iTermSelection);
}

+ (NSColor *) defaultBoldColor
{
    if(iTermBold == nil)
	[self initialize];
    return (iTermBold);
}


- (void) awakeFromNib
{
    //    NSLog(@ "initAddressBook: %d\n%@",[addressBook count], addressBook);
    // Tell the addressbook table in the gui that number of rows have changed.
    // Other the scrollview is not activated for large addressbooks.
    // Cocoa bug?
    [adTable noteNumberOfRowsChanged];
    
}

// NSWindow delegate methods
- (void)windowWillClose:(NSNotification *)aNotification
{

    [self autorelease];
    
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

- (IBAction)adbDuplicateEntry:(id)sender
{
    NSMutableDictionary *entry, *ae;

    entry=[[self addressBook] objectAtIndex:[adTable selectedRow]];

    if(entry == nil)
    {
	NSBeep();
	return;
    }

    ae = [[NSMutableDictionary alloc] initWithDictionary: entry];
    [ae removeObjectForKey: @"DefaultEntry"];
    [ae setObject: [NSString stringWithFormat: @"%@ copy", [entry objectForKey: @"Name"]] forKey: @"Name"];
    
    [[self addressBook] addObject:ae];
    [ae release];

    [[self addressBook] sortUsingFunction: addressBookComparator context: nil];
    //        NSLog(@"%s(%d):-[Address entry added:%@]",
    //              __FILE__, __LINE__, ae );
    [adTable reloadData];
    
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

    if ([adTable selectedRow]<0) return;
    [AE_PANEL center];
    
    entry=[[self addressBook] objectAtIndex:[adTable selectedRow]];
    defaultEntry = isDefaultEntry( entry );
    [adName setStringValue:[entry objectForKey:@"Name"]];
    [adCommand setStringValue:[entry objectForKey:@"Command"]];
    [adEncoding removeAllItems];
    r=0;
    while (*p) {
        //        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [adEncoding addItemWithTitle:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[[entry objectForKey:@"Encoding"] unsignedIntValue]) r=p-encodingList;
        p++;
    }
    [adEncoding selectItemAtIndex:r];
    if ([entry objectForKey:@"Term Type"])
        [adTermType selectItemWithTitle:[entry objectForKey:@"Term Type"]];
    else
        [adTermType selectItemAtIndex:0];
    if ([entry objectForKey:@"Shortcut"]&&[[entry objectForKey:@"Shortcut"] intValue]) {
        [adShortcut setStringValue:[NSString stringWithFormat:@"%c",[[entry  objectForKey:@"Shortcut"] intValue]]];
    }
    else
        [adShortcut selectItemAtIndex:0];

    // set the colors
    [colorScheme selectItemAtIndex: [[entry objectForKey: @"ColorScheme"] intValue]];
    [adForeground setColor:[entry objectForKey:@"Foreground"]];
    [adBackground setColor:[entry objectForKey:@"Background"]];
    if([entry objectForKey:@"SelectionColor"])
        [adSelection setColor:[entry objectForKey:@"SelectionColor"]];
    else
        [adSelection setColor: iTermSelection];
    if([entry objectForKey:@"BoldColor"])
        [adBold setColor:[entry objectForKey:@"BoldColor"]];
    else
        [adBold setColor: iTermBold];
    if([entry objectForKey:@"AnsiBlackColor"])
        [ansiBlack setColor:[entry objectForKey:@"AnsiBlackColor"]];
    else
        [ansiBlack setColor: iTermColorTable[0][0]];
    if([entry objectForKey:@"AnsiRedColor"])
        [ansiRed setColor:[entry objectForKey:@"AnsiRedColor"]];
    else
        [ansiRed setColor: iTermColorTable[0][1]];
    if([entry objectForKey:@"AnsiGreenColor"])
        [ansiGreen setColor:[entry objectForKey:@"AnsiGreenColor"]];
    else
	[ansiGreen setColor:iTermColorTable[0][2]];
    if([entry objectForKey:@"AnsiYellowColor"])
        [ansiYellow setColor:[entry objectForKey:@"AnsiYellowColor"]];
    else
	[ansiYellow setColor:iTermColorTable[0][3]];
    if([entry objectForKey:@"AnsiBlueColor"])
        [ansiBlue setColor:[entry objectForKey:@"AnsiBlueColor"]];
    else
	[ansiBlue setColor:iTermColorTable[0][4]];
    if([entry objectForKey:@"AnsiMagentaColor"])
        [ansiMagenta setColor:[entry objectForKey:@"AnsiMagentaColor"]];
    else
	[ansiMagenta setColor:iTermColorTable[0][5]];
    if([entry objectForKey:@"AnsiCyanColor"])
        [ansiCyan setColor:[entry objectForKey:@"AnsiCyanColor"]];
    else
	[ansiCyan setColor:iTermColorTable[0][6]];
    if([entry objectForKey:@"AnsiWhiteColor"])
        [ansiWhite setColor:[entry objectForKey:@"AnsiWhiteColor"]];
    else
	[ansiWhite setColor:iTermColorTable[0][7]];
    if([entry objectForKey:@"AnsiHiBlackColor"])
        [ansiHiBlack setColor:[entry objectForKey:@"AnsiHiBlackColor"]];
    else
        [ansiHiBlack setColor: iTermColorTable[1][0]];
    if([entry objectForKey:@"AnsiHiRedColor"])
        [ansiHiRed setColor:[entry objectForKey:@"AnsiHiRedColor"]];
    else
        [ansiHiRed setColor: iTermColorTable[1][1]];
    if([entry objectForKey:@"AnsiHiGreenColor"])
        [ansiHiGreen setColor:[entry objectForKey:@"AnsiHiGreenColor"]];
    else
	[ansiHiGreen setColor:iTermColorTable[1][2]];
    if([entry objectForKey:@"AnsiHiYellowColor"])
        [ansiHiYellow setColor:[entry objectForKey:@"AnsiHiYellowColor"]];
    else
	[ansiHiYellow setColor:iTermColorTable[1][3]];
    if([entry objectForKey:@"AnsiHiBlueColor"])
        [ansiHiBlue setColor:[entry objectForKey:@"AnsiHiBlueColor"]];
    else
	[ansiHiBlue setColor:iTermColorTable[1][4]];
    if([entry objectForKey:@"AnsiHiMagentaColor"])
        [ansiHiMagenta setColor:[entry objectForKey:@"AnsiHiMagentaColor"]];
    else
	[ansiHiMagenta setColor:iTermColorTable[1][5]];
    if([entry objectForKey:@"AnsiHiCyanColor"])
        [ansiHiCyan setColor:[entry objectForKey:@"AnsiHiCyanColor"]];
    else
	[ansiHiCyan setColor:iTermColorTable[1][6]];
    if([entry objectForKey:@"AnsiHiWhiteColor"])
        [ansiHiWhite setColor:[entry objectForKey:@"AnsiHiWhiteColor"]];
    else
	[ansiHiWhite setColor:iTermColorTable[1][7]];
    
        
    [adRow setStringValue:[entry objectForKey:@"Row"]];
    [adCol setStringValue:[entry objectForKey:@"Col"]];
    if ([entry objectForKey:@"Transparency"]) {
        [adTransparency setIntValue:[[entry objectForKey:@"Transparency"] intValue]];
        [adTransparency2 setIntValue:[[entry objectForKey:@"Transparency"] intValue]];
    }
    else {
        [adTransparency setIntValue:10];
        [adTransparency2 setIntValue:10];
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
    [adAI setState:([entry objectForKey:@"AntiIdle"]==nil?NO:[[entry objectForKey:@"AntiIdle"] boolValue])?NSOnState:NSOffState];
    [adAICode setIntValue:[entry objectForKey:@"AICode"]==nil?0:[[entry objectForKey:@"AICode"] intValue]];
    [adClose setState:([entry objectForKey:@"AutoClose"]==nil?NO:[[entry objectForKey:@"AutoClose"] boolValue])?NSOnState:NSOffState];
    [adDoubleWidth setState:([entry objectForKey:@"DoubleWidth"]==nil?0:[[entry objectForKey:@"DoubleWidth"] boolValue])?NSOnState:NSOffState];
    [adRemapDeleteKey setState:([entry objectForKey:@"RemapDeleteKey"]==nil?NO:[[entry objectForKey:@"RemapDeleteKey"] boolValue])?NSOnState:NSOffState];


    r= [NSApp runModalForWindow:AE_PANEL];
    [AE_PANEL close];
    if (r == NSRunStoppedResponse) {
        NSDictionary *ae;
        ae=[self _getUpdatedPropertyDictionary];
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
    if ([adTable selectedRow]<0) return;
    
    if ( isDefaultEntry( [[self addressBook] objectAtIndex:[adTable selectedRow]] ) ) {
        // Post Alert or better yet, disable the remote button
    } else {
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
    [[adTextExample window] makeFirstResponder:self];
    [[NSFontManager sharedFontManager] setSelectedFont:aeFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)adEditNAFont:(id)sender
{
    changingNA=YES;
    [[adNATextExample window] makeFirstResponder:self];
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

- (IBAction) changeTab: (id) sender
{
    [tabView selectTabViewItemAtIndex: [sender indexOfSelectedItem]];
}

- (IBAction) executeABCommand: (id) sender
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[AddressBookWindowController executeABCommand:%@]",
          __FILE__, __LINE__, sender);
#endif


    if(([adTable selectedRow] < 0) || ([adTable numberOfRows] == 0))
	return;

    [NSApp stopModal];

    if(sender == openInWindow)
        [[NSApp delegate] executeABCommandAtIndex: [adTable selectedRow] inTerminal: nil];
    else
        [[NSApp delegate] executeABCommandAtIndex: [adTable selectedRow] inTerminal: [[NSApp delegate] frontPseudoTerminal]];
}

- (IBAction)editColorScheme: (id) sender
{
    // set the color scheme to custom
    [colorScheme selectItemAtIndex: 0];
}

- (IBAction)changeColorScheme:(id)sender
{

    switch ([sender indexOfSelectedItem]) {
        case 0:
            break;
        case 1:
	    [adBackground setColor:iTermBackground];
	    [adForeground setColor:iTermForeground];
	    [adSelection setColor: iTermSelection];
	    [adBold setColor: iTermBold];
	    [ansiBlack setColor:iTermColorTable[0][0]];
	    [ansiRed setColor:iTermColorTable[0][1]];
	    [ansiGreen setColor:iTermColorTable[0][2]];
	    [ansiYellow setColor:iTermColorTable[0][3]];
	    [ansiBlue setColor:iTermColorTable[0][4]];
	    [ansiMagenta setColor:iTermColorTable[0][5]];
	    [ansiCyan setColor:iTermColorTable[0][6]];
	    [ansiWhite setColor:iTermColorTable[0][7]];
	    [ansiHiBlack setColor:iTermColorTable[1][0]];
	    [ansiHiRed setColor:iTermColorTable[1][1]];
	    [ansiHiGreen setColor:iTermColorTable[1][2]];
	    [ansiHiYellow setColor:iTermColorTable[1][3]];
	    [ansiHiBlue setColor:iTermColorTable[1][4]];
	    [ansiHiMagenta setColor:iTermColorTable[1][5]];
	    [ansiHiCyan setColor:iTermColorTable[1][6]];
	    [ansiHiWhite setColor:iTermColorTable[1][7]];	    
	    break;
        case 2:
	    [adBackground setColor:xtermBackground];
	    [adForeground setColor:xtermForeground];
	    [adSelection setColor: xtermSelection];
	    [adBold setColor: xtermBold];
	    [ansiBlack setColor:xtermColorTable[0][0]];
	    [ansiRed setColor:xtermColorTable[0][1]];
	    [ansiGreen setColor:xtermColorTable[0][2]];
	    [ansiYellow setColor:xtermColorTable[0][3]];
	    [ansiBlue setColor:xtermColorTable[0][4]];
	    [ansiMagenta setColor:xtermColorTable[0][5]];
	    [ansiCyan setColor:xtermColorTable[0][6]];
	    [ansiWhite setColor:xtermColorTable[0][7]];
	    [ansiHiBlack setColor:xtermColorTable[1][0]];
	    [ansiHiRed setColor:xtermColorTable[1][1]];
	    [ansiHiGreen setColor:xtermColorTable[1][2]];
	    [ansiHiYellow setColor:xtermColorTable[1][3]];
	    [ansiHiBlue setColor:xtermColorTable[1][4]];
	    [ansiHiMagenta setColor:xtermColorTable[1][5]];
	    [ansiHiCyan setColor:xtermColorTable[1][6]];
	    [ansiHiWhite setColor:xtermColorTable[1][7]];	    
	    break;
    }
    [adTextExample setBackgroundColor:[adBackground color]];
    [adNATextExample setBackgroundColor:[adBackground color]];
    [adTextExample setTextColor:[adForeground color]];
    [adNATextExample setTextColor:[adForeground color]];
    
}


// misc
- (void) run;
{
//    int r;

    [[self window] center];
    [adTable setDataSource: self];
    if([adTable numberOfRows] > 0){
	[adTable selectRow: 0 byExtendingSelection: NO];
	[[self window] makeFirstResponder: adTable];
    }
    [adTable setDoubleAction: @selector(executeABCommand:)];
    [adTable setAllowsColumnReordering: NO];
    //r= [NSApp runModalForWindow:[self window]];
    //[[self window] close];
    [tabSelection selectItemAtIndex: 0];
    [tabView selectTabViewItemAtIndex: 0];
    [self showWindow: self];
}

- (void)changeFont:(id)fontManager
{
    if (changingNA) {
        [aeNAFont autorelease];
        aeNAFont=[fontManager convertFont:[adNATextExample font]];
        [adNATextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeNAFont fontName], [aeNAFont pointSize]]];
        [adNATextExample setFont:aeNAFont];
    }
    else {
        [aeFont autorelease];
        aeFont=[fontManager convertFont:[adTextExample font]];
        [adTextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeFont fontName], [aeFont pointSize]]];
        [adTextExample setFont:aeFont];
    }
}

// Table data source
- (int)numberOfRowsInTableView:(NSTableView*)table
{
    return [addressBook count];
}

// this message is called for each row of the table
- (id)tableView:(NSTableView*)table objectValueForTableColumn:(NSTableColumn*)col
	    row:(int)rowIndex
{
    NSDictionary *theRecord;
    NSString *s=nil;

    NSParameterAssert(rowIndex >= 0 && rowIndex < [addressBook count]);
    theRecord = [addressBook objectAtIndex:rowIndex];
    switch ([[col identifier] intValue]) {
        case 0:
            s=entryVisibleName( theRecord, self );
            break;
        case 1:
            s=[theRecord objectForKey:@"Command"];
            break;
        case 2:
	    //            NSLog(@"%@:%d",[theRecord objectForKey:@"Name"],[[theRecord objectForKey:@"Shortcut"] intValue]);
            s=([[theRecord objectForKey:@"Shortcut"] intValue]?
	       [NSString stringWithFormat:@"%c",[[theRecord objectForKey:@"Shortcut"] intValue]]:@"");
    }

    return s;
}



@end

@implementation AddressBookWindowController (Private)

- (NSDictionary *) _getUpdatedPropertyDictionary
{
    NSDictionary *ae;

    ae = [[NSDictionary alloc] initWithObjectsAndKeys:
	[adName stringValue],@"Name",
	[adCommand stringValue],@"Command",
	[NSNumber numberWithUnsignedInt:encodingList[[adEncoding indexOfSelectedItem]]],@"Encoding",
	[NSNumber numberWithUnsignedInt: [colorScheme indexOfSelectedItem]], @"ColorScheme",
	[adForeground color],@"Foreground",
	[adBackground color],@"Background",
	[adSelection color],@"SelectionColor",
	[adBold color],@"BoldColor",
	[ansiBlack color], @"AnsiBlackColor",
	[ansiRed color], @"AnsiRedColor",
	[ansiGreen color], @"AnsiGreenColor",
	[ansiYellow color], @"AnsiYellowColor",
	[ansiBlue color], @"AnsiBlueColor",
	[ansiMagenta color], @"AnsiMagentaColor",
	[ansiCyan color], @"AnsiCyanColor",
	[ansiWhite color], @"AnsiWhiteColor",
	[ansiHiBlack color], @"AnsiHiBlackColor",
	[ansiHiRed color], @"AnsiHiRedColor",
	[ansiHiGreen color], @"AnsiHiGreenColor",
	[ansiHiYellow color], @"AnsiHiYellowColor",
	[ansiHiBlue color], @"AnsiHiBlueColor",
	[ansiHiMagenta color], @"AnsiHiMagentaColor",
	[ansiHiCyan color], @"AnsiHiCyanColor",
	[ansiHiWhite color], @"AnsiHiWhiteColor",
	[adRow stringValue],@"Row",
	[adCol stringValue],@"Col",
	[NSNumber numberWithInt:[adTransparency intValue]],@"Transparency",
	[adTermType titleOfSelectedItem],@"Term Type",
	[adDir stringValue],@"Directory",
	aeFont,@"Font",
	aeNAFont,@"NAFont",
	[NSNumber numberWithBool:([adAI state]==NSOnState)],@"AntiIdle",
	[NSNumber numberWithUnsignedInt:[adAICode intValue]],@"AICode",
	[NSNumber numberWithBool:([adClose state]==NSOnState)],@"AutoClose",
	[NSNumber numberWithBool:([adDoubleWidth state]==NSOnState)],@"DoubleWidth",
	[NSNumber numberWithBool:([adRemapDeleteKey state]==NSOnState)],@"RemapDeleteKey",
	[NSNumber numberWithUnsignedInt:[adShortcut indexOfSelectedItem]?[[adShortcut stringValue] characterAtIndex:0]:0],@"Shortcut",
	[NSNumber numberWithBool:defaultEntry],@"DefaultEntry",
	NULL];

    return (ae);
}

@end

