// $Id: PreferencePanel.m,v 1.99 2004-03-21 02:50:14 ujwal Exp $
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
#import <iTerm/iTermController.h>
#import <iTerm/ITAddressBookMgr.h>
#import <iTerm/iTermKeyBindingMgr.h>
#import <iTerm/iTermDisplayProfileMgr.h>
#import <iTerm/iTermTerminalProfileMgr.h>
#import <iTerm/Tree.h>

static float versionNumber;

static BOOL editingBookmark = NO;

#define iTermOutlineViewPboardType 	@"iTermOutlineViewPboardType"

@implementation PreferencePanel

+ (PreferencePanel*)sharedInstance;
{
    static PreferencePanel* shared = nil;

    if (!shared)
	{
		shared = [[self alloc] init];
	}
    
    return shared;
}

- (id) init
{
	unsigned int storedMajorVersion = 0, storedMinorVersion = 0, storedMicroVersion = 0;

	self = [super init];
	
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
	
	return (self);
}

- (id)initWithWindowNibName: (NSString *) windowNibName
{
#if DEBUG_OBJALLOC
    NSLog(@"%s(%d):-[PreferencePanel init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
        return nil;
	
	[super initWithWindowNibName: windowNibName];
                     
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
    defaultPromptOnClose = [prefs objectForKey:@"PromptOnClose"]?[[prefs objectForKey:@"PromptOnClose"] boolValue]: YES;
    defaultFocusFollowsMouse = [prefs objectForKey:@"FocusFollowsMouse"]?[[prefs objectForKey:@"FocusFollowsMouse"] boolValue]: NO;
	
	[[iTermKeyBindingMgr singleInstance] setProfiles: [prefs objectForKey: @"KeyBindings"]];
	[[iTermDisplayProfileMgr singleInstance] setProfiles: [prefs objectForKey: @"Displays"]];
	[[iTermTerminalProfileMgr singleInstance] setProfiles: [prefs objectForKey: @"Terminals"]];
	[[ITAddressBookMgr sharedInstance] setBookmarks: [prefs objectForKey: @"Bookmarks"]];
}

- (void)run
{
	
	// load nib if we haven't already
	if([self window] == nil)
		[self initWithWindowNibName: @"PreferencePanel"];
	    
    [tabPosition selectCellWithTag: defaultTabViewType];
    [selectionCopiesText setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
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
    defaultPromptOnClose = ([promptOnClose state] == NSOnState);
    defaultFocusFollowsMouse = ([focusFollowsMouse state] == NSOnState);

    [prefs setBool:defaultCopySelection forKey:@"CopySelection"];
    [prefs setBool:defaultHideTab forKey:@"HideTab"];
    [prefs setInteger:defaultTabViewType forKey:@"TabViewType"];
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
	int selectedRow = [bookmarksView selectedRow];
	id selectedItem;
	
	if(selectedRow == -1)
	{
		[bookmarkDeleteButton setEnabled: NO];
		[bookmarkEditButton setEnabled: NO];
	}
	else
	{
		selectedItem = [bookmarksView itemAtRow: selectedRow];
		
		if([[ITAddressBookMgr sharedInstance] mayDeleteBookmarkNode: selectedItem])
			[bookmarkDeleteButton setEnabled: YES];
		else
			[bookmarkDeleteButton setEnabled: NO];
		
		if([[ITAddressBookMgr sharedInstance] isExpandable: selectedItem])
			[bookmarkEditButton setEnabled: NO];
		else
			[bookmarkEditButton setEnabled: YES];
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

// ================================================================
//  NSOutlineView data source methods. (dragging related)
// ================================================================

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard 
{
    draggedNodes = items; // Don't retain since this is just holding temporaral drag information, and it is only used during a drag!  We could put this in the pboard actually.
    
    // Provide data for our custom type, and simple NSStrings.
    [pboard declareTypes:[NSArray arrayWithObjects: iTermOutlineViewPboardType, nil] owner:self];
    
    // the actual data doesn't matter since DragDropSimplePboardType drags aren't recognized by anyone but us!.
    [pboard setData:[NSData data] forType:iTermOutlineViewPboardType]; 
    	
    return YES;
}

- (unsigned int)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)childIndex 
{
    // This method validates whether or not the proposal is a valid one. Returns NO if the drop should not be allowed.
    TreeNode *targetNode = item;
    BOOL targetNodeIsValid = YES;
		
	// Refuse if: dropping "on" the view itself unless we have no data in the view.
	if (targetNode==nil && childIndex==NSOutlineViewDropOnItemIndex && [[ITAddressBookMgr sharedInstance] numberOfChildrenOfItem: nil]!=0) 
		targetNodeIsValid = NO;
	
	if ([targetNode isLeaf])
		targetNodeIsValid = NO;
		
	// Check to make sure we don't allow a node to be inserted into one of its descendants!
	if (targetNodeIsValid && ([info draggingSource]==bookmarksView) && [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject: iTermOutlineViewPboardType]] != nil) 
	{
		NSArray *_draggedNodes = [[[info draggingSource] dataSource] _draggedNodes];
		targetNodeIsValid = ![targetNode isDescendantOfNodeInArray: _draggedNodes];
	}
    
    // Set the item and child index in case we computed a retargeted one.
    [bookmarksView setDropItem:targetNode dropChildIndex:childIndex];
    
    return targetNodeIsValid ? NSDragOperationGeneric : NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(int)childIndex 
{
	TreeNode *parentNode;
	
	parentNode = targetItem;
	if(parentNode == nil)
		parentNode = [[ITAddressBookMgr sharedInstance] rootNode];

	childIndex = (childIndex==NSOutlineViewDropOnItemIndex?0:childIndex);
    
    [self _performDropOperation:info onNode:parentNode atIndex:childIndex];
	
    return YES;
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
	
	editingBookmark = NO;
	
	// load our profiles
	[self _loadProfiles];
	
	[NSApp beginSheet: editBookmarkPanel
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(_editBookmarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];        
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
	id selectedItem;
	NSString *terminalProfile, *keyboardProfile, *displayProfile;
	
	editingBookmark = YES;
	
	// load our profiles
	[self _loadProfiles];
	
	selectedItem = [bookmarksView itemAtRow: [bookmarksView selectedRow]];
	[bookmarkName setStringValue: [[ITAddressBookMgr sharedInstance] objectForKey: KEY_NAME inItem: selectedItem]];
	[bookmarkCommand setStringValue: [[ITAddressBookMgr sharedInstance] objectForKey: KEY_COMMAND inItem: selectedItem]];
	[bookmarkWorkingDirectory setStringValue: [[ITAddressBookMgr sharedInstance] objectForKey: KEY_WORKING_DIRECTORY inItem: selectedItem]];
	
	terminalProfile = [[ITAddressBookMgr sharedInstance] objectForKey: KEY_TERMINAL_PROFILE inItem: selectedItem];
	keyboardProfile = [[ITAddressBookMgr sharedInstance] objectForKey: KEY_KEYBOARD_PROFILE inItem: selectedItem];
	displayProfile = [[ITAddressBookMgr sharedInstance] objectForKey: KEY_DISPLAY_PROFILE inItem: selectedItem];
	
	if([bookmarkTerminalProfile indexOfItemWithTitle: terminalProfile] < 0)
		terminalProfile = NSLocalizedStringFromTableInBundle(@"Default",@"iTerm", [NSBundle bundleForClass: [self class]], @"Terminal Profiles");
	[bookmarkTerminalProfile selectItemWithTitle: terminalProfile];
	
	if([bookmarkKeyboardProfile indexOfItemWithTitle: keyboardProfile] < 0)
		keyboardProfile = NSLocalizedStringFromTableInBundle(@"Global",@"iTerm", [NSBundle bundleForClass: [self class]], @"Key Binding Profiles");
	[bookmarkKeyboardProfile selectItemWithTitle: keyboardProfile];
	
	if([bookmarkDisplayProfile indexOfItemWithTitle: displayProfile] < 0)
		displayProfile = NSLocalizedStringFromTableInBundle(@"Default",@"iTerm", [NSBundle bundleForClass: [self class]], @"Display Profiles");
	[bookmarkDisplayProfile selectItemWithTitle: displayProfile];

	
	[NSApp beginSheet: editBookmarkPanel
	   modalForWindow: [self window]
		modalDelegate: self
	   didEndSelector: @selector(_editBookmarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];        
}


// NSWindow delegate
- (void)windowWillLoad
{
    // We finally set our autosave window frame name and restore the one from the user's defaults.
    [self setWindowFrameAutosaveName: @"Preferences"];
}

- (void) windowDidLoad
{
	// Register to get our custom type!
    [bookmarksView registerForDraggedTypes:[NSArray arrayWithObjects: iTermOutlineViewPboardType, nil]];

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

- (void) setTabViewType: (NSTabViewType) type
{
    defaultTabViewType = type;
}

- (NSTabViewType) tabViewType
{
    return (defaultTabViewType);
}

- (BOOL)promptOnClose
{
    return (defaultPromptOnClose);
}

- (BOOL) focusFollowsMouse
{
    return (defaultFocusFollowsMouse);
}

- (NSString *) wordChars
{
	return ([prefs objectForKey: @"WordCharacters"]);
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
		// Post a notification to all open terminals to reload their addressbooks into the shortcut menu
		[[NSNotificationCenter defaultCenter] postNotificationName: @"iTermReloadAddressBook" object: nil userInfo: nil];    		
	}
	[addBookmarkFolderPanel close];
}

- (void)_deleteBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	
	if(returnCode == NSOKButton)
	{
		
		[[ITAddressBookMgr sharedInstance] deleteBookmarkNode: [bookmarksView itemAtRow: [bookmarksView selectedRow]]];
		[bookmarksView reloadData];
		// Post a notification to all open terminals to reload their addressbooks into the shortcut menu
		[[NSNotificationCenter defaultCenter] postNotificationName: @"iTermReloadAddressBook" object: nil userInfo: nil];    		
	}
	[deleteBookmarkPanel close];
}

- (void)_editBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSMutableDictionary *aDict;
	TreeNode *targetNode;
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
			targetNode = nil;
		else
			targetNode = [bookmarksView itemAtRow: selectedRow];
		
		// If a leaf node is selected, make new node its sibling
		if([bookmarksView isExpandable: targetNode] == NO && !editingBookmark)
			targetNode = [targetNode nodeParent];
		
		if(editingBookmark == NO)
			[[ITAddressBookMgr sharedInstance] addBookmarkWithData: aDict toNode: targetNode];
		else
		{
			[aDict setObject: [[ITAddressBookMgr sharedInstance] objectForKey: KEY_DESCRIPTION inItem: targetNode] forKey: KEY_DESCRIPTION];
			[[ITAddressBookMgr sharedInstance] setBookmarkWithData: aDict forNode: targetNode];
		}

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

- (NSArray *) _selectedNodes 
{ 
    NSMutableArray *items = [NSMutableArray array];
    NSEnumerator *selectedRows = [bookmarksView selectedRowEnumerator];
    NSNumber *selRow = nil;
    while( (selRow = [selectedRows nextObject]) ) 
	{
        if ([bookmarksView itemAtRow:[selRow intValue]]) 
            [items addObject: [bookmarksView itemAtRow:[selRow intValue]]];
    }
    return items;
}


- (NSArray*) _draggedNodes   
{ 
	return draggedNodes; 
}

- (void)_performDropOperation:(id <NSDraggingInfo>)info onNode:(TreeNode*)parentNode atIndex:(int)childIndex 
{
    // Helper method to insert dropped data into the model. 
    NSPasteboard * pboard = [info draggingPasteboard];
    NSMutableArray * itemsToSelect = nil;
    
    // Do the appropriate thing depending on wether the data is DragDropSimplePboardType or NSStringPboardType.
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:iTermOutlineViewPboardType, nil]] != nil) {
        PreferencePanel *dragDataSource = [[info draggingSource] dataSource];
        NSArray *_draggedNodes = [TreeNode minimumNodeCoverFromNodesInArray: [dragDataSource _draggedNodes]];
        NSEnumerator *draggedNodesEnum = [_draggedNodes objectEnumerator];
        TreeNode *_draggedNode = nil, *_draggedNodeParent = nil;
        
		itemsToSelect = [NSMutableArray arrayWithArray:[self _selectedNodes]];
		
        while ((_draggedNode = [draggedNodesEnum nextObject])) {
            _draggedNodeParent = [_draggedNode nodeParent];
            if (parentNode==_draggedNodeParent && [parentNode indexOfChild: _draggedNode]<childIndex) childIndex--;
            [_draggedNodeParent removeChild: _draggedNode];
        }
        [parentNode insertChildren: _draggedNodes atIndex: childIndex];
    } 
	
    [bookmarksView reloadData];
	// Post a notification to all open terminals to reload their addressbooks into the shortcut menu
	[[NSNotificationCenter defaultCenter] postNotificationName: @"iTermReloadAddressBook" object: nil userInfo: nil];    		
}

@end