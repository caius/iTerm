// $Id: PreferencePanel.m,v 1.93 2004-03-18 16:45:11 ujwal Exp $
/*
 **  PreferencePanel.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
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
#import <iTerm/iTermKeyBindingMgr.h>
#import <iTerm/iTermDisplayProfileMgr.h>
#import <iTerm/iTermTerminalProfileMgr.h>
#import <iTerm/Tree.h>

static float versionNumber;

@implementation PreferencePanel

+ (PreferencePanel*)sharedInstance;
{
    static PreferencePanel* shared = nil;
    
    if (!shared)
	{
		shared = [[self alloc] initWithWindowNibName: @"PreferencePanel"];
        [shared window]; // force the window to load now
	}
    
    return shared;
}

- (id)initWithWindowNibName: (NSString *) windowNibName
{
    unsigned int storedMajorVersion = 0, storedMinorVersion = 0, storedMicroVersion = 0;
#if DEBUG_OBJALLOC
    NSLog(@"%s(%d):-[PreferencePanel init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
        return nil;
	
	[super initWithWindowNibName: windowNibName];
    
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

         
    defaultTabViewType=[prefs objectForKey:@"TabViewType"]?[prefs integerForKey:@"TabViewType"]:0;
    defaultCopySelection=[[prefs objectForKey:@"CopySelection"] boolValue];
    defaultHideTab=[prefs objectForKey:@"HideTab"]?[[prefs objectForKey:@"HideTab"] boolValue]: YES;
    defaultOpenAddressBook = [prefs objectForKey:@"OpenAddressBook"]?[[prefs objectForKey:@"OpenAddressBook"] boolValue]: NO;
    defaultPromptOnClose = [prefs objectForKey:@"PromptOnClose"]?[[prefs objectForKey:@"PromptOnClose"] boolValue]: YES;
    defaultFocusFollowsMouse = [prefs objectForKey:@"FocusFollowsMouse"]?[[prefs objectForKey:@"FocusFollowsMouse"] boolValue]: NO;
	
	[[iTermKeyBindingMgr singleInstance] setProfiles: [prefs objectForKey: @"KeyBindings"]];
	[[iTermDisplayProfileMgr singleInstance] setProfiles: [prefs objectForKey: @"Displays"]];
	[[iTermTerminalProfileMgr singleInstance] setProfiles: [prefs objectForKey: @"Terminals"]];
	[[ITAddressBookMgr sharedInstance] setBookmarks: [prefs objectForKey: @"Bookmarks"]];
}

- (void)run
{
	    
    [tabPosition selectCellWithTag: defaultTabViewType];
    [selectionCopiesText setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [openAddressBook setState:defaultOpenAddressBook?NSOnState:NSOffState];
    [promptOnClose setState:defaultPromptOnClose?NSOnState:NSOffState];
	[focusFollowsMouse setState: defaultFocusFollowsMouse?NSOnState:NSOffState];
	[wordChars setStringValue: [prefs objectForKey: @"WordCharacters"]?[prefs objectForKey: @"WordCharacters"]:@""];
	    
	[[self window] setDelegate: self];
	[self showWindow: self];
	
}

- (IBAction)cancel:(id)sender
{
    [self readPreferences];
	[[self window] performClose: self];
}

- (IBAction)ok:(id)sender
{    

    defaultTabViewType=[[tabPosition selectedCell] tag];
    defaultCopySelection=([selectionCopiesText state]==NSOnState);
    defaultHideTab=([hideTab state]==NSOnState);
    defaultOpenAddressBook = ([openAddressBook state] == NSOnState);
    defaultPromptOnClose = ([promptOnClose state] == NSOnState);
    defaultFocusFollowsMouse = ([focusFollowsMouse state] == NSOnState);

    [prefs setBool:defaultCopySelection forKey:@"CopySelection"];
    [prefs setBool:defaultHideTab forKey:@"HideTab"];
    [prefs setInteger:defaultTabViewType forKey:@"TabViewType"];
    [prefs setBool:defaultOpenAddressBook forKey:@"OpenAddressBook"];
    [prefs setBool:defaultPromptOnClose forKey:@"PromptOnClose"];
    [prefs setBool:defaultFocusFollowsMouse forKey:@"FocusFollowsMouse"];
	[prefs setObject: [wordChars stringValue] forKey: @"WordCharacters"];
	[prefs setObject: [[iTermKeyBindingMgr singleInstance] profiles] forKey: @"KeyBindings"];
	[prefs setObject: [[iTermDisplayProfileMgr singleInstance] profiles] forKey: @"Displays"];
	[prefs setObject: [[iTermTerminalProfileMgr singleInstance] profiles] forKey: @"Terminals"];
	[prefs setObject: [[ITAddressBookMgr sharedInstance] bookmarks] forKey: @"Bookmarks"];

    [[self window] performClose: self];
}

// NSOutlineView delegate methods
- (void) outlineViewSelectionDidChange: (NSNotification *) aNotification
{
	if([bookmarksView selectedRow] == -1)
	{
		[bookmarkDeleteFolderButton setEnabled: NO];
		[bookmarkDeleteButton setEnabled: NO];
	}
	else
	{
		[bookmarkDeleteFolderButton setEnabled: YES];
		[bookmarkDeleteButton setEnabled: YES];
	}
}

// NSOutlineView data source methods
// required
- (id)outlineView:(NSOutlineView *)ov child:(int)index ofItem:(id)item
{
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    return [[ITAddressBookMgr sharedInstance] child:index ofItem: item];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    return [[ITAddressBookMgr sharedInstance] isExpandable: item];
}

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    return [[ITAddressBookMgr sharedInstance] numberOfChildrenOfItem: item];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    //NSLog(@"%s", __PRETTY_FUNCTION__);
	// item should be a tree node witha dictionary data object
    return [[ITAddressBookMgr sharedInstance] objectForKey:[tableColumn identifier] inItem: item];
}

// Optional method: needed to allow editing.
- (void)outlineView:(NSOutlineView *)olv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item  
{
	[[ITAddressBookMgr sharedInstance] setObjectValue: object forKey:[tableColumn identifier] inItem: item];	
}


// Bookmark actions
- (IBAction) addBookmarkFolder: (id) sender
{
	[NSApp beginSheet: addBookmarkFolderPanel
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(_addBookmarkFolderSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];        
}

- (IBAction) addBookmarkFolderConfirm: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[NSApp endSheet:addBookmarkFolderPanel returnCode:NSOKButton];
}

- (IBAction) addBookmarkFolderCancel: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[NSApp endSheet:addBookmarkFolderPanel returnCode:NSCancelButton];
}

- (IBAction) deleteBookmarkFolder: (id) sender
{
	[NSApp beginSheet: deleteBookmarkPanel
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(_deleteBookmarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];        
}

- (IBAction) deleteBookmarkConfirm: (id) sender
{
	[NSApp endSheet:deleteBookmarkPanel returnCode:NSOKButton];
}

- (IBAction) deleteBookmarkCancel: (id) sender
{
	[NSApp endSheet:deleteBookmarkPanel returnCode:NSCancelButton];
}

- (IBAction) addBookmark: (id) sender
{
	[self editBookmark: self];
}

- (IBAction) addBookmarkConfirm: (id) sender
{
	[NSApp endSheet:editBookmarkPanel returnCode:NSOKButton];
}

- (IBAction) addBookmarkCancel: (id) sender
{
	[NSApp endSheet:editBookmarkPanel returnCode:NSCancelButton];
}

- (IBAction) deleteBookmark: (id) sender
{
	[NSApp beginSheet: deleteBookmarkPanel
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(_deleteBookmarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];        
}

- (IBAction) editBookmark: (id) sender
{
	
	// load our profiles
	[self _loadProfiles];
	
	[NSApp beginSheet: editBookmarkPanel
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(_editBookmarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];        
}


// NSWindow delegate
- (void)windowWillLoad;
{
    // We finally set our autosave window frame name and restore the one from the user's defaults.
    [self setWindowFrameAutosaveName: @"Preferences"];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	// make sure buttons are properly enabled/disabled
	[bookmarksView reloadData];
	[self outlineViewSelectionDidChange: nil];
    // Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"nonTerminalWindowBecameKey" object: nil userInfo: nil];        
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[profilesWindow performClose: self];
}


// accessors for preferences
- (BOOL) antiAlias
{
    return YES; // fix me
}


- (BOOL) copySelection
{
    return (defaultCopySelection);
}

- (void) setCopySelection: (BOOL) flag
{
	defaultCopySelection = flag;
}

- (BOOL) hideTab
{
    return (defaultHideTab);
}

- (BOOL) silenceBell
{
    return (NO); // fix me
}

- (void) setTabViewType: (NSTabViewType) type
{
    defaultTabViewType = type;
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
    return (NO); // fix me
}

- (BOOL) focusFollowsMouse
{
    return (defaultFocusFollowsMouse);
}

- (NSString *) wordChars
{
	return ([prefs objectForKey: @"WordCharacters"]);
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

@implementation PreferencePanel (Private)

- (void)_addBookmarkFolderSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	TreeNode *parentNode;
	int selectedRow;
	
	selectedRow = [bookmarksView selectedRow];
	
	// if no row is selected, new node is child of root
	if(selectedRow == -1)
		parentNode = nil;
	else
		parentNode = [bookmarksView itemAtRow: selectedRow];
	
	// If a leaf node is selected, make new node its sibling
	if([bookmarksView isExpandable: parentNode] == NO)
		parentNode = [parentNode nodeParent];
	
	if(returnCode == NSOKButton)
	{		
		[[ITAddressBookMgr sharedInstance] addFolder: [bookmarkFolderName stringValue] toNode: parentNode];
		[bookmarksView reloadData];
	}
	[addBookmarkFolderPanel close];
}

- (void)_deleteBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	
	if(returnCode == NSOKButton)
	{
		
		[[ITAddressBookMgr sharedInstance] deleteBookmarkNode: [bookmarksView itemAtRow: [bookmarksView selectedRow]]];
		[bookmarksView reloadData];
	}
	[deleteBookmarkPanel close];
}

- (void)_editBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSMutableDictionary *aDict;
	TreeNode *parentNode;
	int selectedRow;
		
	
	if(returnCode == NSOKButton)
	{
		if([[bookmarkName stringValue] length] <= 0)
		{
			NSBeep();
			return;
		}
		if([[bookmarkCommand stringValue] length] <= 0)
		{
			NSBeep();
			return;
		}
		if([[bookmarkWorkingDirectory stringValue] length] <= 0)
		{
			NSBeep();
			return;
		}
		
		aDict = [[NSMutableDictionary alloc] init];
		
		[aDict setObject: [bookmarkName stringValue] forKey: KEY_NAME];
		[aDict setObject: [bookmarkCommand stringValue] forKey: KEY_DESCRIPTION];
		[aDict setObject: [bookmarkCommand stringValue] forKey: KEY_COMMAND];
		[aDict setObject: [bookmarkWorkingDirectory stringValue] forKey: KEY_WORKING_DIRECTORY];
		[aDict setObject: [bookmarkTerminalProfile titleOfSelectedItem] forKey: KEY_TERMINAL_PROFILE];
		[aDict setObject: [bookmarkKeyboardProfile titleOfSelectedItem] forKey: KEY_KEYBOARD_PROFILE];
		[aDict setObject: [bookmarkDisplayProfile titleOfSelectedItem] forKey: KEY_DISPLAY_PROFILE];
		
		selectedRow = [bookmarksView selectedRow];
		
		// if no row is selected, new node is child of root
		if(selectedRow == -1)
			parentNode = nil;
		else
			parentNode = [bookmarksView itemAtRow: selectedRow];
		
		// If a leaf node is selected, make new node its sibling
		if([bookmarksView isExpandable: parentNode] == NO)
			parentNode = [parentNode nodeParent];
		
		[[ITAddressBookMgr sharedInstance] addBookmarkWithData: aDict toNode: parentNode];

		[aDict release];
	}
	
	[editBookmarkPanel close];
}

- (void) _loadProfiles
{
	NSArray *profileArray;
	
	profileArray = [[[iTermTerminalProfileMgr singleInstance] profiles] allKeys];
	[bookmarkTerminalProfile removeAllItems];
	[bookmarkTerminalProfile addItemsWithTitles: profileArray];
	
	profileArray = [[[iTermKeyBindingMgr singleInstance] profiles] allKeys];
	[bookmarkKeyboardProfile removeAllItems];
	[bookmarkKeyboardProfile addItemsWithTitles: profileArray];
	
	profileArray = [[[iTermDisplayProfileMgr singleInstance] profiles] allKeys];
	[bookmarkDisplayProfile removeAllItems];
	[bookmarkDisplayProfile addItemsWithTitles: profileArray];
	
}

@end