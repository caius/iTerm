// -*- mode:objc -*-
// $Id: MainMenu.m,v 1.56 2003-04-29 17:11:03 yfabian Exp $
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
#import "NSStringITerm.h"
#import "AddressBookWindowController.h"


#define DEFAULT_FONTNAME  @"Osaka-Mono"
#define DEFAULT_FONTSIZE  12

static NSString* ADDRESS_BOOK_FILE = @"~/Library/Application Support/iTerm Address Book";
static NSStringEncoding const *encodingList=nil;

// comaparator function for addressbook entries
static NSComparisonResult addressBookComparator (NSDictionary *entry1, NSDictionary *entry2, void *context)
{
    return ([(NSString *)[entry1 objectForKey: @"Name"] caseInsensitiveCompare: (NSString *)[entry2 objectForKey: @"Name"]]);
}

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
    NSMenu *abMenu = [[NSMenu alloc] initWithTitle: @"Address Book Menu"];
    [self buildAddressBookMenu: abMenu forTerminal: FRONT]; // target the top terminal window.
    [newTabMenuItem setSubmenu: abMenu];
    [abMenu release];
    
    abMenu = [[NSMenu alloc] initWithTitle: @"Address Book Menu"];
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
    PseudoTerminal *term;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu newWindow]",
          __FILE__, __LINE__);
#endif

    term = [[PseudoTerminal alloc] init];
    [self addInTerminals: term];
    [term release];
    
    [term setPreference:PREF_PANEL];
    [term newSession:nil];
}

- (IBAction)newSession:(id)sender
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu newSession]",
          __FILE__, __LINE__);
#endif
    if(FRONT == nil)
        [self newWindow:nil];
    else
        [FRONT newSession: self];
}

// Address book window
- (IBAction)showABWindow:(id)sender
{
    AddressBookWindowController *abWindowController;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu showABWindow:%@]",
          __FILE__, __LINE__, sender);
#endif

//    [self initAddressBook];
//    NSLog(@"showABWindow: %d\n%@",[addressBook count], addressBook);

    abWindowController = [AddressBookWindowController singleInstance];
    [abWindowController setAddressBook: addressBook];
    [abWindowController setPreferences: PREF_PANEL];
    [abWindowController run];    
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
            s=[theRecord objectForKey:@"Name"];
            break;
        case 1:
            s=[theRecord objectForKey:@"Command"];
            break;
        case 2:
            // this is for compatibility with old address book
            if ([[theRecord objectForKey:@"Encoding"] isKindOfClass:[NSString class]]) {
                NSMutableDictionary *new=[theRecord mutableCopy]; //[NSMutableDictionary dictionaryWithDictionary:theRecord];
                [new setObject:[NSNumber numberWithUnsignedInt:[PREF_PANEL encoding]] forKey:@"Encoding"];
                theRecord=new;
                [addressBook replaceObjectAtIndex:rowIndex withObject:new];
                
            }
            
            s=[NSString localizedNameOfStringEncoding:(NSStringEncoding)[[theRecord objectForKey:@"Encoding"] unsignedIntValue]];
            break;
        case 3:
//            NSLog(@"%@:%d",[theRecord objectForKey:@"Name"],[[theRecord objectForKey:@"Shortcut"] intValue]);
            s=([[theRecord objectForKey:@"Shortcut"] intValue]?
            [NSString stringWithFormat:@"%c",[[theRecord objectForKey:@"Shortcut"] intValue]]:@"");
    }
            
    return s;
}

// this message is called when the user double-clicks on a row in the table
- (void)tableView:(NSTableView*)table  setObjectValue:(id)object
                                       forTableColumn:(NSTableColumn*)col
                                                  row:(int)rowIndex
{
    [self saveAddressBook];
    [NSApp stopModal];
}


/// About window

- (IBAction)showAbout:(id)sender
{
    NSURL *author1URL, *author2URL, *webURL, *bugURL;
    NSAttributedString *author1, *author2, *webSite, *bugReport, *mode;
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

#if USE_CUSTOM_DRAWING
    mode = [[NSAttributedString alloc] initWithString: @"(A)"];
#else
    mode = [[NSAttributedString alloc] initWithString: @"(B)"];
#endif
    
    [[AUTHORS textStorage] deleteCharactersInRange: NSMakeRange(0, [[AUTHORS textStorage] length])];
    [[AUTHORS textStorage] appendAttributedString: author1];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: author2];
    [tmpAttrString initWithString: @"\n"];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: webSite];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: mode];
    [[AUTHORS textStorage] appendAttributedString: tmpAttrString];
    [[AUTHORS textStorage] appendAttributedString: bugReport];
    [AUTHORS setAlignment: NSCenterTextAlignment range: NSMakeRange(0, [[AUTHORS textStorage] length])];

    
    [NSApp runModalForWindow:ABOUT];
    [ABOUT close];
    [author1 release];
    [author2 release];
    [webSite release];
    [tmpAttrString release];
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

- (void) initAddressBook
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu initAddressBook]",
          __FILE__, __LINE__);
#endif

    if (addressBook!=nil) return;

    addressBook = [[NSUnarchiver unarchiveObjectWithFile: [ADDRESS_BOOK_FILE stringByExpandingTildeInPath]] retain];
    if (addressBook == nil) {
        NSLog(@"No file loaded");
        addressBook=[[NSMutableArray array] retain];
    }

}

- (void) saveAddressBook
{
    if (![NSArchiver archiveRootObject:addressBook toFile:[ADDRESS_BOOK_FILE stringByExpandingTildeInPath]]) {
        NSLog(@"Save failed");
    }
}

- (void) setFrontPseudoTerminal: (PseudoTerminal *) thePseudoTerminal
{
    FRONT = thePseudoTerminal;
}

- (PseudoTerminal *) frontPseudoTerminal
{
    return (FRONT);
}

- (void) terminalWillClose: (PseudoTerminal *) theTerminalWindow
{
    if(FRONT == theTerminalWindow)
        FRONT = nil;
    if(theTerminalWindow)
    {
        [terminalWindows removeObject: theTerminalWindow];
    }
}

- (NSStringEncoding const*) encodingList
{
    return encodingList;
}

// Returns the entries in the addressbook
- (NSArray *)addressBookNames
{
    NSMutableArray *anArray;
    int i;
    NSDictionary *anEntry;
    
    anArray = [[NSMutableArray alloc] init];
    
    for(i = 0; i < [addressBook count]; i++)
    {
        anEntry = [addressBook objectAtIndex: i];
        [anArray addObject: [anEntry objectForKey:@"Name"]];
    }
    
    return ([anArray autorelease]);
    
}

// Build the address book menu
- (void) buildAddressBookMenu: (NSMenu *) abMenu forTerminal: (id) sender
{
    NSEnumerator *abEnumerator;
    NSString *abEntry;
    int i = 0;
    SEL shellSelector, abCommandSelector;


#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu buildAddressBookMenu]",
          __FILE__, __LINE__);
#endif

    if (sender == nil)
    {
	shellSelector = @selector(newWindow:);
	abCommandSelector = @selector(_executeABMenuCommandInNewWindow:);
    }
    else
    {
	shellSelector = @selector(newSession:);
	abCommandSelector = @selector(_executeABMenuCommandInNewTab:);
    }

    [abMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Default session",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New")
					   action: shellSelector keyEquivalent:@""];
    [abMenu addItem: [NSMenuItem separatorItem]];
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
    NSStringEncoding encoding;
    int i;

    // Grab the addressbook command
    entry = [addressBook objectAtIndex:theIndex];
    [MainMenu breakDown:[entry objectForKey:@"Command"] cmdPath:&cmd cmdArgs:&arg];
    //        NSLog(@"%s(%d):-[PseudoTerminal ready to run:%@ arguments:%@]", __FILE__, __LINE__, cmd, arg );
    encoding=[[entry objectForKey:@"Encoding"] unsignedIntValue];
    
    
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
    
    [aSession setForegroundColor: [entry objectForKey:@"Foreground"]];
    [aSession setBackgroundColor: [[entry objectForKey:@"Background"] colorWithAlphaComponent: (1.0-[[entry objectForKey:@"Transparency"] intValue]/100.0)]];
    [aSession setSelectionColor: [entry objectForKey:@"SelectionColor"]];
    if([entry objectForKey:@"BoldColor"] != nil)
	[aSession setBoldColor: [entry objectForKey:@"BoldColor"]];
    else
	[aSession setBoldColor: [PREF_PANEL boldColor]];
    [aSession setEncoding: encoding];
    [aSession setTERM_VALUE: [entry objectForKey:@"Term Type"]];

    
    NSDictionary *env=[NSDictionary dictionaryWithObject:([entry objectForKey:@"Directory"]?[entry objectForKey:@"Directory"]:@"~")  forKey:@"PWD"];
    
    // Start the command        
    [term startProgram:cmd arguments:arg environment:env];
    [aSession setEncoding:encoding];
    [aSession setAntiCode:[[entry objectForKey:@"AICode"] intValue]];
    [aSession setAntiIdle:[[entry objectForKey:@"AntiIdle"] boolValue]];
    [aSession setAutoClose:[[entry objectForKey:@"AutoClose"] boolValue]];
    
    // If we created a new window, set the size
    if (theTerm == nil) {
        [term setWindowSize: YES];
    };
    [term setCurrentSessionName:[entry objectForKey:@"Name"]];
    [aSession setAddressBookEntry:entry];
    [aSession setDoubleWidth:[[entry objectForKey:@"DoubleWidth"] boolValue]];
    if ([entry objectForKey:@"ansiBlack"]) {
    [aSession setColorTable:0 highLight:NO color:[entry objectForKey:@"ansiBlack"]];
    [aSession setColorTable:1 highLight:NO color:[entry objectForKey:@"ansiRed"]];
    [aSession setColorTable:2 highLight:NO color:[entry objectForKey:@"ansiGreen"]];
    [aSession setColorTable:3 highLight:NO color:[entry objectForKey:@"ansiYellow"]];
    [aSession setColorTable:4 highLight:NO color:[entry objectForKey:@"ansiBlue"]];
    [aSession setColorTable:5 highLight:NO color:[entry objectForKey:@"ansiMagenta"]];
    [aSession setColorTable:6 highLight:NO color:[entry objectForKey:@"ansiCyan"]];
    [aSession setColorTable:7 highLight:NO color:[entry objectForKey:@"ansiWhite"]];
    [aSession setColorTable:0 highLight:YES color:[entry objectForKey:@"ansiHiBlack"]];
    [aSession setColorTable:1 highLight:YES color:[entry objectForKey:@"ansiHiRed"]];
    [aSession setColorTable:2 highLight:YES color:[entry objectForKey:@"ansiHiGreen"]];
    [aSession setColorTable:3 highLight:YES color:[entry objectForKey:@"ansiHiYellow"]];
    [aSession setColorTable:4 highLight:YES color:[entry objectForKey:@"ansiHiBlue"]];
    [aSession setColorTable:5 highLight:YES color:[entry objectForKey:@"ansiHiMagenta"]];
    [aSession setColorTable:6 highLight:YES color:[entry objectForKey:@"ansiHiCyan"]];
    [aSession setColorTable:7 highLight:YES color:[entry objectForKey:@"ansiHiWhite"]];
    }
    else {
        for(i=0;i<8;i++) {
            [aSession setColorTable:i highLight:NO color:[PREF_PANEL colorFromTable:i highLight:NO]];
            [aSession setColorTable:i highLight:YES color:[PREF_PANEL colorFromTable:i highLight:YES]];
        }
    }
    
}

// Returns an entry from the addressbook
- (NSDictionary *)addressBookEntry: (int) entryIndex
{
    if((entryIndex < 0) || (entryIndex >= [addressBook count]))
        return (nil);
    
    return ([addressBook objectAtIndex: entryIndex]);
    
}

- (void) addAddressBookEntry: (NSDictionary *) entry
{
    [addressBook addObject:entry];
    [addressBook sortUsingFunction: addressBookComparator context: nil];
}

- (void) replaceAddressBookEntry:(NSDictionary *) old with:(NSDictionary *)new
{
    [addressBook replaceObjectAtIndex:[addressBook indexOfObject:old] withObject:new];
}

- (void) interpreteKey: (int) code newWindow:(BOOL) newWin
{
    int i, c, n=[addressBook count];

    if (code>='a'&&code<='z') code+='A'-'a';
//    NSLog(@"got code:%d (%s)",code,(newWin?"new":"old"));
    
    for(i=0; i<n; i++) {
        c=[[[addressBook objectAtIndex:i] objectForKey:@"Shortcut"] intValue];
        if (code==c) {
            [self executeABCommandAtIndex:i inTerminal: newWin?nil:FRONT];
        }
    }
            
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
    [object setPreference:PREF_PANEL];
    if([object windowInited] == NO)
    {
	[object initWindow:[PREF_PANEL col]
	     height:[PREF_PANEL row]
	       font:[PREF_PANEL font]
	     nafont:[PREF_PANEL nafont]];
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

@end
