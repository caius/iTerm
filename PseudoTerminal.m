// -*- mode:objc -*-
// $Id: PseudoTerminal.m,v 1.118 2003-02-26 17:30:35 yfabian Exp $
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

#define USE_CUSTOM_DRAWING	1

#import "PseudoTerminal.h"
#import "PTYScrollView.h"
#import "NSStringITerm.h"
#import "PTYSession.h"
#import "VT100Screen.h"
#import "PTYTabView.h"
#import "PTYTabViewItem.h"

@implementation PseudoTerminal

#define NIB_PATH  @"PseudoTerminal"

static NSString *NewToolbarItem = @"New";
static NSString *ABToolbarItem = @"Address";
static NSString *CloseToolbarItem = @"Close";
static NSString *ConfigToolbarItem = @"Config";


+ (PseudoTerminal *)newTerminalWindow: (id) sender
{
    PseudoTerminal *term;
    static int windowCount = 0;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal newTerminal]", __FILE__, __LINE__);
#endif
    term = [[PseudoTerminal alloc] init];
    [term setMainMenu:sender];
    if (term == nil)
	return nil;
    if ([NSBundle loadNibNamed:NIB_PATH owner:term] == NO)
	return nil;
    // save up to 10 window positions
    if(windowCount++ < 10)
    {
	[[term window] setFrameAutosaveName: [NSString stringWithFormat: @"iTerm Window %d", windowCount]];
    }
    [[term window] setToolbar:[term setupToolbar]];
    #if 0
    if (lastwindow) {
        NSRect rect;
        rect=[lastwindow frame];
        [[term window] setFrameTopLeftPoint:[[term window] cascadeTopLeftFromPoint:NSMakePoint(rect.origin.x,rect.origin.y+rect.size.height)]];
    }
    lastwindow=[term window];
    #endif
        
    [sender addTerminalWindow: term];

    return term;
}

- (void) newSession: (id) sender
{
    NSString *cmd;
    NSArray *arg;

    [MainMenu breakDown:[pref shell] cmdPath:&cmd cmdArgs:&arg];

    [self initSession:nil
     foregroundColor:[[currentPtySession TERMINAL] defaultFGColor]
     backgroundColor:[[[currentPtySession TERMINAL] defaultBGColor] colorWithAlphaComponent: [[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]]
     selectionColor: [pref selectionColor]
            encoding:[pref encoding]
                term:[pref terminalType]];
    [self startProgram:cmd arguments:arg];
    [self setCurrentSessionName:nil];
    [currentPtySession setAutoClose: [pref autoclose]];
    [currentPtySession setDoubleWidth:[pref doubleWidth]];

}

- (id)init
{
    if ((self = [super init]) == nil)
	return nil;


    // Allocate a list for our sessions
    ptyList = [[NSMutableArray alloc] init];
    ptyListLock = [[NSLock alloc] init];

    // Read the preference on whether to open new sessions in new tabs or windows
    newwin = [[NSUserDefaults standardUserDefaults] boolForKey:@"SESSION_IN_NEW_WINDOW"];

    tabViewDragOperationInProgress = NO;

#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PseudoTerminal init: 0x%x]", __FILE__, __LINE__, self);
#endif
    
    return self;
}

- (void)initWindow:(int)width
            height:(int)height
              font:(NSFont *)font
            nafont:(NSFont *)nafont
{
    WIDTH=width;
    HEIGHT=height;
    NSRect tabviewRect;
//    NSColor *bgColor;

    if (!font)
        font = [pref font];
    if (!nafont)
        nafont=font;
    
    NSParameterAssert(font != nil);

    if (FONT) [FONT autorelease];
    FONT=[[font copy] retain];
    if (NAFONT) [NAFONT autorelease];
    NAFONT=[[nafont copy] retain];
    
    // Create the tabview
    tabviewRect = [[WINDOW contentView] frame];
    tabviewRect.origin.x -= 10;
    tabviewRect.size.width += 20;
    tabviewRect.origin.y -= 13;
    tabviewRect.size.height += 17;
    TABVIEW = [[PTYTabView alloc] initWithFrame: tabviewRect];
    [TABVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    [TABVIEW setAllowsTruncatedLabels: NO];
    [TABVIEW setControlSize: NSSmallControlSize];
    // Add to the window
    [[WINDOW contentView] addSubview: TABVIEW];
    [[WINDOW contentView] setAutoresizesSubviews: YES];
    [TABVIEW release];
        
    [WINDOW setDelegate: self];
    
    // Add ourselves as an observer for notifications to reload the addressbook.
    [[NSNotificationCenter defaultCenter] addObserver: self
        selector: @selector(_reloadAddressBookMenu:)
        name: @"Reload AddressBook"
        object: nil];
         
}

- (void)initSession:(NSString *)title
   foregroundColor:(NSColor *) fg
   backgroundColor:(NSColor *) bg
   selectionColor:(NSColor *) sc
          encoding:(NSStringEncoding)encoding
              term:(NSString *)term
{
    PTYSession *aSession;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal initSession]",
          __FILE__, __LINE__);
#endif

    // Allocate a new session
    aSession = [[PTYSession alloc] init];
    NSParameterAssert(aSession != nil);    
    
    // Init the rest of the session
    [aSession setParent: self];
    [aSession setPreference: pref];
    [aSession setMainMenu: MAINMENU];
    [aSession initScreen: [TABVIEW contentRect]];

    // set the srolling
    [[aSession SCROLLVIEW] setLineScroll: ([VT100Screen fontSize: FONT].height)];
    [[aSession SCROLLVIEW] setVerticalLineScroll: ([VT100Screen fontSize: FONT].height)];
    
    // Set the bell option
    [VT100Screen setPlayBellFlag: ![pref silenceBell]];
        
    // Set the colors
    if (fg) [aSession setFGColor:fg];
    if (bg) [aSession setBGColor:bg];
    if (sc) 
        [[aSession TEXTVIEW] setSelectionColor: sc];
    else
        [[aSession TEXTVIEW] setSelectionColor: [pref selectionColor]];
    [[aSession SCROLLVIEW] setBackgroundColor: bg];

    // set the font
    [[aSession TEXTVIEW]  setFont:FONT];
    [[aSession SCREEN]  setFont:FONT nafont:NAFONT];

    // set the terminal type
    if (term) 
    {
        [aSession setTERM_VALUE: term];
    }
    else 
    {
        [aSession setTERM_VALUE: [pref terminalType]];
    }

    // assign terminal and task objects
    [[aSession SCREEN] setTerminal:[aSession TERMINAL]];
    [[aSession SCREEN] setShellTask:[aSession SHELL]];
#if USE_CUSTOM_DRAWING
    [[aSession TEXTVIEW] setDataSource: [aSession SCREEN]];
    [[aSession SCREEN] setDisplay:[aSession TEXTVIEW]];
    [[aSession TEXTVIEW] setLineHeight: [VT100Screen fontSize: FONT].height];
    [[aSession TEXTVIEW] setLineWidth: WIDTH * [VT100Screen fontSize: FONT].width];
#else
    [[aSession SCREEN] setTextStorage:[[aSession TEXTVIEW] textStorage]];
#endif
    [[aSession SCREEN] setWindow:WINDOW];
    [[aSession SCREEN] setWidth:WIDTH height:HEIGHT];
//    NSLog(@"%d,%d",WIDTH,HEIGHT);

    // initialize the screen
    [[aSession SCREEN] initScreen];
    [aSession startTimer];

    // set the encoding
    [[aSession TERMINAL] setEncoding:encoding];
    [[aSession TERMINAL] setTrace:YES];	// debug vt100 escape sequence decode

    // tell the shell about our size
    [[aSession SHELL] setWidth:WIDTH  height:HEIGHT];

    pending = NO;

    // Add this session to our list and make it current
    [self addSession: aSession];
    [aSession release];
    [self setCurrentSessionName: nil];    
    
    if (title) 
    {
        [self setWindowTitle: title];
        [aSession setName: title];
    }
             
}

- (void) switchSession: (id) sender
{
    [self selectSession: [sender tag]];
}

- (void) selectSession: (int) sessionIndex
{
    PTYSession *aSession;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal selectSession:%d]",
          __FILE__, __LINE__, sessionIndex);
#endif
    
    if (sessionIndex<0||sessionIndex >= [ptyList count]) return;

    aSession = [ptyList objectAtIndex: sessionIndex];
    [TABVIEW selectTabViewItemWithIdentifier: aSession];
    if (currentPtySession) [currentPtySession resetStatus];
    currentSessionIndex = sessionIndex;
    currentPtySession = aSession;
    [self setWindowTitle];
    [currentPtySession setLabelAttribute];
    [WINDOW makeFirstResponder:[currentPtySession TEXTVIEW]];
    [WINDOW setNextResponder:self];

}

- (void) addSession: (PTYSession *) aSession
{
    PTYTabViewItem *aTabViewItem;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal addSession:]",
          __FILE__, __LINE__, sessionIndex);
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
	[TABVIEW addTabViewItem: aTabViewItem];
	currentSessionIndex = [ptyList count] - 1;
	currentPtySession = aSession;
	[aTabViewItem release];
	[aSession setTabViewItem: aTabViewItem];
	[self selectSession: currentSessionIndex];

	if ([TABVIEW numberOfTabViewItems] == 1)
	{
	    [[aSession TEXTVIEW] scrollRangeToVisible: NSMakeRange([[[aSession TEXTVIEW] string] length] - 1, 1)];
	}

	[WINDOW makeKeyAndOrderFront: self];
	
    }
}

- (void) closeSession: (PTYSession*) aSession
{
    int i;
    int n=[ptyList count];
    
    if((ptyList == nil) || ([ptyList containsObject: aSession] == NO))
        return;
    
    if(n == 1)
    {
        [WINDOW close];
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
                [self selectSession: currentSessionIndex];
            }
            else if (i<currentSessionIndex) currentSessionIndex--;
            
                        
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
       if (![pref autoclose] && 
            NSRunAlertPanel(NSLocalizedStringFromTable(@"The current session will be closed",@"iTerm",@"Close Session"),
                         NSLocalizedStringFromTable(@"All unsaved data will be lost",@"iTerm",@"Close window"),
                         NSLocalizedStringFromTable(@"Cancel",@"iTerm",@"Cancel"),
                         NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK")
                         ,nil)) return;
                         
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
    [self selectSession: theIndex];    
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
    
    [self selectSession: theIndex];

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

    if ([[WINDOW title] compare:@"Window"]==NSOrderedSame) [self setWindowTitle];

//    [window center];
    [WINDOW makeKeyAndOrderFront:self];

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

    if ([[WINDOW title] compare:@"Window"]==NSOrderedSame) [self setWindowTitle];

//    [window center];
    [WINDOW makeKeyAndOrderFront:self];

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

    if ([[WINDOW title] compare:@"Window"]==NSOrderedSame) [self setWindowTitle];

    //    [window center];
    [WINDOW makeKeyAndOrderFront:self];

}


- (void)setWindowSize: (BOOL) resizeContentFrames
{
    NSSize size, vsize, winSize;
    NSWindow *thisWindow;
    int i;
    NSRect tabviewRect;

    // Resize the tabview first if necessary
    if([TABVIEW tabViewType] == NSTopTabsBezelBorder)
    {
	tabviewRect = [[WINDOW contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 20;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 10;
    }
    else if([TABVIEW tabViewType] == NSLeftTabsBezelBorder)
    {
	tabviewRect = [[WINDOW contentView] frame];
	tabviewRect.origin.x += 2;
	tabviewRect.size.width += 8;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 20;
    }
    else if([TABVIEW tabViewType] == NSBottomTabsBezelBorder)
    {
	tabviewRect = [[WINDOW contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 20;
	tabviewRect.origin.y += 2;
	tabviewRect.size.height += 5;
    }
    else if([TABVIEW tabViewType] == NSRightTabsBezelBorder)
    {
	tabviewRect = [[WINDOW contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 8;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 20;
    }
    else
    {
	tabviewRect = [[WINDOW contentView] frame];
	tabviewRect.origin.x -= 10;
	tabviewRect.size.width += 20;
	tabviewRect.origin.y -= 13;
	tabviewRect.size.height += 20;
    }
    [TABVIEW setFrame: tabviewRect];


#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowSize]", __FILE__, __LINE__ );
#endif
    vsize = [VT100Screen requireSizeWithFont:[[currentPtySession SCREEN] font]
				      width:WIDTH
				     height:HEIGHT];

    
    size = [PTYScrollView frameSizeForContentSize:vsize
			    hasHorizontalScroller:NO
			      hasVerticalScroller:YES
			   	       borderType:NSNoBorder];

    for (i = 0; i < [TABVIEW numberOfTabViewItems]; i++)
    {
        [(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setLineScroll: ([VT100Screen fontSize: FONT].height)];
[(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setVerticalLineScroll: ([VT100Screen fontSize: FONT].height)];
	if(resizeContentFrames)
	{
	    [(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setFrameSize: size];
	    [[(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] documentView] setFrameSize:vsize];
	}
    }

    thisWindow = [[currentPtySession SCROLLVIEW] window];
    winSize = size;
    if([TABVIEW tabViewType] == NSTopTabsBezelBorder)
	winSize.height = size.height + 29;
    else if([TABVIEW tabViewType] == NSLeftTabsBezelBorder)
	winSize.width = size.width + 25;
    else if([TABVIEW tabViewType] == NSBottomTabsBezelBorder)
	winSize.height = size.height + 29;
    else if([TABVIEW tabViewType] == NSRightTabsBezelBorder)
	winSize.width = size.width + 25;
    else
        winSize.height = size.height + 0;
    [thisWindow setContentSize:winSize];
}


- (void)setWindowTitle
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowTitle]",
          __FILE__, __LINE__);
#endif

    [WINDOW setTitle:[self currentSessionName]];
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowTitle: exiting]",
          __FILE__, __LINE__);
#endif

}

- (void) setWindowTitle: (NSString *)title
{
    [WINDOW setTitle:title];
}

- (void)setAllFont:(NSFont *)font nafont:(NSFont *) nafont
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setAllFont:%@]",
	  __FILE__, __LINE__, font);
#endif
    int i;

    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] TEXTVIEW]  setFont:font];
        [[[ptyList objectAtIndex:i] SCREEN]  setFont:font nafont:nafont];
    }
    if (FONT) [FONT autorelease];
    FONT=[[font copy] retain];
    if (NAFONT) [NAFONT autorelease];
    NAFONT=[[nafont copy] retain];
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
    return [self showCloseWindow];
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
    [MAINMENU removeTerminalWindow: self];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidBecomeKey:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    [MAINMENU setFrontPseudoTerminal: self];    
}

- (void) windowDidResignKey: (NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResignKey:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    [self windowDidResignMain: aNotification];

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

#if 0

    return (proposedFrameSize);

#else

    NSSize winSize, contentSize, scrollviewSize, textviewSize;
    int h;

    // This calculation ensures that the window size is pruned to display an interger number of lines.

    // Calculate the content size
    contentSize = [NSWindow contentRectForFrameRect: NSMakeRect(0, 0, proposedFrameSize.width, proposedFrameSize.height) styleMask: [WINDOW styleMask]].size;
    //NSLog(@"content size: width = %f; height = %f", contentSize.width, contentSize.height);
    
    // Calculate scrollview size
    scrollviewSize = contentSize;
    if([TABVIEW tabViewType] == NSTopTabsBezelBorder)
	scrollviewSize.height = contentSize.height - 29;
    else if([TABVIEW tabViewType] == NSLeftTabsBezelBorder)
	scrollviewSize.width = contentSize.width - 25;
    else if([TABVIEW tabViewType] == NSBottomTabsBezelBorder)
	scrollviewSize.height = contentSize.height - 29;
    else if([TABVIEW tabViewType] == NSRightTabsBezelBorder)
	scrollviewSize.width = contentSize.width - 25;
    else
        scrollviewSize.height = contentSize.height - 0;    
    //NSLog(@"scrollview size: width = %f; height = %f", scrollviewSize.width, scrollviewSize.height);

    
    // Calculate textview size
    textviewSize = [PTYScrollView contentSizeForFrameSize:scrollviewSize
			    hasHorizontalScroller:NO
			      hasVerticalScroller:YES
			   	       borderType:NSNoBorder];
    //NSLog(@"textview size: width = %f; height = %f", textviewSize.width, textviewSize.height);

                                       
    // Now calculate an appropriate terminal height for this in integers.
    h = floor(textviewSize.height/[VT100Screen requireSizeWithFont: [[currentPtySession SCREEN] font]].height);
    //NSLog(@"h = %d", h);
    
    // Now do the reverse calculation
    
    // Calculate the textview size
    textviewSize.height = h*[VT100Screen requireSizeWithFont: [[currentPtySession SCREEN] font]].height;
    //NSLog(@"textview size: width = %f; height = %f", textviewSize.width, textviewSize.height);

    // Calculate scrollview size
    scrollviewSize = [PTYScrollView frameSizeForContentSize:textviewSize
			    hasHorizontalScroller:NO
			      hasVerticalScroller:YES
			   	       borderType:NSNoBorder];
    //NSLog(@"scrollview size: width = %f; height = %f", scrollviewSize.width, scrollviewSize.height);

    // Calculate the window content size
    contentSize = scrollviewSize;
    if([TABVIEW tabViewType] == NSTopTabsBezelBorder)
	contentSize.height = scrollviewSize.height + 29;
    else if([TABVIEW tabViewType] == NSLeftTabsBezelBorder)
	contentSize.width = scrollviewSize.width + 25;
    else if([TABVIEW tabViewType] == NSBottomTabsBezelBorder)
	contentSize.height = scrollviewSize.height + 29;
    else if([TABVIEW tabViewType] == NSRightTabsBezelBorder)
	contentSize.width = scrollviewSize.width + 25;
    else
	contentSize.height = scrollviewSize.height + 0;    
    //NSLog(@"content size: width = %f; height = %f", contentSize.width, contentSize.height);
    
    // Finally calculate the window frame size
    winSize = [NSWindow frameRectForContentRect: NSMakeRect(0, 0, contentSize.width, contentSize.height) styleMask: [WINDOW styleMask]].size;
    //NSLog(@"window size: width = %f; height = %f", winSize.width, winSize.height);
        
    return (winSize);
    
#endif

}

- (void)windowDidResize:(NSNotification *)aNotification
{
    NSRect frame;
    NSSize termSize, vsize;
    int i, w, h;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResize: width = %f, height = %f]",
	  __FILE__, __LINE__, [WINDOW frame].size.width, [WINDOW frame].size.height);
#endif

    frame = [[[currentPtySession SCROLLVIEW] contentView] frame];
#if 0
    NSLog(@"scrollview content size %.1f, %.1f, %.1f, %.1f",
	  frame.origin.x, frame.origin.y,
	  frame.size.width, frame.size.height);
#endif

    termSize = [VT100Screen screenSizeInFrame: frame font: [[currentPtySession SCREEN] font]];
    
    w = (int)(termSize.width);
    h = (int)(termSize.height);
    
    vsize = [VT100Screen requireSizeWithFont:[[currentPtySession SCREEN] font]
                                       width:w
                                      height:h];

    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[ptyList objectAtIndex:i] SHELL] setWidth:w  height:h];
        //[[[ptyList objectAtIndex:i] TEXTVIEW] setFrameSize:vsize];
    }
    
    WIDTH = w;
    HEIGHT = h;
    
    //NSLog(@"w = %d, h = %d; frame.size.width = %f, frame.size.height = %f",WIDTH,HEIGHT, [WINDOW frame].size.width, [WINDOW frame].size.height);


}


// Close Window
- (BOOL)showCloseWindow
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal showCloseWindow]", __FILE__, __LINE__);
#endif

    return (NSRunAlertPanel(NSLocalizedStringFromTable(@"Close Window?",@"iTerm",@"Close window"),
                            NSLocalizedStringFromTable(@"All sessions will be closed",@"iTerm",@"Close window"),
                            NSLocalizedStringFromTable(@"Cancel",@"iTerm",@"Cancel"),
                            NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK")
                            ,nil)==0);
}

// Config Window

- (BOOL) pending
{
    return pending;
}

- (IBAction)showConfigWindow:(id)sender
{
    int r;
    NSStringEncoding const *p=[MAINMENU encodingList];
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal showConfigWindow:%@]",
          __FILE__, __LINE__, sender);
#endif
    [CONFIG_FOREGROUND setColor:[[currentPtySession TERMINAL] defaultFGColor]];
    [CONFIG_BACKGROUND setColor:[[currentPtySession TERMINAL] defaultBGColor]];
    [CONFIG_SELECTION setColor:[[currentPtySession TEXTVIEW] selectionColor]];
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
        [CONFIG_ENCODING addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[[currentPtySession TERMINAL] encoding]) r=p-[MAINMENU encodingList];
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
    [NSApp beginSheet:CONFIG_PANEL modalForWindow:WINDOW
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
    
    vsize = [VT100Screen requireSizeWithFont:[[currentPtySession SCREEN] font]
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
    if ([CONFIG_COL intValue]<1||[CONFIG_ROW intValue]<1) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid window size",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
    }else
    if ([AI_CODE intValue]>255||[AI_CODE intValue]<0) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid code (0~255)",@"iTerm",@"Anti-Idle: wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
    }else {
        [[self currentSession] setEncoding:[MAINMENU encodingList][[CONFIG_ENCODING indexOfSelectedItem]]];
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
            
        if(([pref transparency] != (100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100)) || 
            ([[currentPtySession TERMINAL] defaultFGColor] != [CONFIG_FOREGROUND color]) || 
            ([[currentPtySession TERMINAL] defaultBGColor] != [CONFIG_BACKGROUND color]))
        {
            NSColor *bgColor;
/*            int i;
            PTYSession *aSession; */
                
            // set the background color for the scrollview with the appropriate transparency
            bgColor = [[CONFIG_BACKGROUND color] colorWithAlphaComponent: (1-[CONFIG_TRANSPARENCY intValue]/100.0)];
            [[currentPtySession SCROLLVIEW] setBackgroundColor: bgColor];
            [currentPtySession setFGColor:  [CONFIG_FOREGROUND color]];
            [currentPtySession setBGColor:  bgColor]; 
            
/*            // Change the transparency for all the sessions.
            if([pref transparency] != (100-[[TERMINAL defaultBGColor] alphaComponent]*100))
            {
                for(i = 0; i < [ptyList count]; i++)
                {
                    aSession = [ptyList objectAtIndex: i];
                    [aSession setBackgroundAlpha: (1-[CONFIG_TRANSPARENCY intValue]/100.0)];
                }
            } */
            [[currentPtySession SCROLLVIEW] setNeedsDisplay: YES];
            
        }

        [[[self currentSession] TEXTVIEW] moveLastLine];
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

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal itemForItemIdentifier]", __FILE__, __LINE__);
#endif    

    if ([itemIdent isEqual: ABToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Address Book",@"iTerm",@"Toolbar Item:Address Book")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Address Book",@"iTerm",@"Toolbar Item:Address Book")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Open the address book",@"iTerm",@"Toolbar Item Tip:Address Book")];
        [toolbarItem setImage: [NSImage imageNamed: @"addressbook"]];
        [toolbarItem setTarget: MAINMENU];
        [toolbarItem setAction: @selector(showABWindow:)];
    }
    else if ([itemIdent isEqual: CloseToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Close",@"iTerm",@"Toolbar Item: Close Session")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Close",@"iTerm",@"Toolbar Item: Close Session")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Close the current session",@"iTerm",@"Toolbar Item Tip: Close")];
        [toolbarItem setImage: [NSImage imageNamed: @"close"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(closeCurrentSession:)];
    }
   else if ([itemIdent isEqual: ConfigToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Configure",@"iTerm",@"Toolbar Item:Configure") ];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Configure",@"iTerm",@"Toolbar Item:Configure") ];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Configure current window",@"iTerm",@"Toolbar Item Tip:Configure")];
        [toolbarItem setImage: [NSImage imageNamed: @"config"]];
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
	[toolbarItem setLabel: NSLocalizedStringFromTable(@"New",@"iTerm",@"Toolbar Item:New")];
	[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"New",@"iTerm",@"Toolbar Item:New")];
	[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Open a new session",@"iTerm",@"Toolbar Item:New")];

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
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal menuForEvent]", __FILE__, __LINE__);
#endif

    if(theMenu == nil)
	return;

    modflag = [theEvent modifierFlags];

    // Address Book
    // Figure out whether the command shall be executed in a new window or tab
    if (modflag & NSCommandKeyMask)
    {
	[theMenu insertItemWithTitle: NSLocalizedStringFromTable(@"New Window",@"iTerm",@"Context menu") action:nil keyEquivalent:@"" atIndex: 0];
	newWin = YES;
    }
    else
    {
	[theMenu insertItemWithTitle: NSLocalizedStringFromTable(@"New Tab",@"iTerm",@"Context menu") action:nil keyEquivalent:@"" atIndex: 0];
	newWin = NO;
    }
    
    // Separator
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex: 1];

    // Build the address book menu
    NSMenu *abMenu = [[NSMenu alloc] initWithTitle: @"Address Book"];
    [MAINMENU buildAddressBookMenu: abMenu forTerminal: (newWin?nil:self)];

    [theMenu setSubmenu: abMenu forItem: [theMenu itemAtIndex: 0]];
    [abMenu release];

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Close current session
    [theMenu addItemWithTitle:NSLocalizedStringFromTable(@"Close",@"iTerm",@"Toolbar Item: Close Session")
						   action:@selector(closeCurrentSession:) keyEquivalent:@""];


    // Configure
    [theMenu addItemWithTitle:NSLocalizedStringFromTable(@"Configure...",@"iTerm",@"Context menu")
				     action:@selector(showConfigWindow:) keyEquivalent:@""];
    
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
    [WINDOW makeFirstResponder:[currentPtySession TEXTVIEW]];
    [WINDOW setNextResponder:self];
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

    [ptyListLock lock];
    if(![ptyList containsObject: [tabViewItem identifier]] &&
       [[tabViewItem identifier] isKindOfClass: [PTYSession class]])
    {
	PTYSession *aSession = [tabViewItem identifier];
	
	[aSession setParent: self];
	[ptyList addObject: [tabViewItem identifier]];

    }
    [ptyListLock unlock];

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
	    [[aSession TEXTVIEW] scrollRangeToVisible: NSMakeRange([[[aSession TEXTVIEW] string] length] - 1, 1)];
	}
	else
	{
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

    [theMenu addItem: [NSMenuItem separatorItem]];

    windowPoint = [WINDOW convertScreenToBase: [NSEvent mouseLocation]];
    localPoint = [TABVIEW convertPoint: windowPoint fromView: nil];

    // add tasks
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Close",@"iTerm",@"Close Session") action:@selector(closeTabContextualMenuAction:) keyEquivalent:@""];
    [aMenuItem setRepresentedObject: [[TABVIEW tabViewItemAtPoint:localPoint] identifier]];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];
    if([ptyList count] > 1)
    {
	aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Move to new window",@"iTerm",@"Move session to new window") action:@selector(moveTabToNewWindowContextualMenuAction:) keyEquivalent:@""];
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
    term = [PseudoTerminal newTerminalWindow: MAINMENU];

    if(term == nil)
	return;

    [term setPreference:pref];
    [term initWindow: WIDTH
              height: HEIGHT
                font: FONT
              nafont: NAFONT];

    // If this is the current session, make previous one active.
    if(aSession == currentPtySession)
    {
	[self selectSession: (currentSessionIndex - 1)];
    }

    aTabViewItem = [aSession tabViewItem];

    // temporarily retain the tabViewItem
    [aTabViewItem retain];

    // remove from our window
    [TABVIEW removeTabViewItem: aTabViewItem];

    // add the session to the new terminal
    [term addSession: aSession];

    // release the tabViewItem
    [aTabViewItem release];

}


- (NSWindow *) window;
{
    return WINDOW;
}

- (IBAction)closeWindow:(id)sender
{
    [WINDOW performClose:sender];
}

- (void) setMainMenu:(id) sender
{
    MAINMENU=sender;
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
    NSDictionary *new, *old=[currentPtySession addressBookEntry];

    if (old&&[[old objectForKey:@"Name"] isEqualToString:[currentPtySession name]]) {
        new=[[NSDictionary alloc] initWithObjectsAndKeys:
            [old objectForKey:@"Name"],@"Name",
            [old objectForKey:@"Command"],@"Command",
            [NSNumber numberWithUnsignedInt:[[currentPtySession TERMINAL] encoding]],@"Encoding",
            [[currentPtySession TERMINAL] defaultFGColor],@"Foreground",
            [[currentPtySession TERMINAL] defaultBGColor],@"Background",
            [[currentPtySession TEXTVIEW] selectionColor],@"SelectionColor",
            [NSString stringWithInt:WIDTH],@"Col",
            [NSString stringWithInt:HEIGHT],@"Row",
            [NSNumber numberWithInt:100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100],@"Transparency",
            [[self currentSession] TERM_VALUE],@"Term Type",
            [old objectForKey:@"Directory"],@"Directory",
            [[currentPtySession SCREEN] font],@"Font",
            [[currentPtySession SCREEN] nafont],@"NAFont",
            [NSNumber numberWithBool:[[self currentSession] antiIdle]],@"AntiIdle",
            [NSNumber numberWithUnsignedInt:[[self currentSession] antiCode]],@"AICode",
            [NSNumber numberWithBool:[[self currentSession] autoClose]],@"AutoClose",
            [NSNumber numberWithBool:[[self currentSession] doubleWidth]],@"doubleWidth",
            NULL];
        //    NSLog(@"new entry:%@",ae);
        [MAINMENU replaceAddressBookEntry:old with:new];
    }
    else {
        new=[[NSDictionary alloc] initWithObjectsAndKeys:
            [self currentSessionName],@"Name",
            (old?[old objectForKey:@"Command"]:[[currentPtySession SHELL] path]),@"Command",
            [NSNumber numberWithUnsignedInt:[[currentPtySession TERMINAL] encoding]],@"Encoding",
            [[currentPtySession TERMINAL] defaultFGColor],@"Foreground",
            [[currentPtySession TERMINAL] defaultBGColor],@"Background",
            [NSString stringWithInt:WIDTH],@"Col",
            [NSString stringWithInt:HEIGHT],@"Row",
            [NSNumber numberWithInt:100-[[[currentPtySession TERMINAL] defaultBGColor] alphaComponent]*100],@"Transparency",
            [[self currentSession] TERM_VALUE],@"Term Type",
            (old?[old objectForKey:@"Directory"]:@""),@"Directory",
            [[currentPtySession SCREEN] font],@"Font",
            [[currentPtySession SCREEN] nafont],@"NAFont",
            [NSNumber numberWithBool:[[self currentSession] antiIdle]],@"AntiIdle",
            [NSNumber numberWithUnsignedInt:[[self currentSession] antiCode]],@"AICode",
            [NSNumber numberWithBool:[[self currentSession] autoClose]],@"AutoClose",
            [NSNumber numberWithBool:[[self currentSession] doubleWidth]],@"doubleWidth",
            NULL];
        //    NSLog(@"new entry:%@",ae);
        [MAINMENU addAddressBookEntry: new];
    }
    [MAINMENU saveAddressBook];

}

@end


// Private interface
@implementation PseudoTerminal (Private)

- (void) _buildToolbarItemPopUpMenu: (NSToolbarItem *) toolbarItem forToolbar: (NSToolbar *)toolbar
{
    NSPopUpButton *aPopUpButton;
    NSMenuItem *item;
    NSImage *image;
    NSMenu *aMenu;
    id newwinItem;

    if (toolbarItem == nil)
	return;
    
    aPopUpButton = (NSPopUpButton *)[toolbarItem view];
    //[aPopUpButton setAction: @selector(_addressbookPopupSelectionDidChange:)];
    [aPopUpButton setAction: nil];
    [aPopUpButton removeAllItems];
    [aPopUpButton addItemWithTitle: @""];

    [MAINMENU buildAddressBookMenu: [aPopUpButton menu] forTerminal: (newwin?nil:self)];

    [[aPopUpButton menu] addItem: [NSMenuItem separatorItem]];
    [[aPopUpButton menu] addItemWithTitle: NSLocalizedStringFromTable(@"Open in a new window",@"iTerm",@"Toolbar Item: New") action: @selector(_toggleNewWindowState:) keyEquivalent: @""];
    newwinItem=[aPopUpButton lastItem];
    [newwinItem setState:(newwin ? NSOnState : NSOffState)];    
    
    // Now set the icon
    item = [[aPopUpButton cell] menuItem];
    image=[NSImage imageNamed:@"newwin"];
    [image setScalesWhenResized:YES];
    if([toolbar sizeMode] == NSToolbarSizeModeSmall)
    {
	[image setSize:NSMakeSize(24.0, 24.0)];
    }
    else
    {
	[image setSize:NSMakeSize(30.0, 30.0)];
    }
    [item setImage:image];
    [item setOnStateImage:nil];
    [item setMixedStateImage:nil];
    [aPopUpButton setPreferredEdge:NSMinXEdge];
    [[[aPopUpButton menu] menuRepresentation] setHorizontalEdgePadding:0.0];

    // build a menu representation for text only.
    item = [[NSMenuItem alloc] initWithTitle: NSLocalizedStringFromTable(@"New",@"iTerm",@"Toolbar Item:New") action: nil keyEquivalent: @""];
    aMenu = [[NSMenu alloc] initWithTitle: @"Address Book"];
    [MAINMENU buildAddressBookMenu: aMenu forTerminal: (newwin?nil:self)];
    [aMenu addItem: [NSMenuItem separatorItem]];
    [aMenu addItemWithTitle: NSLocalizedStringFromTable(@"Open in a new window",@"iTerm",@"Toolbar Item: New") action: @selector(_toggleNewWindowState:) keyEquivalent: @""];
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
    
    toolbarItemArray = [[WINDOW toolbar] items];
    
    // Find the addressbook popup item and reset it
    for(i = 0; i < [toolbarItemArray count]; i++)
    {
        aToolbarItem = [toolbarItemArray objectAtIndex: i];
        
        if([[aToolbarItem itemIdentifier] isEqual: NewToolbarItem])
        {
            [self _buildToolbarItemPopUpMenu: aToolbarItem forToolbar: [WINDOW toolbar]];
                        
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
