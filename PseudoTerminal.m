// -*- mode:objc -*-
// $Id: PseudoTerminal.m,v 1.207 2003-08-09 07:41:18 ujwal Exp $
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


// keys for attributes:
NSString *columnsKey = @"columns";
NSString *rowsKey = @"rows";
// keys for to-many relationships:
NSString *sessionsKey = @"sessions";


#define NIB_PATH  @"PseudoTerminal"

#define TABVIEW_TOP_BOTTOM_OFFSET	29
#define TABVIEW_LEFT_RIGHT_OFFSET	25
#define TOOLBAR_OFFSET			0

static NSString *NewToolbarItem = @"New";
static NSString *ABToolbarItem = @"Address";
static NSString *CloseToolbarItem = @"Close";
static NSString *ConfigToolbarItem = @"Config";

// just to keep track of available window positions
#define CACHED_WINDOW_POSITIONS		100
static unsigned int windowPositions[CACHED_WINDOW_POSITIONS];  


@implementation PseudoTerminal


- (id) initWithWindowNibName: (NSString *) windowNibName
{
    int i;
    
    if ((self = [super initWithWindowNibName: windowNibName]) == nil)
	return nil;

    // set our delegate
    //[self setITermController: [NSApp delegate]];
    
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

    // Allocate a list for our sessions
    ptyList = [[NSMutableArray alloc] init];
    ptyListLock = [[NSLock alloc] init];

    // Read the preference on whether to open new sessions in new tabs or windows
    newwin = [[NSUserDefaults standardUserDefaults] boolForKey:@"SESSION_IN_NEW_WINDOW"];

    tabViewDragOperationInProgress = NO;
    resizeInProgress = NO;

    // Add ourselves as an observer for notifications to reload the addressbook.
    [[NSNotificationCenter defaultCenter] addObserver: self
					     selector: @selector(_reloadAddressBookMenu:)
						 name: @"Reload AddressBook"
					       object: nil];
    
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal init: 0x%x]", __FILE__, __LINE__, self);
#endif

    return self;
}

- (id)init
{

    return ([self initWithWindowNibName: NIB_PATH]);
    
}

// Do not use both initViewWithFrame and initWindow
// initViewWithFrame is mainly meant for embedding a terminal view in a non-iTerm window.
- (PTYTabView*) initViewWithFrame: (NSRect) frame
{
    NSRect tabviewRect;

    // Create the tabview
    TABVIEW = [[PTYTabView alloc] initWithFrame: tabviewRect];
    [TABVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    [TABVIEW setAllowsTruncatedLabels: NO];
    [TABVIEW setControlSize: NSSmallControlSize];
    [TABVIEW setAutoresizesSubviews: YES];


    WIDTH = HEIGHT = 0;
    
    return ([TABVIEW autorelease]);
}

// Do not use both initViewWithFrame and initWindow
- (void)initWindow
{

    NSRect tabviewRect;

    // setup our toolbar
    [[self window] setToolbar:[self setupToolbar]];
    
    // Create the tabview
    tabviewRect = [[[self window] contentView] frame];
    tabviewRect.origin.x -= 10;
    tabviewRect.size.width += 20;
    tabviewRect.origin.y -= 13;
    tabviewRect.size.height += 17;
    TABVIEW = [[PTYTabView alloc] initWithFrame: tabviewRect];
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

- (void)setupSession: (PTYSession *) aSession
		       title: (NSString *)title
{
    NSDictionary *defaultParameters;
    NSFont *aFont1, *aFont2;
    NSSize termSize;
    NSRect contentRect;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setupSession]",
          __FILE__, __LINE__);
#endif

    NSParameterAssert(aSession != nil);

    if(WIDTH == 0)
    {
	aFont1 = FONT;
	if(aFont1 == nil)
	{
	    NSDictionary *defaultSession = [iTerm defaultAddressBookEntry];
	    aFont1 = [defaultSession objectForKey:@"Font"];
	    aFont2 = [defaultSession objectForKey:@"NAFont"];
	    [self setFont: aFont1 nafont: aFont2];
	}
	NSParameterAssert(aFont1 != nil);
	// Calculate the size of the terminal
	contentRect = [TABVIEW contentRect];
	termSize = [VT100Screen screenSizeInFrame: contentRect font: aFont1];
	[self setWidth: (int) termSize.width height: (int) termSize.height];
    }
    
    
    // Init the rest of the session
    [aSession setParent: self];
    [aSession setPreference: pref];
    [aSession setITermController: iTerm];
    [aSession initScreen: [TABVIEW contentRect]];

    // set some default parameters
    defaultParameters = [iTerm addressBookEntry: 0];
    [aSession setAddressBookEntry:defaultParameters];
    [aSession setPreferencesFromAddressBookEntry: defaultParameters];

    // set the font
#if USE_CUSTOM_DRAWING    
    [[aSession TEXTVIEW]  setFont:FONT nafont:NAFONT];
#else
    [[aSession TEXTVIEW]  setFont:FONT];
#endif
    [[aSession SCREEN]  setFont:FONT nafont:NAFONT];
    
    // set the srolling
    [[aSession SCROLLVIEW] setVerticalLineScroll: [[aSession SCREEN] characterSize].height];
    [[aSession SCROLLVIEW] setVerticalPageScroll: [[aSession TEXTVIEW] frame].size.height];
    
    // Set the bell option
    [VT100Screen setPlayBellFlag: ![pref silenceBell]];

    // Set the blinking cursor option
    [[aSession SCREEN] setBlinkingCursor: [pref blinkingCursor]];

    // assign terminal and task objects
    [[aSession SCREEN] setTerminal:[aSession TERMINAL]];
    [[aSession SCREEN] setShellTask:[aSession SHELL]];
    [[aSession TEXTVIEW] setDataSource: [aSession SCREEN]];
#if USE_CUSTOM_DRAWING
    [[aSession SCREEN] setDisplay:[aSession TEXTVIEW]];
    [[aSession TEXTVIEW] setLineHeight: [[aSession SCREEN] characterSize].height];
    [[aSession TEXTVIEW] setLineWidth: WIDTH * [VT100Screen fontSize: FONT].width];
#else
    [[aSession SCREEN] setTextStorage:[[aSession TEXTVIEW] textStorage]];
#endif
    [[aSession SCREEN] setWidth:WIDTH height:HEIGHT];
    [[aSession SCREEN] setScrollback:[pref scrollbackLines]];
//    NSLog(@"%d,%d",WIDTH,HEIGHT);
    
    // initialize the screen
    [[aSession SCREEN] initScreen];

    [aSession startTimer];

    [[aSession TERMINAL] setTrace:YES];	// debug vt100 escape sequence decode

    // tell the shell about our size
    [[aSession SHELL] setWidth:WIDTH  height:HEIGHT];
        

    pending = NO;
    
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

- (void) selectSession: (PTYSession *) aSession
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal selectSession:%@]",
          __FILE__, __LINE__, aSession);
#endif
    
    [TABVIEW selectTabViewItemWithIdentifier: aSession];
    if (currentPtySession) [currentPtySession resetStatus];
    currentSessionIndex = [ptyList indexOfObject: aSession];
    currentPtySession = aSession;
    [self setWindowTitle];
    [currentPtySession setLabelAttribute];
    [[TABVIEW window] makeFirstResponder:[currentPtySession TEXTVIEW]];
    [[TABVIEW window] setNextResponder:self];
}


- (void) selectSessionAtIndex: (int) sessionIndex
{
    PTYSession *aSession;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal selectSessionAtIndex:%d]",
          __FILE__, __LINE__, sessionIndex);
#endif
    
    if (sessionIndex<0||sessionIndex >= [ptyList count]) return;

    aSession = [ptyList objectAtIndex: sessionIndex];
    [self selectSession: aSession];

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

    if([ptyList containsObject: aSession] == NO)
    {

	[aSession setParent: self];
	if([ptyList count] == 0)
	{
	    // Tell us whenever something happens with the tab view
	    [TABVIEW setDelegate: self];
	}	

	// create a new tab
	aTabViewItem = [[PTYTabViewItem alloc] initWithIdentifier: aSession];
	NSParameterAssert(aTabViewItem != nil);
	[aTabViewItem setLabel: [aSession name]];
	[aTabViewItem setView: [aSession SCROLLVIEW]];
	[[aSession SCROLLVIEW] setVerticalPageScroll: 0.0];
	[TABVIEW insertTabViewItem: aTabViewItem atIndex: index];
	//currentSessionIndex = [ptyList count] - 1;
	//currentPtySession = aSession;
	[aTabViewItem release];
	[aSession setTabViewItem: aTabViewItem];
	[self selectSessionAtIndex: index];

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
	[iTerm setFrontPseudoTerminal: self];
    }
}

- (void) closeSession: (PTYSession*) aSession
{
    int i;
    int n=[ptyList count];
    
    if((ptyList == nil) || ([ptyList containsObject: aSession] == NO))
        return;
    
    if(n == 1 && [self windowInited])
    {
        [[self window] close];
        return;
    }

    for(i=0;i<n;i++) 
    {
        if ([ptyList objectAtIndex:i]==aSession)
        {
                    
            // remove from tabview before terminating!! Terminating will
            // set the internal tabview object in the session to nil.
	    [aSession retain];
            [TABVIEW removeTabViewItem: [aSession tabViewItem]];
            [aSession terminate];
	    [aSession release];
	    
            if (i==currentSessionIndex) {
                if (currentSessionIndex >= [ptyList count])
                    currentSessionIndex = [ptyList count] - 1;
        
                currentPtySession = nil;
                [self selectSessionAtIndex: currentSessionIndex];
            }
            else if (i<currentSessionIndex) currentSessionIndex--;

	    [[self iTerm] buildSessionSubmenu];
                        
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

    if(ptyList == nil)
        return;

    if ([currentPtySession exited]==NO) {
       if ([pref promptOnClose] &&
	   NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"The current session will be closed",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close Session"),
                         NSLocalizedStringFromTableInBundle(@"All unsaved data will be lost",@"iTerm", [NSBundle bundleForClass: [self class]], @"Close window"),
			NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
		    NSLocalizedStringFromTableInBundle(@"Cancel",@"iTerm", [NSBundle bundleForClass: [self class]], @"Cancel")
                         ,nil) == 0) return;
                         
    }
        
    [self closeSession: currentPtySession];
    
}

- (IBAction) previousSession:(id)sender
{
    int theIndex;
    
    if (currentSessionIndex == 0)
       theIndex = [ptyList count] - 1;
    else
    {
        theIndex = currentSessionIndex - 1;
    }
    [self selectSessionAtIndex: theIndex];    
}

- (IBAction) nextSession:(id)sender
{
    int theIndex;

    if (currentSessionIndex == ([ptyList count] - 1))
    {
        theIndex = 0;
    }
    else
    {
        theIndex = currentSessionIndex + 1;
    }
    
    [self selectSessionAtIndex: theIndex];

}

- (NSString *) currentSessionName
{
    return ([currentPtySession name]);
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
        [currentPtySession setName: theSessionName];
        [[currentPtySession tabViewItem] setLabel: theSessionName];
    }
    else {
        NSString *progpath = [NSString stringWithFormat: @"%@ #%d", [[[[currentPtySession SHELL] path] pathComponents] lastObject], currentSessionIndex];

        if ([currentPtySession exited])
            [title appendString:@"Finish"];
        else
            [title appendString:progpath];

        [currentPtySession setName: title];
        [[currentPtySession tabViewItem] setLabel: title];

    }
    [self setWindowTitle];
}


- (PTYSession *) currentSession
{
    return (currentPtySession);
}

- (int) currentSessionIndex
{
    return (currentSessionIndex);
}

- (void)dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal dealloc: 0x%x]", __FILE__, __LINE__, self);
#endif
    [self releaseObjects];
    
    [super dealloc];
}

- (void)releaseObjects
{
    int i;
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal releaseObjects]", __FILE__, __LINE__);
#endif
        
    // Release all our sessions
    [ptyListLock lock];
    for(i = 0; i < [ptyList count]; i++)
        [[ptyList objectAtIndex: i] terminate];
    if([ptyList count] > 0)
    {
	[ptyList removeAllObjects];
        [ptyList release];
    }
    [ptyListLock unlock];
    [ptyListLock release];
    ptyListLock = nil;
   
    ptyList = nil;

        
    // Remove ourselves as an observer for notifications to reload the addressbook.
    [[NSNotificationCenter defaultCenter] removeObserver: self
        name: @"Reload AddressBook"
        object: nil];
    
}

- (void)startProgram:(NSString *)program
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@]",
	  __FILE__, __LINE__, program );
#endif
    [currentPtySession startProgram:program
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
    [currentPtySession startProgram:program
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
    [currentPtySession startProgram:program
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

- (void)setWindowSize: (BOOL) resizeContentFrames
{
    NSSize size, vsize, winSize;
    NSWindow *thisWindow;
    int i;
    NSRect tabviewRect, oldFrame;
    NSPoint topLeft;

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


#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowSize]", __FILE__, __LINE__ );
#endif
    vsize = [VT100Screen requireSizeWithFont:[[currentPtySession SCREEN] tallerFont]
				      width:WIDTH
				     height:HEIGHT];

    
    size = [PTYScrollView frameSizeForContentSize:vsize
			    hasHorizontalScroller:NO
			      hasVerticalScroller:YES
			   	       borderType:NSNoBorder];

    for (i = 0; i < [TABVIEW numberOfTabViewItems]; i++)
    {
        [(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setLineScroll: [[currentPtySession SCREEN] characterSize].height];
        [(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setVerticalLineScroll: [[currentPtySession SCREEN] characterSize].height];
	if(resizeContentFrames)
	{
	    [(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setFrameSize: size];
	    [[(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] documentView] setFrameSize:vsize];
	}
    }

    thisWindow = [[currentPtySession SCROLLVIEW] window];
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
    FONT=[font copy];
    [NAFONT autorelease];
    NAFONT=[nafont copy];
}

- (void)setAllFont:(NSFont *)font nafont:(NSFont *) nafont
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setAllFont:%@]",
	  __FILE__, __LINE__, font);
#endif
    int i;

    for(i=0;i<[ptyList count]; i++) {
#if USE_CUSTOM_DRAWING
#else
        [[[ptyList objectAtIndex:i] TEXTVIEW]  setFont:font];
#endif
        [[[ptyList objectAtIndex:i] SCREEN]  setFont:font nafont:nafont];
    }
    [FONT autorelease];
    FONT=[font copy];
    [NAFONT autorelease];
    NAFONT=[nafont copy];
}

- (void)changeFont:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal changeFont:%@]",
	  __FILE__, __LINE__, sender);
#endif
//    NSLog(@"changeFont!!!!");
    if (changingNA) {
        configNAFont=[[NSFontManager sharedFontManager] convertFont:configNAFont];
        if (configNAFont!=nil) {
            [CONFIG_NAEXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configNAFont fontName], [configNAFont pointSize]]];
            [CONFIG_NAEXAMPLE setFont:configNAFont];
        }
    } else{
        configFont=[[NSFontManager sharedFontManager] convertFont:configFont];
        if (configFont!=nil) {
            [CONFIG_EXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configFont fontName], [configFont pointSize]]];
            [CONFIG_EXAMPLE setFont:configFont];
        }
    }
}

- (void)clearBuffer:(id)sender
{
    [currentPtySession clearBuffer];
}

- (void)clearScrollbackBuffer:(id)sender
{
    [currentPtySession clearScrollbackBuffer];
}

- (IBAction)logStart:(id)sender
{
    if (![[currentPtySession SHELL] logging]) [currentPtySession logStart];
}

- (IBAction)logStop:(id)sender
{
    if ([[currentPtySession SHELL] logging]) [currentPtySession logStop];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL logging = [[currentPtySession SHELL] logging];
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

    if([pref promptOnClose])
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
    sessionCount = [ptyList count];
    for (i = 0; i < sessionCount; i++)
    {
        if ([[ptyList objectAtIndex: i] exited]==NO) {
            [[[ptyList objectAtIndex: i] SHELL] stopNoWait];
        }
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
    

    [iTerm terminalWillClose: self];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidBecomeKey:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    [self selectSessionAtIndex: [self currentSessionIndex]];
    
    [iTerm setFrontPseudoTerminal: self];

    // update the cursor
    [[currentPtySession SCREEN] showCursor];
}

- (void) windowDidResignKey: (NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResignKey:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    [self windowDidResignMain: aNotification];

    // update the cursor
    [[currentPtySession SCREEN] showCursor];

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
    NSSize termSize, vsize;
    int i, w, h;


#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResize: width = %f, height = %f]",
	  __FILE__, __LINE__, [[self window] frame].size.width, [[self window] frame].size.height);
#endif

    // To prevent death by recursion
    if(resizeInProgress == YES)
    {
	resizeInProgress = NO;
	return;
    }

    resizeInProgress = YES;    

    frame = [[[currentPtySession SCROLLVIEW] contentView] frame];
#if 0
    NSLog(@"scrollview content size %.1f, %.1f, %.1f, %.1f",
	  frame.origin.x, frame.origin.y,
	  frame.size.width, frame.size.height);
#endif

    termSize = [VT100Screen screenSizeInFrame: frame font: [[currentPtySession SCREEN] tallerFont]];
    
    w = (int)(termSize.width);
    h = (int)(termSize.height);
    
    vsize = [VT100Screen requireSizeWithFont:[[currentPtySession SCREEN] tallerFont]
                                       width:w
                                      height:h];
    vsize.width = [[currentPtySession SCROLLVIEW] frame].size.width;

    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[ptyList objectAtIndex:i] SHELL] setWidth:w  height:h];
        //[[[ptyList objectAtIndex:i] SCROLLVIEW] setFrameSize:[TABVIEW contentRect].size];
    }
    
    WIDTH = w;
    HEIGHT = h;

    

    // this will cause a recursion, so we protect ourselves at the entry of the method.
    [self setWindowSize: NO];

    // Display the new size in the window title.
    NSString *aTitle = [NSString stringWithFormat:@"%@ (%d,%d)", [currentPtySession name], WIDTH, HEIGHT];
    [self setWindowTitle: aTitle];    

    // Reset the scrollbar to the bottom
    [[currentPtySession TEXTVIEW] scrollEnd];


    //NSLog(@"Didresize: w = %d, h = %d; frame.size.width = %f, frame.size.height = %f",WIDTH,HEIGHT, [[self window] frame].size.width, [[self window] frame].size.height);

    
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

// Config Window

- (BOOL) pending
{
    return pending;
}

- (IBAction)showConfigWindow:(id)sender
{
    int r;
    NSStringEncoding const *p=[iTerm encodingList];
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal showConfigWindow:%@]",
          __FILE__, __LINE__, sender);
#endif
    [CONFIG_FOREGROUND setColor:[[currentPtySession TERMINAL] defaultFGColor]];
    [CONFIG_BACKGROUND setColor:[[currentPtySession TERMINAL] defaultBGColor]];
    [CONFIG_SELECTION setColor:[[currentPtySession TEXTVIEW] selectionColor]];
    [CONFIG_BOLD setColor: [[currentPtySession TERMINAL] defaultBoldColor]];
    configFont=[[currentPtySession SCREEN] font];
    [CONFIG_EXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configFont fontName], [configFont pointSize]]];
    [CONFIG_EXAMPLE setTextColor:[[currentPtySession TERMINAL] defaultFGColor]];
    [CONFIG_EXAMPLE setBackgroundColor:[[currentPtySession TERMINAL] defaultBGColor]];
    [CONFIG_EXAMPLE setFont:configFont];
    configNAFont=[[currentPtySession SCREEN] nafont];
    [CONFIG_NAEXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configNAFont fontName], [configNAFont pointSize]]];
    [CONFIG_NAEXAMPLE setTextColor:[[currentPtySession TERMINAL] defaultFGColor]];
    [CONFIG_NAEXAMPLE setBackgroundColor:[[currentPtySession TERMINAL] defaultBGColor]];
    [CONFIG_NAEXAMPLE setFont:configNAFont];
    [CONFIG_COL setIntValue:WIDTH];
    [CONFIG_ROW setIntValue:HEIGHT];
    [CONFIG_NAME setStringValue:[self currentSessionName]];
    [CONFIG_ENCODING removeAllItems];
    r=0;
    while (*p) {
        //        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [CONFIG_ENCODING addItemWithTitle:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[[currentPtySession TERMINAL] encoding]) r=p-[iTerm encodingList];
        p++;
    }
    [CONFIG_ENCODING selectItemAtIndex:r];
    [CONFIG_TRANSPARENCY setIntValue:100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100];
    [CONFIG_TRANS2 setIntValue:100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100];
    [AI_ON setState:[[self currentSession] antiIdle]?NSOnState:NSOffState];
    [AI_CODE setIntValue:[[self currentSession] antiCode]];
    
    [CONFIG_ANTIALIAS setState: [[currentPtySession TEXTVIEW] antiAlias]];
    
//    [CONFIG_PANEL center];
    pending=YES;
    [NSApp beginSheet:CONFIG_PANEL modalForWindow:[TABVIEW window]
        modalDelegate:self didEndSelector:nil contextInfo:nil];
}


- (void) resizeWindow:(int) w height:(int)h
{
    int i;
    NSSize vsize;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal resizeWindow:%d,%d]",
          __FILE__, __LINE__, w, h);
#endif
    
    vsize = [VT100Screen requireSizeWithFont:[[currentPtySession SCREEN] tallerFont]
                                       width:w
                                      height:h];
    
    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[ptyList objectAtIndex:i] SHELL] setWidth:w height:h];
        [[[ptyList objectAtIndex:i] TEXTVIEW] setFrameSize:vsize];
    }
    WIDTH=w;
    HEIGHT=h;
    //NSLog(@"resize window: %d,%d",WIDTH,HEIGHT);

    [self setWindowSize: YES];
    
}

- (IBAction)windowConfigOk:(id)sender
{

    NSDictionary *defaultSessionPreferences = [iTerm defaultAddressBookEntry];

    
    if ([CONFIG_COL intValue]<1||[CONFIG_ROW intValue]<1) {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Wrong Input",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"Please enter a valid window size",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
    }else
    if ([AI_CODE intValue]>255||[AI_CODE intValue]<0) {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Wrong Input",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"Please enter a valid code (0~255)",@"iTerm", [NSBundle bundleForClass: [self class]], @"Anti-Idle: wrong input"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
    }else {
        [[self currentSession] setEncoding:[iTerm encodingList][[CONFIG_ENCODING indexOfSelectedItem]]];
        if ((configFont != nil&&[[currentPtySession SCREEN] font]!=configFont) ||
	    (configNAFont!= nil&&[[currentPtySession SCREEN] nafont]!=configNAFont)) {
            [self setAllFont:configFont nafont:configNAFont];
            [self resizeWindow:[CONFIG_COL intValue] height:[CONFIG_ROW intValue]];
        }

        // resiz the window if asked for
        if((WIDTH != [CONFIG_COL intValue]) || (HEIGHT != [CONFIG_ROW intValue]))
            [self resizeWindow:[CONFIG_COL intValue] height:[CONFIG_ROW intValue]];
        
        // set the anti-alias if it has changed
        if([CONFIG_ANTIALIAS state] != [[currentPtySession TEXTVIEW] antiAlias])
        {
            int i;
            PTYSession *aSession;
            
            for(i = 0; i < [ptyList count]; i++)
            {
                aSession = [ptyList objectAtIndex: i];
                [[aSession TEXTVIEW] setAntiAlias: [CONFIG_ANTIALIAS state]];
            }
            
            [[currentPtySession TEXTVIEW] setNeedsDisplay: YES];

        }
        
        // set the selection color if it has changed
        if([[currentPtySession TEXTVIEW] selectionColor] != [CONFIG_SELECTION color])
            [[currentPtySession TEXTVIEW] setSelectionColor: [CONFIG_SELECTION color]];

        // set the bold color if it has changed
        if([[currentPtySession TERMINAL] defaultBoldColor] != [CONFIG_BOLD color])
            [[currentPtySession TERMINAL] setBoldColor: [CONFIG_BOLD color]];	

        if(([[defaultSessionPreferences objectForKey: @"Transparency"] intValue] != (100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100)) || 
            ([[currentPtySession TERMINAL] defaultFGColor] != [CONFIG_FOREGROUND color]) || 
            ([[currentPtySession TERMINAL] defaultBGColor] != [CONFIG_BACKGROUND color]))
        {
            NSColor *bgColor;
                
            // set the background color for the scrollview with the appropriate transparency
            bgColor = [[CONFIG_BACKGROUND color] colorWithAlphaComponent: (1-[CONFIG_TRANSPARENCY intValue]/100.0)];
            [[currentPtySession SCROLLVIEW] setBackgroundColor: bgColor];
            [currentPtySession setForegroundColor:  [CONFIG_FOREGROUND color]];
            [currentPtySession setBackgroundColor:  bgColor];
            [[currentPtySession TEXTVIEW] setNeedsDisplay:YES];
        }

        [[[self currentSession] TEXTVIEW] scrollEnd];
        [self setCurrentSessionName: [CONFIG_NAME stringValue]]; 
    
        [CONFIG_PANEL setDelegate:CONFIG_PANEL];
        //    [CONFIG_PANEL close];
        pending=NO;

        [[self currentSession] setAntiCode:[AI_CODE intValue]];
        [[self currentSession] setAntiIdle:([AI_ON state]==NSOnState)];

        [CONFIG_PANEL orderOut:nil];
        [NSApp endSheet:CONFIG_PANEL];
        [[NSColorPanel sharedColorPanel] close];
        [[NSFontPanel sharedFontPanel] close];
    }
}

- (IBAction)windowConfigCancel:(id)sender
{
    [CONFIG_PANEL orderOut:nil];
    [NSApp endSheet:CONFIG_PANEL];
    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];

    pending=NO;
}

- (IBAction)windowConfigFont:(id)sender
{
    changingNA=NO;
    [[CONFIG_EXAMPLE window] makeFirstResponder:[CONFIG_EXAMPLE window]];
    [[CONFIG_EXAMPLE window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:configFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)windowConfigNAFont:(id)sender
{
    changingNA=YES;
    [[CONFIG_NAEXAMPLE window] makeFirstResponder:[CONFIG_NAEXAMPLE window]];
    [[CONFIG_NAEXAMPLE window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:configNAFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)windowConfigForeground:(id)sender
{
//    [self setFGColor:[sender color]];
//    [[NSColorPanel sharedColorPanel] close];
    [CONFIG_EXAMPLE setTextColor:[CONFIG_FOREGROUND color]];
}

- (IBAction)windowConfigBackground:(id)sender
{
//    [self setBGColor:[sender color]];
//    [[NSColorPanel sharedColorPanel] close];
    [CONFIG_EXAMPLE setBackgroundColor:[CONFIG_BACKGROUND color]];
}


//Toolbar related
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray* itemIdentifiers= [[[NSMutableArray alloc]init] autorelease];

    [itemIdentifiers addObject: NewToolbarItem];
    [itemIdentifiers addObject: ABToolbarItem];
    [itemIdentifiers addObject: ConfigToolbarItem];
    [itemIdentifiers addObject: NSToolbarSeparatorItemIdentifier];
    [itemIdentifiers addObject: NSToolbarCustomizeToolbarItemIdentifier];
    [itemIdentifiers addObject: CloseToolbarItem];
    [itemIdentifiers addObject: NSToolbarFlexibleSpaceItemIdentifier];

    return itemIdentifiers;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray* itemIdentifiers = [[[NSMutableArray alloc]init] autorelease];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal toolbarAllowedItemIdentifiers]", __FILE__, __LINE__);
#endif    

    [itemIdentifiers addObject: NewToolbarItem];
    [itemIdentifiers addObject: ABToolbarItem];
    [itemIdentifiers addObject: ConfigToolbarItem];
    [itemIdentifiers addObject: NSToolbarCustomizeToolbarItemIdentifier];
    [itemIdentifiers addObject: CloseToolbarItem];
    [itemIdentifiers addObject: NSToolbarFlexibleSpaceItemIdentifier];
    [itemIdentifiers addObject: NSToolbarSpaceItemIdentifier];
    [itemIdentifiers addObject: NSToolbarSeparatorItemIdentifier];

    return itemIdentifiers;
}
    
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
    NSString *imagePath;
    NSImage *anImage;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal itemForItemIdentifier]", __FILE__, __LINE__);
#endif    

    if ([itemIdent isEqual: ABToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"Bookmarks",@"iTerm", thisBundle, @"Toolbar Item:Bookmarks")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"Bookmarks",@"iTerm", thisBundle, @"Toolbar Item:Bookmarks")];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Open the bookmarks",@"iTerm", thisBundle, @"Toolbar Item Tip:Bookmarks")];
	imagePath = [thisBundle pathForResource:@"addressbook"
				    ofType:@"png"];
	anImage = [[NSImage alloc] initByReferencingFile: imagePath];
        [toolbarItem setImage: anImage];
	[anImage release];
        [toolbarItem setTarget: iTerm];
        [toolbarItem setAction: @selector(showABWindow:)];
    }
    else if ([itemIdent isEqual: CloseToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", thisBundle, @"Toolbar Item: Close Session")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", thisBundle, @"Toolbar Item: Close Session")];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Close the current session",@"iTerm", thisBundle, @"Toolbar Item Tip: Close")];
	imagePath = [thisBundle pathForResource:@"close"
							      ofType:@"png"];
	anImage = [[NSImage alloc] initByReferencingFile: imagePath];
        [toolbarItem setImage: anImage];
	[anImage release];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(closeCurrentSession:)];
    }
   else if ([itemIdent isEqual: ConfigToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"Configure",@"iTerm", thisBundle, @"Toolbar Item:Configure") ];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"Configure",@"iTerm", thisBundle, @"Toolbar Item:Configure") ];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Configure current window",@"iTerm", thisBundle, @"Toolbar Item Tip:Configure")];
	imagePath = [thisBundle pathForResource:@"config"
							      ofType:@"png"];
	anImage = [[NSImage alloc] initByReferencingFile: imagePath];
        [toolbarItem setImage: anImage];
	[anImage release];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(showConfigWindow:)];
    } 
    else if ([itemIdent isEqual: NewToolbarItem])
    {
        NSPopUpButton *aPopUpButton;

	if([toolbar sizeMode] == NSToolbarSizeModeSmall)
	{
	    aPopUpButton = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0.0, 0.0, 40.0, 24.0) pullsDown: YES];
	}
	else
	{
	    aPopUpButton = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0.0, 0.0, 48.0, 32.0) pullsDown: YES];
	}
        [aPopUpButton setTarget: self];
        [aPopUpButton setBordered: NO];
        [[aPopUpButton cell] setArrowPosition:NSPopUpArrowAtBottom];
	[toolbarItem setView: aPopUpButton];
        // Release the popup button since it is retained by the toolbar item.
        [aPopUpButton release];

	// build the menu
	[self _buildToolbarItemPopUpMenu: toolbarItem forToolbar: toolbar];

	[toolbarItem setMinSize:[aPopUpButton bounds].size];
	[toolbarItem setMaxSize:[aPopUpButton bounds].size];
	[toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", thisBundle, @"Toolbar Item:New")];
	[toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", thisBundle, @"Toolbar Item:New")];
	[toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Open a new session",@"iTerm", thisBundle, @"Toolbar Item:New")];

    }
    else { 
        toolbarItem=nil;
    }

    return toolbarItem;
}

- (NSToolbar *) setupToolbar;
{
    NSToolbar* toolbar;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setupToolbar]", __FILE__, __LINE__);
#endif    

    toolbar = [[NSToolbar alloc] initWithIdentifier: @"Terminal Toolbar"];
    [toolbar setVisible:true];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeDefault];
    [toolbar insertItemWithItemIdentifier: NewToolbarItem atIndex:0];
    [toolbar insertItemWithItemIdentifier: ABToolbarItem atIndex:1];
    [toolbar insertItemWithItemIdentifier: ConfigToolbarItem atIndex:2];
    [toolbar insertItemWithItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier atIndex:3];
    [toolbar insertItemWithItemIdentifier: NSToolbarCustomizeToolbarItemIdentifier atIndex:4];
    [toolbar insertItemWithItemIdentifier: NSToolbarSeparatorItemIdentifier atIndex:5];
    [toolbar insertItemWithItemIdentifier: CloseToolbarItem atIndex:6];


//    NSLog(@"Toolbar created");

    return [toolbar autorelease];
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
    [iTerm buildAddressBookMenu: abMenu forTerminal: (newWin?nil:self)];

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
    
    if (currentPtySession) [currentPtySession resetStatus];
    currentSessionIndex = [TABVIEW indexOfTabViewItem: tabViewItem];
    currentPtySession = aSession;
    [self setWindowTitle];
    [[TABVIEW window] makeFirstResponder:[currentPtySession TEXTVIEW]];
    [[TABVIEW window] setNextResponder:self];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: didSelectTabViewItem]", __FILE__, __LINE__);
#endif
    
    [currentPtySession setLabelAttribute];
    
}

- (void)tabView:(NSTabView *)tabView willRemoveTabViewItem:(NSTabViewItem *)tabViewItem
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal tabView: willRemoveTabViewItem]", __FILE__, __LINE__);
#endif
    
    [ptyListLock lock];
    if([ptyList containsObject: [tabViewItem identifier]] &&
       [[tabViewItem identifier] isKindOfClass: [PTYSession class]])
    {
	PTYSession *aSession = [tabViewItem identifier];
	[ptyList removeObject: aSession];
    }
    [ptyListLock unlock];

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
    
    [ptyListLock lock];
    if(![ptyList containsObject: [tabViewItem identifier]] &&
       [[tabViewItem identifier] isKindOfClass: [PTYSession class]])
    {
	PTYSession *aSession = [tabViewItem identifier];

	[aSession setParent: self];
	
	if (index >= [ptyList count])
	    [ptyList addObject: aSession];
	else
	    [ptyList insertObject: aSession atIndex: index];
    }
    [ptyListLock unlock];
    
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
    
    currentSessionIndex = [TABVIEW indexOfTabViewItem: [TABVIEW selectedTabViewItem]];

    if ([TABVIEW numberOfTabViewItems] == 1)
    {
	if([pref hideTab])
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
	    [TABVIEW setTabViewType: [pref tabViewType]];
	    [self setWindowSize: NO];
	}

    }
    else if([TABVIEW numberOfTabViewItems] == 2)
    {
	[TABVIEW setTabViewType: [pref tabViewType]];
	[self setWindowSize: NO];
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
    if([ptyList count] > 1)
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
    term = [[PseudoTerminal alloc] init];
    if(term == nil)
	return;

    [iTerm addInTerminals: term];

    if([term windowInited] == NO)
    {
	[term setWidth: WIDTH height: HEIGHT];
	[term setFont: FONT nafont: NAFONT];
	[term initWindow];
    }


    [term release];
    
    [term setPreference:pref];


    // If this is the current session, make previous one active.
    if(aSession == currentPtySession)
    {
	[self selectSessionAtIndex: (currentSessionIndex - 1)];
    }

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

- (iTermController *) iTerm;
{
    return (iTerm);
}

- (void) setITermController:(id) sender
{
    iTerm=sender;
}


// Preferences
- (void)setPreference:(id)preference;
{
    pref=preference;
}

- (id) preference
{
    return (pref);
}

- (IBAction)saveSession:(id)sender
{
    NSMutableDictionary *currentABEntry;

    currentABEntry=[NSMutableDictionary dictionaryWithDictionary:[currentPtySession addressBookEntry]];

    if(currentABEntry != nil)
    {
	[currentABEntry setObject: [NSNumber numberWithUnsignedInt:[[currentPtySession TERMINAL] encoding]] forKey: @"Encoding"];
	[currentABEntry setObject: [currentPtySession foregroundColor] forKey: @"Foreground"];
	[currentABEntry setObject: [currentPtySession backgroundColor] forKey: @"Background"];
	[currentABEntry setObject: [currentPtySession boldColor] forKey: @"BoldColor"];
	[currentABEntry setObject: [currentPtySession selectionColor] forKey: @"SelectionColor"];
	[currentABEntry setObject: [NSString stringWithInt:WIDTH] forKey: @"Col"];
	[currentABEntry setObject: [NSString stringWithInt:HEIGHT] forKey: @"Row"];
	[currentABEntry setObject: [NSNumber numberWithInt:100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100] forKey: @"Transparency"];
	[currentABEntry setObject: [[self currentSession] TERM_VALUE] forKey: @"Term Type"];
	[currentABEntry setObject: [[currentPtySession SCREEN] font] forKey: @"Font"];
	[currentABEntry setObject: [[currentPtySession SCREEN] nafont] forKey: @"NAFont"];
	[currentABEntry setObject: [NSNumber numberWithBool:[[self currentSession] antiIdle]] forKey: @"AntiIdle"];
	[currentABEntry setObject: [NSNumber numberWithUnsignedInt:[[self currentSession] antiCode]] forKey: @"AICode"];
	[currentABEntry setObject: [[currentPtySession SCREEN] nafont] forKey: @"NAFont"];

	[[iTerm addressBook] replaceObjectAtIndex: [[iTerm addressBook] indexOfObject: [currentPtySession addressBookEntry]] withObject: currentABEntry];

	NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Configuration saved",@"iTerm", [NSBundle bundleForClass: [self class]], @"Config"),
		 [currentABEntry objectForKey:@"Name"],
		 NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
		 nil,nil);
	
    }
    else
    {
	NSMutableDictionary *new;
	
	new=[[NSMutableDictionary alloc] initWithObjectsAndKeys:
	    [currentPtySession name],@"Name",
	    [[currentPtySession SHELL] path],@"Command",
	    [NSNumber numberWithUnsignedInt:[[currentPtySession TERMINAL] encoding]],@"Encoding",
	    [currentPtySession foregroundColor],@"Foreground",
	    [currentPtySession backgroundColor],@"Background",
	    [currentPtySession boldColor],@"BoldColor",
	    [currentPtySession selectionColor],@"SelectionColor",
	    [NSString stringWithInt:WIDTH],@"Col",
	    [NSString stringWithInt:HEIGHT],@"Row",
	    [NSNumber numberWithInt:100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100],@"Transparency",
	    [[self currentSession] TERM_VALUE],@"Term Type",
	    @"",@"Directory",
	    [[currentPtySession SCREEN] font],@"Font",
	    [[currentPtySession SCREEN] nafont],@"NAFont",
	    [NSNumber numberWithBool:[[self currentSession] antiIdle]],@"AntiIdle",
	    [NSNumber numberWithUnsignedInt:[[self currentSession] antiCode]],@"AICode",
	    [NSNumber numberWithBool:[[self currentSession] autoClose]],@"AutoClose",
	    [NSNumber numberWithBool:[[self currentSession] doubleWidth]],@"DoubleWidth",
	    NULL];
        [iTerm addAddressBookEntry: new];
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Configuration saved as a new entry in Bookmarks",@"iTerm", [NSBundle bundleForClass: [self class]], @"Config"),
                        [new objectForKey:@"Name"],
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
	[new release];
	[currentPtySession setAddressBookEntry: new];
    }
    [iTerm saveAddressBook];

    
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
	if([ptyList count] > 0)
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
	if([ptyList count] > 0)
	    [self setWindowSize: NO];
    }
}

// accessors for to-many relationships:
-(NSArray*)sessions
{
    return (ptyList);
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
    return ([ptyList objectAtIndex: index]);
}

-(id)valueWithName: (NSString *)uniqueName inPropertyWithKey: (NSString*)propertyKey
{
    id result = nil;
    int i;

    if([propertyKey isEqualToString: sessionsKey] == YES)
    {
	PTYSession *aSession;
	
	for (i= 0; i < [ptyList count]; i++)
	{
	    aSession = [ptyList objectAtIndex: i];
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

	for (i= 0; i < [ptyList count]; i++)
	{
	    aSession = [ptyList objectAtIndex: i];
	    if([[aSession tty] isEqualToString: uniqueID] == YES)
		return (aSession);
	}
    }
    
    return result;
}



-(void)replaceInSessions:(PTYSession *)object atIndex:(unsigned)index
{
    // NSLog(@"PseudoTerminal: -replaceInSessions: 0x%x atIndex: %d", object, index);
    [ptyList replaceObjectAtIndex: index withObject: object];
}

-(void)addInSessions:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -addInSessions: 0x%x", object);
    [self insertInSessions: object];
}

-(void)insertInSessions:(PTYSession *)object
{
    // NSLog(@"PseudoTerminal: -insertInSessions: 0x%x", object);
    [self insertInSessions: object atIndex: [ptyList count]];
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
    if(index < [ptyList count])
    {
	PTYSession *aSession = [ptyList objectAtIndex: index];
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

    NSArray *terminals = [[self iTerm] terminals];
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
    } else {
        return nil;
    }

}

// Handlers for supported commands:
-(void)handleLaunchScriptCommand: (NSScriptCommand *)command
{
    // Get the command's arguments:
    NSDictionary *args = [command evaluatedArguments];
    NSString *session = [args objectForKey:@"session"];
    NSDictionary *abEntry;

    NSArray *abArray;
    int i;
    
    // search for the session in the addressbook
    abArray = [iTerm addressBookNames];
    for (i = 0; i < [abArray count]; i++)
    {
	if([[abArray objectAtIndex: i] caseInsensitiveCompare: session] == NSOrderedSame)
	{
	    break;
	}
    }
    if(i == [abArray count])
	i = 0; // index of default session
    abEntry = [iTerm addressBookEntry: i];

    // If we have not set up a window, do it now
    if([self windowInited] == NO)
    {

	[self setWidth: [[abEntry objectForKey: @"Col"] intValue]
				height: [[abEntry objectForKey: @"Row"] intValue]];
	[self setFont: [abEntry objectForKey: @"Font"]
			       nafont: [abEntry objectForKey: @"NAFont"]];
	[self initWindow];
    }

    // launch the session!
    [iTerm executeABCommandAtIndex: i inTerminal: self];
    
    return;
}

@end

// Private interface
@implementation PseudoTerminal (Private)

- (void) _buildToolbarItemPopUpMenu: (NSToolbarItem *) toolbarItem forToolbar: (NSToolbar *)toolbar
{
    NSPopUpButton *aPopUpButton;
    NSMenuItem *item;
    NSMenu *aMenu;
    id newwinItem;
    NSString *imagePath;
    NSImage *anImage;
    NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal _buildToolbarItemPopUpMenu]",
          __FILE__, __LINE__);
#endif
    

    if (toolbarItem == nil)
	return;
    
    aPopUpButton = (NSPopUpButton *)[toolbarItem view];
    //[aPopUpButton setAction: @selector(_addressbookPopupSelectionDidChange:)];
    [aPopUpButton setAction: nil];
    [aPopUpButton removeAllItems];
    [aPopUpButton addItemWithTitle: @""];

    [iTerm buildAddressBookMenu: [aPopUpButton menu] forTerminal: (newwin?nil:self)];

    [[aPopUpButton menu] addItem: [NSMenuItem separatorItem]];
    [[aPopUpButton menu] addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Open in a new window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New") action: @selector(_toggleNewWindowState:) keyEquivalent: @""];
    newwinItem=[aPopUpButton lastItem];
    [newwinItem setState:(newwin ? NSOnState : NSOffState)];    
    
    // Now set the icon
    item = [[aPopUpButton cell] menuItem];
    imagePath = [thisBundle pathForResource:@"newwin"
								 ofType:@"png"];
    anImage = [[NSImage alloc] initByReferencingFile: imagePath];
    [toolbarItem setImage: anImage];
    [anImage release];
    [anImage setScalesWhenResized:YES];
    if([toolbar sizeMode] == NSToolbarSizeModeSmall)
    {
	[anImage setSize:NSMakeSize(24.0, 24.0)];
    }
    else
    {
	[anImage setSize:NSMakeSize(30.0, 30.0)];
    }
    [item setImage:anImage];
    [item setOnStateImage:nil];
    [item setMixedStateImage:nil];
    [aPopUpButton setPreferredEdge:NSMinXEdge];
    [[[aPopUpButton menu] menuRepresentation] setHorizontalEdgePadding:0.0];

    // build a menu representation for text only.
    item = [[NSMenuItem alloc] initWithTitle: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item:New") action: nil keyEquivalent: @""];
    aMenu = [[NSMenu alloc] initWithTitle: @"Bookmarks"];
    [iTerm buildAddressBookMenu: aMenu forTerminal: (newwin?nil:self)];
    [aMenu addItem: [NSMenuItem separatorItem]];
    [aMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Open in a new window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New") action: @selector(_toggleNewWindowState:) keyEquivalent: @""];
    newwinItem=[aMenu itemAtIndex: ([aMenu numberOfItems] - 1)];
    [newwinItem setState:(newwin ? NSOnState : NSOffState)];
    
    [item setSubmenu: aMenu];
    [aMenu release];
    [toolbarItem setMenuFormRepresentation: item];
    [item release];
    
}


// Reloads the addressbook entries into the popup toolbar item
- (void) _reloadAddressBookMenu: (NSNotification *) aNotification
{
    NSArray *toolbarItemArray;
    NSToolbarItem *aToolbarItem;
    int i;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal _reloadAddressBookMenu]",
          __FILE__, __LINE__);
#endif
    
    toolbarItemArray = [[[self window] toolbar] items];
    
    // Find the addressbook popup item and reset it
    for(i = 0; i < [toolbarItemArray count]; i++)
    {
        aToolbarItem = [toolbarItemArray objectAtIndex: i];
        
        if([[aToolbarItem itemIdentifier] isEqual: NewToolbarItem])
        {
            [self _buildToolbarItemPopUpMenu: aToolbarItem forToolbar: [[self window] toolbar]];
                        
            break;
        }
        
    }
    
}

- (void) _toggleNewWindowState: (id) sender
{
    newwin = !newwin;
    [self _reloadAddressBookMenu: nil];
    // Save our latest preference on where to open new sessions
    [[NSUserDefaults standardUserDefaults] setBool: newwin forKey:@"SESSION_IN_NEW_WINDOW"];    
}



@end
