// -*- mode:objc -*-
// $Id: PseudoTerminal.m,v 1.42 2002-12-20 00:06:44 ujwal Exp $
//
//  PseudoTerminal.m
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0
#define DEBUG_KEYDOWNDUMP     0

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

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal newTerminal]", __FILE__, __LINE__);
#endif
    term = [[PseudoTerminal alloc] init];
    [term setMainMenu:sender];
    if (term == nil)
	return nil;
    if ([NSBundle loadNibNamed:NIB_PATH owner:term] == NO)
	return nil;

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
     foregroundColor:[TERMINAL defaultFGColor]
     backgroundColor:[[TERMINAL defaultBGColor] colorWithAlphaComponent: [[TERMINAL defaultBGColor] alphaComponent]]
            encoding:[pref encoding]
                term:[pref terminalType]];
    [self startProgram:cmd arguments:arg];
    [self setCurrentSessionName:nil];

}

- (id)init
{
#if DEBUG_OBJALLOC
    NSLog(@"%s(%d):-[PseudoTerminal init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
	return nil;


    // Allocate a list for our sessions
    ptyList = [[NSMutableArray alloc] init];
    ptyListLock = [[NSLock alloc] init];

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
    tabviewRect.origin.y -= 12;
    tabviewRect.size.height += 10;
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
          encoding:(NSStringEncoding)encoding
              term:(NSString *)term
{
    PTYSession *aSession;
    PTYTabViewItem *aTabViewItem;
    PTYScrollView *aScrollView;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal initSession]",
          __FILE__, __LINE__);
#endif

    // Allocate a new session
    aSession = [[PTYSession alloc] init];
    NSParameterAssert(aSession != nil);


    // Allocate a new tabview item
    aTabViewItem = [[PTYTabViewItem alloc] initWithIdentifier: aSession];
    NSParameterAssert(aTabViewItem != nil);
    [TABVIEW addTabViewItem: aTabViewItem];
    [aTabViewItem release];

    
    // Allocate a scrollview and add to the tabview
    aScrollView = [[PTYScrollView alloc] initWithFrame: [TABVIEW contentRect]];
    NSParameterAssert(aScrollView != nil);
    [aTabViewItem setView: aScrollView];
    [aScrollView setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    [SCROLLVIEW setLineScroll: ([VT100Screen fontSize: FONT].height)];
    [aScrollView release];

    // Init the rest of the session
    [aSession setTabViewItem: aTabViewItem];
    [aSession setParent: self];
    [aSession setPreference: pref];
    [aSession setMainMenu: MAINMENU];
    [aSession initScreen: [SCROLLVIEW documentVisibleRect]];
    // Set this session to be the current session
    [aScrollView setDocumentView:[aSession TEXTVIEW]];
    [aTabViewItem setLabel: @""];

    SCROLLVIEW = (PTYScrollView *)[aTabViewItem view];
    SHELL = [aSession SHELL];
    TERMINAL = [aSession TERMINAL];
    SCREEN = [aSession SCREEN];
    NSParameterAssert(SHELL != nil && TERMINAL != nil && SCREEN != nil);

   
    TEXTVIEW = [aSession TEXTVIEW];
    [TEXTVIEW setDelegate: aSession];
    
    // Set the colors
    if (fg) [aSession setFGColor:fg];
    if (bg) [aSession setBGColor:bg];
    [SCROLLVIEW setBackgroundColor: bg];

    [self setFont:FONT nafont:NAFONT];
    if (term) 
    {
        [aSession setTERM_VALUE: term];
    }
    else 
    {
        [aSession setTERM_VALUE: [pref terminalType]];
    }
    
    [SCREEN setTerminal:TERMINAL];
    [SCREEN setShellTask:SHELL];
    [SCREEN setTextStorage:[TEXTVIEW textStorage]];
    [SCREEN setWindow:WINDOW];
    [SCREEN setWidth:WIDTH height:HEIGHT];
//    NSLog(@"%d,%d",WIDTH,HEIGHT);
    [SCREEN initScreen];
    

    [TERMINAL setEncoding:encoding];
    [TERMINAL setTrace:YES];	// debug vt100 escape sequence decode
    
    if([ptyList count] == 0)
    {
        [self setWindowSize];
        // Tell us whenever something happens with the tab view
        [TABVIEW setDelegate: self];
    }

    [SHELL setWidth:WIDTH  height:HEIGHT];

    [WINDOW makeFirstResponder:TEXTVIEW];
    [WINDOW setNextResponder:self];

    pending = NO;
    if (title) 
    {
        [self setWindowTitle: title];
        [aSession setName: title];
    }
     
    // Add this session to our list and make it current
    [ptyList addObject: aSession];
    [aSession release];
    currentSessionIndex = [ptyList count] - 1;
    [currentPtySession resetStatus];
    currentPtySession = aSession;
    [TABVIEW selectTabViewItem: aTabViewItem];
    [self setCurrentSessionName: nil];
        
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
    SCROLLVIEW = (PTYScrollView *)[[TABVIEW selectedTabViewItem] view];
    TEXTVIEW = [aSession TEXTVIEW];
    SHELL = [aSession SHELL];
    TERMINAL = [aSession TERMINAL];
    SCREEN = [aSession SCREEN];
    if (currentPtySession) [currentPtySession resetStatus];
    currentSessionIndex = sessionIndex;
    currentPtySession = aSession;
    [self setWindowTitle];
    [WINDOW makeFirstResponder:TEXTVIEW];
    [WINDOW setNextResponder:self];

}

- (void) closeSession: (PTYSession*) aSession
{
    int i;
    int n=[ptyList count];
    
    if(n == 1)
    {
        [WINDOW close];
        return;
    }

    for(i=0;i<n;i++) 
    {
        if ([ptyList objectAtIndex:i]==aSession)
        {
            [ptyListLock lock];
            [[ptyList objectAtIndex: i] terminate];
            [ptyList removeObjectAtIndex: i];
            [ptyListLock unlock];
            if (i==currentSessionIndex) {
                if (currentSessionIndex >= [ptyList count])
                    currentSessionIndex = [ptyList count] - 1;
        
                currentPtySession = nil;
                [self selectSession: currentSessionIndex];
            }
            else if (i<currentSessionIndex) currentSessionIndex--;
            
            [TABVIEW removeTabViewItem: [aSession tabViewItem]];
            
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

    if ([currentPtySession exited]==NO&&![pref autoclose]) {
       if (NSRunAlertPanel(NSLocalizedStringFromTable(@"The current session will be closed",@"iTerm",@"Close Session"),
                         NSLocalizedStringFromTable(@"All unsaved data will be lost",@"iTerm",@"Close window"),
                         NSLocalizedStringFromTable(@"Cancel",@"iTerm",@"Cancel"),
                         NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK")
                         ,nil)) return;
    }
        
    if([ptyList count] == 1)
    {
        [WINDOW close];
        return;
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
        NSString *progpath = [NSString stringWithFormat: @"%@ #%d", [[[SHELL path] pathComponents] lastObject], currentSessionIndex];

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
    NSLog(@"%s(%d):-[PseudoTerminal dealloc]", __FILE__, __LINE__);
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

    SHELL    = nil;
    TERMINAL = nil;
    SCREEN   = nil;
        
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

                
- (void)setWindowSize
{
    NSSize size, vsize, winSize;
    NSWindow *thisWindow;
    int i;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setWindowSize]", __FILE__, __LINE__ );
#endif
    vsize = [VT100Screen requireSizeWithFont:[SCREEN font]
				      width:WIDTH
				     height:HEIGHT];

    
    size = [PTYScrollView frameSizeForContentSize:vsize
			    hasHorizontalScroller:NO
			      hasVerticalScroller:YES
			   	       borderType:NSNoBorder];

    for (i = 0; i < [TABVIEW numberOfTabViewItems]; i++)
    {
        [[[TABVIEW tabViewItemAtIndex: i] view] setFrameSize:size];
        [(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] setLineScroll: ([VT100Screen fontSize: FONT].height)];
        [[(PTYScrollView *)[[TABVIEW tabViewItemAtIndex: i] view] documentView] setFrameSize:vsize];
    }

    thisWindow = [SCROLLVIEW window];
    winSize = size;
    winSize.height = size.height + 3*[SCROLLVIEW lineScroll];
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

- (void)setFont:(NSFont *)font nafont:(NSFont *) nafont
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setFont:%@]",
          __FILE__, __LINE__, font);
#endif
    [TEXTVIEW  setFont:font];
    [SCREEN  setFont:font nafont:nafont];
/*    if (FONT) [FONT autorelease];
    FONT=[[font copy] retain]; */
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
            [CONFIG_NAEXAMPLE setFont:configFont];
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
    if (![SHELL logging]) [currentPtySession logStart];
}

- (IBAction)logStop:(id)sender
{
    if ([SHELL logging]) [currentPtySession logStop];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL logging = [SHELL logging];
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

- (void)windowDidResize:(NSNotification *)aNotification
{
    NSRect frame;
    NSSize termSize, vsize;
    int i, w, h;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowDidResize:%@]",
	  __FILE__, __LINE__, aNotification);
#endif

    frame = [[SCROLLVIEW contentView] frame];
#if 0
    NSLog(@"window size %.1f, %.1f, %.1f, %.1f",
	  frame.origin.x, frame.origin.y,
	  frame.size.width, frame.size.height);
#endif

    termSize = [VT100Screen screenSizeInFrame: frame font: [SCREEN font]];

    w = (int)(termSize.width);
    h = (int)(termSize.height);
    
    vsize = [VT100Screen requireSizeWithFont:[SCREEN font]
                                       width:w
                                      height:h];

    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] SCREEN] beginEditing];
        [[[ptyList objectAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[ptyList objectAtIndex:i] SCREEN] endEditing];
        [[[ptyList objectAtIndex:i] SHELL] setWidth:w  height:h];
        [[[ptyList objectAtIndex:i] TEXTVIEW] setFrameSize:vsize];
    }
    
    WIDTH = w;
    HEIGHT = h;
//    NSLog(@"%d,%d",WIDTH,HEIGHT);


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
    [CONFIG_FOREGROUND setColor:[TERMINAL defaultFGColor]];
    [CONFIG_BACKGROUND setColor:[TERMINAL defaultBGColor]];
    configFont=[SCREEN font];
    [CONFIG_EXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configFont fontName], [configFont pointSize]]];
    [CONFIG_EXAMPLE setTextColor:[TERMINAL defaultFGColor]];
    [CONFIG_EXAMPLE setBackgroundColor:[TERMINAL defaultBGColor]];
    configNAFont=[SCREEN nafont];
    [CONFIG_NAEXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configNAFont fontName], [configNAFont pointSize]]];
    [CONFIG_NAEXAMPLE setTextColor:[TERMINAL defaultFGColor]];
    [CONFIG_NAEXAMPLE setBackgroundColor:[TERMINAL defaultBGColor]];
    [CONFIG_COL setIntValue:[SCREEN width]];
    [CONFIG_ROW setIntValue:[SCREEN height]];
    [CONFIG_NAME setStringValue:[self currentSessionName]];
    [CONFIG_ENCODING removeAllItems];
    r=0;
    while (*p) {
        //        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [CONFIG_ENCODING addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[TERMINAL encoding]) r=p-[MAINMENU encodingList];
        p++;
    }
    [CONFIG_ENCODING selectItemAtIndex:r];
    [CONFIG_TRANSPARENCY setIntValue:100-[[TERMINAL defaultBGColor] alphaComponent]*100];
    [CONFIG_TRANS2 setIntValue:100-[[TERMINAL defaultBGColor] alphaComponent]*100];
    [AI_ON setState:[[self currentSession] antiIdle]?NSOnState:NSOffState];
    [AI_CODE setIntValue:[[self currentSession] antiCode]];
    
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
    
    vsize = [VT100Screen requireSizeWithFont:[SCREEN font]
                                       width:w
                                      height:h];
    
    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] SCREEN] beginEditing];
        [[[ptyList objectAtIndex:i] SCREEN] resizeWidth:w height:h];
        [[[ptyList objectAtIndex:i] SCREEN] endEditing];
        [[[ptyList objectAtIndex:i] SHELL] setWidth:w  height:h];
        [[[ptyList objectAtIndex:i] TEXTVIEW] setFrameSize:vsize];
    }
    WIDTH=w;
    HEIGHT=h;
    //NSLog(@"resize window: %d,%d",WIDTH,HEIGHT);

    [self setWindowSize];
    
}

- (IBAction)windowConfigOk:(id)sender
{
    if ([CONFIG_COL intValue]>150||[CONFIG_COL intValue]<10||[CONFIG_ROW intValue]>150||[CONFIG_ROW intValue]<3) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid window size",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
    }else if ([AI_CODE intValue]>255||[AI_CODE intValue]<0) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid code (0~255)",@"iTerm",@"Anti-Idle: wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
    }else {
        [[self currentSession] setEncoding:[MAINMENU encodingList][[CONFIG_ENCODING indexOfSelectedItem]]];
        if ((configFont != nil&&[SCREEN font]!=configFont)||(configNAFont!= nil&&[SCREEN nafont]!=configNAFont)) {
            [self setAllFont:configFont nafont:configNAFont];
        }

        [self resizeWindow:[CONFIG_COL intValue] height:[CONFIG_ROW intValue]];
        if(([pref transparency] != (100-[[TERMINAL defaultBGColor] alphaComponent]*100)) || 
            ([TERMINAL defaultFGColor] != [CONFIG_FOREGROUND color]) || 
            ([TERMINAL defaultBGColor] != [CONFIG_BACKGROUND color]))
        {
            NSColor *bgColor;
/*            int i;
            PTYSession *aSession; */
                
            // set the background color for the scrollview with the appropriate transparency
            bgColor = [[CONFIG_BACKGROUND color] colorWithAlphaComponent: (1-[CONFIG_TRANSPARENCY intValue]/100.0)];
            [SCROLLVIEW setBackgroundColor: bgColor];
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
            [SCROLLVIEW setNeedsDisplay: YES];
            
        }
        [SCREEN showCursor];
        [[self currentSession] moveLastLine];
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

    if ([itemIdent isEqual: ABToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Address Book",@"iTerm",@"Toolbar Item:Address Book")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Open the address book",@"iTerm",@"Toolbar Item Tip:Address Book")];
        [toolbarItem setImage: [NSImage imageNamed: @"addressbook"]];
        [toolbarItem setTarget: MAINMENU];
        [toolbarItem setAction: @selector(showABWindow:)];
    }
    else if ([itemIdent isEqual: CloseToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Close",@"iTerm",@"Toolbar Item: Close Session")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Close the current session",@"iTerm",@"Toolbar Item Tip: Close")];
        [toolbarItem setImage: [NSImage imageNamed: @"close"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(closeCurrentSession:)];
    }
   else if ([itemIdent isEqual: ConfigToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Configure",@"iTerm",@"Toolbar Item:Configure") ];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Configure current window",@"iTerm",@"Toolbar Item Tip:Configure")];
        [toolbarItem setImage: [NSImage imageNamed: @"config"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(showConfigWindow:)];
    } 
    else if ([itemIdent isEqual: NewToolbarItem])
    {
        NSPopUpButton *aPopUpButton;
        
        aPopUpButton = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0.0, 0.0, 48.0, 32.0) pullsDown: YES];
        [aPopUpButton setTarget: self];
        [aPopUpButton setBordered: NO];
        [[aPopUpButton cell] setArrowPosition:NSPopUpArrowAtBottom];

        [aPopUpButton setAction: @selector(_addressbookPopupSelectionDidChange:)];
        
        [self _buildAddressBookMenu: aPopUpButton];        
        
        [toolbarItem setView: aPopUpButton];
        // Release the popup button since it is retained by the toolbar item.
        [aPopUpButton release];

        [toolbarItem setMinSize:[aPopUpButton bounds].size];
        [toolbarItem setMaxSize:[aPopUpButton bounds].size];
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"New",@"iTerm",@"Toolbar Item:New")];
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


// NSTabView
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    PTYSession *aSession;
    
    aSession = [tabViewItem identifier];
    
    SCROLLVIEW = (PTYScrollView *)[tabViewItem view];
    TEXTVIEW = [aSession TEXTVIEW];
    SHELL = [aSession SHELL];
    TERMINAL = [aSession TERMINAL];
    SCREEN = [aSession SCREEN];
    if (currentPtySession) [currentPtySession resetStatus];
    currentSessionIndex = [TABVIEW indexOfTabViewItem: tabViewItem];
    currentPtySession = aSession;
    [self setWindowTitle];
    [WINDOW makeFirstResponder:TEXTVIEW];
    [WINDOW setNextResponder:self];
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


@end


// Private interface
@implementation PseudoTerminal (Private)

// Runs a command from the addressbook popup
- (void) _addressbookPopupSelectionDidChange: (id) sender
{
    int commandIndex;
    NSDictionary *anEntry;
    NSString *cmd;
    NSArray *arg;
    PseudoTerminal *term;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal _addressbookPopupSelectionDidChange]",
          __FILE__, __LINE__);
#endif
    
    // If we selected tha last item, show the address book.
    if([sender indexOfSelectedItem] == [sender indexOfItem: [sender lastItem]])
    {
//        [MAINMENU showABWindow: self];
        newwin=newwin?NO:YES;
        [newwinItem setState:(newwin ? NSOnState : NSOffState)];
        return;
    }
    
    commandIndex = [sender indexOfSelectedItem] - 1;
    
    if(commandIndex < 0)
        return;
    if (commandIndex==0) {
        if (newwin) [MAINMENU newWindow:nil];
        else [MAINMENU newSession:nil];
    }
    else {
        anEntry = [MAINMENU addressBookEntry: commandIndex-2];

        if (newwin) {
            term = [PseudoTerminal newTerminalWindow: MAINMENU];
            [term setPreference:pref];
            [term initWindow:[[anEntry objectForKey:@"Col"]intValue]
                      height:[[anEntry objectForKey:@"Row"] intValue]
                        font:[anEntry objectForKey:@"Font"]
                      nafont:[anEntry objectForKey:@"NAFont"]];
        }
        else term=self;

        // Init a new session and run the command
        [term initSession:[anEntry objectForKey:@"Name"]
          foregroundColor:[anEntry objectForKey:@"Foreground"]
          backgroundColor:[[anEntry objectForKey:@"Background"] colorWithAlphaComponent: (1.0-[[anEntry objectForKey:@"Transparency"] intValue]/100.0)]
                 encoding:[[anEntry objectForKey:@"Encoding"] unsignedIntValue]
                     term:[anEntry objectForKey:@"Term Type"]];

        NSDictionary *env=[NSDictionary dictionaryWithObject:([anEntry objectForKey:@"Directory"]?[anEntry objectForKey:@"Directory"]:@"~")  forKey:@"PWD"];

        [MainMenu breakDown:[anEntry objectForKey:@"Command"] cmdPath:&cmd cmdArgs:&arg];
        [term startProgram:cmd arguments:arg environment:env];
        [term setCurrentSessionName:[anEntry objectForKey:@"Name"]];
    }
}

// Build the address book menu
- (void) _buildAddressBookMenu: (NSPopUpButton *) aPopUpButton
{
    NSMenuItem *item;
    NSImage *image;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal _buildAddressBookMenu]",
          __FILE__, __LINE__);
#endif

    // build the menu
    [aPopUpButton removeAllItems];
    [aPopUpButton addItemWithTitle: @""];
    [aPopUpButton addItemWithTitle: NSLocalizedStringFromTable(@"Default session",@"iTerm",@"Toolbar Item: New")];
    [[aPopUpButton menu] addItem: [NSMenuItem separatorItem]];
    [aPopUpButton addItemsWithTitles: [MAINMENU addressBookNames]];
    [[aPopUpButton menu] addItem: [NSMenuItem separatorItem]];
    [aPopUpButton addItemWithTitle: NSLocalizedStringFromTable(@"Open in a new window",@"iTerm",@"Toolbar Item: New")];
    newwinItem=[aPopUpButton lastItem];
    [newwinItem setState:(newwin ? NSOnState : NSOffState)];
    
//    [aPopUpButton addItemWithTitle: NSLocalizedStringFromTable(@"Open Address Book",@"iTerm",@"Toolbar Item:Address Book")];
    
    // Now set the icon
    item = [[aPopUpButton cell] menuItem];
    image=[NSImage imageNamed:@"newwin"];
    [image setScalesWhenResized:YES];
    [image setSize:NSMakeSize(30.0,30.0)];
    [item setImage:image];
    [item setOnStateImage:nil];
    [item setMixedStateImage:nil];
    [aPopUpButton setPreferredEdge:NSMinXEdge];
    [[[aPopUpButton menu] menuRepresentation] setHorizontalEdgePadding:0.0];

}

// Reloads the addressbook entries into the popup toolbar item
- (void) _reloadAddressBookMenu: (NSNotification *) aNotification
{
    NSArray *toolbarItemArray;
    NSToolbarItem *aToolbarItem;
    NSPopUpButton *aPopUpButton;
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
            aPopUpButton = (NSPopUpButton *)[aToolbarItem view];
            [self _buildAddressBookMenu: aPopUpButton];
                        
            break;
        }
        
    }
    
}

// Called by session popup to switch sessions
- (void) _sessionPopupSelectionDidChange: (id) sender
{
    [self selectSession: ([sender indexOfSelectedItem] - 1)];
    
}


@end
