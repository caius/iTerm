/*
 **  iTermProfileWindowController.h
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: window controller for profile editors.
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

#import <iTerm/iTermKeyBindingMgr.h>
#import <iTerm/iTermProfileWindowController.h>


@implementation iTermProfileWindowController

- (IBAction) showProfilesWindow: (id) sender
{
	NSEnumerator *kbProfileEnumerator;
	NSString *aString;
	
	[kbProfileSelector removeAllItems];
	kbProfileEnumerator = [[[iTermKeyBindingMgr singleInstance] profiles] keyEnumerator];
	while((aString = [kbProfileEnumerator nextObject]) != nil)
		[kbProfileSelector addItemWithTitle: aString];
	
	[self kbProfileChanged: nil];
	[self tableViewSelectionDidChange: nil];	
	
	[self showWindow: self];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    // Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"nonTerminalWindowBecameKey" object: nil userInfo: nil];        
}


// Keybinding profile UI
- (void) kbOptionKeyChanged: (id) sender
{
	
	[[iTermKeyBindingMgr singleInstance] setOptionKey: [kbOptionKey selectedColumn] 
										   forProfile: [kbProfileSelector titleOfSelectedItem]];
}

- (IBAction) kbProfileChanged: (id) sender
{
	NSString *selectedKBProfile;
	//NSLog(@"%s; %@", __PRETTY_FUNCTION__, sender);
	
	selectedKBProfile = [kbProfileSelector titleOfSelectedItem];
	
	[kbProfileDeleteButton setEnabled: ![[iTermKeyBindingMgr singleInstance] isGlobalProfile: selectedKBProfile]];
    [kbOptionKey selectCellAtRow:0 column:[[iTermKeyBindingMgr singleInstance] optionKeyForProfile: selectedKBProfile]];
	
	[kbEntryTableView reloadData];
}

- (IBAction) kbProfileAdd: (id) sender
{
	[NSApp beginSheet: addKBProfile
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(_addKBProfileSheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];        
}

- (IBAction) kbProfileDelete: (id) sender
{
	[NSApp beginSheet: deleteKBProfile
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(_deleteKBProfileSheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];        
}

- (IBAction) kbProfileAddConfirm: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[NSApp endSheet:addKBProfile returnCode:NSOKButton];
}

- (IBAction) kbProfileAddCancel: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[NSApp endSheet:addKBProfile returnCode:NSCancelButton];
}

- (IBAction) kbProfileDeleteConfirm: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[NSApp endSheet:deleteKBProfile returnCode:NSOKButton];
}

- (IBAction) kbProfileDeleteCancel: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[NSApp endSheet:deleteKBProfile returnCode:NSCancelButton];
}

- (IBAction) kbEntryAdd: (id) sender
{
	int i;
	
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	[kbEntryKeyCode setStringValue: @""];
	[kbEntryText setStringValue: @""];
	[kbEntryKeyModifierOption setState: NSOffState];
	[kbEntryKeyModifierControl setState: NSOffState];
	[kbEntryKeyModifierShift setState: NSOffState];
	[kbEntryKeyModifierCommand setState: NSOffState];
	[kbEntryKeyModifierOption setEnabled: YES];
	[kbEntryKeyModifierControl setEnabled: YES];
	[kbEntryKeyModifierShift setEnabled: YES];
	[kbEntryKeyModifierCommand setEnabled: YES];
	[kbEntryKeyCode setHidden: YES];
	[kbEntryText setHidden: YES];
				
	[kbEntryKey selectItemAtIndex: 0];
	[kbEntryKey setTarget: self];
	[kbEntryKey setAction: @selector(kbEntrySelectorChanged:)];
	[kbEntryAction selectItemAtIndex: 0];
	[kbEntryAction setTarget: self];
	[kbEntryAction setAction: @selector(kbEntrySelectorChanged:)];
	
	
	
	if([[iTermKeyBindingMgr singleInstance] isGlobalProfile: [kbProfileSelector titleOfSelectedItem]])
	{
		for (i = KEY_ACTION_NEXT_SESSION; i < KEY_ACTION_ESCAPE_SEQUENCE; i++)
		{
			[[kbEntryAction itemAtIndex: i] setEnabled: YES];
			[[kbEntryAction itemAtIndex: i] setAction: @selector(kbEntrySelectorChanged:)];
			[[kbEntryAction itemAtIndex: i] setTarget: self];
		}
	}
	else
	{
		for (i = KEY_ACTION_NEXT_SESSION; i < KEY_ACTION_ESCAPE_SEQUENCE; i++)
		{
			[[kbEntryAction itemAtIndex: i] setEnabled: NO];
			[[kbEntryAction itemAtIndex: i] setAction: nil];
		}
		[kbEntryAction selectItemAtIndex: KEY_ACTION_ESCAPE_SEQUENCE];
	}
	
	
	
	[NSApp beginSheet: addKBEntry
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: @selector(_addKBEntrySheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];        
	
}

- (IBAction) kbEntryAddConfirm: (id) sender
{
	[NSApp endSheet:addKBEntry returnCode:NSOKButton];
}

- (IBAction) kbEntryAddCancel: (id) sender
{
	[NSApp endSheet:addKBEntry returnCode:NSCancelButton];
}


- (IBAction) kbEntryDelete: (id) sender
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	if([kbEntryTableView selectedRow] >= 0)
	{
		[[iTermKeyBindingMgr singleInstance] deleteEntryAtIndex: [kbEntryTableView selectedRow] 
													  inProfile: [kbProfileSelector titleOfSelectedItem]];
		[kbEntryTableView reloadData];
	}
	else
		NSBeep();
}

- (IBAction) kbEntrySelectorChanged: (id) sender
{
	if(sender == kbEntryKey)
	{
		if([kbEntryKey indexOfSelectedItem] == KEY_HEX_CODE)
		{			
			[kbEntryKeyCode setHidden: NO];
		}
		else
		{			
			[kbEntryKeyCode setStringValue: @""];
			[kbEntryKeyCode setHidden: YES];
		}
	}
	else if(sender == kbEntryAction)
	{
		if([kbEntryAction indexOfSelectedItem] == KEY_ACTION_HEX_CODE ||
		   [kbEntryAction indexOfSelectedItem] == KEY_ACTION_ESCAPE_SEQUENCE)
		{			
			[kbEntryText setHidden: NO];
		}
		else
		{
			[kbEntryText setStringValue: @""];
			[kbEntryText setHidden: YES];
		}
	}	
}

// NSTableView data source
- (int) numberOfRowsInTableView: (NSTableView *)aTableView
{
	if([kbProfileSelector numberOfItems] == 0)
		return (0);
	
	return ([[iTermKeyBindingMgr singleInstance] numberOfEntriesInProfile: [kbProfileSelector titleOfSelectedItem]]);
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if([[aTableColumn identifier] intValue] ==  0)
	{
		return ([[iTermKeyBindingMgr singleInstance] keyCombinationAtIndex: rowIndex 
																 inProfile: [kbProfileSelector titleOfSelectedItem]]);
	}
	else
	{
		return ([[iTermKeyBindingMgr singleInstance] actionForKeyCombinationAtIndex: rowIndex 
																		  inProfile: [kbProfileSelector titleOfSelectedItem]]);
	}
}

// NSTableView delegate
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([kbEntryTableView selectedRow] < 0)
		[kbEntryDeleteButton setEnabled: NO];
	else
		[kbEntryDeleteButton setEnabled: YES];
}


@end

@implementation iTermProfileWindowController (Private)

- (void)_addKBEntrySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	if(returnCode == NSOKButton)
	{
		unsigned int modifiers = 0;
		unsigned int hexCode = 0;
		
		if([kbEntryKeyModifierOption state] == NSOnState)
			modifiers |= NSAlternateKeyMask;
		if([kbEntryKeyModifierControl state] == NSOnState)
			modifiers |= NSControlKeyMask;
		if([kbEntryKeyModifierShift state] == NSOnState)
			modifiers |= NSShiftKeyMask;
		if([kbEntryKeyModifierCommand state] == NSOnState)
			modifiers |= NSCommandKeyMask;
		
		if([kbEntryKey indexOfSelectedItem] == KEY_HEX_CODE)
		{
			if(sscanf([[kbEntryKeyCode stringValue] UTF8String], "%x", &hexCode) == 1)
			{
				[[iTermKeyBindingMgr singleInstance] addEntryForKeyCode: hexCode 
															  modifiers: modifiers 
																 action: [kbEntryAction indexOfSelectedItem] 
																   text: [kbEntryText stringValue]
																profile: [kbProfileSelector titleOfSelectedItem]];
			}
		}
		else
		{
			[[iTermKeyBindingMgr singleInstance] addEntryForKey: [kbEntryKey indexOfSelectedItem] 
													  modifiers: modifiers 
														 action: [kbEntryAction indexOfSelectedItem] 
														   text: [kbEntryText stringValue]
														profile: [kbProfileSelector titleOfSelectedItem]];			
		}
		[self kbProfileChanged: nil];
	}
	
	[addKBEntry close];
}

- (void)_addKBProfileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == NSOKButton && [[kbProfileName stringValue] length] > 0)
	{
		NSEnumerator *kbProfileEnumerator;
		NSString *aString;
		
		[[iTermKeyBindingMgr singleInstance] addProfileWithName: [kbProfileName stringValue] 
													copyProfile: [kbProfileSelector titleOfSelectedItem]];
		
		[kbProfileSelector removeAllItems];
		kbProfileEnumerator = [[[iTermKeyBindingMgr singleInstance] profiles] keyEnumerator];
		while((aString = [kbProfileEnumerator nextObject]) != nil)
			[kbProfileSelector addItemWithTitle: aString];	
		[kbProfileSelector selectItemWithTitle: [kbProfileName stringValue]];
		[self kbProfileChanged: nil];
	}
	
	[addKBProfile close];
}

- (void)_deleteKBProfileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == NSOKButton)
	{
		NSEnumerator *kbProfileEnumerator;
		NSString *aString;
		
		[[iTermKeyBindingMgr singleInstance] deleteProfileWithName: [kbProfileSelector titleOfSelectedItem]];
		
		[kbProfileSelector removeAllItems];
		kbProfileEnumerator = [[[iTermKeyBindingMgr singleInstance] profiles] keyEnumerator];
		while((aString = [kbProfileEnumerator nextObject]) != nil)
			[kbProfileSelector addItemWithTitle: aString];
		if([kbProfileSelector numberOfItems] > 0)
			[kbProfileSelector selectItemAtIndex: 0];
		[self kbProfileChanged: nil];
	}
	
	[deleteKBProfile close];
}


@end

