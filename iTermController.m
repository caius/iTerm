// -*- mode:objc -*-
// $Id: iTermController.m,v 1.15 2003-09-08 19:39:36 ujwal Exp $
/*
 **  iTermController.m
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

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import <iTerm/iTermController.h>
#import <iTerm/PreferencePanel.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYSession.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/AddressBookWindowController.h>
#import <iTerm/ITAddressBookMgr.h>

static NSString* APPLICATION_SUPPORT_DIRECTORY = @"~/Library/Application Support";
static NSString* AUTO_LAUNCH_SCRIPT = @"~/Library/Application Support/iTerm/AutoLaunch.scpt";
static NSString *SUPPORT_DIRECTORY = @"~/Library/Application Support/iTerm";
static NSStringEncoding const *encodingList=nil;

static BOOL usingAutoLaunchScript = NO;

@implementation iTermController

+ (iTermController*)sharedInstance;
{
    static iTermController* shared = nil;
    
    if (!shared)
        shared = [[iTermController alloc] init];
    
    return shared;
}

- (BOOL)applicationShouldTerminate: (NSNotification *) theNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermController applicationShouldTerminate]",
          __FILE__, __LINE__);
#endif

    if(([terminalWindows count] > 0) && [[PreferencePanel sharedInstance] promptOnClose] && ![[terminalWindows objectAtIndex: 0] showCloseWindow])
	return (NO);
    
    return (YES);
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)app
{
    // Check if we have an autolauch script to execute. Do it only once, i.e. at application launch.
    if(usingAutoLaunchScript == NO &&
       [[NSFileManager defaultManager] fileExistsAtPath: [AUTO_LAUNCH_SCRIPT stringByExpandingTildeInPath]] != nil)
    {
	usingAutoLaunchScript = YES;
	
	NSAppleScript *autoLaunchScript;
	NSDictionary *errorInfo = [NSDictionary dictionary];
	NSURL *aURL = [NSURL fileURLWithPath: [AUTO_LAUNCH_SCRIPT stringByExpandingTildeInPath]];

	usingAutoLaunchScript = YES;

	// Make sure our script suite registry is loaded
	[NSScriptSuiteRegistry sharedScriptSuiteRegistry];

	autoLaunchScript = [[NSAppleScript alloc] initWithContentsOfURL: aURL error: &errorInfo];
	[autoLaunchScript executeAndReturnError: &errorInfo];
		
	return (YES);
    }

    // else do the usual default stuff.
    if ([[PreferencePanel sharedInstance] openAddressBook])
        [[ITAddressBookMgr sharedInstance] showABWindow];
    else
        [self newWindow:nil];
    
    return YES;
}

// sent when application is made visible after a hide operation. Should not really need to implement this,
// but some users reported that keyboard input is blocked after a hide/unhide operation.
- (void)applicationDidUnhide:(NSNotification *)aNotification
{
    // Make sure that the first responder stuff is set up OK.
    [FRONT selectSessionAtIndex: [FRONT currentSessionIndex]];
}

// Creates the dock menu
- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
    NSMenu *aMenu;
    NSMenuItem *newTabMenuItem, *newWindowMenuItem;
    
    aMenu = [[NSMenu alloc] initWithTitle: @"Dock Menu"];
    newTabMenuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedStringFromTableInBundle(@"New Tab",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" ]; 
    newWindowMenuItem = [[NSMenuItem alloc] initWithTitle: NSLocalizedStringFromTableInBundle(@"New Window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" ]; 
    [aMenu addItem: newTabMenuItem];
    [aMenu addItem: newWindowMenuItem];
    [newTabMenuItem release];
    [newWindowMenuItem release];
    
    // Create the addressbook submenus for new tabs and windows.
    NSMenu *abMenu = [[NSMenu alloc] initWithTitle: @"Bookmarks Menu"];
    [self buildAddressBookMenu: abMenu target: FRONT withShortcuts: NO]; // target the top terminal window.
    [newTabMenuItem setSubmenu: abMenu];
    [abMenu release];
    
    abMenu = [[NSMenu alloc] initWithTitle: @"Bookmarks Menu"];
    [self buildAddressBookMenu: abMenu target: nil withShortcuts: NO]; // target the top terminal window.
    [newWindowMenuItem setSubmenu: abMenu];
    [abMenu release];
            
    return ([aMenu autorelease]);
}

// init
- (id) init
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermController init]",
          __FILE__, __LINE__);
#endif
    self = [super init];

    // activate our fonts
    // Get the main bundle object
    NSBundle *appBundle = [NSBundle bundleForClass: [self class]];
    // Ask for the path to the resources
    NSString *fontsPath = [appBundle pathForResource: @"Fonts" ofType: nil inDirectory: nil];

    // Using the Carbon APIs:  get a file reference and spec for the path
    FSRef fsRef;
    FSSpec fsSpec;
    int osstatus = FSPathMakeRef( [fontsPath UTF8String], &fsRef, NULL);
    if ( osstatus == noErr)
        osstatus = FSGetCatalogInfo( &fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL);
    
    //activate the font file using the file spec
    osstatus = FMActivateFonts( &fsSpec, NULL, NULL, kFMLocalActivationContext);
    
    // create the iTerm directory if it does not exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // create the "~/Library/Application Support" directory if it does not exist
    if([fileManager fileExistsAtPath: [APPLICATION_SUPPORT_DIRECTORY stringByExpandingTildeInPath]] == NO)
        [fileManager createDirectoryAtPath: [APPLICATION_SUPPORT_DIRECTORY stringByExpandingTildeInPath] attributes: nil];
    
    if([fileManager fileExistsAtPath: [SUPPORT_DIRECTORY stringByExpandingTildeInPath]] == NO)
        [fileManager createDirectoryAtPath: [SUPPORT_DIRECTORY stringByExpandingTildeInPath] attributes: nil];
    
    encodingList=[NSString availableStringEncodings];
    terminalWindows = [[NSMutableArray alloc] init];
    
    return (self);
}

- (void) dealloc
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermController dealloc]",
          __FILE__, __LINE__);
#endif
    
    [terminalWindows removeAllObjects];
    [terminalWindows release];
    
    [super dealloc];
}

// Action methods
- (IBAction)newWindow:(id)sender
{
    [self executeABCommandAtIndex:0 inTerminal: nil];
}

- (void) newSessionInTabAtIndex: (id) sender
{
    [self executeABCommandAtIndex:[sender tag] inTerminal:FRONT];
}

- (void)newSessionInWindowAtIndex: (id) sender
{
    [self executeABCommandAtIndex:[sender tag] inTerminal: nil];
}

- (IBAction)newSession:(id)sender
{
    [self executeABCommandAtIndex:0 inTerminal: FRONT];
}

// navigation
- (IBAction) previousTerminal: (id) sender
{
    unsigned int currentIndex;

    currentIndex = [[self terminals] indexOfObject: FRONT];
    if(FRONT == nil || currentIndex == NSNotFound)
    {
	NSBeep();
	return;
    }

    // get the previous terminal
    if(currentIndex == 0)
	currentIndex = [[self terminals] count] - 1;
    else
	currentIndex--;

    // make that terminal's window active
    [[[[self terminals] objectAtIndex: currentIndex] window] makeKeyAndOrderFront: self];
    
}
- (IBAction)nextTerminal: (id) sender
{
    unsigned int currentIndex;

    currentIndex = [[self terminals] indexOfObject: FRONT];
    if(FRONT == nil || currentIndex == NSNotFound)
    {
	NSBeep();
	return;
    }

    // get the next terminal
    if(currentIndex == [[self terminals] count] - 1)
	currentIndex = 0;
    else
	currentIndex++;

    // make that terminal's window active
    [[[[self terminals] objectAtIndex: currentIndex] window] makeKeyAndOrderFront: self];
}

// Utility
+ (void) breakDown:(NSString *)cmdl cmdPath: (NSString **) cmd cmdArgs: (NSArray **) path
{
    int i,j,k,qf;
    char tmp[100];
    const char *s;
    NSMutableArray *p;

    p=[[NSMutableArray alloc] init];

    s=[cmdl cString];

    i=j=qf=0;
    k=-1;
    while (i<=strlen(s)) {
        if (qf) {
            if (s[i]=='\"') {
                qf=0;
            }
            else {
                tmp[j++]=s[i];
            }
        }
        else {
            if (s[i]=='\"') {
                qf=1;
            }
            else if (s[i]==' ' || s[i]=='\t' || s[i]=='\n'||s[i]==0) {
                tmp[j]=0;
                if (k==-1) {
                    *cmd=[NSString stringWithCString:tmp];
                }
                else
                    [p addObject:[NSString stringWithCString:tmp]];
                j=0;
                k++;
                while (s[i+1]==' '||s[i+1]=='\t'||s[i+1]=='\n'||s[i+1]==0) i++;
            }
            else {
                tmp[j++]=s[i];
            }
        }
        i++;
    }

    *path = [NSArray arrayWithArray:p];
    [p release];
}

- (void) setFrontPseudoTerminal: (PseudoTerminal *) thePseudoTerminal
{
    FRONT = thePseudoTerminal;

    // Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermWindowBecameKey" object: nil userInfo: nil];    

}

- (PseudoTerminal *) frontPseudoTerminal
{
    return (FRONT);
}

- (void) terminalWillClose: (PseudoTerminal *) theTerminalWindow
{
    if(FRONT == theTerminalWindow)
	[self setFrontPseudoTerminal: nil];

    if(theTerminalWindow)
        [terminalWindows removeObject: theTerminalWindow];
}

- (NSStringEncoding const*) encodingList
{
    return encodingList;
}

// Build the bookmarks menu
- (void) buildAddressBookMenu:(NSMenu *)abMenu target:(id)target withShortcuts: (BOOL) withShortcuts
{
    NSEnumerator *abEnumerator;
    NSDictionary *abEntry;
    NSString *shortcut;
    unsigned int mask;
    int i = 0;
    SEL action;
    
    if (target == nil)
        action = @selector(newSessionInWindowAtIndex:);
    else
        action = @selector(newSessionInTabAtIndex:);
    
    abEnumerator = [[[ITAddressBookMgr sharedInstance] addressBook] objectEnumerator];
    while ((abEntry = [abEnumerator nextObject]) != nil)
    {
	shortcut=([[abEntry objectForKey:@"Shortcut"] intValue]? [NSString stringWithFormat:@"%c",[[abEntry objectForKey:@"Shortcut"] intValue]]:@"");
	shortcut = [shortcut lowercaseString];
	mask = NSCommandKeyMask | NSAlternateKeyMask;
	if(target == nil)
	    mask |= NSShiftKeyMask;	
	if(isDefaultEntry(abEntry))
	{
	    shortcut = target?@"t":@"n";
	    mask = NSCommandKeyMask;
	}
	if(withShortcuts == NO)
	    shortcut = @"";
	NSMenuItem *abMenuItem = [[[NSMenuItem alloc] initWithTitle: entryVisibleName(abEntry, self) action:action keyEquivalent:shortcut] autorelease];
	[abMenuItem setKeyEquivalentModifierMask: mask];
	[abMenuItem setTag:i++];
	[abMenuItem setTarget:target];

        [abMenu addItem: abMenuItem];
    }
}

// Executes an addressbook command in new window or tab
- (void) executeABCommandAtIndex: (int) theIndex inTerminal: (PseudoTerminal *) theTerm
{
    PseudoTerminal *term;
    PTYSession *aSession;
    NSString *cmd;
    NSArray *arg;
    NSDictionary *entry;

    // Grab the addressbook command
    entry = [[[ITAddressBookMgr sharedInstance] addressBook] objectAtIndex:theIndex];
    [iTermController breakDown:[entry objectForKey:@"Command"] cmdPath:&cmd cmdArgs:&arg];
    //        NSLog(@"%s(%d):-[PseudoTerminal ready to run:%@ arguments:%@]", __FILE__, __LINE__, cmd, arg );
    
    // Where do we execute this command?
    if(theTerm == nil)
    {
        term = [[PseudoTerminal alloc] init];
	[term initWindow];
	[self addInTerminals: term];
	[term release];

	[term setColumns: [[entry objectForKey:@"Col"]intValue]];
	[term setRows: [[entry objectForKey:@"Row"]intValue]];
	[term setAllFont: [entry objectForKey:@"Font"] nafont: [entry objectForKey:@"NAFont"]];
    }
    else
        term = theTerm;
    
    // Initialize a new session
    aSession = [[[PTYSession alloc] init] autorelease];
    // Add this session to our term and make it current
    [term addInSessions: aSession];

    // set our preferences
    [aSession setAddressBookEntry:entry];
    [aSession setPreferencesFromAddressBookEntry: entry];
    if ([entry objectForKey: @"Scrollback"])
        [[aSession SCREEN] setScrollback:[[entry objectForKey: @"Scrollback"] intValue]];
    else
        [[aSession SCREEN] setScrollback:100000];
    
    NSDictionary *env=[NSDictionary dictionaryWithObject:([entry objectForKey:@"Directory"]?[entry objectForKey:@"Directory"]:@"~")  forKey:@"PWD"];
    
    // Start the command        
    [term startProgram:cmd arguments:arg environment:env];
    
    // If we created a new window, set the size
    if (theTerm == nil)
        [term setWindowSize: NO];
    
    [term setCurrentSessionName:[entry objectForKey:@"Name"]];
}

- (PTYTextView *) frontTextView
{
    return ([[FRONT currentSession] TEXTVIEW]);
}

@end

// keys for to-many relationships:
NSString *terminalsKey = @"terminals";

// Scripting support
@implementation iTermController (KeyValueCoding)

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    // NSLog(@"key = %@", key);
    return [key isEqualToString:@"terminals"];
}

// accessors for to-many relationships:
-(NSArray*)terminals
{
    // NSLog(@"iTerm: -terminals");
    return (terminalWindows);
}

-(void)setTerminals: (NSArray*)terminals
{
    // no-op
}

// accessors for to-many relationships:
// (See NSScriptKeyValueCoding.h)
-(id)valueInTerminalsAtIndex:(unsigned)index
{
    // NSLog(@"iTerm: valueInTerminalsAtIndex %d", index);
    return ([terminalWindows objectAtIndex: index]);
}

-(void)replaceInTerminals:(PseudoTerminal *)object atIndex:(unsigned)index
{
    // NSLog(@"iTerm: replaceInTerminals 0x%x atIndex %d", object, index);
    [terminalWindows replaceObjectAtIndex: index withObject: object];
}

- (void) addInTerminals: (PseudoTerminal *) object
{
    // NSLog(@"iTerm: addInTerminals 0x%x", object);
    [self insertInTerminals: object atIndex: [terminalWindows count]];
}

- (void) insertInTerminals: (PseudoTerminal *) object
{
    // NSLog(@"iTerm: insertInTerminals 0x%x", object);
    [self insertInTerminals: object atIndex: [terminalWindows count]];
}

-(void)insertInTerminals:(PseudoTerminal *)object atIndex:(unsigned)index
{
    if([terminalWindows containsObject: object] == YES)
	return;
    [terminalWindows insertObject: object atIndex: index];
}

-(void)removeFromTerminalsAtIndex:(unsigned)index
{
    // NSLog(@"iTerm: removeFromTerminalsAtInde %d", index);
    [terminalWindows removeObjectAtIndex: index];
}

// a class method to provide the keys for KVC:
- (NSArray*)kvcKeys
{
    static NSArray *_kvcKeys = nil;
    if( nil == _kvcKeys ){
	_kvcKeys = [[NSArray alloc] initWithObjects:
	    terminalsKey,  nil ];
    }
    return _kvcKeys;
}

@end

