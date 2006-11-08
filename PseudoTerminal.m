// -*- mode:objc -*-
// $Id: PseudoTerminal.m,v 1.372 2006-11-08 01:00:48 yfabian Exp $
//
/*
 **  PseudoTerminal.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Session and window controller for iTerm.
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

#import <iTerm/iTerm.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYScrollView.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/PTYSession.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/PTYTabView.h>
#import <iTerm/PreferencePanel.h>
#import <iTerm/iTermController.h>
#import <iTerm/PTYTask.h>
#import <iTerm/PTYTextView.h>
#import <iTerm/VT100Terminal.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/PTYSession.h>
#import <iTerm/PTToolbarController.h>
#import <iTerm/FindPanelWindowController.h>
#import <iTerm/ITAddressBookMgr.h>
#import <iTerm/ITConfigPanelController.h>
#import <iTerm/iTermTerminalProfileMgr.h>
#import <iTerm/iTermDisplayProfileMgr.h>
#import <iTerm/Tree.h>
#import <PSMTabBarControl.h>
#import <PSMTabStyle.h>
#import <iTermBookmarkController.h>
#import <iTermOutlineView.h>
#include <unistd.h>

@interface PSMTabBarControl (Private)
- (void)update;
@end

@interface NSWindow (private)
- (void)setBottomCornerRounded:(BOOL)rounded;
@end

// keys for attributes:
NSString *columnsKey = @"columns";
NSString *rowsKey = @"rows";
// keys for to-many relationships:
NSString *sessionsKey = @"sessions";

#define TABVIEW_TOP_OFFSET				29
#define TABVIEW_BOTTOM_OFFSET			27
#define TABVIEW_LEFT_RIGHT_OFFSET		29
#define TOOLBAR_OFFSET					0

// just to keep track of available window positions
#define CACHED_WINDOW_POSITIONS		100
static unsigned int windowPositions[CACHED_WINDOW_POSITIONS];  

@implementation PseudoTerminal

// Utility
+ (void) breakDown:(NSString *)cmdl cmdPath: (NSString **) cmd cmdArgs: (NSArray **) path
{
    int i,j,k,qf,slen;
    char tmp[100];
    const char *s;
    NSMutableArray *p;
    
    p=[[NSMutableArray alloc] init];
    
    s=[cmdl cString];
    slen = strlen(s);
    
    i=j=qf=0;
    k=-1;
    while (i<=slen) {
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
                while (i<slen&&s[i+1]==' '||s[i+1]=='\t'||s[i+1]=='\n'||s[i+1]==0) i++;
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

- (id)initWithWindowNibName: (NSString *) windowNibName
{
    int i;
	NSScrollView *aScrollView;
	NSTableColumn *aTableColumn;
	NSSize aSize;
	NSRect aRect;
	unsigned int styleMask;
	PTYWindow *myWindow;
	NSDrawer	*myDrawer;
	
    
    if ((self = [super initWithWindowNibName: windowNibName]) == nil)
		return nil;
	
	//enforce the nib to load
	[self window];
	
	// create the window programmatically with appropriate style mask
	styleMask = NSTitledWindowMask | 
		NSClosableWindowMask | 
		NSMiniaturizableWindowMask | 
		NSResizableWindowMask;
	
	// set the window style according to preference
	if([[PreferencePanel sharedInstance] windowStyle] == 0)
		styleMask |= NSTexturedBackgroundWindowMask;
	
	myWindow = [[PTYWindow alloc] initWithContentRect: [[NSScreen mainScreen] frame]
											styleMask: styleMask 
											  backing: NSBackingStoreBuffered 
												defer: YES];
	[self setWindow: myWindow];
	[myWindow release];
	
	// create and set up drawer
	myDrawer = [[NSDrawer alloc] initWithContentSize: NSMakeSize(20, 100) preferredEdge: NSMinXEdge];
	[myDrawer setParentWindow: myWindow];
    [myDrawer setDelegate:self];
	[myWindow setDrawer: myDrawer];
	float aWidth = [[NSUserDefaults standardUserDefaults] floatForKey: @"BookmarksDrawerWidth"];
    if (aWidth<=0) aWidth = 150.0;
    [myDrawer setContentSize: NSMakeSize(aWidth, 0)];
    [myDrawer release];
    
	aScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 20, 100)];
	[aScrollView setBorderType:NSBezelBorder];
	[aScrollView setHasHorizontalScroller: NO];
	[aScrollView setHasVerticalScroller: YES];
	[[aScrollView verticalScroller] setControlSize:NSSmallControlSize];
	[aScrollView setAutohidesScrollers: YES];
	aSize = [aScrollView contentSize];
	aRect = NSZeroRect;
	aRect.size = aSize;
	
	bookmarksView = [[iTermOutlineView alloc] initWithFrame:aRect];
	aTableColumn = [[NSTableColumn alloc] initWithIdentifier: @"Name"];
	[[aTableColumn headerCell] setStringValue: NSLocalizedStringFromTableInBundle(@"Bookmarks",@"iTerm", [NSBundle bundleForClass: [self class]], @"Bookmarks")];
	[bookmarksView addTableColumn: aTableColumn];
	[aTableColumn release];
	[bookmarksView setOutlineTableColumn: aTableColumn];
	[bookmarksView setDelegate: self];
	[bookmarksView setTarget: self];
	[bookmarksView setDoubleAction: @selector(doubleClickedOnBookmarksView:)];	
	[bookmarksView setDataSource: [iTermBookmarkController sharedInstance]];
	
	[aScrollView setDocumentView:bookmarksView];
	[bookmarksView release];
	[myDrawer setContentView: aScrollView];
	[aScrollView release];
	
    
    // Look for an available window position
    for (i = 0; i < CACHED_WINDOW_POSITIONS; i++)
    {
		if(windowPositions[i] == 0)
		{
			[[self window] setFrameAutosaveName: [NSString stringWithFormat: @"iTerm Window %d", i]];
			windowPositions[i] = (unsigned int) self;
			break;
		}
    }
	     
	[self _commonInit];
	
#if DEBUG_ALLOC
    NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif
	
    return self;
}

- (id)init
{
    return ([self initWithWindowNibName: @"PseudoTerminal"]);
}


// Do not use both initViewWithFrame and initWindow
// initViewWithFrame is mainly meant for embedding a terminal view in a non-iTerm window.
- (PTYTabView*) initViewWithFrame: (NSRect) frame
{
    NSFont *aFont1, *aFont2;
    NSSize contentSize;
	NSString *displayProfile;
	
	// sanity check
	if(TABVIEW != nil)
		return (TABVIEW);
    
    // Create the tabview
    TABVIEW = [[PTYTabView alloc] initWithFrame: frame];
    [TABVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    [TABVIEW setAllowsTruncatedLabels: NO];
    [TABVIEW setControlSize: NSSmallControlSize];
    [TABVIEW setAutoresizesSubviews: YES];
	// Tell us whenever something happens with the tab view
	[TABVIEW setDelegate: self];
	
    aFont1 = FONT;
    if(aFont1 == nil)
    {
		NSDictionary *defaultSession = [[ITAddressBookMgr sharedInstance] defaultBookmarkData];
		displayProfile = [defaultSession objectForKey: KEY_DISPLAY_PROFILE];
		if(displayProfile == nil)
			displayProfile = [[iTermDisplayProfileMgr singleInstance] defaultProfileName];
		aFont1 = [[iTermDisplayProfileMgr singleInstance] windowFontForProfile: displayProfile];
		aFont2 = [[iTermDisplayProfileMgr singleInstance] windowNAFontForProfile: displayProfile];
		[self setFont: aFont1 nafont: aFont2];
    }
    
    NSParameterAssert(aFont1 != nil);
    // Calculate the size of the terminal
    contentSize = [NSScrollView contentSizeForFrameSize: [TABVIEW contentRect].size
								  hasHorizontalScroller: NO
									hasVerticalScroller: YES
											 borderType: NSNoBorder];
	
    [self setCharSizeUsingFont: aFont1];
    [self setWidth: (int) ((contentSize.width - MARGIN * 2)/charWidth + 0.1)
			height: (int) ((contentSize.height) /charHeight + 0.1)];
	
    return ([TABVIEW autorelease]);
}

// Do not use both initViewWithFrame and initWindow
- (void)initWindowWithAddressbook:(NSDictionary *)entry;
{
	NSRect aRect;
	// sanity check
    if(TABVIEW != nil)
		return;
	
    _toolbarController = [[PTToolbarController alloc] initWithPseudoTerminal:self];
	
	if ([[self window] respondsToSelector:@selector(setBottomCornerRounded:)])
		[[self window] setBottomCornerRounded:NO];
    
	// create the tab bar control
	aRect = [[[self window] contentView] bounds];
	aRect.size.height = 22;
	tabBarControl = [[PSMTabBarControl alloc] initWithFrame: aRect];
	[tabBarControl setAutoresizingMask: (NSViewWidthSizable | NSViewMinYMargin)];
	[[[self window] contentView] addSubview: tabBarControl];
	[tabBarControl release];	
	
    // create the tabview
	aRect = [[[self window] contentView] bounds];
	//aRect.size.height -= [tabBarControl frame].size.height;
    TABVIEW = [[PTYTabView alloc] initWithFrame: aRect];
    [TABVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
	[TABVIEW setAutoresizesSubviews: YES];
    [TABVIEW setAllowsTruncatedLabels: NO];
    [TABVIEW setControlSize: NSSmallControlSize];
	[TABVIEW setTabViewType: NSNoTabsNoBorder];
    // Add to the window
    [[[self window] contentView] addSubview: TABVIEW];
	[TABVIEW release];
	
	// assign tabview and delegates
	[tabBarControl setTabView: TABVIEW];
	[TABVIEW setDelegate: tabBarControl];
	[tabBarControl setDelegate: self];
	[tabBarControl setHideForSingleTab: NO];
    
	
	// set the style of tabs to match window style
	switch ([[PreferencePanel sharedInstance] windowStyle]) {
        case 0:
            [tabBarControl setStyleNamed:@"Metal"];
            break;
        case 1:
            [tabBarControl setStyleNamed:@"Aqua"];
            break;
        case 2:
            [tabBarControl setStyleNamed:@"Unified"];
            break;
        default:
            [tabBarControl setStyleNamed:@"Adium"];
            break;
    }

	
	// position the tabview and control
	aRect = [TABVIEW frame];
	aRect.origin.x = 0;
	aRect.origin.y = 0;
	[TABVIEW setFrame: aRect];		
	aRect = [tabBarControl frame];
	aRect.origin.x = 0;
	aRect.origin.y = [TABVIEW frame].size.height;
	aRect.size.width = [[[self window] contentView] bounds].size.width;
	[tabBarControl setFrame: aRect];	
    [tabBarControl setSizeCellsToFit:NO];
    [tabBarControl setCellMinWidth:75];
    [tabBarControl setCellOptimumWidth:175];
	
	
    [[[self window] contentView] setAutoresizesSubviews: YES];
		
	
    [[self window] setDelegate: self];
		
	[[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_reloadAddressBook:)
                                                 name: @"iTermReloadAddressBook"
                                               object: nil];	
	
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_refreshTerminal:)
                                                 name: @"iTermRefreshTerminal"
                                               object: nil];	
	
    [self setWindowInited: YES];
    
    if (entry) {
        NSString *displayProfile;
        iTermDisplayProfileMgr *displayProfileMgr;
        
        displayProfileMgr = [iTermDisplayProfileMgr singleInstance];
        
        // grab the profiles
        displayProfile = [entry objectForKey: KEY_DISPLAY_PROFILE];
        if(displayProfile == nil)
            displayProfile = [displayProfileMgr defaultProfileName];
        
 		WIDTH = [displayProfileMgr windowColumnsForProfile: displayProfile];
		HEIGHT = [displayProfileMgr windowRowsForProfile: displayProfile];
		[self setAntiAlias: [displayProfileMgr windowAntiAliasForProfile: displayProfile]];
		[self setFont: [displayProfileMgr windowFontForProfile: displayProfile] 
			   nafont: [displayProfileMgr windowNAFontForProfile: displayProfile]];
		[self setCharacterSpacingHorizontal: [displayProfileMgr windowHorizontalCharSpacingForProfile: displayProfile] 
                                   vertical: [displayProfileMgr windowVerticalCharSpacingForProfile: displayProfile]];
    }
}


- (void)setupSession: (PTYSession *) aSession
		       title: (NSString *)title
{
    NSDictionary *addressBookPreferences;
    NSDictionary *tempPrefs;
	NSString *terminalProfile, *displayProfile;
	iTermTerminalProfileMgr *terminalProfileMgr;
	iTermDisplayProfileMgr *displayProfileMgr;
	ITAddressBookMgr *bookmarkManager;
		
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setupSession]",
          __FILE__, __LINE__);
#endif
	
    NSParameterAssert(aSession != nil);    
	
	// get our shared managers
	terminalProfileMgr = [iTermTerminalProfileMgr singleInstance];
	displayProfileMgr = [iTermDisplayProfileMgr singleInstance];
	bookmarkManager = [ITAddressBookMgr sharedInstance];	
	
    // Init the rest of the session
    [aSession setParent: self];
	
    // set some default parameters
    if([aSession addressBookEntry] == nil)
    {
		// get the default entry
		addressBookPreferences = [[ITAddressBookMgr sharedInstance] defaultBookmarkData];
		[aSession setAddressBookEntry:addressBookPreferences];
		tempPrefs = addressBookPreferences;
    }
    else
    {
		tempPrefs = [aSession addressBookEntry];
    }
	
	terminalProfile = [tempPrefs objectForKey: KEY_TERMINAL_PROFILE];
	displayProfile = [tempPrefs objectForKey: KEY_DISPLAY_PROFILE];
	
    if(WIDTH == 0 && HEIGHT == 0)
    {
		WIDTH = [displayProfileMgr windowColumnsForProfile: displayProfile];
		HEIGHT = [displayProfileMgr windowRowsForProfile: displayProfile];
		[self setAntiAlias: [displayProfileMgr windowAntiAliasForProfile: displayProfile]];
    }
    [aSession initScreen: [TABVIEW contentRect] width:WIDTH height:HEIGHT];
    if(FONT == nil) 
	{
		[self setFont: [displayProfileMgr windowFontForProfile: displayProfile] 
			   nafont: [displayProfileMgr windowNAFontForProfile: displayProfile]];
		[self setCharacterSpacingHorizontal: [displayProfileMgr windowHorizontalCharSpacingForProfile: displayProfile] 
								   vertical: [displayProfileMgr windowVerticalCharSpacingForProfile: displayProfile]];
    }
    
    [aSession setPreferencesFromAddressBookEntry: tempPrefs];
	 	
    [[aSession SCREEN] setDisplay:[aSession TEXTVIEW]];
	[[aSession TEXTVIEW] setFont:FONT nafont:NAFONT];
	[[aSession TEXTVIEW] setAntiAlias: antiAlias];
    [[aSession TEXTVIEW] setLineHeight: charHeight];
    [[aSession TEXTVIEW] setLineWidth: WIDTH * charWidth];
	[[aSession TEXTVIEW] setCharWidth: charWidth];
	// NSLog(@"%d,%d",WIDTH,HEIGHT);
		
    [[aSession TERMINAL] setTrace:YES];	// debug vt100 escape sequence decode
	
    // tell the shell about our size
    [[aSession SHELL] setWidth:WIDTH  height:HEIGHT];
	
    if (title) 
    {
        [self setWindowTitle: title];
        [aSession setName: title];
    }
}

- (void)selectSessionAtIndexAction:(id)sender
{
    [TABVIEW selectTabViewItemAtIndex:[sender tag]];
}

- (void) newSessionInTabAtIndex: (id) sender
{
    [self addNewSession: [sender representedObject]];
}

- (void) insertSession: (PTYSession *) aSession atIndex: (int) index
{
    NSTabViewItem *aTabViewItem;
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal insertSession: 0x%x atIndex: %d]",
          __FILE__, __LINE__, aSession, index);
#endif    
	
    if(aSession == nil)
		return;
	
    if ([TABVIEW indexOfTabViewItemWithIdentifier: aSession] == NSNotFound)
    {
        // create a new tab
		aTabViewItem = [[NSTabViewItem alloc] initWithIdentifier: aSession];
		[aSession setTabViewItem: aTabViewItem];
		NSParameterAssert(aTabViewItem != nil);
		[aTabViewItem setLabel: [aSession name]];
		[aTabViewItem setView: [aSession view]];
		[[aSession SCROLLVIEW] setLineScroll: charHeight];
        [[aSession SCROLLVIEW] setPageScroll: HEIGHT*charHeight/2];
        [TABVIEW insertTabViewItem: aTabViewItem atIndex: index];
		
        [aTabViewItem release];
		[TABVIEW selectTabViewItemAtIndex: index];

		if([self windowInited])
			[[self window] makeKeyAndOrderFront: self];
		[[iTermController sharedInstance] setCurrentTerminal: self];
		[self setWindowSize];
    }
}

- (void) closeSession: (PTYSession*) aSession
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, aSession);
#endif    
	
    NSTabViewItem *aTabViewItem;
	int numberOfSessions;
    
    if([TABVIEW indexOfTabViewItemWithIdentifier: aSession] == NSNotFound)
        return;
    
    numberOfSessions = [TABVIEW numberOfTabViewItems]; 
    if(numberOfSessions == 1 && [self windowInited])
    {   
        [[self window] close];
    }
	else {
         // now get rid of this session
        aTabViewItem = [aSession tabViewItem];
        [aSession terminate];
        [TABVIEW removeTabViewItem: aTabViewItem];
    }
}

- (IBAction) closeCurrentSession: (id) sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal closeCurrentSession]",
          __FILE__, __LINE__);
#endif
	PTYSession *aSession = [[TABVIEW selectedTabViewItem] identifier];
    
    if (![aSession exited])
    {
		if ([[PreferencePanel sharedInstance] promptOnClose] &&
			NSRunAlertPanel([NSString stringWithFormat:@"%@ #%d", [aSession name], [aSession realObjectCount]],
							NSLocalizedStringFromTableInBundle(@"This session will be closed.",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close Session"),
							NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
							NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
							,nil) == 0) return;
    }
    
    [self closeSession:[[TABVIEW selectedTabViewItem] identifier]];
} 

- (IBAction)previousSession:(id)sender
{
    NSTabViewItem *tvi=[TABVIEW selectedTabViewItem];
    [TABVIEW selectPreviousTabViewItem: sender];
    if (tvi==[TABVIEW selectedTabViewItem]) [TABVIEW selectTabViewItemAtIndex: [TABVIEW numberOfTabViewItems]-1];
}

- (IBAction) nextSession:(id)sender
{
    NSTabViewItem *tvi=[TABVIEW selectedTabViewItem];
    [TABVIEW selectNextTabViewItem: sender];
    if (tvi==[TABVIEW selectedTabViewItem]) [TABVIEW selectTabViewItemAtIndex: 0];
}

- (NSString *) currentSessionName
{
    return ([[[TABVIEW selectedTabViewItem] identifier] name]);
}

- (void) setCurrentSessionName: (NSString *) theSessionName
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setCurrentSessionName]",
          __FILE__, __LINE__);
#endif
    NSMutableString *title = [NSMutableString string];
    PTYSession *aSession = [[TABVIEW selectedTabViewItem] identifier];
    
    if(theSessionName != nil)
    {
        [aSession setName: theSessionName];
    }
    else {
        NSString *progpath = [NSString stringWithFormat: @"%@ #%d", [[[[aSession SHELL] path] pathComponents] lastObject], [TABVIEW indexOfTabViewItem:[TABVIEW selectedTabViewItem]]];
		
        if ([aSession exited])
            [title appendString:@"Finish"];
        else
            [title appendString:progpath];
		
        [aSession setName: title];
		
    }
}

- (PTYSession *) currentSession
{
    return [[TABVIEW selectedTabViewItem] identifier];
}

- (int) currentSessionIndex
{
    return ([TABVIEW indexOfTabViewItem:[TABVIEW selectedTabViewItem]]);
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    // Release all our sessions
    NSTabViewItem *aTabViewItem;
    for(;[TABVIEW numberOfTabViewItems];) 
    {
        aTabViewItem = [TABVIEW tabViewItemAtIndex:0];
        [[aTabViewItem identifier] terminate];
        [TABVIEW removeTabViewItem: aTabViewItem];
    }
	
    [_toolbarController release];
    
    [super dealloc];
}

- (void)startProgram:(NSString *)program
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@]",
		  __FILE__, __LINE__, program );
#endif
    [[self currentSession] startProgram:program
									 arguments:[NSArray array]
								   environment:[NSDictionary dictionary]];
		
}

- (void)startProgram:(NSString *)program arguments:(NSArray *)prog_argv
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@ arguments:%@]",
          __FILE__, __LINE__, program, prog_argv );
#endif
    [[self currentSession] startProgram:program
									 arguments:prog_argv
								   environment:[NSDictionary dictionary]];
		
}

- (void)startProgram:(NSString *)program
		   arguments:(NSArray *)prog_argv
		 environment:(NSDictionary *)prog_env
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@ arguments:%@]",
          __FILE__, __LINE__, program, prog_argv );
#endif
    [[self currentSession] startProgram:program
									 arguments:prog_argv
								   environment:prog_env];
	
    if ([[[self window] title] compare:@"Window"]==NSOrderedSame) 
		[self setWindowTitle];

}

- (void) setWidth: (int) width height: (int) height
{
    WIDTH = width;
    HEIGHT = height;
}

- (int)width;
{
    return WIDTH;
}

- (int)height;
{
    return HEIGHT;
}

- (void)setCharSizeUsingFont: (NSFont *)font
{
	int i;
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSSize sz;
    [dic setObject:font forKey:NSFontAttributeName];
    sz = [@"W" sizeWithAttributes:dic];
	
	charWidth = (sz.width * charHorizontalSpacingMultiplier);
	charHeight = ([font defaultLineHeightForFont] * charVerticalSpacingMultiplier);

	for(i=0;i<[TABVIEW numberOfTabViewItems]; i++) 
    {
        PTYSession* session = [[TABVIEW tabViewItemAtIndex:i] identifier];
		[[session TEXTVIEW] setCharWidth: charWidth];
		[[session TEXTVIEW] setLineHeight: charHeight];
    }
	
	
	[[self window] setResizeIncrements: NSMakeSize(charWidth, charHeight)];
	
}	
- (int)charWidth
{
	return charWidth;
}

- (int)charHeight
{
	return charHeight;
}

- (float) charSpacingHorizontal
{
	return (charHorizontalSpacingMultiplier);
}

- (float) charSpacingVertical
{
	return (charVerticalSpacingMultiplier);
}


- (void)setWindowSize
{    
    NSSize size, vsize, winSize, tabViewSize;
    NSWindow *thisWindow = [self window];
    NSRect aRect;
    NSPoint topLeft;
		
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowSize] (%d,%d)", __FILE__, __LINE__, WIDTH, HEIGHT );
#endif
    
    if([self windowInited] == NO)
		return;
	
    if (WIDTH<20) WIDTH=20;
    if (HEIGHT<2) HEIGHT=2;
    // desired size of textview
    vsize.width = charWidth * WIDTH + MARGIN * 2;
	vsize.height = charHeight * HEIGHT;
    
    // NSLog(@"width=%d,height=%d",[[[_sessionMgr currentSession] SCREEN] width],[[[_sessionMgr currentSession] SCREEN] height]);
    
	// desired size of scrollview
	size = [PTYScrollView frameSizeForContentSize:vsize
							hasHorizontalScroller:NO
							  hasVerticalScroller:YES
									   borderType:NSNoBorder];
#if 0
    NSLog(@"%s: scrollview content size %.1f, %.1f", __PRETTY_FUNCTION__,
		  size.width, size.height);
#endif
	
	
	// desired size of tabview
	tabViewSize = [PTYTabView frameSizeForContentSize:size 
										  tabViewType:[TABVIEW tabViewType] 
										  controlSize:[TABVIEW controlSize]];
#if 0
    NSLog(@"%s: tabview content size %.1f, %.1f", __PRETTY_FUNCTION__,
		  tabViewSize.width, tabViewSize.height);
#endif
	
	// desired size of window content
	winSize = tabViewSize;

    if([TABVIEW numberOfTabViewItems] == 1 && [[PreferencePanel sharedInstance] hideTab])
	{
		[tabBarControl setHidden: YES];
		aRect.origin.x = 0;
		aRect.origin.y = 0;
		aRect.size = tabViewSize;
		[TABVIEW setFrame: aRect];		
	}
	else
	{
		[tabBarControl setHidden: NO];
        [tabBarControl setTabLocation: [[PreferencePanel sharedInstance] tabViewType]];
        winSize.height += [tabBarControl frame].size.height;
		if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_TopTab) {
            aRect.origin.x = 0;
            aRect.origin.y = 0;
            aRect.size = tabViewSize;
            [TABVIEW setFrame: aRect];
            aRect.origin.y = aRect.size.height;
            aRect.size.height = [tabBarControl frame].size.height;
            [tabBarControl setFrame: aRect];
        }
        else {
            aRect.origin.x = 0;
            aRect.origin.y = 0;
            aRect.size.width = tabViewSize.width;
            aRect.size.height = [tabBarControl frame].size.height;
            [tabBarControl setFrame: aRect];
            aRect.origin.y = [tabBarControl frame].size.height;
            aRect.size.height = tabViewSize.height;
            //[TABVIEW setAutoresizesSubviews: NO];
            [TABVIEW setFrame: aRect];
            //[TABVIEW setAutoresizesSubviews: YES];
        }
 	}
	
    // set the style of tabs to match window style
	switch ([[PreferencePanel sharedInstance] windowStyle]) {
        case 0:
            [tabBarControl setStyleNamed:@"Metal"];
            break;
        case 1:
            [tabBarControl setStyleNamed:@"Aqua"];
            break;
        case 2:
            [tabBarControl setStyleNamed:@"Unified"];
            break;
        default:
            [tabBarControl setStyleNamed:@"Adium"];
            break;
    }
    
    [tabBarControl setDisableTabClose:[[PreferencePanel sharedInstance] useCompactLabel]];
    [tabBarControl setCellMinWidth: [[PreferencePanel sharedInstance] useCompactLabel]?
                                  [[PreferencePanel sharedInstance] minCompactTabWidth]:
                                  [[PreferencePanel sharedInstance] minTabWidth]];
    [tabBarControl setSizeCellsToFit: [[PreferencePanel sharedInstance] useUnevenTabs]];
    [tabBarControl setCellOptimumWidth:  [[PreferencePanel sharedInstance] optimumTabWidth]];
    
    int i;
    for (i=0;i<[TABVIEW numberOfTabViewItems];i++) 
    {
        PTYSession *aSession = [[TABVIEW tabViewItemAtIndex: i] identifier];
        [aSession setObjectCount:i+1];
        [[aSession SCREEN] resizeWidth:WIDTH height:HEIGHT];
        [[aSession SHELL] setWidth:WIDTH  height:HEIGHT];
    }
    
#if 0
    NSLog(@"%s: window content size %.1f, %.1f", __PRETTY_FUNCTION__,
		  winSize.width, winSize.height);
#endif
	
	
	    // preserve the top left corner of the frame
    aRect = [thisWindow frame];
    topLeft.x = aRect.origin.x;
    topLeft.y = aRect.origin.y + aRect.size.height;
	
	
	[[thisWindow contentView] setAutoresizesSubviews: NO];
    [thisWindow setContentSize:winSize];
	[[thisWindow contentView] setAutoresizesSubviews: YES]; 
	[thisWindow setFrameTopLeftPoint: topLeft];

	[[[self currentSession] TEXTVIEW] setForceUpdate: YES];
//    [[[self currentSession] TEXTVIEW] setNeedsDisplay: YES];
	[[[self currentSession] SCROLLVIEW] setNeedsDisplay: YES];
	[tabBarControl update];
}


- (void)setWindowTitle
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowTitle]",
          __FILE__, __LINE__);
#endif
    NSString *title = [[self currentSession] windowTitle] ? [[self currentSession] windowTitle] : [self currentSessionName];
	
	[self setWindowTitle: title];
}

- (void) setWindowTitle: (NSString *)title
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowTitle:%@]",
          __FILE__, __LINE__, title);
#endif
	NSString *temp = title ? title : @"Session";
	
	[[self window] setTitle: [self sendInputToAllSessions] ? [NSString stringWithFormat:@">>%@<<", temp] : temp];
}

// increases or dcreases font size
- (void) changeFontSize: (BOOL) increase
{
	
    float newFontSize;
    
	    
    float asciiFontSize = [[self font] pointSize];
    if(increase == YES)
		newFontSize = [self largerSizeForSize: asciiFontSize];
    else
		newFontSize = [self smallerSizeForSize: asciiFontSize];	
    NSFont *newAsciiFont = [NSFont fontWithName: [[self font] fontName] size: newFontSize];
    
    float nonAsciiFontSize = [[self nafont] pointSize];
    if(increase == YES)
		newFontSize = [self largerSizeForSize: nonAsciiFontSize];
    else
		newFontSize = [self smallerSizeForSize: nonAsciiFontSize];	    
    NSFont *newNonAsciiFont = [NSFont fontWithName: [[self nafont] fontName] size: newFontSize];
    
    if(newAsciiFont != nil && newNonAsciiFont != nil)
    {
		[self setFont: newAsciiFont nafont: newNonAsciiFont];		
		[self resizeWindow: [self width] height: [self height]];
    }
    
	
}

- (float) largerSizeForSize: (float) aSize 
    /*" Given a font size of aSize, return the next larger size.   Uses the 
    same list of font sizes as presented in the font panel. "*/ 
{
    
    if (aSize <= 8.0) return 9.0;
    if (aSize <= 9.0) return 10.0;
    if (aSize <= 10.0) return 11.0;
    if (aSize <= 11.0) return 12.0;
    if (aSize <= 12.0) return 13.0;
    if (aSize <= 13.0) return 14.0;
    if (aSize <= 14.0) return 18.0;
    if (aSize <= 18.0) return 24.0;
    if (aSize <= 24.0) return 36.0;
    if (aSize <= 36.0) return 48.0;
    if (aSize <= 48.0) return 64.0;
    if (aSize <= 64.0) return 72.0;
    if (aSize <= 72.0) return 96.0;
    if (aSize <= 96.0) return 144.0;
	
    // looks odd, but everything reasonable should have been covered above
    return 288.0; 
} 

- (float) smallerSizeForSize: (float) aSize 
    /*" Given a font size of aSize, return the next smaller size.   Uses 
    the same list of font sizes as presented in the font panel. "*/
{
    
    if (aSize >= 288.0) return 144.0;
    if (aSize >= 144.0) return 96.0;
    if (aSize >= 96.0) return 72.0;
    if (aSize >= 72.0) return 64.0;
    if (aSize >= 64.0) return 48.0;
    if (aSize >= 48.0) return 36.0;
    if (aSize >= 36.0) return 24.0;
    if (aSize >= 24.0) return 18.0;
    if (aSize >= 18.0) return 14.0;
    if (aSize >= 14.0) return 13.0;
    if (aSize >= 13.0) return 12.0;
    if (aSize >= 12.0) return 11.0;
    if (aSize >= 11.0) return 10.0;
    if (aSize >= 10.0) return 9.0;
    
    // looks odd, but everything reasonable should have been covered above
    return 8.0; 
} 

- (void) setCharacterSpacingHorizontal: (float) horizontal vertical: (float) vertical
{
	charHorizontalSpacingMultiplier = horizontal;
	charVerticalSpacingMultiplier = vertical;
	[self setCharSizeUsingFont: FONT];
}

- (BOOL) antiAlias
{
	return (antiAlias);
}

- (void) setAntiAlias: (BOOL) bAntiAlias
{
	PTYSession *aSession;
	int i, cnt = [TABVIEW numberOfTabViewItems];
	
	antiAlias = bAntiAlias;
	
	for(i=0; i<cnt; i++)
	{
		aSession = [[TABVIEW tabViewItemAtIndex: i] identifier];
		[[aSession TEXTVIEW] setAntiAlias: antiAlias];
	}
	
	[[[self currentSession] TEXTVIEW] setNeedsDisplay: YES];
	
}

- (void)setFont:(NSFont *)font nafont:(NSFont *)nafont
{
	int i;
	
    [FONT autorelease];
    [font retain];
    FONT=font;
    [NAFONT autorelease];
    [nafont retain];
    NAFONT=nafont;
	[self setCharSizeUsingFont: FONT];
    for(i=0;i<[TABVIEW numberOfTabViewItems]; i++) 
    {
        PTYSession* session = [[TABVIEW tabViewItemAtIndex: i] identifier];
        [[session TEXTVIEW]  setFont:FONT nafont:NAFONT];
    }
}

- (NSFont *) font
{
	return FONT;
}

- (NSFont *) nafont
{
	return NAFONT;
}

- (void)reset:(id)sender
{
	[[[self currentSession] TERMINAL] reset];
}

- (void)clearBuffer:(id)sender
{
    [[self currentSession] clearBuffer];
}

- (void)clearScrollbackBuffer:(id)sender
{
    [[self currentSession] clearScrollbackBuffer];
}

- (IBAction)logStart:(id)sender
{
    if (![[self currentSession] logging]) [[self currentSession] logStart];
    // send a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermSessionBecameKey" object: [self currentSession]];
}

- (IBAction)logStop:(id)sender
{
    if ([[self currentSession] logging]) [[self currentSession] logStop];
    // send a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermSessionBecameKey" object: [self currentSession]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL logging = [[self currentSession] logging];
    BOOL result = YES;
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal validateMenuItem:%@]",
          __FILE__, __LINE__, item );
#endif
	
    if ([item action] == @selector(logStart:)) {
        result = logging == YES ? NO:YES;
    }
    else if ([item action] == @selector(logStop:)) {
        result = logging == NO ? NO:YES;
    }
    return result;
}

- (void) sendInputToAllSessions: (NSData *) data
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal sendDataToAllSessions:]",
		  __FILE__, __LINE__);
#endif
	// could be called from a thread
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
    PTYSession *aSession;
    int i;
    
    int n = [TABVIEW numberOfTabViewItems];    
    for (i=0; i<n; i++)
    {
        aSession = [[TABVIEW tabViewItemAtIndex: i] identifier];
		PTYScroller *ptys=(PTYScroller *)[[aSession SCROLLVIEW] verticalScroller];
		
		[[aSession SHELL] writeTask:data];

		// Make sure we scroll down to the end
		[[aSession TEXTVIEW] scrollEnd];
		[ptys setUserScroll: NO];		
    }    
	[pool release];
}

- (BOOL) sendInputToAllSessions
{
    return (sendInputToAllSessions);
}

- (void) setSendInputToAllSessions: (BOOL) flag
{
#if DEBUG_METHOD_TRACE
	NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
	
    sendInputToAllSessions = flag;
	if(flag)
		sendInputToAllSessions = (NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Warning!",@"iTerm", [NSBundle bundleForClass: [self class]], @"Warning"),
									 NSLocalizedStringFromTableInBundle(@"Keyboard input will be sent to all sessions in this terminal.",@"iTerm", [NSBundle bundleForClass: [self class]], @"Keyboard Input"), 
									 NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"Profile"), 
                                     NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel"), nil) == 1);
	
}

- (IBAction) toggleInputToAllSessions: (id) sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal toggleInputToAllSessions:%@]",
		  __FILE__, __LINE__, sender);
#endif
	[self setSendInputToAllSessions: ![self sendInputToAllSessions]];
    
    // cause reloading of menus
    [[iTermController sharedInstance] setCurrentTerminal: self];
	[self setWindowTitle];
}

- (void) setFontSizeFollowWindowResize: (BOOL) flag
{
    fontSizeFollowWindowResize = flag;
}

- (IBAction) toggleFontSizeFollowWindowResize: (id) sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal toggleFontSizeFollowWindowResize:%@]",
		  __FILE__, __LINE__, sender);
#endif
    fontSizeFollowWindowResize = !fontSizeFollowWindowResize;
    
    // cause reloading of menus
    [[iTermController sharedInstance] setCurrentTerminal: self];
}

- (BOOL) fontSizeFollowWindowResize
{
    return (fontSizeFollowWindowResize);
}


// NSWindow delegate methods
- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidDeminiaturize:%@]",
		  __FILE__, __LINE__, aNotification);
#endif
}

- (BOOL)windowShouldClose:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowShouldClose:%@]",
		  __FILE__, __LINE__, aNotification);
#endif
	
    if([[PreferencePanel sharedInstance] promptOnClose])
		return [self showCloseWindow];
    else
		return (YES);
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    int i;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowWillClose:%@]",
		  __FILE__, __LINE__, aNotification);
#endif
	
	// tabBarControl is holding on to us, so we have to tell it to let go
	[tabBarControl setDelegate: nil];
	
    // Release our window postion
    for (i = 0; i < CACHED_WINDOW_POSITIONS; i++)
    {
		if(windowPositions[i] == (unsigned int) self)
		{
			windowPositions[i] = 0;
			break;
		}
    }
	EXIT = YES;
    [[iTermController sharedInstance] terminalWillClose: self];
	
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidBecomeKey:%@]",
		  __FILE__, __LINE__, aNotification);
#endif
	
    //[self selectSessionAtIndex: [self currentSessionIndex]];
    [[iTermController sharedInstance] setCurrentTerminal: self];
	
    // update the cursor
    [[[self currentSession] TEXTVIEW] setNeedsDisplay: YES];
}

- (void) windowDidResignKey: (NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResignKey:%@]",
		  __FILE__, __LINE__, aNotification);
#endif
	
    [self windowDidResignMain: aNotification];
	
    // update the cursor
    [[[self currentSession] TEXTVIEW] setNeedsDisplay: YES];
	
}

- (void)windowDidResignMain:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResignMain:%@]",
		  __FILE__, __LINE__, aNotification);
#endif
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowWillResize: proposedFrameSize width = %f; height = %f]",
		  __FILE__, __LINE__, proposedFrameSize.width, proposedFrameSize.height);
#endif
    if (sender!=[self window]) {
        NSLog(@"Aha!");
        return proposedFrameSize;
    }
    
    float nch = [sender frame].size.height - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.height;
    float wch = [sender frame].size.width - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.width;

	if (fontSizeFollowWindowResize) {
		//scale = defaultFrame.size.height / [sender frame].size.height;
		float scale = (proposedFrameSize.height - nch) / HEIGHT / charHeight;
		NSFont *font = [[NSFontManager sharedFontManager] convertFont:FONT toSize:(int)(([FONT pointSize] * scale))];
		font = [self _getMaxFont:font height:proposedFrameSize.height - nch lines:HEIGHT];
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
		NSSize sz;
		[dic setObject:font forKey:NSFontAttributeName];
		sz = [@"W" sizeWithAttributes:dic];
		
		proposedFrameSize.height = [font defaultLineHeightForFont] * charVerticalSpacingMultiplier * HEIGHT + nch;
        proposedFrameSize.width = sz.width * charHorizontalSpacingMultiplier * WIDTH + wch + MARGIN * 2;
	}
    else {
		int new_height = (proposedFrameSize.height - nch) / charHeight + 0.5;
        int new_width = (proposedFrameSize.width - wch - MARGIN*2) / charWidth + 0.5;
        if (new_height<2) new_height = 2;
        if (new_width<20) new_width = 20;
		proposedFrameSize.height = charHeight * new_height + nch;
		proposedFrameSize.width = charWidth * new_width + wch + MARGIN * 2;
		//NSLog(@"actual height: %f",proposedFrameSize.height);
    }
    
    return (proposedFrameSize);
}

- (void)windowDidResize:(NSNotification *)aNotification
{
    NSRect frame;
    int w, h;
	
	
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResize: width = %f, height = %f]",
		  __FILE__, __LINE__, [[self window] frame].size.width, [[self window] frame].size.height);
#endif
		
	int tabBarHeight = [tabBarControl isHidden] ? 0 : [tabBarControl frame].size.height;
    frame = [[[self currentSession] SCROLLVIEW] documentVisibleRect];
    if (frame.size.height + tabBarHeight > [[[self window] contentView] frame].size.height) {
        frame.size.height = [[[self window] contentView] frame].size.height - tabBarHeight;
    }
    
#if 0
    NSLog(@"scrollview content size %.1f, %.1f, %.1f, %.1f",
		  frame.origin.x, frame.origin.y,
		  frame.size.width, frame.size.height);
#endif
	if (fontSizeFollowWindowResize) {
		float scale = (frame.size.height) / HEIGHT / charHeight;
		NSFont *font = [[NSFontManager sharedFontManager] convertFont:FONT toSize:(int)(([FONT pointSize] * scale))];
		font = [self _getMaxFont:font height:frame.size.height lines:HEIGHT];
		
		float height = [font defaultLineHeightForFont] * charVerticalSpacingMultiplier;

		if (height != charHeight) {
			//NSLog(@"Old size: %f\t proposed New size:%f\tWindow Height: %f",[FONT pointSize], [font pointSize],frame.size.height);
			NSFont *nafont = [[NSFontManager sharedFontManager] convertFont:FONT toSize:(int)(([NAFONT pointSize] * scale))];
			nafont = [self _getMaxFont:nafont height:frame.size.height lines:HEIGHT];
			
			[self setFont:font nafont:nafont];
			NSString *aTitle = [NSString stringWithFormat:@"%@ (%.0f)", [[self currentSession] name], [font pointSize]];
			[self setWindowTitle: aTitle];    

		}
        
        WIDTH = (int)((frame.size.width - MARGIN * 2)/charWidth + 0.5);
		HEIGHT = (int)((frame.size.height)/charHeight + 0.5);
        [self setWindowSize];
    }
	else {	    
		w = (int)((frame.size.width - MARGIN * 2)/charWidth);
		h = (int)((frame.size.height)/charHeight);

        if (w<20) w=20;
        if (h<2) h=2;
        if (w!=WIDTH || h!=HEIGHT) {
            WIDTH = w;
            HEIGHT = h;
            // Display the new size in the window title.
            NSString *aTitle = [NSString stringWithFormat:@"%@ (%d,%d)", [[self currentSession] name], WIDTH, HEIGHT];
            [self setWindowTitle: aTitle];
            [self setWindowSize];
    	}
	}	
    
    
	// Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermWindowDidResize" object: self userInfo: nil];    
}

// PTYWindowDelegateProtocol
- (void) windowWillToggleToolbarVisibility: (id) sender
{
}

- (void) windowDidToggleToolbarVisibility: (id) sender
{
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowWillUseStandardFrame: defaultFramewidth = %f, height = %f]",
		  __FILE__, __LINE__, defaultFrame.size.width, defaultFrame.size.height);
#endif
	float scale;
	
    float nch = [sender frame].size.height - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.height;
	float wch = [sender frame].size.width - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.width;
    
    defaultFrame.origin.x = [sender frame].origin.x;
    
    if (fontSizeFollowWindowResize) {
		scale = (defaultFrame.size.height - nch) / HEIGHT / charHeight;
		NSFont *font = [[NSFontManager sharedFontManager] convertFont:FONT toSize:(int)(([FONT pointSize] * scale))];
		font = [self _getMaxFont:font height:defaultFrame.size.height - nch lines:HEIGHT];
		NSMutableDictionary *dic = [NSMutableDictionary dictionary];
		NSSize sz;
		[dic setObject:font forKey:NSFontAttributeName];
		sz = [@"W" sizeWithAttributes:dic];
		
		defaultFrame.size.height = [font defaultLineHeightForFont] * charVerticalSpacingMultiplier * HEIGHT + nch;
		defaultFrame.size.width = sz.width * charHorizontalSpacingMultiplier * WIDTH + wch;
		NSLog(@"actual height: %f\t (nch=%f) scale: %f\t new font:%f\told:%f",defaultFrame.size.height,nch,scale, [font pointSize], [FONT pointSize]);
	}
	else {
        int new_height = (defaultFrame.size.height -nch) / charHeight;
        int new_width =  (defaultFrame.size.width - wch - MARGIN * 2) /charWidth;
        
		defaultFrame.size.height = charHeight * new_height + nch;
		defaultFrame.size.width = ([[PreferencePanel sharedInstance] maxVertically] ? [sender frame].size.width : new_width*charWidth+wch+MARGIN*2);
		//NSLog(@"actual width: %f, height: %f",defaultFrame.size.width,defaultFrame.size.height);
	}
	
    
	return defaultFrame;
}
	
// Close Window
- (BOOL)showCloseWindow
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal showCloseWindow]", __FILE__, __LINE__);
#endif
	
    return (NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Close Window?",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close window"),
                            NSLocalizedStringFromTableInBundle(@"All sessions will be closed",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close window"),
							NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                            NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
							,nil)==1);
}

- (IBAction)showConfigWindow:(id)sender;
{
    if ([ITConfigPanelController onScreen])
        [ITConfigPanelController close];
    else
        [ITConfigPanelController show];
}

- (void) resizeWindow:(int) w height:(int)h
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal resizeWindow:%d,%d]",
          __FILE__, __LINE__, w, h);
#endif
    NSRect frm = [[self window] frame];
    float rh = frm.size.height - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.height;
    float rw = frm.size.width - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.width;
    
    HEIGHT=h?h:(([[[self window] screen] frame].size.height - rh)/charHeight + 0.5);
    WIDTH=w?w:(([[[self window] screen] frame].size.width - rw - MARGIN*2)/charWidth + 0.5); 

	// resize the TABVIEW and TEXTVIEW
    [self setWindowSize];
}

// Resize the window so that the text display area has pixel size of w*h
- (void) resizeWindowToPixelsWidth:(int)w height:(int)h
{
    NSRect frm = [[self window] frame];
    float rh = frm.size.height - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.height;
    float rw = frm.size.width - [[[self currentSession] SCROLLVIEW] documentVisibleRect].size.width;
	
    frm.origin.y += frm.size.height;
    if (!h) h= [[[self window] screen] frame].size.height - rh;
    
    int n = (h) / charHeight + 0.5;
    frm.size.height = n*charHeight + rh;
        
    if (!w) w= [[[self window] screen] frame].size.width - rw;
    n = (w - MARGIN*2) / charWidth + 0.5;
    frm.size.width = n*charWidth + rw + MARGIN*2;
    
    frm.origin.y -= frm.size.height; //keep the top left point the same
    
    [[self window] setFrame:frm display:NO];
    [self windowDidResize:nil];
}

// Contextual menu
- (BOOL) suppressContextualMenu
{
	return (suppressContextualMenu);
}

- (void) setSuppressContextualMenu: (BOOL) aBool
{
	suppressContextualMenu = aBool;
}

- (void) menuForEvent:(NSEvent *)theEvent menu: (NSMenu *) theMenu
{
    unsigned int modflag = 0;
    int nextIndex;
	NSMenuItem *aMenuItem;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal menuForEvent]", __FILE__, __LINE__);
#endif
	
    if(theMenu == nil || suppressContextualMenu)
		return;
	
    modflag = [theEvent modifierFlags];
	
    // Bookmarks
    [theMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" atIndex: 0];
    nextIndex = 1;
	
    // Create a menu with a submenu to navigate between tabs if there are more than one
    if([TABVIEW numberOfTabViewItems] > 1)
    {	
		[theMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"Select",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" atIndex: nextIndex];
		
		NSMenu *tabMenu = [[NSMenu alloc] initWithTitle:@""];
		int i;
		
		for (i = 0; i < [TABVIEW numberOfTabViewItems]; i++)
		{
			aMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ #%d", [[TABVIEW tabViewItemAtIndex: i] label], i+1]
												   action:@selector(selectTab:) keyEquivalent:@""];
			[aMenuItem setRepresentedObject: [[TABVIEW tabViewItemAtIndex: i] identifier]];
			[aMenuItem setTarget: TABVIEW];
			[tabMenu addItem: aMenuItem];
			[aMenuItem release];
		}
		[theMenu setSubmenu: tabMenu forItem: [theMenu itemAtIndex: nextIndex]];
		[tabMenu release];
		nextIndex++;
    }
	
	// Bookmarks
	[theMenu insertItemWithTitle: 
		NSLocalizedStringFromTableInBundle(@"Bookmarks",@"iTerm", [NSBundle bundleForClass: [self class]], @"Bookmarks") 
						  action:@selector(toggleBookmarksView:) keyEquivalent:@"" atIndex: nextIndex++];
    
    // Separator
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex: nextIndex];
	
    // Build the bookmarks menu
	NSMenu *aMenu = [[[NSMenu alloc] init] autorelease];
    [[iTermController sharedInstance] alternativeMenu: aMenu 
                                              forNode: [[ITAddressBookMgr sharedInstance] rootNode] 
                                               target: self
                                        withShortcuts: NO];
    [aMenu addItem: [NSMenuItem separatorItem]];
    NSMenuItem *tip = [[[NSMenuItem alloc] initWithTitle: NSLocalizedStringFromTableInBundle(@"Press Option for New Window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New") action:@selector(xyz) keyEquivalent: @""] autorelease];
    [tip setKeyEquivalentModifierMask: NSCommandKeyMask];
    [aMenu addItem: tip];
    tip = [[tip copy] autorelease];
    [tip setTitle:NSLocalizedStringFromTableInBundle(@"Open In New Window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New")];
    [tip setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
    [tip setAlternate:YES];
    [aMenu addItem: tip];
	
    [theMenu setSubmenu: aMenu forItem: [theMenu itemAtIndex: 0]];
	
    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];
	
    // Info
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Info...",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:@selector(showConfigWindow:) keyEquivalent:@""];
    [aMenuItem setTarget: self];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Close current session
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:@selector(closeCurrentSession:) keyEquivalent:@""];
    [aMenuItem setTarget: self];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];
	
}

// NSTabView
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willSelectTabViewItem]", __FILE__, __LINE__);
#endif
    if (![[self currentSession] exited]) [[self currentSession] resetStatus];
    
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: didSelectTabViewItem]", __FILE__, __LINE__);
#endif
    
	[[tabViewItem identifier] resetStatus];
	[[tabViewItem identifier] setLabelAttribute];
	[[[tabViewItem identifier] SCREEN] setDirty];
	[[[tabViewItem identifier] TEXTVIEW] setNeedsDisplay: YES];
	[self setWindowTitle];

    [[TABVIEW window] makeFirstResponder:[[tabViewItem identifier] TEXTVIEW]];

	// Post notifications
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermSessionBecameKey" object: [tabViewItem identifier]];    
}

- (void)tabView:(NSTabView *)tabView willRemoveTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willRemoveTabViewItem]", __FILE__, __LINE__);
#endif
}

- (void)tabView:(NSTabView *)tabView willAddTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willAddTabViewItem]", __FILE__, __LINE__);
#endif
	
    [self tabView: tabView willInsertTabViewItem: tabViewItem atIndex: [tabView numberOfTabViewItems]];
}

- (void)tabView:(NSTabView *)tabView willInsertTabViewItem:(NSTabViewItem *)tabViewItem atIndex: (int) index
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willInsertTabViewItem: atIndex: %d]", __FILE__, __LINE__, index);
#endif
    [[tabViewItem identifier] setParent: self];
}

- (BOOL)tabView:(NSTabView*)tabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
    PTYSession *aSession = [tabViewItem identifier];
    
    return [aSession exited] ||		
        ![[PreferencePanel sharedInstance] promptOnClose] ||
        NSRunAlertPanel([NSString stringWithFormat:@"%@ #%d", [aSession name], [aSession realObjectCount]],
                        NSLocalizedStringFromTableInBundle(@"This session will be closed.",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close Session"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
                        ,nil);
    
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl
{
    return YES;
}

- (BOOL)tabView:(NSTabView*)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
    //NSLog(@"shouldDropTabViewItem: %@ inTabBar: %@", [tabViewItem label], tabBarControl);
    return YES;
}

- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)aTabBarControl
{
	//NSLog(@"didDropTabViewItem: %@ inTabBar: %@", [tabViewItem label], aTabBarControl);
    int i;
	PTYSession *aSession = [tabViewItem identifier];
    
    [[aSession SCREEN] resizeWidth:WIDTH height:HEIGHT];
    [[aSession SHELL] setWidth:WIDTH  height:HEIGHT];
    [[aSession TEXTVIEW] setFont:FONT nafont:NAFONT];
    [[aSession TEXTVIEW] setCharWidth: charWidth];
    [[aSession TEXTVIEW] setLineHeight: charHeight];
    [[aSession TEXTVIEW] setLineWidth: WIDTH * charWidth];
    
    for (i=0;i<[TABVIEW numberOfTabViewItems];i++) 
    {
        aSession = [[TABVIEW tabViewItemAtIndex: i] identifier];
        [aSession setObjectCount:i+1];
    }        
}

- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem
{
	//NSLog(@"closeWindowForLastTabViewItem: %@", [tabViewItem label]);
	[[self window] close];
}

- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(unsigned int *)styleMask
{
    NSImage *viewImage;
    
    if (tabViewItem == [aTabView selectedTabViewItem]) { 
        NSView *textview = [tabViewItem view];
        NSRect tabFrame = [tabBarControl frame];
        int tabHeight = tabFrame.size.height;

        NSRect contentFrame, viewRect;
        contentFrame = viewRect = [textview frame];
        contentFrame.size.height += tabHeight;

        // grabs whole tabview image
        viewImage = [[[NSImage alloc] initWithSize:contentFrame.size] autorelease];
        NSImage *tabViewImage = [[[NSImage alloc] init] autorelease];

        [textview lockFocus];
        NSBitmapImageRep *tabviewRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:viewRect] autorelease];
        [tabViewImage addRepresentation:tabviewRep];
        [textview unlockFocus];

        [viewImage lockFocus];
        //viewRect.origin.x += 10;
        if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_BottomTab) {
            viewRect.origin.y += tabHeight;
        }
        [tabViewImage compositeToPoint:viewRect.origin operation:NSCompositeSourceOver];
        [viewImage unlockFocus];

        //draw over where the tab bar would usually be
        [viewImage lockFocus];
        [[NSColor windowBackgroundColor] set];
        if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_TopTab) {
            tabFrame.origin.y += viewRect.size.height;
        }
        NSRectFill(tabFrame);
        //draw the background flipped, which is actually the right way up
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform scaleXBy:1.0 yBy:-1.0];
        [transform concat];
        tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
        [(id <PSMTabStyle>)[[aTabView delegate] style] drawBackgroundInRect:tabFrame];
        [transform invert];
        [transform concat];

        [viewImage unlockFocus];

        offset->width = [(id <PSMTabStyle>)[tabBarControl style] leftMarginForTabBarControl];
        if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_TopTab) {
            offset->height = 22;
        }
        else {
            offset->height = viewRect.size.height + 22;
        }
        *styleMask = NSBorderlessWindowMask;
	}
    else {
        NSView *textview = [tabViewItem view];
        NSRect tabFrame = [tabBarControl frame];
        int tabHeight = tabFrame.size.height;
        
        NSRect contentFrame, viewRect;
        contentFrame = viewRect = [textview frame];
        contentFrame.size.height += tabHeight;
        
        // grabs whole tabview image
        viewImage = [[[NSImage alloc] initWithSize:contentFrame.size] autorelease];
        NSImage *textviewImage = [[[NSImage alloc] initWithSize:viewRect.size] autorelease];
        
        [textviewImage setFlipped: YES];
        [textviewImage lockFocus];
        //draw the background flipped, which is actually the right way up
        [[[tabViewItem identifier] TEXTVIEW] setForceUpdate: YES];
        [[[tabViewItem identifier] TEXTVIEW] drawRect: viewRect];
        [textviewImage unlockFocus];
        
        [viewImage lockFocus];
        //viewRect.origin.x += 10;
        if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_BottomTab) {
            viewRect.origin.y += tabHeight;
        }
        [textviewImage compositeToPoint:viewRect.origin operation:NSCompositeSourceOver];
        [viewImage unlockFocus];
        
        //draw over where the tab bar would usually be
        [viewImage lockFocus];
        [[NSColor windowBackgroundColor] set];
        if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_TopTab) {
            tabFrame.origin.y += viewRect.size.height;
        }
        NSRectFill(tabFrame);
        //draw the background flipped, which is actually the right way up
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform scaleXBy:1.0 yBy:-1.0];
        [transform concat];
        tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
        [(id <PSMTabStyle>)[[aTabView delegate] style] drawBackgroundInRect:tabFrame];
        [transform invert];
        [transform concat];
        
        [viewImage unlockFocus];
        
        offset->width = [(id <PSMTabStyle>)[tabBarControl style] leftMarginForTabBarControl];
        if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_TopTab) {
            offset->height = 22;
        }
        else {
            offset->height = viewRect.size.height + 22;
        }
        *styleMask = NSBorderlessWindowMask;
    }
        
	return viewImage;
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabViewDidChangeNumberOfTabViewItems]", __FILE__, __LINE__);
#endif
	
	// check window size in case tabs have to be hidden or shown
    if ([[PreferencePanel sharedInstance] hideTab] && 
		(([TABVIEW numberOfTabViewItems] > 1 && [tabBarControl isHidden]) || ([TABVIEW numberOfTabViewItems] < 2 && ![tabBarControl isHidden])))
    {
        [self setWindowSize];
		/*
        PTYSession *aSession = [[TABVIEW tabViewItemAtIndex: 0] identifier];
        [[aSession TEXTVIEW] scrollEnd];
        // make sure the display is up-to-date.
        [[aSession TEXTVIEW] setForceUpdate: YES]; */
        
    }
    
    int i;
    for (i=0;i<[TABVIEW numberOfTabViewItems];i++) 
    {
        PTYSession *aSession = [[TABVIEW tabViewItemAtIndex: i] identifier];
        [aSession setObjectCount:i+1];
    }        
			
	[[NSNotificationCenter defaultCenter] postNotificationName: @"iTermNumberOfSessionsDidChange" object: self userInfo: nil];		
	//[tabBarControl update];
}

- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSMenuItem *aMenuItem;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabViewContextualMenu]", __FILE__, __LINE__);
#endif    
	
    NSMenu *theMenu = [[[NSMenu alloc] init] autorelease];
	
    // Create a menu with a submenu to navigate between tabs if there are more than one
    if([TABVIEW numberOfTabViewItems] > 1)
    {	
        int nextIndex = 0;
        int i;
		
		[theMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"Select",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" atIndex: nextIndex];
		NSMenu *tabMenu = [[NSMenu alloc] initWithTitle:@""];
		
		for (i = 0; i < [TABVIEW numberOfTabViewItems]; i++)
		{
			aMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ #%d", [[TABVIEW tabViewItemAtIndex: i] label], i+1]
												   action:@selector(selectTab:) keyEquivalent:@""];
			[aMenuItem setRepresentedObject: [[TABVIEW tabViewItemAtIndex: i] identifier]];
			[aMenuItem setTarget: TABVIEW];
			[tabMenu addItem: aMenuItem];
			[aMenuItem release];
		}
		[theMenu setSubmenu: tabMenu forItem: [theMenu itemAtIndex: nextIndex]];
		[tabMenu release];
		nextIndex++;
        [theMenu addItem: [NSMenuItem separatorItem]];
   }
    
 	
    // add tasks
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Close Tab",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context Menu") action:@selector(closeTabContextualMenuAction:) keyEquivalent:@""];
    [aMenuItem setRepresentedObject: tabViewItem];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];
    if([TABVIEW numberOfTabViewItems] > 1)
    {
		aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Move to new window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context Menu") action:@selector(moveTabToNewWindowContextualMenuAction:) keyEquivalent:@""];
		[aMenuItem setRepresentedObject: tabViewItem];
		[theMenu addItem: aMenuItem];
		[aMenuItem release];
    }
    
    return theMenu;
}

- (PSMTabBarControl *)tabView:(NSTabView *)aTabView newTabBarForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point
{
    PseudoTerminal *term;
    PTYSession *aSession = [tabViewItem identifier];
	
    if(aSession == nil)
		return nil;
	
    // create a new terminal window
    term = [[PseudoTerminal alloc] init];
    if(term == nil)
		return nil;
	
	if([term windowInited] == NO)
    {
		[term setWidth: WIDTH height: HEIGHT];
		[term setFont: FONT nafont: NAFONT];
		[term initWindowWithAddressbook:NULL];
    }	
	
    [[iTermController sharedInstance] addInTerminals: term];
	[term release];
	
	
    // If this is the current session, make previous one active.
//    if(aSession == [self currentSession])
//		[self selectSessionAtIndex: ([_sessionMgr currentSessionIndex] - 1)];
	
    if ([[PreferencePanel sharedInstance] tabViewType] == PSMTab_TopTab) {
        [[term window] setFrameTopLeftPoint:point];
    }
    else {
        [[term window] setFrameOrigin:point];
    }
    
    return [term tabBarControl];
}

- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)aTabViewItem
{
	NSDictionary *ade = [[aTabViewItem identifier] addressBookEntry];
	
	NSString *temp = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Name: %@\nCommand: %@\nTerminal Profile: %@\nDisplay Profile: %@\nKeyboard Profile: %@",@"iTerm", [NSBundle bundleForClass: [self class]], @"Tab Tooltips"),
		[ade objectForKey:KEY_NAME], [ade objectForKey:KEY_COMMAND], [ade objectForKey:KEY_TERMINAL_PROFILE],
		[ade objectForKey:KEY_DISPLAY_PROFILE], [ade objectForKey:KEY_KEYBOARD_PROFILE]];
	
	return temp;
	
}

- (void)tabView:(NSTabView *)tabView doubleClickTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabView selectTabViewItem:tabViewItem];
	[ITConfigPanelController show];
}

- (void) setLabelColor: (NSColor *) color forTabViewItem: tabViewItem
{
    [tabBarControl setLabelColor: color forTabViewItem:tabViewItem];
}

- (PSMTabBarControl*) tabBarControl
{
    return tabBarControl;
}

- (PTYTabView *) tabView
{
    return TABVIEW;
}



// closes a tab
- (void) closeTabContextualMenuAction: (id) sender
{
    [self closeCurrentSession: [[sender representedObject] identifier]];
}

- (void) closeTabWithIdentifier: (id) identifier
{
    [self closeSession: identifier];
}

// moves a tab with its session to a new window
- (void) moveTabToNewWindowContextualMenuAction: (id) sender
{
    PseudoTerminal *term;
    NSTabViewItem *aTabViewItem = [sender representedObject];
    PTYSession *aSession = [aTabViewItem identifier];
	
    if(aSession == nil)
		return;
	
    // create a new terminal window
    term = [[PseudoTerminal alloc] init];
    if(term == nil)
		return;
	
	if([term windowInited] == NO)
    {
		[term setWidth: WIDTH height: HEIGHT];
		[term setFont: FONT nafont: NAFONT];
		[term initWindowWithAddressbook:NULL];
    }	
	
    [[iTermController sharedInstance] addInTerminals: term];
	[term release];
	
	
    // If this is the current session, make previous one active.
   // if(aSession == [_sessionMgr currentSession])
	//	[self selectSessionAtIndex: ([_sessionMgr currentSessionIndex] - 1)];
	
    // temporarily retain the tabViewItem
    [aTabViewItem retain];
	
    // remove from our window
    [TABVIEW removeTabViewItem: aTabViewItem];
	
    // add the session to the new terminal
    [term insertSession: aSession atIndex: 0];
	
    // release the tabViewItem
    [aTabViewItem release];
}

- (IBAction)closeWindow:(id)sender
{
    [[self window] performClose:sender];
}

- (void) updateCurretSessionProfiles
{
	iTermDisplayProfileMgr *displayProfileMgr;
	NSDictionary *aDict;
	NSString *displayProfile;
	PTYSession *current;
	
	current = [self currentSession];
	displayProfileMgr = [iTermDisplayProfileMgr singleInstance];
	aDict = [current addressBookEntry];
	displayProfile = [aDict objectForKey: KEY_DISPLAY_PROFILE];
	if(displayProfile == nil)
		displayProfile = [displayProfileMgr defaultProfileName];	
	
	[displayProfileMgr setTransparency: [current transparency] forProfile: displayProfile];
	[displayProfileMgr setDisableBold: [current disableBold] forProfile: displayProfile];
	[displayProfileMgr setBackgroundImage: [current backgroundImagePath] forProfile: displayProfile];
	[displayProfileMgr setWindowColumns: [self columns] forProfile: displayProfile];
	[displayProfileMgr setWindowRows: [self rows] forProfile: displayProfile];
	[displayProfileMgr setWindowFont: [self font] forProfile: displayProfile];
	[displayProfileMgr setWindowNAFont: [self nafont] forProfile: displayProfile];
	[displayProfileMgr setWindowHorizontalCharSpacing: charHorizontalSpacingMultiplier forProfile: displayProfile];
	[displayProfileMgr setWindowVerticalCharSpacing: charVerticalSpacingMultiplier forProfile: displayProfile];
	[displayProfileMgr setWindowAntiAlias: [[current TEXTVIEW] antiAlias] forProfile: displayProfile];
	[displayProfileMgr setColor: [current foregroundColor] forType: TYPE_FOREGROUND_COLOR forProfile: displayProfile];
	[displayProfileMgr setColor: [current backgroundColor] forType: TYPE_BACKGROUND_COLOR forProfile: displayProfile];
	[displayProfileMgr setColor: [current boldColor] forType: TYPE_BOLD_COLOR forProfile: displayProfile];
	[displayProfileMgr setColor: [current selectionColor] forType: TYPE_SELECTION_COLOR forProfile: displayProfile];
	[displayProfileMgr setColor: [current selectedTextColor] forType: TYPE_SELECTED_TEXT_COLOR forProfile: displayProfile];
	[displayProfileMgr setColor: [current cursorColor] forType: TYPE_CURSOR_COLOR forProfile: displayProfile];
	[displayProfileMgr setColor: [current cursorTextColor] forType: TYPE_CURSOR_TEXT_COLOR forProfile: displayProfile];

    iTermTerminalProfileMgr *terminalProfileMgr;
	NSString *terminalProfile;
	
    terminalProfileMgr = [iTermTerminalProfileMgr singleInstance];
	aDict = [current addressBookEntry];
	terminalProfile = [aDict objectForKey: KEY_TERMINAL_PROFILE];
	if(terminalProfile == nil)
		terminalProfile = [terminalProfileMgr defaultProfileName];	
    
	[terminalProfileMgr setEncoding: [current encoding] forProfile: terminalProfile];
	[terminalProfileMgr setSendIdleChar: [current antiIdle] forProfile: terminalProfile];
	[terminalProfileMgr setIdleChar: [current antiCode] forProfile: terminalProfile];
    
    id prefs = [NSUserDefaults standardUserDefaults];
    
    [prefs setObject: [[iTermDisplayProfileMgr singleInstance] profiles] forKey: @"Displays"];
	[prefs setObject: [[iTermTerminalProfileMgr singleInstance] profiles] forKey: @"Terminals"];
	[prefs synchronize];
    
	NSRunInformationalAlertPanel(
        [NSString stringWithFormat: NSLocalizedStringFromTableInBundle(@"%@'s display profile %@ and terminal profile %@ have been updated",@"iTerm", [NSBundle bundleForClass: [self class]], @"Profile"), 
            [[current addressBookEntry] objectForKey: @"Name"], displayProfile, terminalProfile],
         NSLocalizedStringFromTableInBundle(@"All bookmarks associated with these profiles are affected",@"iTerm", [NSBundle bundleForClass: [self class]], @"Profile"), 
         NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"Profile"), nil, nil);
}

// NSOutlineView delegate methods
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn 
			   item:(id)item
{
	return (NO);
}

// NSOutlineView doubleclick action
- (IBAction) doubleClickedOnBookmarksView: (id) sender
{
	int selectedRow = [bookmarksView selectedRow];
	TreeNode *selectedItem;
	
	if(selectedRow < 0)
		return;
	
	selectedItem = [bookmarksView itemAtRow: selectedRow];
	if(selectedItem != nil && [selectedItem isLeaf])
	{
		[[iTermController sharedInstance] launchBookmark: [selectedItem nodeData] inTerminal: self];
	}
	
}

// Bookmarks
- (IBAction) toggleBookmarksView: (id) sender
{
	[[(PTYWindow *)[self window] drawer] toggle: sender];	
	// Post a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermWindowBecameKey" object: self userInfo: nil];    
}

- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize
{
	// save the width to preferences
	[[NSUserDefaults standardUserDefaults] setFloat: contentSize.width forKey: @"BookmarksDrawerWidth"];
	
	return (contentSize);
}

- (IBAction) parameterPanelEnd: (id) sender
{
    [NSApp stopModal];
}

@end

@implementation PseudoTerminal (Private)

- (void) _commonInit
{
	charHorizontalSpacingMultiplier = charVerticalSpacingMultiplier = 1.0;
		
}

- (NSFont *) _getMaxFont:(NSFont* ) font 
				  height:(float) height
				   lines:(float) lines
{
	float newSize = [font pointSize], newHeight;
	NSFont *newfont=nil;
	
	do {
		newfont = font;
		font = [[NSFontManager sharedFontManager] convertFont:font toSize:newSize];
		newSize++;
		newHeight = [font defaultLineHeightForFont] * charVerticalSpacingMultiplier * lines;
	} while (height >= newHeight);
	
	return newfont;
}

- (void) _reloadAddressBook: (NSNotification *) aNotification
{
	[bookmarksView reloadData];
}

- (void) _refreshTerminal: (NSNotification *) aNotification
{
	[self setWindowSize];
}

- (NSString *) _getSessionParameters: (NSString *) command
{
	NSMutableString *completeCommand = [[NSMutableString alloc] initWithString:command];
	NSRange r1, r2, currentRange;
	
	
	while (1)
	{
		currentRange = NSMakeRange(0,[completeCommand length]);
		r1 = [completeCommand rangeOfString:@"$$" options:NSLiteralSearch range:currentRange];
		if (r1.location == NSNotFound) break;
		currentRange.location = r1.location + 2;
		currentRange.length -= r1.location + 2;
		r2 = [completeCommand rangeOfString:@"$$" options:NSLiteralSearch range:currentRange];
		if (r2.location == NSNotFound) break;
		
		[parameterName setStringValue: [completeCommand substringWithRange:NSMakeRange(r1.location+2, r2.location - r1.location-2)]];
		[parameterValue setStringValue:@""];
		[NSApp beginSheet: parameterPanel
		   modalForWindow: [self window]
			modalDelegate: self
		   didEndSelector: nil
			  contextInfo: nil];

		[NSApp runModalForWindow:parameterPanel];
		
		[NSApp endSheet:parameterPanel];
		[parameterPanel orderOut:self];

		[completeCommand replaceOccurrencesOfString:[completeCommand  substringWithRange:NSMakeRange(r1.location, r2.location - r1.location+2)] withString:[parameterValue stringValue] options:NSLiteralSearch range:NSMakeRange(0,[completeCommand length])];
	}
	
	return completeCommand;
}

@end


@implementation PseudoTerminal (KeyValueCoding)

// accessors for attributes:
-(int)columns
{
    // NSLog(@"PseudoTerminal: -columns");
    return (WIDTH);
}

-(void)setColumns: (int)columns
{
    // NSLog(@"PseudoTerminal: setColumns: %d", columns);
    if(columns > 0)
    {
        WIDTH = columns;
		if([TABVIEW numberOfTabViewItems] > 0) {
            [self setWindowSize];
        }
    }
}

-(int)rows
{
    // NSLog(@"PseudoTerminal: -rows");
    return (HEIGHT);
}

-(void)setRows: (int)rows
{
    // NSLog(@"PseudoTerminal: setRows: %d", rows);
    if(rows > 0)
    {
        HEIGHT = rows;
        if([TABVIEW numberOfTabViewItems] > 0) {
            [self setWindowSize];
        }
    }
}


// accessors for to-many relationships:
// (See NSScriptKeyValueCoding.h)
-(id)valueInSessionsAtIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -valueInSessionsAtIndex: %d", index);
    return ([[TABVIEW tabViewItemAtIndex:index] identifier]);
}

-(NSArray*)sessions
{
    int n = [TABVIEW numberOfTabViewItems];
    NSMutableArray *sessions = [NSMutableArray arrayWithCapacity: n];
    int i;
    
    for (i= 0; i < n; i++)
    {
        [sessions addObject: [[TABVIEW tabViewItemAtIndex:i] identifier]];
    } 

    return sessions;
}

-(void)setSessions: (NSArray*)sessions {}

-(id)valueWithName: (NSString *)uniqueName inPropertyWithKey: (NSString*)propertyKey
{
    id result = nil;
    int i;
	
    if([propertyKey isEqualToString: sessionsKey] == YES)
    {
		PTYSession *aSession;
		
		for (i= 0; i < [TABVIEW numberOfTabViewItems]; i++)
		{
			aSession = [[TABVIEW tabViewItemAtIndex:i] identifier];
			if([[aSession name] isEqualToString: uniqueName] == YES)
				return (aSession);
		}
    }
	
    return result;
}

// The 'uniqueID' argument might be an NSString or an NSNumber.
-(id)valueWithID: (NSString *)uniqueID inPropertyWithKey: (NSString*)propertyKey
{
    id result = nil;
    int i;
	
    if([propertyKey isEqualToString: sessionsKey] == YES)
    {
		PTYSession *aSession;
		
		for (i= 0; i < [TABVIEW numberOfTabViewItems]; i++)
		{
			aSession = [[TABVIEW tabViewItemAtIndex:i] identifier];
			if([[aSession tty] isEqualToString: uniqueID] == YES)
				return (aSession);
		}
    }
    
    return result;
}

-(void)addNewSession:(NSDictionary *) addressbookEntry
{
    // NSLog(@"PseudoTerminal: -addInSessions: 0x%x", object);
    PTYSession *aSession;
    NSString *terminalProfile;
    
    terminalProfile = [addressbookEntry objectForKey: KEY_TERMINAL_PROFILE];
	if(terminalProfile == nil)
		terminalProfile = [[iTermTerminalProfileMgr singleInstance] defaultProfileName];	
	
    // Initialize a new session
    aSession = [[PTYSession alloc] init];
	[[aSession SCREEN] setScrollback:[[iTermTerminalProfileMgr singleInstance] scrollbackLinesForProfile: [addressbookEntry objectForKey: KEY_TERMINAL_PROFILE]]];
    // set our preferences
    [aSession setAddressBookEntry: addressbookEntry];
    // Add this session to our term and make it current
    [self appendSession: aSession];
    
    
    NSString *cmd;
    NSArray *arg;
    NSString *pwd;
	
    // Grab the addressbook command
	cmd = [self _getSessionParameters: [addressbookEntry objectForKey: KEY_COMMAND]];
	
    [PseudoTerminal breakDown:cmd cmdPath:&cmd cmdArgs:&arg];
    
	pwd = [addressbookEntry objectForKey: KEY_WORKING_DIRECTORY];
	if([pwd length] <= 0)
		pwd = NSHomeDirectory();
    NSDictionary *env=[NSDictionary dictionaryWithObject: pwd forKey:@"PWD"];
    
    [self setCurrentSessionName:[addressbookEntry objectForKey: KEY_NAME]];	
    
    // Start the command        
    [self startProgram:cmd arguments:arg environment:env];
	
    [aSession release];
}

-(void)addNewSession:(NSDictionary *) addressbookEntry withURL: (NSString *)url
{
    // NSLog(@"PseudoTerminal: -addInSessions: 0x%x", object);
    PTYSession *aSession;
    NSString *terminalProfile;
    
    terminalProfile = [addressbookEntry objectForKey: KEY_TERMINAL_PROFILE];
	if(terminalProfile == nil)
		terminalProfile = [[iTermTerminalProfileMgr singleInstance] defaultProfileName];	
	
    // Initialize a new session
    aSession = [[PTYSession alloc] init];
	[[aSession SCREEN] setScrollback:[[iTermTerminalProfileMgr singleInstance] scrollbackLinesForProfile: [addressbookEntry objectForKey: KEY_TERMINAL_PROFILE]]];
    // set our preferences
    [aSession setAddressBookEntry: addressbookEntry];
    // Add this session to our term and make it current
    [self appendSession: aSession];
    
    // We process the cmd to insert URL parts
    NSMutableString *cmd = [[[NSMutableString alloc] initWithString:[addressbookEntry objectForKey: KEY_COMMAND]] autorelease];
	NSURL *urlRep = [NSURL URLWithString: url];
	
    
    // Grab the addressbook command
	[cmd replaceOccurrencesOfString:@"$$URL$$" withString:url options:NSLiteralSearch range:NSMakeRange(0, [cmd length])];
	[cmd replaceOccurrencesOfString:@"$$HOST$$" withString:[urlRep host]?[urlRep host]:@"" options:NSLiteralSearch range:NSMakeRange(0, [cmd length])];
	[cmd replaceOccurrencesOfString:@"$$USER$$" withString:[urlRep user]?[urlRep user]:@"" options:NSLiteralSearch range:NSMakeRange(0, [cmd length])];
	[cmd replaceOccurrencesOfString:@"$$PASSWORD$$" withString:[urlRep password]?[urlRep password]:@"" options:NSLiteralSearch range:NSMakeRange(0, [cmd length])];
	[cmd replaceOccurrencesOfString:@"$$PORT$$" withString:[urlRep port]?[[urlRep port] stringValue]:@"" options:NSLiteralSearch range:NSMakeRange(0, [cmd length])];
	[cmd replaceOccurrencesOfString:@"$$PATH$$" withString:[urlRep path]?[urlRep path]:@"" options:NSLiteralSearch range:NSMakeRange(0, [cmd length])];

	NSArray *arg;
	NSString *pwd;
	[PseudoTerminal breakDown:cmd cmdPath:&cmd cmdArgs:&arg];
    
	pwd = [addressbookEntry objectForKey: KEY_WORKING_DIRECTORY];
	if([pwd length] <= 0)
		pwd = NSHomeDirectory();
    NSDictionary *env=[NSDictionary dictionaryWithObject: pwd forKey:@"PWD"];
    
    [self setCurrentSessionName:[addressbookEntry objectForKey: KEY_NAME]];	
    
    // Start the command        
    [self startProgram:[self _getSessionParameters: cmd] arguments:arg environment:env];
	
    [aSession release];
}

-(void)appendSession:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -appendSession: 0x%x", object);
    [self setupSession: object title: nil];
    [self insertSession: object atIndex:[TABVIEW numberOfTabViewItems]];
}

-(void)replaceInSessions:(PTYSession *)object atIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -replaceInSessions: 0x%x atIndex: %d", object, index);
    NSLog(@"Replace Sessions: not implemented.");
}

-(void)addInSessions:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -addInSessions: 0x%x", object);
    [self insertInSessions: object];
}

-(void)insertInSessions:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -insertInSessions: 0x%x", object);
    [self insertInSessions: object atIndex:[TABVIEW numberOfTabViewItems]];
}

-(void)insertInSessions:(PTYSession *)object atIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -insertInSessions: 0x%x atIndex: %d", object, index);
    [self setupSession: object title: nil];
    [self insertSession: object atIndex: index];
}

-(void)removeFromSessionsAtIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -removeFromSessionsAtIndex: %d", index);
    if(index < [TABVIEW numberOfTabViewItems])
    {
		PTYSession *aSession = [[TABVIEW tabViewItemAtIndex:index] identifier];
		[self closeSession: aSession];
    }
}

- (BOOL)windowInited
{
    return (windowInited);
}

- (void) setWindowInited: (BOOL) flag
{
    windowInited = flag;
}


// a class method to provide the keys for KVC:
+(NSArray*)kvcKeys
{
    static NSArray *_kvcKeys = nil;
    if( nil == _kvcKeys ){
		_kvcKeys = [[NSArray alloc] initWithObjects:
			columnsKey, rowsKey, sessionsKey,  nil ];
    }
    return _kvcKeys;
}

@end

@implementation PseudoTerminal (ScriptingSupport)

// Object specifier
- (NSScriptObjectSpecifier *)objectSpecifier
{
    unsigned index = 0;
    id classDescription = nil;
    
    NSScriptObjectSpecifier *containerRef;
    
    NSArray *terminals = [[iTermController sharedInstance] terminals];
    index = [terminals indexOfObjectIdenticalTo:self];
    if (index != NSNotFound) {
        containerRef     = [NSApp objectSpecifier];
        classDescription = [NSClassDescription classDescriptionForClass:[NSApp class]];
        //create and return the specifier
        return [[[NSIndexSpecifier allocWithZone:[self zone]]
               initWithContainerClassDescription: classDescription
                              containerSpecifier: containerRef
                                             key: @ "terminals"
                                           index: index] autorelease];
    } 
    else
        return nil;
}

// Handlers for supported commands:

-(void)handleSelectScriptCommand: (NSScriptCommand *)command
{
    [[iTermController sharedInstance] setCurrentTerminal: self];
}

-(void)handleLaunchScriptCommand: (NSScriptCommand *)command
{
    // Get the command's arguments:
    NSDictionary *args = [command evaluatedArguments];
    NSString *session = [args objectForKey:@"session"];
    NSDictionary *abEntry;

	abEntry = [[ITAddressBookMgr sharedInstance] dataForBookmarkWithName: session];
	if(abEntry == nil)
		abEntry = [[ITAddressBookMgr sharedInstance] defaultBookmarkData];
    	
    // If we have not set up a window, do it now
    if([self windowInited] == NO)
    {
		[self initWindowWithAddressbook:abEntry];
    }
	
    // launch the session!
    [[iTermController sharedInstance] launchBookmark: abEntry inTerminal: self];
    
    return;
}

@end

