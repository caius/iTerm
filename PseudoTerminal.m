// -*- mode:objc -*-
// $Id: PseudoTerminal.m,v 1.249 2003-11-06 20:46:45 ujwal Exp $
//
/*
 **  PseudoTerminal.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
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
#define DEBUG_KEYDOWNDUMP     0

#import <iTerm/iTerm.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYScrollView.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/PTYSession.h>
#import <iTerm/VT100Screen.h>
#import <iTerm/PTYTabView.h>
#import <iTerm/PTYTabViewItem.h>
#import <iTerm/AddressBookWindowController.h>
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
#import <iTerm/ITSessionMgr.h>

// keys for attributes:
NSString *columnsKey = @"columns";
NSString *rowsKey = @"rows";
// keys for to-many relationships:
NSString *sessionsKey = @"sessions";

#define TABVIEW_TOP_BOTTOM_OFFSET	29
#define TABVIEW_LEFT_RIGHT_OFFSET	29
#define TOOLBAR_OFFSET			0

// just to keep track of available window positions
#define CACHED_WINDOW_POSITIONS		100
static unsigned int windowPositions[CACHED_WINDOW_POSITIONS];  

@implementation PseudoTerminal

- (id)initWithWindowNibName: (NSString *) windowNibName
{
    int i;
    
    if ((self = [super initWithWindowNibName: windowNibName]) == nil)
	return nil;
    
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

    _sessionMgr = [[ITSessionMgr alloc] init];

    tabViewDragOperationInProgress = NO;
    resizeInProgress = NO;
    
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal init: 0x%x]", __FILE__, __LINE__, self);
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
    NSSize termSize, contentSize;
    
    // Create the tabview
    TABVIEW = [[PTYTabView alloc] initWithFrame: frame];
    [TABVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    [TABVIEW setAllowsTruncatedLabels: NO];
    [TABVIEW setControlSize: NSSmallControlSize];
    [TABVIEW setAutoresizesSubviews: YES];

    aFont1 = FONT;
    if(aFont1 == nil)
    {
	NSDictionary *defaultSession = [[ITAddressBookMgr sharedInstance] defaultAddressBookEntry];
	aFont1 = [defaultSession objectForKey:@"Font"];
	aFont2 = [defaultSession objectForKey:@"NAFont"];
	[self setFont: aFont1 nafont: aFont2];
    }
    
    NSParameterAssert(aFont1 != nil);
    // Calculate the size of the terminal
    contentSize = [NSScrollView contentSizeForFrameSize: [TABVIEW contentRect].size
							    hasHorizontalScroller: NO
							    hasVerticalScroller: YES
							    borderType: NSNoBorder];
	
    termSize = [VT100Screen screenSizeInFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height) font: aFont1];
    [self setWidth: (int) termSize.width height: (int) termSize.height];

    return ([TABVIEW autorelease]);
}

// Do not use both initViewWithFrame and initWindow
- (void)initWindow
{
    if(TABVIEW != nil)
	return;

    _toolbarController = [[PTToolbarController alloc] initWithPseudoTerminal:self];
    
    // Create the tabview
    TABVIEW = [[PTYTabView alloc] initWithFrame:[[[self window] contentView] bounds]];
    [TABVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    [TABVIEW setAllowsTruncatedLabels: NO];
    [TABVIEW setControlSize: NSSmallControlSize];
    // Add to the window
    [[[self window] contentView] addSubview: TABVIEW];
    [[[self window] contentView] setAutoresizesSubviews: YES];
    [TABVIEW release];
        
    [[self window] setDelegate: self];
    
    [self setWindowInited: YES];
}

- (ITSessionMgr*)sessionMgr;
{
    return _sessionMgr;
}

- (void)setupSession: (PTYSession *) aSession
		       title: (NSString *)title
{
    NSMutableDictionary *addressBookPreferences;
    NSDictionary *tempPrefs;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setupSession]",
          __FILE__, __LINE__);
#endif

    NSParameterAssert(aSession != nil);    

    // Init the rest of the session
    [aSession setParent: self];
    [aSession initScreen: [TABVIEW contentRect]];

    // set some default parameters
    if([aSession addressBookEntry] == nil)
    {
	// get the default entry
	addressBookPreferences = [NSMutableDictionary dictionaryWithDictionary: [[ITAddressBookMgr sharedInstance] addressBookEntry: 0]];
	[addressBookPreferences removeObjectForKey: @"BackgroundImagePath"];
	[aSession setAddressBookEntry:addressBookPreferences];
	[aSession setPreferencesFromAddressBookEntry: addressBookPreferences];
	tempPrefs = addressBookPreferences;
    }
    else
    {
	[aSession setPreferencesFromAddressBookEntry: [aSession addressBookEntry]];
	tempPrefs = [aSession addressBookEntry];
    }

    if(FONT == nil)
    {
	[self setAllFont: [tempPrefs objectForKey:@"Font"] nafont: [tempPrefs objectForKey:@"NAFont"]];
    }
    
    if(WIDTH == 0 && HEIGHT == 0)
    {
	[self setColumns: [[tempPrefs objectForKey:@"Col"]intValue]];
	[self setRows: [[tempPrefs objectForKey:@"Row"]intValue]];
    }
    

    
    // Set the bell option
    [VT100Screen setPlayBellFlag: ![[PreferencePanel sharedInstance] silenceBell]];

    // Set the blinking cursor option
    [[aSession SCREEN] setBlinkingCursor: [[PreferencePanel sharedInstance] blinkingCursor]];

#if USE_CUSTOM_DRAWING
    [[aSession SCREEN] setDisplay:[aSession TEXTVIEW]];
    [[aSession TEXTVIEW] setLineHeight: [[aSession SCREEN] characterSize].height];
    [[aSession TEXTVIEW] setLineWidth: WIDTH * [VT100Screen fontSize: FONT].width];
#endif
    [[aSession SCREEN] setFont: FONT nafont: NAFONT];
    [[aSession SCREEN] setWidth:WIDTH height:HEIGHT];
//    NSLog(@"%d,%d",WIDTH,HEIGHT);
    
    [aSession startTimer];

    [[aSession TERMINAL] setTrace:YES];	// debug vt100 escape sequence decode

    // tell the shell about our size
    [[aSession SHELL] setWidth:WIDTH  height:HEIGHT];
            
    if (title) 
    {
        [self setWindowTitle: title];
        [aSession setName: title];
    }
}

- (void) switchSession: (id) sender
{
    [self selectSessionAtIndex: [sender tag]];
}

- (void) setCurrentSession: (PTYSession *) aSession
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setCurrentSession:%@]",
          __FILE__, __LINE__, aSession);
#endif
    
    [TABVIEW selectTabViewItemWithIdentifier: aSession];
    if ([_sessionMgr currentSession]) 
        [[_sessionMgr currentSession] resetStatus];
    
    [_sessionMgr setCurrentSession:aSession];

    [self setWindowTitle];
    [[_sessionMgr currentSession] setLabelAttribute];
    [[TABVIEW window] makeFirstResponder:[[_sessionMgr currentSession] TEXTVIEW]];
    [[TABVIEW window] setNextResponder:self];

    // send a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermSessionDidBecomeActive" object: aSession];
}

- (void)selectSessionAtIndexAction:(id)sender
{
    [self selectSessionAtIndex:[sender tag]];
}

- (void) newSessionInTabAtIndex: (id) sender
{
    [[iTermController sharedInstance] executeABCommandAtIndex:[sender tag] inTerminal:self];
}

- (void) selectSessionAtIndex: (int) sessionIndex
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal selectSessionAtIndex:%d]",
          __FILE__, __LINE__, sessionIndex);
#endif
    if (sessionIndex < 0 || sessionIndex >= [_sessionMgr numberOfSessions]) 
        return;

    [self setCurrentSession:[_sessionMgr sessionAtIndex:sessionIndex]];
}

- (void) insertSession: (PTYSession *) aSession atIndex: (int) index
{
    PTYTabViewItem *aTabViewItem;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal insertSession: 0x%x atIndex: %d]",
          __FILE__, __LINE__, aSession, index);
#endif    

    if(aSession == nil)
	return;

    if (![_sessionMgr containsSession:aSession])
    {
	[aSession setParent:self];
        
	if ([_sessionMgr numberOfSessions] == 0)
	{
	    // Tell us whenever something happens with the tab view
	    [TABVIEW setDelegate: self];
	}	

	// create a new tab
	aTabViewItem = [[PTYTabViewItem alloc] initWithIdentifier: aSession];
	NSParameterAssert(aTabViewItem != nil);
	[aTabViewItem setLabel: [aSession name]];
	[aTabViewItem setView: [aSession view]];
	[[aSession SCROLLVIEW] setVerticalPageScroll: 0.0];
	[TABVIEW insertTabViewItem: aTabViewItem atIndex: index];

        [aTabViewItem release];
	[aSession setTabViewItem: aTabViewItem];
	[self selectSessionAtIndex:index];

	if ([TABVIEW numberOfTabViewItems] == 1)
	{
#if USE_CUSTOM_DRAWING
            [[aSession TEXTVIEW] scrollEnd];
#else
	    [[aSession TEXTVIEW] scrollRangeToVisible: NSMakeRange([[[aSession TEXTVIEW] string] length] - 1, 1)];
#endif
	}

	if([self windowInited])
	    [[self window] makeKeyAndOrderFront: self];
	[[iTermController sharedInstance] setCurrentTerminal: self];
    }
}

- (void) closeSession: (PTYSession*) aSession
{
    int i;
    int n=[_sessionMgr numberOfSessions];
    
    if((_sessionMgr == nil) || ![_sessionMgr containsSession:aSession])
        return;
    
    if(n == 1 && [self windowInited])
    {
        [[self window] close];
        return;
    }

    for(i=0;i<n;i++) 
    {
        if ([_sessionMgr sessionAtIndex:i] == aSession)
        {
            // remove from tabview before terminating!! Terminating will
            // set the internal tabview object in the session to nil.
	    [aSession retain];
            [TABVIEW removeTabViewItem: [aSession tabViewItem]];
            [aSession terminate];
	    [aSession release];
	                
            // the above code removes the item and resets the currentSessionIndex
            [self selectSessionAtIndex:[_sessionMgr currentSessionIndex]];

	    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermNumberOfSessionsDidChange" object: self userInfo: nil];
	    
            break;
        }
    }
}

- (IBAction) closeCurrentSession: (id) sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal closeCurrentSession]",
          __FILE__, __LINE__);
#endif

    if(_sessionMgr == nil)
        return;

    if (![[_sessionMgr currentSession] exited])
    {
       if ([[PreferencePanel sharedInstance] promptOnClose] &&
	   NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"The current session will be closed",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close Session"),
                         NSLocalizedStringFromTableInBundle(@"All unsaved data will be lost",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close window"),
			NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
		    NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
                         ,nil) == 0) return;
    }
        
    [self closeSession:[_sessionMgr currentSession]];
}

- (IBAction)previousSession:(id)sender
{
    int theIndex;
    
    if ([_sessionMgr currentSessionIndex] == 0)
        theIndex = [_sessionMgr numberOfSessions] - 1;
    else
        theIndex = [_sessionMgr currentSessionIndex] - 1;
    
    [self selectSessionAtIndex: theIndex];    
}

- (IBAction) nextSession:(id)sender
{
    int theIndex;

    if ([_sessionMgr currentSessionIndex] == ([_sessionMgr numberOfSessions] - 1))
        theIndex = 0;
    else
        theIndex = [_sessionMgr currentSessionIndex] + 1;
    
    [self selectSessionAtIndex: theIndex];
}

- (NSString *) currentSessionName
{
    return ([[_sessionMgr currentSession] name]);
}

- (void) setCurrentSessionName: (NSString *) theSessionName
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setCurrentSessionName]",
          __FILE__, __LINE__);
#endif
    NSMutableString *title = [NSMutableString string];
    
    if(theSessionName != nil)
    {
        [[_sessionMgr currentSession] setName: theSessionName];
        [[[_sessionMgr currentSession] tabViewItem] setLabel: theSessionName];
    }
    else {
        NSString *progpath = [NSString stringWithFormat: @"%@ #%d", [[[[[_sessionMgr currentSession] SHELL] path] pathComponents] lastObject], [_sessionMgr currentSessionIndex]];

        if ([[_sessionMgr currentSession] exited])
            [title appendString:@"Finish"];
        else
            [title appendString:progpath];

        [[_sessionMgr currentSession] setName: title];
        [[[_sessionMgr currentSession] tabViewItem] setLabel: title];

    }
    [self setWindowTitle];
}

- (PTYSession *) currentSession
{
    return [_sessionMgr currentSession];
}

- (int) currentSessionIndex
{
    return ([_sessionMgr currentSessionIndex]);
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal dealloc: 0x%x]", __FILE__, __LINE__, self);
#endif
    [self releaseObjects];
    [_toolbarController release];
        
    [super dealloc];
}

- (void)releaseObjects
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal releaseObjects]", __FILE__, __LINE__);
#endif
        
    // Release all our sessions
    [_sessionMgr release];
    _sessionMgr = nil;
}

- (void)startProgram:(NSString *)program
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@]",
	  __FILE__, __LINE__, program );
#endif
    [[_sessionMgr currentSession] startProgram:program
	     arguments:[NSArray array]
           environment:[NSDictionary dictionary]];

    if ([[[self window] title] compare:@"Window"]==NSOrderedSame) [self setWindowTitle];

//    [window center];
    if([self windowInited])
	[[self window] makeKeyAndOrderFront: self];
}

- (void)startProgram:(NSString *)program arguments:(NSArray *)prog_argv
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@ arguments:%@]",
          __FILE__, __LINE__, program, prog_argv );
#endif
    [[_sessionMgr currentSession] startProgram:program
             arguments:prog_argv
           environment:[NSDictionary dictionary]];

    if ([[[self window] title] compare:@"Window"]==NSOrderedSame) [self setWindowTitle];

//    [window center];
    if([self windowInited])
	[[self window] makeKeyAndOrderFront: self];
}

- (void)startProgram:(NSString *)program
                  arguments:(NSArray *)prog_argv
                environment:(NSDictionary *)prog_env
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@ arguments:%@]",
          __FILE__, __LINE__, program, prog_argv );
#endif
    [[_sessionMgr currentSession] startProgram:program
                          arguments:prog_argv
                        environment:prog_env];

    if ([[[self window] title] compare:@"Window"]==NSOrderedSame) [self setWindowTitle];

    //    [window center];
    if([self windowInited])
	[[self window] makeKeyAndOrderFront: self];
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

- (void)setWindowSize: (BOOL) resizeContentFrames
{    
    NSSize size, vsize, winSize;
    NSWindow *thisWindow;
    int i;
    NSRect tabviewRect, oldFrame;
    NSPoint topLeft;
    PTYTextView *theTextView;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowSize]", __FILE__, __LINE__ );
#endif
    
    if([self windowInited] == NO)
	return;
    
    // Resize the tabview first if necessary
    if([TABVIEW tabViewType] == NSTopTabsBezelBorder)
    {
	tabviewRect = [[[self window] contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 20;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 10;
    }
    else if([TABVIEW tabViewType] == NSLeftTabsBezelBorder)
    {
	tabviewRect = [[[self window] contentView] frame];
	tabviewRect.origin.x += 2;
	tabviewRect.size.width += 8;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 20;
    }
    else if([TABVIEW tabViewType] == NSBottomTabsBezelBorder)
    {
	tabviewRect = [[[self window] contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 20;
	tabviewRect.origin.y += 2;
	tabviewRect.size.height += 5;
    }
    else if([TABVIEW tabViewType] == NSRightTabsBezelBorder)
    {
	tabviewRect = [[[self window] contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 8;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 20;
    }
    else
    {
	tabviewRect = [[[self window] contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 20;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 20;
    }
    [TABVIEW setFrame: tabviewRect];

    vsize = [VT100Screen requireSizeWithFont:[[[_sessionMgr currentSession] SCREEN] tallerFont]
				      width:[[[_sessionMgr currentSession] SCREEN] width]
				     height:[[[_sessionMgr currentSession] SCREEN] height]];
    
    size = [PTYScrollView frameSizeForContentSize:vsize
			    hasHorizontalScroller:NO
			      hasVerticalScroller:YES
			   	       borderType:NSNoBorder];

    for (i = 0; i < [_sessionMgr numberOfSessions]; i++)
    {
        [[[_sessionMgr sessionAtIndex: i] SCROLLVIEW] setLineScroll: [[[_sessionMgr currentSession] SCREEN] characterSize].height];
        [[[_sessionMgr sessionAtIndex: i] SCROLLVIEW] setVerticalLineScroll: [[[_sessionMgr currentSession] SCREEN] characterSize].height];
	if(resizeContentFrames)
	{
	    [[[_sessionMgr sessionAtIndex: i] view] setFrameSize: size];
	    theTextView = [[[_sessionMgr sessionAtIndex: i] SCROLLVIEW] documentView];
	    [theTextView setFrameSize: vsize];
	}
    }
    
    thisWindow = [[[_sessionMgr currentSession] SCROLLVIEW] window];
    winSize = size;
    if([TABVIEW tabViewType] == NSTopTabsBezelBorder)
	winSize.height = size.height + TABVIEW_TOP_BOTTOM_OFFSET;
    else if([TABVIEW tabViewType] == NSLeftTabsBezelBorder)
	winSize.width = size.width + TABVIEW_LEFT_RIGHT_OFFSET;
    else if([TABVIEW tabViewType] == NSBottomTabsBezelBorder)
	winSize.height = size.height + TABVIEW_TOP_BOTTOM_OFFSET;
    else if([TABVIEW tabViewType] == NSRightTabsBezelBorder)
	winSize.width = size.width + TABVIEW_LEFT_RIGHT_OFFSET;
    else
        winSize.height = size.height + 0;
    if([[thisWindow toolbar] isVisible] == YES)
	winSize.height += TOOLBAR_OFFSET;

    // preserve the top left corner of the frame
    oldFrame = [thisWindow frame];
    topLeft.x = oldFrame.origin.x;
    topLeft.y = oldFrame.origin.y + oldFrame.size.height;
    
    [thisWindow setContentSize:winSize];

    [thisWindow setFrameTopLeftPoint: topLeft];
}

- (void)setWindowTitle
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowTitle]",
          __FILE__, __LINE__);
#endif

    if([[self currentSession] windowTitle] == nil)
	[[self window] setTitle:[self currentSessionName]];
    else
	[[self window] setTitle:[[self currentSession] windowTitle]];
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowTitle: exiting]",
          __FILE__, __LINE__);
#endif
}

- (void) setWindowTitle: (NSString *)title
{
    [[self window] setTitle:title];
}

- (void)setFont:(NSFont *)font nafont:(NSFont *)nafont
{
    [FONT autorelease];
    [font retain];
    FONT=font;
    [NAFONT autorelease];
    [nafont retain];
    NAFONT=nafont;
}

- (void)setAllFont:(NSFont *)font nafont:(NSFont *) nafont
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setAllFont:%@]",
	  __FILE__, __LINE__, font);
#endif
    int i;

    for(i=0;i<[_sessionMgr numberOfSessions]; i++) 
    {
        PTYSession* session = [_sessionMgr sessionAtIndex:i];
#if USE_CUSTOM_DRAWING
#else
        [[session TEXTVIEW]  setFont:font];
#endif
        [[session SCREEN]  setFont:font nafont:nafont];
    }
    [FONT autorelease];
    [font retain];
    FONT=font;
    [NAFONT autorelease];
    [nafont retain];
    NAFONT=nafont;
}

- (void)clearBuffer:(id)sender
{
    [[_sessionMgr currentSession] clearBuffer];
}

- (void)clearScrollbackBuffer:(id)sender
{
    [[_sessionMgr currentSession] clearScrollbackBuffer];
}

- (IBAction)logStart:(id)sender
{
    if (![[_sessionMgr currentSession] logging]) [[_sessionMgr currentSession] logStart];
    // send a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermSessionDidBecomeActive" object: [_sessionMgr currentSession]];
}

- (IBAction)logStop:(id)sender
{
    if ([[_sessionMgr currentSession] logging]) [[_sessionMgr currentSession] logStop];
    // send a notification
    [[NSNotificationCenter defaultCenter] postNotificationName: @"iTermSessionDidBecomeActive" object: [_sessionMgr currentSession]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL logging = [[_sessionMgr currentSession] logging];
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
    int i,sessionCount;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowWillClose:%@]",
	  __FILE__, __LINE__, aNotification);
#endif
    sessionCount = [_sessionMgr numberOfSessions];
    for (i = 0; i < sessionCount; i++)
    {
        if ([[_sessionMgr sessionAtIndex: i] exited]==NO)
            [[[_sessionMgr sessionAtIndex: i] SHELL] stopNoWait];
    }

    [self releaseObjects];

    // Release our window postion
    for (i = 0; i < CACHED_WINDOW_POSITIONS; i++)
    {
	if(windowPositions[i] == (unsigned int) self)
	{
	    windowPositions[i] = 0;
	    break;
	}
    }

    [[iTermController sharedInstance] terminalWillClose: self];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidBecomeKey:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    [self selectSessionAtIndex: [self currentSessionIndex]];
    
    [[iTermController sharedInstance] setCurrentTerminal: self];

    // update the cursor
    [[[_sessionMgr currentSession] SCREEN] showCursor];
}

- (void) windowDidResignKey: (NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResignKey:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    [self windowDidResignMain: aNotification];

    // update the cursor
    [[[_sessionMgr currentSession] SCREEN] showCursor];

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

    return (proposedFrameSize);
}

- (void)windowDidResize:(NSNotification *)aNotification
{
    NSRect frame;
    NSSize termSize;
    int i, w, h;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResize: width = %f, height = %f]",
	  __FILE__, __LINE__, [[self window] frame].size.width, [[self window] frame].size.height);
#endif

    // To prevent death by recursion
    if(resizeInProgress == YES)
    {
	return;
    }

    resizeInProgress = YES;    

    frame = [[[[_sessionMgr currentSession] SCROLLVIEW] contentView] frame];
#if 0
    NSLog(@"scrollview content size %.1f, %.1f, %.1f, %.1f",
	  frame.origin.x, frame.origin.y,
	  frame.size.width, frame.size.height);
#endif

    termSize = [VT100Screen screenSizeInFrame: frame font: [[[_sessionMgr currentSession] SCREEN] tallerFont]];
    
    w = (int)(termSize.width);
    h = (int)(termSize.height);
    
    for(i=0;i<[_sessionMgr numberOfSessions]; i++) {
        [[[_sessionMgr sessionAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[_sessionMgr sessionAtIndex:i] SHELL] setWidth:w  height:h];
        //[[[_sessionMgr sessionAtIndex:i] SCROLLVIEW] setFrameSize:[TABVIEW contentRect].size];
    }
    
    WIDTH = w;
    HEIGHT = h;

    // this will cause a recursion, so we protect ourselves at the entry of the method.
    [self setWindowSize: NO];

    // Display the new size in the window title.
    NSString *aTitle = [NSString stringWithFormat:@"%@ (%d,%d)", [[_sessionMgr currentSession] name], WIDTH, HEIGHT];
    [self setWindowTitle: aTitle];    

    // Reset the scrollbar to the bottom
    [[[_sessionMgr currentSession] TEXTVIEW] scrollEnd];

    //NSLog(@"Didresize: w = %d, h = %d; frame.size.width = %f, frame.size.height = %f",WIDTH,HEIGHT, [[self window] frame].size.width, [[self window] frame].size.height);
    resizeInProgress = NO;
}

// PTYWindowDelegateProtocol
- (void) windowWillToggleToolbarVisibility: (id) sender
{
    // prevent any resizing processing by lying
    resizeInProgress = YES;
}

- (void) windowDidToggleToolbarVisibility: (id) sender
{
    // allow resizing
    resizeInProgress = NO;
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
    [ITConfigPanelController show:self parentWindow:[TABVIEW window]];
}

- (void) resizeWindow:(int) w height:(int)h
{
    int i;
    NSSize vsize;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal resizeWindow:%d,%d]",
          __FILE__, __LINE__, w, h);
#endif
    
    vsize = [VT100Screen requireSizeWithFont:[[[_sessionMgr currentSession] SCREEN] tallerFont]
                                       width:w
                                      height:h];
    
    for(i=0;i<[_sessionMgr numberOfSessions]; i++) {
        [[[_sessionMgr sessionAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[_sessionMgr sessionAtIndex:i] SHELL] setWidth:w height:h];
        [[[_sessionMgr sessionAtIndex:i] TEXTVIEW] setFrameSize:vsize];
    }
    WIDTH=w;
    HEIGHT=h;

    [self setWindowSize: NO];
}

// Contextual menu
- (void) menuForEvent:(NSEvent *)theEvent menu: (NSMenu *) theMenu
{
    unsigned int modflag = 0;
    BOOL newWin;
    int nextIndex;
    NSMenuItem *aMenuItem;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal menuForEvent]", __FILE__, __LINE__);
#endif

    if(theMenu == nil)
	return;

    modflag = [theEvent modifierFlags];

    // Bookmarks
    // Figure out whether the command shall be executed in a new window or tab
    if (modflag & NSCommandKeyMask)
    {
	[theMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"New Window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" atIndex: 0];
	newWin = YES;
    }
    else
    {
	[theMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"New Tab",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" atIndex: 0];
	newWin = NO;
    }
    nextIndex = 1;

    // Create a menu with a submenu to navigate between tabs if there are more than one
    if([TABVIEW numberOfTabViewItems] > 1)
    {	
	[theMenu insertItemWithTitle: NSLocalizedStringFromTableInBundle(@"Select",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:nil keyEquivalent:@"" atIndex: nextIndex];

	NSMenu *tabMenu = [[NSMenu alloc] initWithTitle:@""];
	int i;

	for (i = 0; i < [TABVIEW numberOfTabViewItems]; i++)
	{
	    aMenuItem = [[NSMenuItem alloc] initWithTitle:[[TABVIEW tabViewItemAtIndex: i] label]
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
    
    // Separator
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex: nextIndex];

    // Build the bookmarks menu
    NSMenu *abMenu = [[NSMenu alloc] initWithTitle: @"Bookmarks"];
    [[iTermController sharedInstance] buildAddressBookMenu: abMenu target: (newWin?nil:self) withShortcuts: NO];

    [theMenu setSubmenu: abMenu forItem: [theMenu itemAtIndex: 0]];
    [abMenu release];

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Close current session
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:@selector(closeCurrentSession:) keyEquivalent:@""];
    [aMenuItem setTarget: self];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];

    // Configure
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Configure...",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:@selector(showConfigWindow:) keyEquivalent:@""];
    [aMenuItem setTarget: self];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];
}

// NSTabView
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    PTYSession *aSession;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willSelectTabViewItem]", __FILE__, __LINE__);
#endif
    
    aSession = [tabViewItem identifier];
    
    if ([_sessionMgr currentSession]) 
        [[_sessionMgr currentSession] resetStatus];
    
    [_sessionMgr setCurrentSession:aSession];
    
    [self setWindowTitle];
    [[TABVIEW window] makeFirstResponder:[[_sessionMgr currentSession] TEXTVIEW]];
    [[TABVIEW window] setNextResponder:self];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: didSelectTabViewItem]", __FILE__, __LINE__);
#endif
    
    [[_sessionMgr currentSession] setLabelAttribute];
}

- (void)tabView:(NSTabView *)tabView willRemoveTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willRemoveTabViewItem]", __FILE__, __LINE__);
#endif
    PTYSession *aSession = [tabViewItem identifier];

    if([_sessionMgr containsSession: aSession] && [aSession isKindOfClass: [PTYSession class]])
	[_sessionMgr removeSession: aSession];
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

    if(tabView == nil || tabViewItem == nil || index < 0)
	return;
    
    PTYSession *aSession = [tabViewItem identifier];

    if(![_sessionMgr containsSession: aSession] && [aSession isKindOfClass: [PTYSession class]])
    {
	[aSession setParent: self];
	
        [_sessionMgr insertSession: aSession atIndex: index];
    }

    if([TABVIEW numberOfTabViewItems] == 1)
    {
	[TABVIEW setTabViewType: [[PreferencePanel sharedInstance] tabViewType]];
	[self setWindowSize: NO];
    }    
}

- (void)tabViewWillPerformDragOperation:(NSTabView *)tabView
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabViewWillPerformDragOperation]", __FILE__, __LINE__);
#endif

    tabViewDragOperationInProgress = YES;
}

- (void)tabViewDidPerformDragOperation:(NSTabView *)tabView
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabViewDidPerformDragOperation]", __FILE__, __LINE__);
#endif

    tabViewDragOperationInProgress = NO;
    [self tabViewDidChangeNumberOfTabViewItems: tabView];
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabViewDidChangeNumberOfTabViewItems]", __FILE__, __LINE__);
#endif

    if(tabViewDragOperationInProgress == YES)
	return;
    
    [_sessionMgr setCurrentSessionIndex:[TABVIEW indexOfTabViewItem: [TABVIEW selectedTabViewItem]]];

    if ([TABVIEW numberOfTabViewItems] == 1)
    {
	if([[PreferencePanel sharedInstance] hideTab])
	{
            PTYSession *aSession = [[TABVIEW tabViewItemAtIndex: 0] identifier];

            [TABVIEW setTabViewType: NSNoTabsBezelBorder];
	    [self setWindowSize: NO];
#if USE_CUSTOM_DRAWING
            [[aSession TEXTVIEW] scrollEnd];
#else
	    [[aSession TEXTVIEW] scrollRangeToVisible: NSMakeRange([[[aSession TEXTVIEW] string] length] - 1, 1)];
#endif
	}
	else
	{
	    [TABVIEW setTabViewType: [[PreferencePanel sharedInstance] tabViewType]];
	    [self setWindowSize: NO];
	}

    }
    
}

- (void)tabViewContextualMenu: (NSEvent *)theEvent menu: (NSMenu *)theMenu
{
    NSMenuItem *aMenuItem;
    NSPoint windowPoint, localPoint;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabViewContextualMenu]", __FILE__, __LINE__);
#endif    

    if((theEvent == nil) || (theMenu == nil))
	return;

    windowPoint = [[TABVIEW window] convertScreenToBase: [NSEvent mouseLocation]];
    localPoint = [TABVIEW convertPoint: windowPoint fromView: nil];

    if([TABVIEW tabViewItemAtPoint:localPoint] == nil)
	return;

    [theMenu addItem: [NSMenuItem separatorItem]];

    // add tasks
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close Session") action:@selector(closeTabContextualMenuAction:) keyEquivalent:@""];
    [aMenuItem setRepresentedObject: [[TABVIEW tabViewItemAtPoint:localPoint] identifier]];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];
    if([_sessionMgr numberOfSessions] > 1)
    {
	aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Move to new window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Move session to new window") action:@selector(moveTabToNewWindowContextualMenuAction:) keyEquivalent:@""];
	[aMenuItem setRepresentedObject: [[TABVIEW tabViewItemAtPoint:localPoint] identifier]];
	[theMenu addItem: aMenuItem];
	[aMenuItem release];
    }
}

// closes a tab
- (void) closeTabContextualMenuAction: (id) sender
{
    [self closeSession: [sender representedObject]];
}

// moves a tab with its session to a new window
- (void) moveTabToNewWindowContextualMenuAction: (id) sender
{
    PseudoTerminal *term;
    PTYSession *aSession;
    PTYTabViewItem *aTabViewItem;

    // grab the referenced session
    aSession = [sender representedObject];
    if(aSession == nil)
	return;

    // create a new terminal window
    term = [[[PseudoTerminal alloc] init] autorelease];
    if(term == nil)
	return;

    [[iTermController sharedInstance] addInTerminals: term];

    if([term windowInited] == NO)
    {
	[term setWidth: WIDTH height: HEIGHT];
	[term setFont: FONT nafont: NAFONT];
	[term initWindow];
    }

    // If this is the current session, make previous one active.
    if(aSession == [_sessionMgr currentSession])
	[self selectSessionAtIndex: ([_sessionMgr currentSessionIndex] - 1)];

    aTabViewItem = [aSession tabViewItem];

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

- (IBAction)saveSession:(id)sender
{
    NSMutableDictionary *currentABEntry;

    currentABEntry=[NSMutableDictionary dictionaryWithDictionary:[[_sessionMgr currentSession] addressBookEntry]];

    if(currentABEntry != nil)
    {
	[currentABEntry setObject: [NSNumber numberWithUnsignedInt:[[[_sessionMgr currentSession] TERMINAL] encoding]] forKey: @"Encoding"];
	[currentABEntry setObject: [[_sessionMgr currentSession] foregroundColor] forKey: @"Foreground"];
	[currentABEntry setObject: [[_sessionMgr currentSession] backgroundColor] forKey: @"Background"];
	[currentABEntry setObject: [[_sessionMgr currentSession] boldColor] forKey: @"BoldColor"];
	[currentABEntry setObject: [[_sessionMgr currentSession] selectionColor] forKey: @"SelectionColor"];
	[currentABEntry setObject: [NSString stringWithInt:WIDTH] forKey: @"Col"];
	[currentABEntry setObject: [NSString stringWithInt:HEIGHT] forKey: @"Row"];
	[currentABEntry setObject: [NSNumber numberWithInt: [[_sessionMgr currentSession] transparency]*100] forKey: @"Transparency"];
	[currentABEntry setObject: [[self currentSession] TERM_VALUE] forKey: @"Term Type"];
	[currentABEntry setObject: [[[_sessionMgr currentSession] SCREEN] font] forKey: @"Font"];
	[currentABEntry setObject: [[[_sessionMgr currentSession] SCREEN] nafont] forKey: @"NAFont"];
	[currentABEntry setObject: [NSNumber numberWithBool:[[self currentSession] antiIdle]] forKey: @"AntiIdle"];
	[currentABEntry setObject: [NSNumber numberWithUnsignedInt:[[self currentSession] antiCode]] forKey: @"AICode"];
	[currentABEntry setObject: [[[_sessionMgr currentSession] SCREEN] nafont] forKey: @"NAFont"];
	[currentABEntry setObject: [[_sessionMgr currentSession] backgroundImagePath]?[[_sessionMgr currentSession] backgroundImagePath]:@"" forKey: @"BackgroundImagePath"];


	[[[ITAddressBookMgr sharedInstance] addressBook] replaceObjectAtIndex: [[[ITAddressBookMgr sharedInstance] addressBook] indexOfObject: [[_sessionMgr currentSession] addressBookEntry]] withObject: currentABEntry];

	NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Configuration saved",@"iTerm", [NSBundle bundleForClass: [self class]], @"Config"),
		 [currentABEntry objectForKey:@"Name"],
		 NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
		 nil,nil);
	
    }
    else
    {
	NSMutableDictionary *new;
	
	new=[[NSMutableDictionary alloc] initWithObjectsAndKeys:
	    [[_sessionMgr currentSession] name],@"Name",
	    [[[_sessionMgr currentSession] SHELL] path],@"Command",
	    [NSNumber numberWithUnsignedInt:[[[_sessionMgr currentSession] TERMINAL] encoding]],@"Encoding",
	    [[_sessionMgr currentSession] foregroundColor],@"Foreground",
	    [[_sessionMgr currentSession] backgroundColor],@"Background",
	    [[_sessionMgr currentSession] boldColor],@"BoldColor",
	    [[_sessionMgr currentSession] selectionColor],@"SelectionColor",
	    [NSString stringWithInt:WIDTH],@"Col",
	    [NSString stringWithInt:HEIGHT],@"Row",
	    [NSNumber numberWithInt:100-[[[[_sessionMgr currentSession] TERMINAL] defaultBGColor] alphaComponent]*100],@"Transparency",
	    [[self currentSession] TERM_VALUE],@"Term Type",
	    @"",@"Directory",
	    [[[_sessionMgr currentSession] SCREEN] font],@"Font",
	    [[[_sessionMgr currentSession] SCREEN] nafont],@"NAFont",
	    [NSNumber numberWithBool:[[self currentSession] antiIdle]],@"AntiIdle",
	    [NSNumber numberWithUnsignedInt:[[self currentSession] antiCode]],@"AICode",
	    [NSNumber numberWithBool:[[self currentSession] autoClose]],@"AutoClose",
	    [NSNumber numberWithBool:[[self currentSession] doubleWidth]],@"DoubleWidth",
	    NULL];
        [[ITAddressBookMgr sharedInstance] addAddressBookEntry: new];
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Configuration saved as a new entry in Bookmarks",@"iTerm", [NSBundle bundleForClass: [self class]], @"Config"),
                        [new objectForKey:@"Name"],
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
	[new release];
	[[_sessionMgr currentSession] setAddressBookEntry: new];
    }
    
    [[ITAddressBookMgr sharedInstance] saveAddressBook];
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
	if([_sessionMgr numberOfSessions] > 0)
	    [self setWindowSize: NO];
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
	if([_sessionMgr numberOfSessions] > 0)
	    [self setWindowSize: NO];
    }
}

// accessors for to-many relationships:
-(NSArray*)sessions
{
    return [_sessionMgr sessionList];
}

-(void)setSessions: (NSArray*)sessions
{
    // no-op
}

// accessors for to-many relationships:
// (See NSScriptKeyValueCoding.h)
-(id)valueInSessionsAtIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -valueInSessionsAtIndex: %d", index);
    return ([_sessionMgr sessionAtIndex: index]);
}

-(id)valueWithName: (NSString *)uniqueName inPropertyWithKey: (NSString*)propertyKey
{
    id result = nil;
    int i;

    if([propertyKey isEqualToString: sessionsKey] == YES)
    {
	PTYSession *aSession;
	
	for (i= 0; i < [_sessionMgr numberOfSessions]; i++)
	{
	    aSession = [_sessionMgr sessionAtIndex: i];
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

	for (i= 0; i < [_sessionMgr numberOfSessions]; i++)
	{
	    aSession = [_sessionMgr sessionAtIndex: i];
	    if([[aSession tty] isEqualToString: uniqueID] == YES)
		return (aSession);
	}
    }
    
    return result;
}

-(void)replaceInSessions:(PTYSession *)object atIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -replaceInSessions: 0x%x atIndex: %d", object, index);
    [_sessionMgr replaceSessionAtIndex: index withSession: object];
}

-(void)addInSessions:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -addInSessions: 0x%x", object);
    [self insertInSessions: object];
}

-(void)insertInSessions:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -insertInSessions: 0x%x", object);
    [self insertInSessions: object atIndex:[_sessionMgr numberOfSessions]];
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
    if(index < [_sessionMgr numberOfSessions])
    {
	PTYSession *aSession = [_sessionMgr sessionAtIndex: index];
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

    NSArray *abArray;
    int i;
    
    // search for the session in the addressbook
    abArray = [[ITAddressBookMgr sharedInstance] addressBookNames];
    for (i = 0; i < [abArray count]; i++)
    {
	if([[abArray objectAtIndex: i] caseInsensitiveCompare: session] == NSOrderedSame)
	    break;
    }
    if(i == [abArray count])
	i = 0; // index of default session
    abEntry = [[ITAddressBookMgr sharedInstance] addressBookEntry: i];

    // If we have not set up a window, do it now
    if([self windowInited] == NO)
    {
	[self setWidth: [[abEntry objectForKey: @"Col"] intValue] height: [[abEntry objectForKey: @"Row"] intValue]];
	[self setFont: [abEntry objectForKey: @"Font"] nafont: [abEntry objectForKey: @"NAFont"]];
	[self initWindow];
    }

    // launch the session!
    [[iTermController sharedInstance] executeABCommandAtIndex: i inTerminal: self];
    
    return;
}

@end

