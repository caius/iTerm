// -*- mode:objc -*-
// $Id: MainMenu.m,v 1.78 2003-06-22 18:18:37 ujwal Exp $
/*
 **  MainMenu.m
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

#import "MainMenu.h"
#import "PreferencePanel.h"
#import "PseudoTerminal.h"
#import "PTYSession.h"
#import "NSStringITerm.h"
#import "AddressBookWindowController.h"


static NSString* OLD_ADDRESS_BOOK_FILE = @"~/Library/Application Support/iTerm Address Book";
static NSString* ADDRESS_BOOK_FILE = @"~/Library/Application Support/iTerm/AddressBook";
static NSString* AUTO_LAUNCH_SCRIPT = @"~/Library/Application Support/iTerm/AutoLaunch.scpt";
static NSString *SUPPORT_DIRECTORY = @"~/Library/Application Support/iTerm";
static NSStringEncoding const *encodingList=nil;

static BOOL usingAutoLaunchScript = NO;

// comaparator function for addressbook entries
extern BOOL isDefaultEntry( NSDictionary *entry );
extern NSString *entryVisibleName( NSDictionary *entry, id sender );
extern  NSComparisonResult addressBookComparator (NSDictionary *entry1, NSDictionary *entry2, void *context);

@implementation MainMenu

// NSApplication delegate methods
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu applicationWillFinishLaunching]",
          __FILE__, __LINE__);
#endif

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
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu applicationDidFinishLaunching]",
          __FILE__, __LINE__);
#endif
    
}

- (BOOL) applicationShouldTerminate: (NSNotification *) theNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu applicationShouldTerminate]",
          __FILE__, __LINE__);
#endif

    if(([terminalWindows count] > 0) && [PREF_PANEL promptOnClose] && ![[terminalWindows objectAtIndex: 0] showCloseWindow])
	return (NO);

    [terminalWindows removeAllObjects];

    [PREF_PANEL release];
    PREF_PANEL = nil;
    
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
    if ([PREF_PANEL openAddressBook]) {
        [self showABWindow:nil];
    }
    else [self newWindow:nil];
    
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
    [self buildAddressBookMenu: abMenu forTerminal: FRONT]; // target the top terminal window.
    [newTabMenuItem setSubmenu: abMenu];
    [abMenu release];
    
    abMenu = [[NSMenu alloc] initWithTitle: @"Bookmarks Menu"];
    [self buildAddressBookMenu: abMenu forTerminal: nil]; // target the top terminal window.
    [newWindowMenuItem setSubmenu: abMenu];
    [abMenu release];
            
    return ([aMenu autorelease]);
    
}

// init
- (id) init
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu init]",
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
    {
	osstatus = FSGetCatalogInfo( &fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL);
    }
    //activate the font file using the file spec
    osstatus = FMActivateFonts( &fsSpec, NULL, NULL, kFMLocalActivationContext);

    // create the iTerm directory if it does not exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath: [SUPPORT_DIRECTORY stringByExpandingTildeInPath]] == NO)
    {
	[fileManager createDirectoryAtPath: [SUPPORT_DIRECTORY stringByExpandingTildeInPath] attributes: nil];
    }    
    
    [self initAddressBook];
    [self initPreferences];
    encodingList=[NSString availableStringEncodings];
    terminalWindows = [[NSMutableArray alloc] init];

    return (self);
}

- (void) dealloc
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu dealloc]",
          __FILE__, __LINE__);
#endif

    [terminalWindows removeAllObjects];
    [terminalWindows release];

    [PREF_PANEL release];
    
}

// Action methods
- (IBAction)newWindow:(id)sender
{
//    PseudoTerminal *term;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu newWindow]",
          __FILE__, __LINE__);
#endif

    [self executeABCommandAtIndex:0 inTerminal: nil];

//    term = [[PseudoTerminal alloc] init];
//    [self addInTerminals: term];
//    [term release];
    
//    [term setPreference:PREF_PANEL];
//    [term newSession:nil];
}

- (IBAction)newSession:(id)sender
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu newSession]",
          __FILE__, __LINE__);
#endif

    [self executeABCommandAtIndex:0 inTerminal: FRONT];
//    if(FRONT == nil)
//        [self newWindow:nil];
//    else
//        [FRONT newSession: self];
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

// Preference Panel
- (IBAction)showPrefWindow:(id)sender
{
//    PreferencePanel *pref=[[PreferencePanel alloc] init];
    [PREF_PANEL run];
//    [pref dealloc];
}

- (PreferencePanel *) preferencePanel
{
    return (PREF_PANEL);
}

- (void) initPreferences
{
    PREF_PANEL = [[PreferencePanel alloc] init];
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

    [self buildSessionSubmenu];

}

- (PseudoTerminal *) frontPseudoTerminal
{
    return (FRONT);
}

- (void) buildSessionSubmenu
{
    // build a submenu to select tabs
    NSMenu *aMenu = [[NSMenu alloc] initWithTitle: @"SessionMenu"];
    NSEnumerator *anEnumerator;
    PTYSession *aSession;
    int i;

    // clear whatever menu we already have
    [selectTab setSubmenu: nil];

    anEnumerator = [[FRONT sessions] objectEnumerator];

    i = 0;
    while((aSession = [anEnumerator nextObject]) != nil)
    {
	NSMenuItem *aMenuItem;

	i++;

	if(i < 10)
	{
	    aMenuItem  = [[NSMenuItem alloc] initWithTitle: [aSession name] action: @selector(_selectSessionAtIndex:) keyEquivalent: [NSString stringWithFormat: @"%d", i]];
	    [aMenuItem setTag: i-1];

	    [aMenu addItem: aMenuItem];
	    [aMenuItem release];
	}
	
    }
    [selectTab setSubmenu: aMenu];

    [aMenu release];
    
}

- (void) terminalWillClose: (PseudoTerminal *) theTerminalWindow
{
    if(FRONT == theTerminalWindow)
    {
	[self setFrontPseudoTerminal: nil];
    }
    if(theTerminalWindow)
    {
        [terminalWindows removeObject: theTerminalWindow];
    }
}

- (NSStringEncoding const*) encodingList
{
    return encodingList;
}


// Build the bookmarks menu
- (void) buildAddressBookMenu: (NSMenu *) abMenu forTerminal: (id) sender
{
    NSEnumerator *abEnumerator;
    NSString *abEntry;
    int i = 0;
//    SEL shellSelector;
    SEL abCommandSelector;


#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu buildAddressBookMenu]",
          __FILE__, __LINE__);
#endif

    if (sender == nil)
    {
//	shellSelector = @selector(newWindow:);
	abCommandSelector = @selector(_executeABMenuCommandInNewWindow:);
    }
    else
    {
//	shellSelector = @selector(newSession:);
	abCommandSelector = @selector(_executeABMenuCommandInNewTab:);
    }

//    [abMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Default session",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New")
//					   action: shellSelector keyEquivalent:@""];
//    [abMenu addItem: [NSMenuItem separatorItem]];
    abEnumerator = [[self addressBookNames] objectEnumerator];
    while ((abEntry = [abEnumerator nextObject]) != nil)
    {
	NSMenuItem *abMenuItem = [[NSMenuItem alloc] initWithTitle: abEntry action: abCommandSelector keyEquivalent:@""];
	[abMenuItem setTag: i++];
        [abMenuItem setRepresentedObject: sender]; // so that we know where this menu item is going to be executed
	[abMenu addItem: abMenuItem];
	[abMenuItem release];
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
    entry = [[self addressBook] objectAtIndex:theIndex];
    [MainMenu breakDown:[entry objectForKey:@"Command"] cmdPath:&cmd cmdArgs:&arg];
    //        NSLog(@"%s(%d):-[PseudoTerminal ready to run:%@ arguments:%@]", __FILE__, __LINE__, cmd, arg );
    
    
    // Where do we execute this command?
    if(theTerm == nil)
    {
        term = [[PseudoTerminal alloc] init];
	[self addInTerminals: term];
	[term release];

	[term setPreference:PREF_PANEL];
	[term setColumns: [[entry objectForKey:@"Col"]intValue]];
	[term setRows: [[entry objectForKey:@"Row"]intValue]];
	[term setAllFont: [entry objectForKey:@"Font"] nafont: [entry objectForKey:@"NAFont"]];
    }
    else
        term = theTerm;
    
    // Initialize a new session
    aSession = [[PTYSession alloc] init];
    // Add this session to our term and make it current
    [term addInSessions: aSession];
    [aSession release];

    // set our preferences
    [aSession setAddressBookEntry:entry];
    [aSession setPreferencesFromAddressBookEntry: entry];
    
    NSDictionary *env=[NSDictionary dictionaryWithObject:([entry objectForKey:@"Directory"]?[entry objectForKey:@"Directory"]:@"~")  forKey:@"PWD"];
    
    // Start the command        
    [term startProgram:cmd arguments:arg environment:env];
    
    // If we created a new window, set the size
    if (theTerm == nil) {
        [term setWindowSize: NO];
    };
    [term setCurrentSessionName:[entry objectForKey:@"Name"]];
    
}

- (void) interpreteKey: (int) code newWindow:(BOOL) newWin
{
    int i, c, n=[[self addressBook] count];

    if (code>='a'&&code<='z') code+='A'-'a';
//    NSLog(@"got code:%d (%s)",code,(newWin?"new":"old"));
    
    for(i=0; i<n; i++) {
        c=[[[[self addressBook] objectAtIndex:i] objectForKey:@"Shortcut"] intValue];
        if (code==c) {
            [self executeABCommandAtIndex:i inTerminal: newWin?nil:FRONT];
        }
    }
            
}

- (PTYTextView *) frontTextView
{
    return ([[FRONT currentSession] TEXTVIEW]);
}

@end


// AddressBook/Bookmark methods
@implementation MainMenu (AddressBook)

- (NSMutableArray *) addressBook
{
    return (addressBook);
}

// Address book window
- (IBAction)showABWindow:(id)sender
{
    AddressBookWindowController *abWindowController;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu showABWindow:%@]",
          __FILE__, __LINE__, sender);
#endif

    [self initAddressBook];
    //    NSLog(@"showABWindow: %d\n%@",[[self addressBook] count], [self addressBook]);

    abWindowController = [AddressBookWindowController singleInstance];
    [abWindowController setAddressBook: [self addressBook]];
    [abWindowController setPreferences: PREF_PANEL];
    [abWindowController run];
}

- (void) initAddressBook
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu initAddressBook]",
          __FILE__, __LINE__);
#endif

    if ([self addressBook]!=nil)
    {
	[[self addressBook] release];
    }

    // We have a new location for the addressbook
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath: [OLD_ADDRESS_BOOK_FILE stringByExpandingTildeInPath]])
    {
	// move the addressbook to the new location
	[fileManager movePath: [OLD_ADDRESS_BOOK_FILE stringByExpandingTildeInPath]
				     toPath: [ADDRESS_BOOK_FILE stringByExpandingTildeInPath] handler: nil];
    }

    addressBook = [[NSUnarchiver unarchiveObjectWithFile: [ADDRESS_BOOK_FILE stringByExpandingTildeInPath]] retain];
    if (addressBook == nil) {
        NSLog(@"No file loaded");
        addressBook=[[NSMutableArray array] retain];
    }

    // Insert default entry
    if ( [addressBook count] < 1 || ![[addressBook objectAtIndex: 0] objectForKey:@"DefaultEntry"] ) {
        [addressBook insertObject:[self newDefaultAddressBookEntry] atIndex: 0];
    }
    // There can be only one
    int i;
    for ( i = 1; i < [addressBook count]; i++) {
        if ( isDefaultEntry( [addressBook objectAtIndex: i] ) ) {
            NSDictionary *entry = [addressBook objectAtIndex: i];
            NSMutableDictionary *newentry = [NSMutableDictionary dictionaryWithDictionary:entry];
            // [entry release]?
            [newentry removeObjectForKey:@"DefaultEntry"];
            entry = [NSDictionary dictionaryWithDictionary:newentry];
            [addressBook replaceObjectAtIndex:i withObject:entry];
        }
    }
}

- (void) saveAddressBook
{
    if (![NSArchiver archiveRootObject:[self addressBook] toFile:[ADDRESS_BOOK_FILE stringByExpandingTildeInPath]]) {
        NSLog(@"Save failed");
    }
}


// Returns an entry from the addressbook
- (NSDictionary *)addressBookEntry: (int) entryIndex
{
    if((entryIndex < 0) || (entryIndex >= [[self addressBook] count]))
        return (nil);

    return ([[self addressBook] objectAtIndex: entryIndex]);

}

- (NSMutableDictionary *) defaultAddressBookEntry
{
    int i;

    for(i = 0; i < [[self addressBook] count]; i++)
    {
	NSMutableDictionary *entry = [[self addressBook] objectAtIndex: i];

	if([entry objectForKey: @"DefaultEntry"] != nil)
	    return (entry);
    }

    return (nil);
}

- (NSDictionary *)newDefaultAddressBookEntry
{
    char *userShell, *thisUser;
    NSString *shell;

    // This would be better read from a file stored in the package (with some bits added at run time)

    // Get the user's default shell
    if((thisUser = getenv("USER")) != NULL) {
        shell = [NSString stringWithFormat: @"login -fp %s", thisUser];
    } else if((userShell = getenv("SHELL")) != NULL) {
        shell = [NSString stringWithCString: userShell];
    } else {
        shell = @"/bin/bash --login";
    }

    NSDictionary *ae;
    ae=[[NSDictionary alloc] initWithObjectsAndKeys:
        @"Default session",@"Name",
        shell,@"Command",
        [NSNumber numberWithUnsignedInt:1],@"Encoding",
        [NSColor colorWithCalibratedRed:0.8f
				  green:0.8f
				   blue:0.8f
				  alpha:1.0f],@"Foreground",
        [NSColor blackColor],@"Background",
        [NSColor colorWithCalibratedRed:0.45f
				  green:0.5f
				   blue:0.55f
				  alpha:1.0f],@"SelectionColor",
        [NSColor redColor],@"BoldColor",
        [NSNumber numberWithUnsignedInt:25],@"Row",
        [NSNumber numberWithUnsignedInt:80],@"Col",
        [NSNumber numberWithInt:10],@"Transparency",
        @"xterm",@"Term Type",
        [@"~"  stringByExpandingTildeInPath],@"Directory",
        [NSFont fontWithName:@"FreeMonoBold" size:13],@"Font",
        [NSFont fontWithName:@"Osaka-Mono"
					     size:14],@"NAFont",
        [NSNumber numberWithBool:false],@"AntiIdle",
        [NSNumber numberWithUnsignedInt:0],@"AICode",
        [NSNumber numberWithBool:true],@"AutoClose",
        [NSNumber numberWithBool:false],@"DoubleWidth",
        [NSNumber numberWithUnsignedInt:0],@"Shortcut",
        [NSNumber numberWithBool:true],@"DefaultEntry",
        NULL];
        [ae autorelease];
    return ae;
}


- (void) addAddressBookEntry: (NSDictionary *) entry
{
    [[self addressBook] addObject:entry];
    [[self addressBook] sortUsingFunction: addressBookComparator context: nil];
}

- (void) replaceAddressBookEntry:(NSDictionary *) old with:(NSDictionary *)new
{
    [[self addressBook] replaceObjectAtIndex:[[self addressBook] indexOfObject:old] withObject:new];
}

// Returns the entries in the addressbook
- (NSArray *)addressBookNames
{
    NSMutableArray *anArray;
    int i;
    NSDictionary *anEntry;

    anArray = [[NSMutableArray alloc] init];

    for(i = 0; i < [[self addressBook] count]; i++)
    {
        anEntry = [[self addressBook] objectAtIndex: i];
        [anArray addObject: entryVisibleName( anEntry, self )];
    }

    return ([anArray autorelease]);

}


@end

// keys for to-many relationships:
NSString *terminalsKey = @"terminals";

// Scripting support
@implementation MainMenu (KeyValueCoding)

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
    [object setMainMenu: self];
    [object setPreference:PREF_PANEL];
    if([object windowInited] == NO)
    {
	NSDictionary *defaultSessionPreferences = [self defaultAddressBookEntry];

	[object initWindow:[[defaultSessionPreferences objectForKey: @"Col"] intValue]
	     height:[[defaultSessionPreferences objectForKey: @"Row"] intValue]
	       font:[defaultSessionPreferences objectForKey: @"Font"]
	     nafont:[defaultSessionPreferences objectForKey: @"NAFont"]];
    }
    [terminalWindows insertObject: object atIndex: index];
}

-(void)removeFromTerminalsAtIndex:(unsigned)index
{
    // NSLog(@"iTerm: removeFromTerminalsAtInde %d", index);
    [terminalWindows removeObjectAtIndex: index];
}


// a class method to provide the keys for KVC:
+(NSArray*)kvcKeys
{
    static NSArray *_kvcKeys = nil;
    if( nil == _kvcKeys ){
	_kvcKeys = [[NSArray alloc] initWithObjects:
	    terminalsKey,  nil ];
    }
    return _kvcKeys;
}


@end


// Private interface
@implementation MainMenu (Private)

- (void) _executeABMenuCommandInNewTab: (id) sender
{
    [self executeABCommandAtIndex: [sender tag] inTerminal: [sender representedObject]];
}

- (void) _executeABMenuCommandInNewWindow: (id) sender
{
    [self executeABCommandAtIndex: [sender tag] inTerminal: nil];
}

- (void) _selectSessionAtIndex: (id) sender
{
    if(FRONT != nil)
	[FRONT selectSessionAtIndex: [sender tag]];
    else
	NSBeep();
}

@end
