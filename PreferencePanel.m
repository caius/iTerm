// $Id: PreferencePanel.m,v 1.62 2003-09-02 05:53:04 yfabian Exp $
/*
 **  PreferencePanel.m
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

#import <iTerm/PreferencePanel.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/AddressBookWindowController.h>
#import <iTerm/iTermController.h>
#import <iTerm/ITAddressBookMgr.h>


static float versionNumber;

@implementation PreferencePanel

+ (PreferencePanel*)sharedInstance;
{
    static PreferencePanel* shared = nil;
    
    if (!shared)
        shared = [[PreferencePanel alloc] init];
    
    return shared;
}

- (id)init
{
    unsigned int storedMajorVersion = 0, storedMinorVersion = 0, storedMicroVersion = 0;
#if DEBUG_OBJALLOC
    NSLog(@"%s(%d):-[PreferencePanel init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
        return nil;
    
    [self readPreferences];
    
    // get the version
    NSDictionary *myDict = [[NSBundle bundleForClass:[self class]] infoDictionary];
    versionNumber = [(NSNumber *)[myDict objectForKey:@"CFBundleVersion"] floatValue];
    if([prefs objectForKey: @"iTerm Version"])
    {
	sscanf([[prefs objectForKey: @"iTerm Version"] cString], "%d.%d.%d", &storedMajorVersion, &storedMinorVersion, &storedMicroVersion);
	// briefly, version 0.7.0 was stored as 0.70
	if(storedMajorVersion == 0 && storedMinorVersion == 70)
	    storedMinorVersion = 7;
    }
    //NSLog(@"Stored version = %d.%d.%d", storedMajorVersion, storedMinorVersion, storedMicroVersion);
        

    // sync the version number
    [prefs setObject: [myDict objectForKey:@"CFBundleVersion"] forKey: @"iTerm Version"];
                 
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void) readPreferences
{
    prefs = [NSUserDefaults standardUserDefaults];

    defaultAntiAlias=[prefs objectForKey:@"AntiAlias"]?[[prefs objectForKey:@"AntiAlias"] boolValue]: YES;
        
    defaultOption=[prefs objectForKey:@"OptionKey"]?[prefs integerForKey:@"OptionKey"]:0;
    defaultMacNavKeys=[prefs objectForKey:@"MacNavKeys"]?[[prefs objectForKey:@"MacNavKeys"] boolValue]: NO;
    defaultTabViewType=[prefs objectForKey:@"TabViewType"]?[prefs integerForKey:@"TabViewType"]:0;
    defaultCopySelection=[[prefs objectForKey:@"CopySelection"] boolValue];
    defaultHideTab=[prefs objectForKey:@"HideTab"]?[[prefs objectForKey:@"HideTab"] boolValue]: YES;
    defaultSilenceBell=[[prefs objectForKey:@"SilenceBell"] boolValue];
    defaultOpenAddressBook = [prefs objectForKey:@"OpenAddressBook"]?[[prefs objectForKey:@"OpenAddressBook"] boolValue]: NO;
    defaultPromptOnClose = [prefs objectForKey:@"PromptOnClose"]?[[prefs objectForKey:@"PromptOnClose"] boolValue]: YES;
    defaultBlinkingCursor = [prefs objectForKey:@"BlinkingCursor"]?[[prefs objectForKey:@"BlinkingCursor"] boolValue]: NO;
    defaultEnforceCharacterAlignment = [prefs objectForKey:@"EnforceCharacterAlignment"]?[[prefs objectForKey:@"EnforceCharacterAlignment"] boolValue]: YES;
}

- (void)run
{
    // Load our bundle
    if ([NSBundle loadNibNamed:@"PreferencePanel" owner:self] == NO)
	return;

    [prefPanel center];
    
    [antiAlias setState:defaultAntiAlias?NSOnState:NSOffState];
    
    [macnavkeys setState:defaultMacNavKeys?NSOnState:NSOffState];
    [optionKey selectCellAtRow:0 column:defaultOption];
    [tabViewType selectCellWithTag: defaultTabViewType];
    [copySelection setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [silenceBell setState:defaultSilenceBell?NSOnState:NSOffState];
    [openAddressBook setState:defaultOpenAddressBook?NSOnState:NSOffState];
    [promptOnClose setState:defaultPromptOnClose?NSOnState:NSOffState];
    [blinkingCursor setState: defaultBlinkingCursor?NSOnState:NSOffState];
    [enforceCharacterAlignment setState:defaultEnforceCharacterAlignment?NSOnState:NSOffState];
    
    [NSApp runModalForWindow:prefPanel];
    [prefPanel close];
}

- (IBAction)cancel:(id)sender
{
    [self readPreferences];
    [NSApp abortModal];
}

- (IBAction)ok:(id)sender
{    
    defaultAntiAlias = ([antiAlias state]==NSOnState);

    defaultMacNavKeys=([macnavkeys state]==NSOnState);
    defaultOption=[optionKey selectedColumn];
    defaultTabViewType=[[tabViewType selectedCell] tag];
    defaultCopySelection=([copySelection state]==NSOnState);
    defaultHideTab=([hideTab state]==NSOnState);
    defaultSilenceBell=([silenceBell state]==NSOnState);
    defaultOpenAddressBook = ([openAddressBook state] == NSOnState);
    defaultPromptOnClose = ([promptOnClose state] == NSOnState);
    defaultBlinkingCursor = ([blinkingCursor state] == NSOnState);
    defaultEnforceCharacterAlignment = ([enforceCharacterAlignment state] == NSOnState);

    [prefs setBool:defaultMacNavKeys forKey:@"MacNavKeys"];
    [prefs setInteger:defaultOption forKey:@"OptionKey"];
    [prefs setBool:defaultAntiAlias forKey:@"AntiAlias"];
    [prefs setBool:defaultCopySelection forKey:@"CopySelection"];
    [prefs setBool:defaultHideTab forKey:@"HideTab"];
    [prefs setBool:defaultSilenceBell forKey:@"SilenceBell"];
    [prefs setInteger:defaultTabViewType forKey:@"TabViewType"];
    [prefs setBool:defaultOpenAddressBook forKey:@"OpenAddressBook"];
    [prefs setBool:defaultPromptOnClose forKey:@"PromptOnClose"];
    [prefs setBool:defaultBlinkingCursor forKey:@"BlinkingCursor"];
    [prefs setBool:defaultEnforceCharacterAlignment forKey:@"EnforceCharacterAlignment"];
    
    [NSApp stopModal];
}

- (IBAction)restore:(id)sender
{    
    defaultMacNavKeys=YES;
    defaultOption=0;
    defaultHideTab=YES;
    defaultCopySelection=YES;
    defaultSilenceBell=NO;
    defaultTabViewType = NSTopTabsBezelBorder;
    defaultOpenAddressBook = NO;
    defaultBlinkingCursor = NO;
    defaultEnforceCharacterAlignment = YES;

    [macnavkeys setState:defaultMacNavKeys?NSOnState:NSOffState];
    [optionKey selectCellAtRow:0 column:defaultOption];
    [copySelection setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [silenceBell setState:defaultSilenceBell?NSOnState:NSOffState];
    [openAddressBook setState:defaultOpenAddressBook?NSOnState:NSOffState];
    [promptOnClose setState:defaultPromptOnClose?NSOnState:NSOffState];
    [tabViewType selectCellWithTag: defaultTabViewType];
    [blinkingCursor setState:defaultBlinkingCursor?NSOnState:NSOffState];
    [enforceCharacterAlignment setState:defaultEnforceCharacterAlignment?NSOnState:NSOffState];    
}

- (BOOL) antiAlias
{
    return defaultAntiAlias;
}

- (BOOL) macnavkeys
{
    return defaultMacNavKeys;
}

- (int) option
{
    return defaultOption;
}

- (BOOL) copySelection
{
    return (defaultCopySelection);
}

- (BOOL) hideTab
{
    return (defaultHideTab);
}

- (BOOL) silenceBell
{
    return (defaultSilenceBell);
}

- (NSTabViewType) tabViewType
{
    return (defaultTabViewType);
}

- (BOOL)openAddressBook
{
    return (defaultOpenAddressBook);
}

- (BOOL)promptOnClose
{
    return (defaultPromptOnClose);
}

- (BOOL) blinkingCursor
{
    return (defaultBlinkingCursor);
}

- (BOOL) enforceCharacterAlignment;
{
    return (defaultEnforceCharacterAlignment);
}

- (IBAction) editDefaultSession: (id) sender
{
    AddressBookWindowController *abWindowController;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermController showABWindow:%@]",
          __FILE__, __LINE__, sender);
#endif

    abWindowController = [AddressBookWindowController singleInstance];
    if([[abWindowController window] isVisible] == NO)
	[abWindowController setAddressBook: [[ITAddressBookMgr sharedInstance] addressBook]];
    
    [abWindowController adbEditEntryAtIndex: 0 newEntry: NO];
}

@end
