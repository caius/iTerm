// -*- mode:objc -*-
// $Id: iTermApplicationDelegate.m,v 1.7 2003-10-03 00:07:14 ujwal Exp $
/*
 **  iTermApplicationDelegate.m
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

#import <iTerm/iTermApplicationDelegate.h>
#import <iTerm/iTermController.h>
#import <iTerm/ITAddressBookMgr.h>
#import <iTerm/PreferencePanel.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYSession.h>
#import <iTerm/FindPanelWindowController.h>

@implementation iTermApplicationDelegate

// NSApplication delegate methods
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    // Check the system version for minimum requirements.
    SInt32 gSystemVersion;    
    Gestalt(gestaltSystemVersion, &gSystemVersion);
    if(gSystemVersion < 0x1020)
    {
	NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Sorry",@"iTerm", [NSBundle bundleForClass: [self class]], @"Sorry"),
		 NSLocalizedStringFromTableInBundle(@"Minimum_OS", @"iTerm", [NSBundle bundleForClass: [self class]], @"OS Version"),
		NSLocalizedStringFromTableInBundle(@"Quit",@"iTerm", [NSBundle bundleForClass: [self class]], @"Quit"),
		 nil, nil);
	[NSApp terminate: self];
    }

    // set the TERM_PROGRAM environment variable
    putenv("TERM_PROGRAM=iTerm.app");
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSImage *scriptIcon = [NSImage imageNamed: @"script"];
    NSMenu *scriptMenu = [[NSMenu alloc] initWithTitle: @"Script"];
    NSMenuItem *scriptMenuItem = [[NSMenuItem alloc] initWithTitle: @"Script Item" action: nil keyEquivalent: @""];
    [scriptMenuItem setSubmenu: scriptMenu];
    [scriptMenu release];
    [scriptMenuItem setImage: scriptIcon];
    [[NSApp mainMenu] addItem: scriptMenuItem];
    [scriptMenuItem release];
}

- (BOOL) applicationShouldTerminate: (NSNotification *) theNotification
{
    return [[iTermController sharedInstance] applicationShouldTerminate:theNotification];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)app
{
    return [[iTermController sharedInstance] applicationOpenUntitledFile:app];
}

// sent when application is made visible after a hide operation. Should not really need to implement this,
// but some users reported that keyboard input is blocked after a hide/unhide operation.
- (void)applicationDidUnhide:(NSNotification *)aNotification
{
    [[iTermController sharedInstance] applicationDidUnhide:aNotification];
}

// init
- (id)init
{
    self = [super init];

    // Add ourselves as an observer for notifications.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadMenus:)
                                                 name:@"iTermWindowBecameKey"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(buildAddressBookMenu:)
                                                 name: @"iTermReloadAddressBook"
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(buildSessionSubmenu:)
                                                 name: @"iTermNumberOfSessionsDidChange"
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(buildSessionSubmenu:)
                                                 name: @"iTermNameOfSessionDidChange"
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(resetLogMenu:)
                                                 name: @"iTermSessionDidBecomeActive"
                                               object: nil];    
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}

// Action methods
- (IBAction)newWindow:(id)sender
{
    [[iTermController sharedInstance] newWindow:sender];
}

- (IBAction)newSession:(id)sender
{
    [[iTermController sharedInstance] newSession:sender];
}

// navigation
- (IBAction) previousTerminal: (id) sender
{
    [[iTermController sharedInstance] previousTerminal:sender];
}

- (IBAction) nextTerminal: (id) sender
{
    [[iTermController sharedInstance] nextTerminal:sender];
}

- (IBAction)showABWindow:(id)sender
{
    [[ITAddressBookMgr sharedInstance] showABWindow];
}

- (IBAction)showPrefWindow:(id)sender
{
    [[PreferencePanel sharedInstance] run];
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
    return [[iTermController sharedInstance] applicationDockMenu:sender];
}

/// About window

- (IBAction)showAbout:(id)sender
{
    NSURL *author1URL, *author2URL, *webURL, *bugURL;
    NSAttributedString *author1, *author2, *webSite, *bugReport;
    NSMutableAttributedString *tmpAttrString;
    NSDictionary *linkAttributes;
//    [NSApp orderFrontStandardAboutPanel:nil];

    // First Author
    author1URL = [NSURL URLWithString: @"mailto:fabian@macvillage.net"];
    linkAttributes= [NSDictionary dictionaryWithObjectsAndKeys: author1URL, NSLinkAttributeName,
                        [NSNumber numberWithInt: NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
					    [NSColor blueColor], NSForegroundColorAttributeName,
					    NULL];
    author1 = [[NSAttributedString alloc] initWithString: NSLocalizedStringFromTableInBundle(@"fabian",@"iTerm", [NSBundle bundleForClass: [self class]], @"Author") attributes: linkAttributes];
    
    // Spacer...
    tmpAttrString = [[NSMutableAttributedString alloc] initWithString: @", "];
    
    // Second Author
    author2URL = [NSURL URLWithString: @"mailto:ujwal@setlurgroup.com"];
    linkAttributes= [NSDictionary dictionaryWithObjectsAndKeys: author2URL, NSLinkAttributeName,
                        [NSNumber numberWithInt: NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
					    [NSColor blueColor], NSForegroundColorAttributeName,
					    NULL];
    author2 = [[NSAttributedString alloc] initWithString: NSLocalizedStringFromTableInBundle(@"Ujwal S. Sathyam",@"iTerm", [NSBundle bundleForClass: [self class]], @"Author") attributes: linkAttributes];
    
    // Web URL
    webURL = [NSURL URLWithString: @"http://iterm.sourceforge.net"];
    linkAttributes= [NSDictionary dictionaryWithObjectsAndKeys: webURL, NSLinkAttributeName,
                        [NSNumber numberWithInt: NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
					    [NSColor blueColor], NSForegroundColorAttributeName,
					    NULL];
    webSite = [[NSAttributedString alloc] initWithString: @"http://iterm.sourceforge.net" attributes: linkAttributes];

    // Bug report
    bugURL = [NSURL URLWithString: @"https://sourceforge.net/tracker/?func=add&group_id=67789&atid=518973"];
    linkAttributes= [NSDictionary dictionaryWithObjectsAndKeys: webURL, NSLinkAttributeName,
        [NSNumber numberWithInt: NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
        [NSColor blueColor], NSForegroundColorAttributeName,
        NULL];
    bugReport = [[NSAttributedString alloc] initWithString: NSLocalizedStringFromTableInBundle(@"Report A Bug", @"iTerm", [NSBundle bundleForClass: [self class]], @"About") attributes: linkAttributes];

    // version number and mode
    NSDictionary *myDict = [[NSBundle bundleForClass:[self class]] infoDictionary];
    NSMutableString *versionString = [[NSMutableString alloc] initWithString: (NSString *)[myDict objectForKey:@"CFBundleVersion"]];
#if USE_CUSTOM_DRAWING
    [versionString appendString: @" (A)"];
#else
    [versionString appendString: @" (B)"];
#endif
    
    [[AUTHORS textStorage] deleteCharactersInRange: NSMakeRange(0, [[AUTHORS textStorage] length])];
    [tmpAttrString initWithString: versionString];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [tmpAttrString initWithString: @"\n"];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: author1];
    tmpAttrString = [[NSMutableAttributedString alloc] initWithString: @", "];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: author2];
    [tmpAttrString initWithString: @"\n"];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: webSite];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: bugReport];
    [AUTHORS setAlignment: NSCenterTextAlignment range: NSMakeRange(0, [[AUTHORS textStorage] length])];

    
    [NSApp runModalForWindow:ABOUT];
    [ABOUT close];
    [author1 release];
    [author2 release];
    [webSite release];
    [tmpAttrString release];
    [versionString release];
}

- (IBAction)aboutOK:(id)sender
{
    [NSApp stopModal];
}

// Notifications
- (void) reloadMenus: (NSNotification *) aNotification
{
    PseudoTerminal *frontTerminal = [[iTermController sharedInstance] currentTerminal];
    
    [previousTerminal setAction: (frontTerminal?@selector(previousTerminal:):nil)];
    [nextTerminal setAction: (frontTerminal?@selector(nextTerminal:):nil)];

    [self buildSessionSubmenu: aNotification];
    [self buildAddressBookMenu: aNotification];
}

- (void) buildSessionSubmenu: (NSNotification *) aNotification
{
    // build a submenu to select tabs
    NSMenu *aMenu = [[NSMenu alloc] initWithTitle: @"SessionMenu"];
    NSEnumerator *anEnumerator;
    PTYSession *aSession;
    int i;

    // clear whatever menu we already have
    [selectTab setSubmenu: nil];

    anEnumerator = [[[[iTermController sharedInstance] currentTerminal] sessions] objectEnumerator];

    i = 0;
    while((aSession = [anEnumerator nextObject]) != nil)
    {
	NSMenuItem *aMenuItem;

	i++;

	if(i < 10)
	{
	    aMenuItem  = [[NSMenuItem alloc] initWithTitle: [aSession name] action: @selector(selectSessionAtIndexAction:) keyEquivalent: [NSString stringWithFormat: @"%d", i]];
	    [aMenuItem setTag: i-1];

	    [aMenu addItem: aMenuItem];
	    [aMenuItem release];
	}

    }
    [selectTab setSubmenu: aMenu];

    [aMenu release];
}

- (void) buildAddressBookMenu : (NSNotification *) aNotification
{
    NSMenu *newMenu;
    PseudoTerminal *frontTerminal = [[iTermController sharedInstance] currentTerminal];

    
    // clear whatever menus we already have
    [newTab setSubmenu: nil];
    [newWindow setSubmenu: nil];

    // new window
    newMenu = [[NSMenu alloc] init];
    [[iTermController sharedInstance] buildAddressBookMenu: newMenu target: nil withShortcuts: YES];
    [newWindow setSubmenu: newMenu];
    [newMenu release];

    // new tab
    newMenu = [[NSMenu alloc] init];
    [[iTermController sharedInstance] buildAddressBookMenu: newMenu target: frontTerminal withShortcuts: YES];
    [newTab setSubmenu: newMenu];
    [newMenu release];    
    
}

- (void) resetLogMenu: (NSNotification *) aNotification
{
    PTYSession *aSession = [aNotification object];

    if(aSession == nil)
	return;

    [logStart setEnabled: ![aSession logging]];
    [logStop setEnabled: [aSession logging]];
}

@end

// Scripting support
@implementation iTermApplicationDelegate (KeyValueCoding)

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    //NSLog(@"iTermApplicationDelegate: delegateHandlesKey: '%@'", key);
    return [[iTermController sharedInstance] application:sender delegateHandlesKey:key];
}

// accessors for to-one relationships:
- (PseudoTerminal *)currentTerminal
{
    //NSLog(@"iTermApplicationDelegate: currentTerminal");
    return [[iTermController sharedInstance] currentTerminal];
}

- (void) setCurrentTerminal: (PseudoTerminal *) aTerminal
{
    //NSLog(@"iTermApplicationDelegate: setCurrentTerminal '0x%x'", aTerminal);
    return [[iTermController sharedInstance] setCurrentTerminal: aTerminal];
}


// accessors for to-many relationships:
- (NSArray*)terminals
{
    return [[iTermController sharedInstance] terminals];
}

-(void)setTerminals: (NSArray*)terminals
{
    // no-op
}

// accessors for to-many relationships:
// (See NSScriptKeyValueCoding.h)
-(id)valueInTerminalsAtIndex:(unsigned)index
{
    return [[iTermController sharedInstance] valueInTerminalsAtIndex:index];
}

-(void)replaceInTerminals:(PseudoTerminal *)object atIndex:(unsigned)index
{
    [[iTermController sharedInstance] replaceInTerminals:object atIndex:index];
}

- (void)addInTerminals:(PseudoTerminal *) object
{
    [[iTermController sharedInstance] addInTerminals:object];
}

- (void)insertInTerminals:(PseudoTerminal *) object
{
    [[iTermController sharedInstance] insertInTerminals:object];
}

-(void)insertInTerminals:(PseudoTerminal *)object atIndex:(unsigned)index
{
    [[iTermController sharedInstance] insertInTerminals:object atIndex:index];
}

-(void)removeFromTerminalsAtIndex:(unsigned)index
{
    // NSLog(@"iTerm: removeFromTerminalsAtInde %d", index);
    [[iTermController sharedInstance] removeFromTerminalsAtIndex: index];
}

// a class method to provide the keys for KVC:
+(NSArray*)kvcKeys
{
    return [[iTermController sharedInstance] kvcKeys];
}

@end

@implementation iTermApplicationDelegate (Find_Actions)

- (IBAction) showFindPanel: (id) sender;
{
    [[FindPanelWindowController sharedInstance] showWindow:self];
}

- (IBAction) findNext: (id) sender
{
    [[FindCommandHandler sharedInstance] findNext];
}

- (IBAction) findPrevious: (id) sender
{
    [[FindCommandHandler sharedInstance] findPrevious];
}

- (IBAction) findWithSelection: (id) sender
{
    [[FindCommandHandler sharedInstance] findWithSelection];
}

- (IBAction) jumpToSelection: (id) sender
{
    [[FindCommandHandler sharedInstance] jumpToSelection];
}

@end

@implementation iTermApplicationDelegate (MoreActions)

- (void) newSessionInTabAtIndex: (id) sender
{
    [[iTermController sharedInstance] newSessionInTabAtIndex:sender];
}

- (void)newSessionInWindowAtIndex: (id) sender
{
    [[iTermController sharedInstance] newSessionInWindowAtIndex:sender];
}

@end



