// -*- mode:objc -*-
// $Id: PseudoTerminal.m,v 1.6 2002-11-28 19:28:41 ujwal Exp $
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
#define DEBUG_SCREENDUMP      0
#define DEBUG_KEYDOWNDUMP     0

#import "PseudoTerminal.h"
#import "PTYScrollView.h"
#import "NSStringITerm.h"
#import "PTYSession.h"

@implementation PseudoTerminal

#define NIB_PATH  @"PseudoTerminal"

static NSString *NewWToolbarItem = @"New Window";
static NSString *NewSToolbarItem = @"New Session";
static NSString *QRToolbarItem = @"Open";
static NSString *ABToolbarItem = @"Address";
static NSString *CloseToolbarItem = @"Close";
static NSString *ConfigToolbarItem = @"Config";

static NSDictionary *normalStateAttribute;
static NSDictionary *chosenStateAttribute;
static NSDictionary *idleStateAttribute;
static NSDictionary *newOutputStateAttribute;

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
     foregroundColor:[pref foreground]
     backgroundColor:[pref background]
            encoding:[pref encoding]
                term:[pref terminalType]];
    [self startProgram:cmd arguments:arg];
    [[self window] setAlphaValue:1.0-[pref transparency]/100.0];
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
    buttonList = [[NSMutableArray alloc] init];
    ptyListLock = [[NSLock alloc] init];
    
    normalStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor grayColor],NSForegroundColorAttributeName,nil] retain];
    chosenStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor blackColor],NSForegroundColorAttributeName,nil] retain];
    idleStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor redColor],NSForegroundColorAttributeName,nil] retain];
    newOutputStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor blueColor],NSForegroundColorAttributeName,nil] retain];
        
    return self;
}

- (void)initWindow:(int)width
            height:(int)height
              font:(NSFont *)font
{
    WIDTH=width;
    HEIGHT=height;

    if (!font)
        font = [[[pref font] copy] retain];
    NSParameterAssert(font != nil);

    if (FONT) [FONT autorelease];
    FONT=[[font copy] retain];    
}

- (void)initSession:(NSString *)title
   foregroundColor:(NSColor *) fg
   backgroundColor:(NSColor *) bg
          encoding:(NSStringEncoding)encoding
              term:(NSString *)term
{
    NSWindow *window;
    PTYSession *aSession;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal initSession]",
          __FILE__, __LINE__);
#endif


    // Allocate a new session and initialize it
    aSession = [[PTYSession alloc] init];
    NSParameterAssert(aSession != nil);
    [aSession setParent: self];
    [aSession setPreference: pref];
    [aSession setMainMenu: MAINMENU];
    [aSession initScreen: [SCROLLVIEW documentVisibleRect]];

    // Set this session to be the current session
    [SCROLLVIEW setDocumentView:[aSession TEXTVIEW]];
    //[SCROLLVIEW setNextResponder:textview];

    SHELL = [aSession SHELL];
    TERMINAL = [aSession TERMINAL];
    SCREEN = [aSession SCREEN];
    NSParameterAssert(SHELL != nil && TERMINAL != nil && SCREEN != nil);

/*    cMenu = [[NSMenu alloc] initWithTitle:@"test"];
    [cMenu addItemWithTitle:@"Configure" action:@selector(showConfigWindow:) keyEquivalent:@""];
    [TEXTVIEW setMenu:cMenu]; */
    
    TEXTVIEW = [SCROLLVIEW documentView];
    [TEXTVIEW setDelegate: aSession];
    
    // Set the colors
    if (fg) [aSession setFGColor:fg];
    if (bg) [aSession setBGColor:bg];
    
    [self setFont:FONT];
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
    [SCREEN initScreen];
    

    [TERMINAL setEncoding:encoding];
    [TERMINAL setTrace:YES];	// debug vt100 escape sequence decode
    

    [self setWindowSize];
    [SHELL setWidth:WIDTH  height:HEIGHT];

    window = [SCROLLVIEW window];
    [window makeFirstResponder:TEXTVIEW];
    [window setNextResponder:self];
    [window setDelegate:self];

    EXIT = NO;
    pending = NO;
    if (title) 
    {
        [self setWindowTitle: title];
        [aSession setName: title];
    }
    [window makeKeyAndOrderFront:self];
    
    // Add this session to our list and make it current
    [ptyList addObject: aSession];
    [aSession release];
    currentSessionIndex = [ptyList count] - 1;
    [currentPtySession resetStatus];
    currentPtySession = aSession;
    [self _drawSessionButtons];

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
    
    if(sessionIndex < 0)
        sessionIndex = 0;
    if(sessionIndex >= [ptyList count])
        sessionIndex = [ptyList count] - 1;

    currentSessionIndex = sessionIndex;
    aSession = [ptyList objectAtIndex: sessionIndex];
    currentPtySession = aSession;
    [SCROLLVIEW setDocumentView: [aSession TEXTVIEW]];
    SHELL = [aSession SHELL];
    TERMINAL = [aSession TERMINAL];
    SCREEN = [aSession SCREEN];
    [currentPtySession resetStatus];
    [currentPtySession moveLastLine];
    [self _drawSessionButtons];
    [self setWindowTitle];
//    [WINDOW makeFirstResponder: self];
}

- (void) closeSession: (PTYSession *)theSession
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal closeSession]",
          __FILE__, __LINE__);
#endif

    if(ptyList == nil)
        return;
    
    if([ptyList count] == 1)
    {
        [WINDOW close];
        return;
    }
    
    [ptyListLock lock];    
    [[ptyList objectAtIndex: currentSessionIndex] terminate];
    [ptyList removeObjectAtIndex: currentSessionIndex];
    [ptyListLock unlock];
    
    if (currentSessionIndex == 0)
        currentSessionIndex = 0;    
    else if (currentSessionIndex >= [ptyList count])
        currentSessionIndex = [ptyList count] - 1;
            
    [self selectSession: currentSessionIndex];
    
}

- (void) closeCurrentSession: (PTYSession *)theSession
{
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
        theIndex = 0;
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
    
    if(theSessionName != nil)
    {
        [currentPtySession setName: theSessionName];
    }
    else {
        NSMutableString *title = [NSMutableString string];
        NSString *progpath = [SHELL path];

        if (EXIT)
            [title appendString:@"Finish"];
        else
            [title appendString:progpath];

        [currentPtySession setName: title];
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
    if([buttonList count] > 0)
    {
        [buttonList removeAllObjects];
        [buttonList release];
    }
    [ptyListLock unlock];
    [ptyListLock release];
    ptyListLock = nil;
   
    ptyList = nil;
    buttonList = nil; 

    SHELL    = nil;
    TERMINAL = nil;
    SCREEN   = nil;
    
    [normalStateAttribute release];
    normalStateAttribute = nil;
    [chosenStateAttribute release];
    chosenStateAttribute = nil;
    [idleStateAttribute release];
    idleStateAttribute = nil;
    [newOutputStateAttribute release];
    newOutputStateAttribute = nil;
    
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

- (void)setWindowSize
{
    NSSize size, vsize, winSize;
    NSWindow *window;

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

    window = [SCROLLVIEW window];
    winSize = size;
    winSize.height = size.height + 35;
    [window setContentSize:winSize];
    [SCROLLVIEW setFrameSize:size];
    [[SCROLLVIEW documentView] setFrameSize:vsize];
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

- (void)setAllFont:(NSFont *)font
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setAllFont:%@]",
	  __FILE__, __LINE__, font);
#endif
    int i;

    for(i=0;i<[ptyList count]; i++) {
        [[[ptyList objectAtIndex:i] TEXTVIEW]  setFont:font];
        [[[ptyList objectAtIndex:i] SCREEN]  setFont:font];
    }
    if (FONT) [FONT autorelease];
    FONT=[[font copy] retain];
}

- (void)setFont:(NSFont *)font
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setFont:%@]",
          __FILE__, __LINE__, font);
#endif
    [TEXTVIEW  setFont:font];
    [SCREEN  setFont:font];
    if (FONT) [FONT autorelease];
    FONT=[[font copy] retain];
}


- (void)keyDown:(NSEvent *)theEvent
{
    unsigned int mod_flag;
    unsigned short key_code;
    NSString *keystr;
    NSString *unmod_keystr;
    unichar unicode;

    mod_flag = [theEvent modifierFlags];
    key_code = [theEvent keyCode];
    keystr = [theEvent characters];
    unmod_keystr = [theEvent charactersIgnoringModifiers];
    unicode = [keystr characterAtIndex:0];

    // Check if we are navigating through sessions
    if ((mod_flag & NSFunctionKeyMask) && (mod_flag & NSShiftKeyMask)) 
    {
        // function key's
        switch (unicode) 
        {
            case NSLeftArrowFunctionKey: // cursor left
                // Check if we want to just move to the previous session
                [self previousSession: nil];
                break;
            case NSRightArrowFunctionKey: // cursor left
                // Check if we want to just move to the next session
                [self nextSession: nil];
                break;  
            default:
                break;      
        }
    }
    else // Re-direct the event to the appropriate session
        [currentPtySession keyDown: theEvent];
}

- (void)changeFont:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal changeFont:%@]",
	  __FILE__, __LINE__, sender);
#endif
//    NSLog(@"changeFont!!!!");
    configFont=[[NSFontManager sharedFontManager] convertFont:configFont];
    if (configFont!=nil) {
        [CONFIG_EXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configFont fontName], [configFont pointSize]]];
        [CONFIG_EXAMPLE setFont:configFont];
    }
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
    return EXIT||[self showCloseWindow];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal windowWillClose:%@]",
	  __FILE__, __LINE__, aNotification);
#endif
    if (EXIT == NO) {
	[SHELL stopNoWait];
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
    int ec;
    
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
    [CONFIG_COL setIntValue:[SCREEN width]];
    [CONFIG_ROW setIntValue:[SCREEN height]];
    [CONFIG_NAME setStringValue:[self currentSessionName]];
    ec=[TERMINAL encoding];
    if (ec==NSStringEUCCNEncoding)
        [CONFIG_ENCODING selectItemAtIndex:1];
    else if (ec==NSStringBig5Encoding)
        [CONFIG_ENCODING selectItemAtIndex:2];
    else if (ec==NSUTF8StringEncoding)
        [CONFIG_ENCODING selectItemAtIndex:0];
    [CONFIG_TRANSPARENCY setIntValue:100-[WINDOW alphaValue]*100];
    [CONFIG_TRANS2 setIntValue:100-[WINDOW alphaValue]*100];
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
        if ([TERMINAL defaultFGColor]!=[CONFIG_FOREGROUND color]) [[self currentSession] setFGColor:[CONFIG_FOREGROUND color]];
        if ([TERMINAL defaultBGColor]!=[CONFIG_BACKGROUND color]) [[self currentSession] setBGColor:[CONFIG_BACKGROUND color]];
        switch ([CONFIG_ENCODING indexOfSelectedItem]) {
            case 0:
                [[self currentSession] setEncoding:NSUTF8StringEncoding];
                break;
            case 1:
                [[self currentSession] setEncoding:NSStringEUCCNEncoding];
                break;
            case 2:
                [[self currentSession] setEncoding:NSStringBig5Encoding];
                break;
            case 3:
                [[self currentSession] setEncoding:NSJapaneseEUCStringEncoding];
                break;
            case 4:
                [[self currentSession] setEncoding:NSShiftJISStringEncoding];
                break;
            case 5:
                [[self currentSession] setEncoding:NSEUCKRStringEncoding];
                break;
        }
        if (configFont != nil&&[SCREEN font]!=configFont) {
            [self setAllFont:configFont];
        }

        [self resizeWindow:[CONFIG_COL intValue] height:[CONFIG_ROW intValue]];
        [WINDOW setAlphaValue:1-[CONFIG_TRANSPARENCY intValue]/100.0];
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
    [[CONFIG_EXAMPLE window] makeFirstResponder:[CONFIG_EXAMPLE window]];
    [[CONFIG_EXAMPLE window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:configFont isMultiple:NO];
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

    [itemIdentifiers addObject: NewWToolbarItem];
    [itemIdentifiers addObject: NewSToolbarItem];
    [itemIdentifiers addObject: QRToolbarItem];
    [itemIdentifiers addObject: ABToolbarItem];
    [itemIdentifiers addObject: ConfigToolbarItem];
    [itemIdentifiers addObject: NSToolbarSeparatorItemIdentifier];
    [itemIdentifiers addObject: NSToolbarCustomizeToolbarItemIdentifier];
    [itemIdentifiers addObject: CloseToolbarItem];

    return itemIdentifiers;
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray* itemIdentifiers = [[[NSMutableArray alloc]init] autorelease];

    [itemIdentifiers addObject: NewWToolbarItem];
    [itemIdentifiers addObject: NewSToolbarItem];
    [itemIdentifiers addObject: QRToolbarItem];
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

    if ([itemIdent isEqual: NewWToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"New Window",@"iTerm",@"Toolbar Item:New Window")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Open session in a new window",@"iTerm",@"Toolbar Item Tip:New Window")];
        [toolbarItem setImage: [NSImage imageNamed: @"newwin"]];
        [toolbarItem setTarget: MAINMENU];
        [toolbarItem setAction: @selector(newWindow:)];
    }
    else if ([itemIdent isEqual: NewSToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"New Session",@"iTerm",@"Toolbar Item:New Session")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Open session in current window",@"iTerm",@"Toolbar Item Tip:New Session")];
        [toolbarItem setImage: [NSImage imageNamed: @"new"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(newSession:)];
    }
    else if ([itemIdent isEqual: QRToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Quick Run",@"iTerm",@"Toolbar Item:New")];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Run a command in a new window",@"iTerm",@"Toolbar Item Tip:Quick Run")];
        [toolbarItem setImage: [NSImage imageNamed: @"exec"]];
        [toolbarItem setTarget: MAINMENU];
        [toolbarItem setAction: @selector(showQOWindow:)];
    }
    else if ([itemIdent isEqual: ABToolbarItem]) {
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
        [toolbarItem setAction: @selector(closeSession:)];
    }
   else if ([itemIdent isEqual: ConfigToolbarItem]) {
        [toolbarItem setLabel: NSLocalizedStringFromTable(@"Configure",@"iTerm",@"Toolbar Item:Configure") ];
        [toolbarItem setToolTip: NSLocalizedStringFromTable(@"Configure current window",@"iTerm",@"Toolbar Item Tip:Configure")];
        [toolbarItem setImage: [NSImage imageNamed: @"config"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(showConfigWindow:)];
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
    [toolbar insertItemWithItemIdentifier: NewWToolbarItem atIndex:0];
    [toolbar insertItemWithItemIdentifier: NewSToolbarItem atIndex:1];
    [toolbar insertItemWithItemIdentifier: QRToolbarItem atIndex:2];
    [toolbar insertItemWithItemIdentifier: ABToolbarItem atIndex:3];
    [toolbar insertItemWithItemIdentifier: ConfigToolbarItem atIndex:4];
    [toolbar insertItemWithItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier atIndex:5];
    [toolbar insertItemWithItemIdentifier: NSToolbarCustomizeToolbarItemIdentifier atIndex:6];
    [toolbar insertItemWithItemIdentifier: NSToolbarSeparatorItemIdentifier atIndex:7];
    [toolbar insertItemWithItemIdentifier: CloseToolbarItem atIndex:8];


//    NSLog(@"Toolbar created");

    return toolbar;
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


- (void) _drawSessionButtons
{
    int sessionCount;
    int i;
    NSButton *aButton;
    NSDictionary *attr;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal _drawSessionButtons]",
          __FILE__, __LINE__);
#endif

    [ptyListLock lock];
    
    sessionCount = [ptyList count];
    
    // Discard all previous buttons
    for(i = 0; i < [buttonList count]; i++)
    {
        aButton = [buttonList objectAtIndex: i];
        [aButton removeFromSuperviewWithoutNeedingDisplay];
    }
    [buttonList removeAllObjects];
    
    [[WINDOW contentView] setNeedsDisplay: YES];
    
    for (i = 0; i < sessionCount; i++)
    {
        NSRect aFrame;
        
        aFrame.origin.x = i * 80;
        aFrame.origin.y = 0;
        aFrame.size.width = 80;
        aFrame.size.height = [[WINDOW contentView] frame].size.height - [SCROLLVIEW frame].size.height - 3;
        aButton = [[NSButton alloc] initWithFrame: aFrame];
        [aButton setTarget: self];
        [aButton setAction: @selector(switchSession:)];
        [aButton setTag: i];
        [aButton setButtonType: NSOnOffButton];
        //[aButton setShowsStateBy: NSChangeBackgroundCellMask];
        attr=normalStateAttribute;
        if(i == currentSessionIndex)
        {
//            [aButton highlight: YES];
            [aButton setBordered: YES];
            [self setWindowTitle];
            attr=chosenStateAttribute;
        }
        else {
//            [aButton highlight: NO];
            [aButton setBordered: NO];
            if ([[ptyList objectAtIndex: i] refreshed])
                attr=([[ptyList objectAtIndex: i] idle])?idleStateAttribute:newOutputStateAttribute;
        }

        if ([[[ptyList objectAtIndex: i] name] length]<=10) {
            [aButton setAttributedTitle:[[NSAttributedString alloc] initWithString:[[ptyList objectAtIndex: i] name]
                                                              attributes:attr]];
        }
        else {
            [aButton setAttributedTitle:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@...%@",
                              [[[ptyList objectAtIndex: i] name] substringToIndex:5],
                              [[[ptyList objectAtIndex: i] name] substringFromIndex:
                                  [[[ptyList objectAtIndex: i] name] length]-3]]
                                                                        attributes:attr]];
        }
        
        [[WINDOW contentView] addSubview: aButton];
        [aButton setNeedsDisplay: YES];
        [buttonList addObject: aButton];
        [aButton release];
    }
    
    [ptyListLock unlock];
    
}

@end
