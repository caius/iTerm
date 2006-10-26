// $Id: PreferencePanel.m,v 1.141 2006-10-26 05:36:55 yfabian Exp $
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
#import <iTermBookmarkController.h>

static float versionNumber;
static NSString *NoHandler = @"<No Handler>";

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
	if(defaultEnableBonjour == YES)
		[[ITAddressBookMgr sharedInstance] locateBonjourServices];
	
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

	[[NSNotificationCenter defaultCenter] addObserver: self
									 selector: @selector(_reloadURLHandlers:)
										 name: @"iTermReloadAddressBook"
									   object: nil];	

	return (self);
}


- (void)dealloc
{
	[defaultWordChars release];
    [super dealloc];
}

- (void) readPreferences
{
    prefs = [NSUserDefaults standardUserDefaults];
         
	defaultWindowStyle=[prefs objectForKey:@"WindowStyle"]?[prefs integerForKey:@"WindowStyle"]:0;
    defaultTabViewType=[prefs objectForKey:@"TabViewType"]?[prefs integerForKey:@"TabViewType"]:0;
    if (defaultTabViewType>1) defaultTabViewType = 0;
    defaultCopySelection=[[prefs objectForKey:@"CopySelection"] boolValue];
	defaultPasteFromClipboard=[[prefs objectForKey:@"PasteFromClipboard"] boolValue];
    defaultHideTab=[prefs objectForKey:@"HideTab"]?[[prefs objectForKey:@"HideTab"] boolValue]: YES;
    defaultPromptOnClose = [prefs objectForKey:@"PromptOnClose"]?[[prefs objectForKey:@"PromptOnClose"] boolValue]: YES;
    defaultFocusFollowsMouse = [prefs objectForKey:@"FocusFollowsMouse"]?[[prefs objectForKey:@"FocusFollowsMouse"] boolValue]: NO;
	defaultEnableBonjour = [prefs objectForKey:@"EnableRendezvous"]?[[prefs objectForKey:@"EnableRendezvous"] boolValue]: YES;
	defaultEnableGrowl = [prefs objectForKey:@"EnableGrowl"]?[[prefs objectForKey:@"EnableGrowl"] boolValue]: NO;
	defaultCmdSelection = [prefs objectForKey:@"CommandSelection"]?[[prefs objectForKey:@"CommandSelection"] boolValue]: YES;
	defaultMaxVertically = [prefs objectForKey:@"MaxVertically"]?[[prefs objectForKey:@"MaxVertically"] boolValue]: YES;
	defaultUseCompactLabel = [prefs objectForKey:@"UseCompactLabel"]?[[prefs objectForKey:@"UseCompactLabel"] boolValue]: NO;
	defaultRefreshRate = [prefs objectForKey:@"RefreshRate"]?[[prefs objectForKey:@"RefreshRate"] intValue]: 25;
	[defaultWordChars release];
	defaultWordChars = [[prefs objectForKey: @"WordCharacters"] retain];
    defaultOpenBookmark = [prefs objectForKey:@"OpenBookmark"]?[[prefs objectForKey:@"OpenBookmark"] boolValue]: NO;
	defaultQuitWhenAllWindowsClosed = [prefs objectForKey:@"QuitWhenAllWindowsClosed"]?[[prefs objectForKey:@"QuitWhenAllWindowsClosed"] boolValue]: NO;

	NSArray *urlArray;
	NSDictionary *tempDict = [prefs objectForKey:@"URLHandlers"];
	int i;
	
	// make sure bookmarks are loaded
	[iTermBookmarkController sharedInstance];
    
	// read in the handlers by converting the index back to bookmarks
	urlHandlers = [[NSMutableDictionary alloc] init];
	if (tempDict) {
		NSEnumerator *enumerator = [tempDict keyEnumerator];
		id key;
	   
		while ((key = [enumerator nextObject])) {
			//NSLog(@"%@\n%@",[tempDict objectForKey:key], [[ITAddressBookMgr sharedInstance] bookmarkForIndex:[[tempDict objectForKey:key] intValue]]);
			[urlHandlers setObject:[[ITAddressBookMgr sharedInstance] bookmarkForIndex:[[tempDict objectForKey:key] intValue]]
						    forKey:key];
		}
	}
	urlArray = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
	urlTypes = [[NSMutableArray alloc] initWithCapacity:[urlArray count]];
	for (i=0; i<[urlArray count]; i++) {
		[urlTypes addObject:[[[urlArray objectAtIndex:i] objectForKey: @"CFBundleURLSchemes"] objectAtIndex:0]];
	}
}

- (void) savePreferences
{
    [prefs setBool:defaultCopySelection forKey:@"CopySelection"];
	[prefs setBool:defaultPasteFromClipboard forKey:@"PasteFromClipboard"];
    [prefs setBool:defaultHideTab forKey:@"HideTab"];
	[prefs setInteger:defaultWindowStyle forKey:@"WindowStyle"];
    [prefs setInteger:defaultTabViewType forKey:@"TabViewType"];
    [prefs setBool:defaultPromptOnClose forKey:@"PromptOnClose"];
    [prefs setBool:defaultFocusFollowsMouse forKey:@"FocusFollowsMouse"];
	[prefs setBool:defaultEnableBonjour forKey:@"EnableRendezvous"];
	[prefs setBool:defaultEnableGrowl forKey:@"EnableGrowl"];
	[prefs setBool:defaultCmdSelection forKey:@"CommandSelection"];
	[prefs setBool:defaultMaxVertically forKey:@"MaxVertically"];
	[prefs setBool:defaultUseCompactLabel forKey:@"UseCompactLabel"];
	[prefs setInteger:defaultRefreshRate forKey:@"RefreshRate"];
	[prefs setObject: defaultWordChars forKey: @"WordCharacters"];
	[prefs setBool:defaultOpenBookmark forKey:@"OpenBookmark"];
	[prefs setObject: [[iTermKeyBindingMgr singleInstance] profiles] forKey: @"KeyBindings"];
	[prefs setObject: [[iTermDisplayProfileMgr singleInstance] profiles] forKey: @"Displays"];
	[prefs setObject: [[iTermTerminalProfileMgr singleInstance] profiles] forKey: @"Terminals"];
	[prefs setObject: [[ITAddressBookMgr sharedInstance] bookmarks] forKey: @"Bookmarks"];
	[prefs setBool:defaultQuitWhenAllWindowsClosed forKey:@"QuitWhenAllWindowsClosed"];
    [prefs setBool:([checkUpdate state] == NSOnState) forKey:@"SUCheckAtStartup"];

	// save the handlers by converting the bookmark into an index
	NSMutableDictionary *tempDict = [[NSMutableDictionary alloc] init];
	NSEnumerator *enumerator = [urlHandlers keyEnumerator];
	id key;
   
	while ((key = [enumerator nextObject])) {
		[tempDict setObject:[NSNumber numberWithInt:[[ITAddressBookMgr sharedInstance] indexForBookmark:[urlHandlers objectForKey:key]]]
					 forKey:key];
	}
	[prefs setObject: tempDict forKey:@"URLHandlers"];

	[prefs synchronize];
}

- (void)run
{
	
	// load nib if we haven't already
	if([self window] == nil)
		[self initWithWindowNibName: @"PreferencePanel"];
			    
	[[self window] setDelegate: self]; // also forces window to load
	
	[windowStyle selectItemAtIndex: defaultWindowStyle];
	[tabPosition selectItemAtIndex: defaultTabViewType];
    [selectionCopiesText setState:defaultCopySelection?NSOnState:NSOffState];
	[middleButtonPastesFromClipboard setState:defaultPasteFromClipboard?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [promptOnClose setState:defaultPromptOnClose?NSOnState:NSOffState];
	[focusFollowsMouse setState: defaultFocusFollowsMouse?NSOnState:NSOffState];
	[enableBonjour setState: defaultEnableBonjour?NSOnState:NSOffState];
	[enableGrowl setState: defaultEnableGrowl?NSOnState:NSOffState];
	[cmdSelection setState: defaultCmdSelection?NSOnState:NSOffState];
	[maxVertically setState: defaultMaxVertically?NSOnState:NSOffState];
	[useCompactLabel setState: defaultUseCompactLabel?NSOnState:NSOffState];
    [openBookmark setState: defaultOpenBookmark?NSOnState:NSOffState];
    [refreshRate setIntValue: defaultRefreshRate];
	[wordChars setStringValue: ([defaultWordChars length] > 0)?defaultWordChars:@""];	
	[quitWhenAllWindowsClosed setState: defaultQuitWhenAllWindowsClosed?NSOnState:NSOffState];
    [checkUpdate setState: [[prefs objectForKey:@"SUCheckAtStartup"] boolValue]];
	
	[self showWindow: self];

}

- (IBAction)settingChanged:(id)sender
{    

    if (sender == windowStyle || 
        sender == tabPosition ||
        sender == hideTab ||
        sender == useCompactLabel)
    {
        defaultWindowStyle = [windowStyle indexOfSelectedItem];
        defaultTabViewType=[tabPosition indexOfSelectedItem];
        defaultUseCompactLabel = ([useCompactLabel state] == NSOnState);
        defaultHideTab=([hideTab state]==NSOnState);
        [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermRefreshTerminal" object: nil userInfo: nil];    
    }
    else
    {
        defaultCopySelection=([selectionCopiesText state]==NSOnState);
        defaultPasteFromClipboard=([middleButtonPastesFromClipboard state]==NSOnState);
        defaultPromptOnClose = ([promptOnClose state] == NSOnState);
        defaultFocusFollowsMouse = ([focusFollowsMouse state] == NSOnState);
        defaultEnableBonjour = ([enableBonjour state] == NSOnState);
        defaultEnableGrowl = ([enableGrowl state] == NSOnState);
        defaultCmdSelection = ([cmdSelection state] == NSOnState);
        defaultMaxVertically = ([maxVertically state] == NSOnState);
        defaultOpenBookmark = ([openBookmark state] == NSOnState);
        defaultRefreshRate = [refreshRate intValue];
        [defaultWordChars release];
        defaultWordChars = [[wordChars stringValue] retain];
        defaultQuitWhenAllWindowsClosed = ([quitWhenAllWindowsClosed state] == NSOnState);
    }
}

// NSWindow delegate
- (void)windowWillLoad
{
    // We finally set our autosave window frame name and restore the one from the user's defaults.
    [self setWindowFrameAutosaveName: @"Preferences"];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[self savePreferences];
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

- (BOOL) pasteFromClipboard
{
	return (defaultPasteFromClipboard);
}

- (void) setPasteFromClipboard: (BOOL) flag
{
	defaultPasteFromClipboard = flag;
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

- (int) windowStyle
{
	return (defaultWindowStyle);
}

- (BOOL)promptOnClose
{
    return (defaultPromptOnClose);
}

- (BOOL) focusFollowsMouse
{
    return (defaultFocusFollowsMouse);
}

- (BOOL) enableBonjour
{
	return (defaultEnableBonjour);
}

- (BOOL) enableGrowl
{
	return (defaultEnableGrowl);
}

- (BOOL) cmdSelection
{
	return (defaultCmdSelection);
}

- (BOOL) maxVertically
{
	return (defaultMaxVertically);
}

- (BOOL) useCompactLabel
{
	return (defaultUseCompactLabel);
}

- (BOOL) openBookmark
{
	return (defaultOpenBookmark);
}

- (int) refreshRate
{
	return (defaultRefreshRate);
}

- (NSString *) wordChars
{
	if([defaultWordChars length] <= 0)
		return (@"");
	return (defaultWordChars);
}

- (BOOL) quitWhenAllWindowsClosed
{
    return defaultQuitWhenAllWindowsClosed;
}

// The following are preferences with no UI, but accessible via "defaults read/write"
// examples:
//  defaults write iTerm UseUnevenTabs -bool true
//  defaults write iTerm MinTabWidth -int 100        
//  defaults write iTerm MinCompactTabWidth -int 120
//  defaults write iTerm OptimumTabWidth -int 100
//  defaults write iTerm StrokeWidth -float -1
//  defaults write iTerm BoldStrokeWidth -float -3

- (BOOL) useUnevenTabs
{
    return [prefs objectForKey:@"UseUnevenTabs"]?[[prefs objectForKey:@"UseUnevenTabs"] boolValue]:NO;
}

- (int) minTabWidth
{
    return [prefs objectForKey:@"MinTabWidth"]?[[prefs objectForKey:@"MinTabWidth"] intValue]:75;
}

- (int) minCompactTabWidth
{
    return [prefs objectForKey:@"MinCompactTabWidth"]?[[prefs objectForKey:@"MinCompactTabWidth"] intValue]:60;
}

- (int) optimumTabWidth
{
    return [prefs objectForKey:@"OptimumTabWidth"]?[[prefs objectForKey:@"OptimumTabWidth"] intValue]:175;
}

- (float) strokeWidth
{
    return [prefs objectForKey:@"StrokeWidth"]?[[prefs objectForKey:@"StrokeWidth"] floatValue]:-2;
}

- (float) boldStrokeWidth
{
    return [prefs objectForKey:@"BoldStrokeWidth"]?[[prefs objectForKey:@"BoldStrokeWidth"] floatValue]:-3;
}

// URL handler stuff
- (NSDictionary *) handlerBookmarkForURL:(NSString *)url
{
	return [urlHandlers objectForKey: url];
}

// NSTableView data source
- (int) numberOfRowsInTableView: (NSTableView *)aTableView
{
	return [urlTypes count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    //NSLog(@"%s: %@", __PRETTY_FUNCTION__, aTableView);
    
	return [urlTypes objectAtIndex: rowIndex];
}

// NSTableView delegate
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int i;
	
    //NSLog(@"%s", __PRETTY_FUNCTION__);
	if ((i=[urlTable selectedRow])<0) 
		[urlHandlerOutline deselectAll:nil];
	else {
		id temp = [urlHandlers objectForKey: [urlTypes objectAtIndex: i]];
		if (temp) {
			[urlHandlerOutline selectRow: [urlHandlerOutline rowForItem: temp] byExtendingSelection:NO];
		}
		else {
			[urlHandlerOutline selectRow: 0 byExtendingSelection:NO];
		}
		[urlHandlerOutline scrollRowToVisible: [urlHandlerOutline selectedRow]];
	}
}

// NSOutlineView delegate methods
- (void) outlineViewSelectionDidChange: (NSNotification *) aNotification
{
}

// NSOutlineView data source methods
// required
- (id)outlineView:(NSOutlineView *)ov child:(int)index ofItem:(id)item
{
    //NSLog(@"%s", __PRETTY_FUNCTION__);
	if (item)
		return [[ITAddressBookMgr sharedInstance] child:index ofItem: item];
	else if (index)
		return [[ITAddressBookMgr sharedInstance] child:index-1 ofItem: item];
	else
		return NoHandler;
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
    //NSLog(@"%s", __PRETTY_FUNCTION__);
	if ([item isKindOfClass:[NSString class]])
		return NO;
	else
		return [[ITAddressBookMgr sharedInstance] isExpandable: item];
}

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{
    //NSLog(@"%s: ov = 0x%x; item = 0x%x; numChildren: %d", __PRETTY_FUNCTION__, ov, item,
	//	  [[ITAddressBookMgr sharedInstance] numberOfChildrenOfItem: item]);
	if (item)
		return [[ITAddressBookMgr sharedInstance] numberOfChildrenOfItem: item];
	else
		return [[ITAddressBookMgr sharedInstance] numberOfChildrenOfItem: item] + 1;
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    //NSLog(@"%s: outlineView = 0x%x; item = %@; column= %@", __PRETTY_FUNCTION__, ov, item, [tableColumn identifier]);
	// item should be a tree node witha dictionary data object
	if ([item isKindOfClass:[NSString class]])
        return item;
	else
		return [[ITAddressBookMgr sharedInstance] objectForKey:@"Name" inItem: item];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

- (IBAction)connectURL:(id)sender
{
	int i, j;

	if ((i=[urlTable selectedRow])<0 ||(j=[urlHandlerOutline selectedRow])<0) return;
	if (!j) { // No Handler
		[urlHandlers removeObjectForKey:[urlTypes objectAtIndex: i]];
	}
	else {
		[urlHandlers setObject:[urlHandlerOutline itemAtRow:j] forKey: [urlTypes objectAtIndex: i]];
		
		NSURL *appURL = nil;
		OSStatus err;
		BOOL set = NO;
		
		err = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString:[[urlTypes objectAtIndex: i] stringByAppendingString:@":"]], kLSRolesAll, NULL, (CFURLRef *)&appURL);
		if (err != noErr) {
			set = NSRunAlertPanel([NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"iTerm is not the default handler for %@. Would you like to set iTerm as the default handler?", @"iTerm", [NSBundle bundleForClass: [self class]], @"URL Handler"), [urlTypes objectAtIndex: i]],
								  NSLocalizedStringFromTableInBundle(@"There is no handler currently.",@"iTerm", [NSBundle bundleForClass: [self class]], @"URL Handler"),
								  NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
								  NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
								  ,nil);
		}
		else if (![[[NSFileManager defaultManager] displayNameAtPath:[appURL path]] isEqualToString:@"iTerm"]) {
			set = NSRunAlertPanel([NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"iTerm is not the default handler for %@. Would you like to set iTerm as the default handler?", @"iTerm", [NSBundle bundleForClass: [self class]], @"URL Handler"), [urlTypes objectAtIndex: i]],
								  [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The current handler is: %@" ,@"iTerm", [NSBundle bundleForClass: [self class]], @"URL Handler"), [[NSFileManager defaultManager] displayNameAtPath:[appURL path]]],
								  NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
								  NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
								  ,nil);
		}
			
		if (set) {
			  LSSetDefaultHandlerForURLScheme ((CFStringRef)[urlTypes objectAtIndex: i],(CFStringRef)[[NSBundle mainBundle] bundleIdentifier]);
		}
	}
	//NSLog(@"urlHandlers:%@", urlHandlers);
}

- (IBAction)closeWindow:(id)sender
{
	[[self window] close];
}

@end


@implementation PreferencePanel (Private)

- (void) _reloadURLHandlers: (NSNotification *) aNotification
{
	[urlHandlerOutline reloadData];
}

@end