/*
 **  PreferencePanel.h
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

#import <Cocoa/Cocoa.h>

#define OPT_NORMAL 0
#define OPT_META   1
#define OPT_ESC    2

@class iTermController;

@interface PreferencePanel : NSWindowController
{
	IBOutlet NSMatrix *tabPosition;
    IBOutlet id antiAlias;
    IBOutlet NSButton *selectionCopiesText;
    IBOutlet id hideTab;
    IBOutlet id openAddressBook;
    IBOutlet id optionKey;
    IBOutlet id promptOnClose;
    IBOutlet id silenceBell;
    IBOutlet id blinkingCursor;
    IBOutlet NSButton *focusFollowsMouse;
	
	// Keybinding stuff
	IBOutlet NSPopUpButton *kbProfileSelector;
	IBOutlet NSTextField *kbProfileName;
	IBOutlet NSPanel *addKBProfile;
	IBOutlet NSPanel *deleteKBProfile;
	IBOutlet NSPanel *addKBEntry;
	IBOutlet NSPopUpButton *kbEntryKey;
	IBOutlet NSButton *kbEntryKeyModifierOption;
	IBOutlet NSButton *kbEntryKeyModifierControl;
	IBOutlet NSButton *kbEntryKeyModifierShift;
	IBOutlet NSButton *kbEntryKeyModifierCommand;
	IBOutlet NSPopUpButton *kbEntryAction;
	IBOutlet NSTextField *kbEntryText;
	IBOutlet NSTextField *kbEntryKeyCode;
	IBOutlet NSTableView *kbEntryTableView;
	IBOutlet NSButton *kbProfileDeleteButton;
	IBOutlet NSButton *kbEntryDeleteButton;
    
    NSUserDefaults *prefs;

    unsigned int defaultScrollback;

    BOOL defaultAntiAlias;
    BOOL defaultCopySelection;
    BOOL defaultHideTab;
    BOOL defaultSilenceBell;
    int defaultTabViewType;
    BOOL defaultOpenAddressBook;
    BOOL defaultPromptOnClose;
    BOOL defaultBlinkingCursor;
    BOOL defaultFocusFollowsMouse;
}

- (IBAction) editDefaultSession: (id) sender;

+ (PreferencePanel*)sharedInstance;
- (id)initWithWindowNibName: (NSString *) windowNibName;

- (void) readPreferences;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)restore:(id)sender;

// Keybinding stuff
- (IBAction) kbProfileChanged: (id) sender;
- (IBAction) kbProfileAdd: (id) sender;
- (IBAction) kbProfileDelete: (id) sender;
- (IBAction) kbProfileAddConfirm: (id) sender;
- (IBAction) kbProfileAddCancel: (id) sender;
- (IBAction) kbProfileDeleteConfirm: (id) sender;
- (IBAction) kbProfileDeleteCancel: (id) sender;
- (IBAction) kbEntryAdd: (id) sender;
- (IBAction) kbEntryAddConfirm: (id) sender;
- (IBAction) kbEntryAddCancel: (id) sender;
- (IBAction) kbEntryDelete: (id) sender;
- (IBAction) kbEntrySelectorChanged: (id) sender;

- (void)run;

- (BOOL) antiAlias;
- (BOOL) copySelection;
- (void) setCopySelection: (BOOL) flag;
- (BOOL) hideTab;
- (BOOL) silenceBell;
- (NSTabViewType) tabViewType;
- (void) setTabViewType: (NSTabViewType) type;
- (BOOL) promptOnClose;
- (BOOL) openAddressBook;
- (BOOL) blinkingCursor;
- (BOOL) focusFollowsMouse;

@end

@interface PreferencePanel (Private)
- (void)_addKBEntrySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_addKBProfileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)_deleteKBProfileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end
