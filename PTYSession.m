/*
 **  PTYSession.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Implements the model class for a terminal session.
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

#import <iTerm/iTerm.h>
#import <iTerm/PTYSession.h>
#import <iTerm/PTYTask.h>
#import <iTerm/PTYTextView.h>
#import <iTerm/PTYScrollView.h>;
#import <iTerm/VT100Screen.h>
#import <iTerm/VT100Terminal.h>
#import <iTerm/PreferencePanel.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/iTermController.h>
#import <iTerm/NSStringITerm.h>
#import <iTerm/PTYTabViewitem.h>
#import <iTerm/AddressBookWindowController.h>
#import <iTerm/iTermImageView.h>

#import <iTerm/VT100TextStorage.h>
#import <iTerm/VT100LayoutManager.h>
#import <iTerm/VT100Typesetter.h>

#include <unistd.h>

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

@implementation PTYSession

static NSString *TERM_ENVNAME = @"TERM";
static NSString *PWD_ENVNAME = @"PWD";
static NSString *PWD_ENVVALUE = @"~";

// init/dealloc
- (id) init
{
    if((self = [super init]) == nil)
        return (nil);

    iIdleCount=0;
    oIdleCount=1000;
    blink = 0;
    output= 3;
    dirty = NO;
    waiting=antiIdle=EXIT=NO;
    
    if (normalStateAttribute == nil) 
    {
        normalStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor blackColor],NSForegroundColorAttributeName,nil] retain];
        chosenStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor blackColor],NSForegroundColorAttributeName,nil] retain];
        idleStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor redColor],NSForegroundColorAttributeName,nil] retain];
        newOutputStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor purpleColor],NSForegroundColorAttributeName,nil] retain];
        deadStateAttribute=[[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor grayColor],NSForegroundColorAttributeName,nil] retain];
    }
    addressBookEntry=nil;

#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYSession init 0x%x]", __FILE__, __LINE__, self);
#endif    
    
    return (self);
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYSession dealloc 0x%x]", __FILE__, __LINE__, self);
#endif

    [SHELL release];
    SHELL = nil;

    [SCREEN release];
    SCREEN = nil;
    [TERMINAL release];
    TERMINAL = nil;    
    
    [textStorage release];
    textStorage = nil;
    
    
    [TERM_VALUE release];
    [view release];
    [name release];
    [windowTitle release];
    [addressBookEntry release];
    [backgroundImagePath release];
        
    [normalStateAttribute release];
    normalStateAttribute = nil;
    [chosenStateAttribute release];
    chosenStateAttribute = nil;
    [idleStateAttribute release];
    idleStateAttribute = nil;
    [newOutputStateAttribute release];
    newOutputStateAttribute = nil;
     
    [super dealloc];    
}

// Session specific methods
- (void)initScreen: (NSRect) aRect
{
    NSSize aSize;
     
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession initScreen]",
          __FILE__, __LINE__);
#endif

    // Allocate screen, shell, and terminal objects
    SHELL = [[PTYTask alloc] init];
    TERMINAL = [[VT100Terminal alloc] init];
    SCREEN = [[VT100Screen alloc] init];
    NSParameterAssert(SHELL != nil && TERMINAL != nil && SCREEN != nil);

    [SCREEN setSession:self];
    [self setName:@"Shell"];

    // allocate an imageview for the background image
    imageView = [[iTermImageView alloc] initWithFrame: aRect];
    [imageView setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];

    // Allocate a scrollview
    SCROLLVIEW = [[PTYScrollView alloc] initWithFrame: NSMakeRect(0, 0, aRect.size.width, aRect.size.height)];
    [SCROLLVIEW setHasVerticalScroller:YES];
    NSParameterAssert(SCROLLVIEW != nil);
    [SCROLLVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];

    // add the scrollview as a subview to the imageview
    [imageView addSubview: SCROLLVIEW];
    [SCROLLVIEW release];

    // assign the main view
    view = imageView;
    
    // Allocate a text view
    aSize = [PTYScrollView contentSizeForFrameSize: [SCROLLVIEW frame].size hasHorizontalScroller: NO hasVerticalScroller: YES borderType: [SCROLLVIEW borderType]];
#if USE_CUSTOM_DRAWING
    TEXTVIEW = [[[PTYTextView alloc] initWithFrame: NSMakeRect(0, 0, aSize.width, aSize.height)] autorelease];
#else

    if([[PreferencePanel sharedInstance] enforceCharacterAlignment] == YES)
    {
        VT100LayoutManager* aLayoutManager = [[VT100LayoutManager alloc] init];
	VT100Typesetter *aTypesetter;
	NSTextContainer *aTextContainer;

	textStorage = [[VT100TextStorage alloc] init];
	[textStorage addLayoutManager:aLayoutManager];
	[aLayoutManager release];

        aTextContainer = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(aSize.width, 1e7)];
	[aLayoutManager addTextContainer:aTextContainer];
	[aTextContainer release];

        aTypesetter = [[VT100Typesetter alloc] init];
	[aTypesetter setScreen: SCREEN];
	[aLayoutManager setTypesetter: aTypesetter];
	[aTypesetter release];

        TEXTVIEW = [[PTYTextView alloc] initWithFrame: NSMakeRect(0, 0, aSize.width, aSize.height) textContainer: aTextContainer];
	[aTextContainer setWidthTracksTextView:YES];
	[aTextContainer setHeightTracksTextView:NO];
	[TEXTVIEW setMaxSize:NSMakeSize(1e7, 1e7)];
	[TEXTVIEW setHorizontallyResizable:NO];
	[TEXTVIEW setVerticallyResizable:YES];
    }
    else
	TEXTVIEW = [[[PTYTextView alloc] initWithFrame: NSMakeRect(0, 0, aSize.width, aSize.height)] autorelease];
  
    [TEXTVIEW setDrawsBackground:NO];
    [TEXTVIEW setEditable:YES]; // For NSTextInput protocol
    [TEXTVIEW setSelectable:YES];
    [TEXTVIEW setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
    
#endif

    // assign terminal and task objects
    [SCREEN setShellTask:SHELL];
    [SCREEN setTextStorage:[TEXTVIEW textStorage]];
    [SCREEN setTerminal:TERMINAL];
    [TERMINAL setScreen: SCREEN];
    [SHELL setDelegate:self];

    [TEXTVIEW setDataSource: SCREEN];
    [TEXTVIEW setDelegate: self];
    [TEXTVIEW setAntiAlias: [[PreferencePanel sharedInstance] antiAlias]];
    [SCROLLVIEW setDocumentView:TEXTVIEW];
    [TEXTVIEW release];
    [SCROLLVIEW setDocumentCursor: [NSCursor arrowCursor]];

    ai_code=0;
    antiIdle = NO;
    REFRESHED = NO;

    [tabViewItem setLabelAttributes: chosenStateAttribute];
}

- (BOOL) isActiveSession
{
    return ([[[self tabViewItem] tabView] selectedTabViewItem] == [self tabViewItem]);
}

- (void) startTimer
{
    timer =[[NSTimer scheduledTimerWithTimeInterval:0.02
                                             target:self
                                           selector:@selector(timerTick:)
                                           userInfo:nil
                                            repeats:YES] retain];
}

- (void)startProgram:(NSString *)program
	   arguments:(NSArray *)prog_argv
	 environment:(NSDictionary *)prog_env
{
    NSString *path = program;
    NSMutableArray *argv = [NSMutableArray arrayWithArray:prog_argv];
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:prog_env];
    NSSize screenSize, textViewSize, scrollViewSize;

    // set screen size
    screenSize = [VT100Screen screenSizeInFrame: [[self TEXTVIEW] frame] font: [[self SCREEN] font]];
    [[self SCREEN] setWidth: (int) screenSize.width height: (int) screenSize.height];
    textViewSize = [VT100Screen requireSizeWithFont:[[self SCREEN] tallerFont] width:(int) screenSize.width height:(int) screenSize.height];
    //[[self TEXTVIEW] setFrame: NSMakeRect(0, 0, textViewSize.width, textViewSize.height)];
    scrollViewSize = [PTYScrollView frameSizeForContentSize:textViewSize
						 hasHorizontalScroller:NO
						   hasVerticalScroller:YES
								borderType:NSNoBorder];
    //[[self SCROLLVIEW] setFrame: NSMakeRect(0, 0, scrollViewSize.width, scrollViewSize.height)];
    
        
    // initialize the screen
    [[self SCREEN] initScreen];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession startProgram:%@ arguments:%@ environment:%@]",
	  __FILE__, __LINE__, program, prog_argv, prog_env );
#endif
    if ([env objectForKey:TERM_ENVNAME] == nil)
        [env setObject:TERM_VALUE forKey:TERM_ENVNAME];

    if ([env objectForKey:PWD_ENVNAME] == nil)
        [env setObject:[PWD_ENVVALUE stringByExpandingTildeInPath] forKey:PWD_ENVNAME];

    [SHELL launchWithPath:path
		arguments:argv
	      environment:env
		    width:[SCREEN width]
		   height:[SCREEN height]];

}


- (void) terminate
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYSession -terminate: retainCount = %d]", __FILE__, __LINE__, [self retainCount]);
#endif

    [SHELL sendSignal: SIGHUP];
    if(tabViewItem)
    {
        [tabViewItem release];
        tabViewItem = nil;
    }
    [addressBookEntry release];
    addressBookEntry = nil;

    [SHELL setDelegate:nil];
    [SCREEN setShellTask:nil];
    [SCREEN setSession: nil];
    [SCREEN setTerminal: nil];
    [TERMINAL setScreen: nil];
    [TEXTVIEW setDataSource: nil];
    [TEXTVIEW removeFromSuperview];
    [self setTabViewItem: nil];    

    
    if (timer)
    {
        [timer invalidate];
        [timer release];
        timer = nil;
    }  
    
    parent = nil;
}

- (void)readTask:(NSData *)data
{
    VT100TCC token;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession readTask:%@]", __FILE__, __LINE__, [[[NSString alloc] initWithData: data encoding: nil] autorelease] );
#endif
    if (data == nil)
        return;

    [TERMINAL putStreamData:data];
    
#warning is this pending stuff necessary
    //    if ([parent pending] || [SCREEN screenIsLocked]) 
    if ([SCREEN screenIsLocked]) 
        return;
    
    if (REFRESHED==NO)
    {
        REFRESHED=YES;
        if([[tabViewItem tabView] selectedTabViewItem] != tabViewItem)
            [tabViewItem setLabelAttributes: newOutputStateAttribute];
    }

#if USE_CUSTOM_DRAWING
    [TEXTVIEW hideCursor];
#endif
    while (TERMINAL&&((token = [TERMINAL getNextToken]), 
	   token.type != VT100CC_NULL &&
	   token.type != VT100_WAIT))
    {
	if (token.type != VT100_SKIP)
	    [SCREEN putToken:token];
    }
    
    oIdleCount=0;
    if (token.type == VT100_NOTSUPPORT) {
	NSLog(@"%s(%d):not support token", __FILE__ , __LINE__);
    }

#if USE_CUSTOM_DRAWING
    [TEXTVIEW showCursor];
    [TEXTVIEW refresh];
//    [TEXTVIEW moveLastLine];
#endif
}

- (void)brokenPipe
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession brokenPipe]", __FILE__, __LINE__);
#endif
    [SHELL sendSignal:SIGKILL];
    [SHELL stop];
    EXIT = YES;

    if (timer) 
    {
        [timer invalidate];
        [timer release];
        timer=nil;
    }
    
    if (autoClose)
        [parent closeSession:self];
    else 
    {
        [self setName:[NSString stringWithFormat:@"[%@]",[self name]]];
        [tabViewItem setLabelAttributes: deadStateAttribute];
    }
}

// PTYTextView
- (void)keyDown:(NSEvent *)event
{
    unsigned char *send_str = NULL;
    size_t send_strlen = 0;
    int send_chr = -1;
    int send_pchr = -1;

    unsigned int modflag;
    unsigned short keycode;
    NSString *keystr;
    NSString *unmodkeystr;
    unichar unicode;
    
#if DEBUG_METHOD_TRACE || DEBUG_KEYDOWNDUMP
    NSLog(@"%s(%d):-[PseudoTerminal keyDown:%@]",
	  __FILE__, __LINE__, event);
#endif

    modflag = [event modifierFlags];
    keycode = [event keyCode];
    keystr  = [event characters];
    unmodkeystr = [event charactersIgnoringModifiers];
    unicode = [keystr length]>0?[keystr characterAtIndex:0]:0;

    iIdleCount=0;

//    NSLog(@"event:%@ (%x+%x)[%@][%@]:%x(%c)",
//          event,modflag,keycode,keystr,unmodkeystr,unicode,unicode);

    // Clear the bell
    [self setBell: NO];

    if ( (modflag & NSFunctionKeyMask) && [[PreferencePanel sharedInstance] macnavkeys] && ((unicode == NSPageUpFunctionKey) || (unicode == NSPageDownFunctionKey) || (unicode == NSHomeFunctionKey) || (unicode == NSEndFunctionKey)) ) {
        modflag ^= NSShiftKeyMask; // Toggle meaning of shift key for
    }

    // Check if we are navigating through sessions or scrolling
    if ((modflag & NSFunctionKeyMask) && ((modflag & NSCommandKeyMask) || (modflag & NSShiftKeyMask)))
    {
	// command/shift + function key's
	switch (unicode)
	{
	    case NSLeftArrowFunctionKey: // cursor left
					    // Check if we want to just move to the previous session
		[parent previousSession: nil];
		return;
	    case NSRightArrowFunctionKey: // cursor left
					    // Check if we want to just move to the next session
		[parent nextSession: nil];
		return;
	    case NSDeleteFunctionKey:
                // NSLog(@"### DEBUG ###\n%@", SCREEN);
		break;
	    case NSPageUpFunctionKey:
                [TEXTVIEW scrollPageUp: self];
		break;
	    case NSPageDownFunctionKey:
                [TEXTVIEW scrollPageDown: self];
		break;
	    case NSHomeFunctionKey:
                [TEXTVIEW scrollHome];
		break;
	    case NSEndFunctionKey:
                [TEXTVIEW scrollEnd];
		break;
	    case NSClearLineFunctionKey:
		if(modflag & NSCommandKeyMask)
		    [TERMINAL toggleNumLock];
		break;
            case NSUpArrowFunctionKey:
                if ((modflag & NSShiftKeyMask) && (modflag & NSCommandKeyMask))
                    [TEXTVIEW scrollPageUp: self];
                else
                    [TEXTVIEW scrollLineUp: self];
                break;
            case NSDownArrowFunctionKey:
                if ((modflag & NSShiftKeyMask) && (modflag & NSCommandKeyMask))
                    [TEXTVIEW scrollPageDown: self];
                else
                    [TEXTVIEW scrollLineDown: self];
                break;
                
	    default:
		if (NSF1FunctionKey<=unicode&&unicode<=NSF35FunctionKey)
		    [parent selectSessionAtIndex:unicode-NSF1FunctionKey];                    
		break;
	}
    }
    else if((modflag & NSAlternateKeyMask) && (unicode == NSDeleteCharacter))
	[self setRemapDeleteKey: ![self remapDeleteKey]];
    else 
    {
	if (modflag & NSFunctionKeyMask)
        {
	    NSData *data = nil;

	    switch(unicode) 
            {
                case NSUpArrowFunctionKey: data = [TERMINAL keyArrowUp:modflag]; break;
		case NSDownArrowFunctionKey: data = [TERMINAL keyArrowDown:modflag]; break;
		case NSLeftArrowFunctionKey: data = [TERMINAL keyArrowLeft:modflag]; break;
		case NSRightArrowFunctionKey: data = [TERMINAL keyArrowRight:modflag]; break;

		case NSInsertFunctionKey:
		    // case NSHelpFunctionKey:
		    data = [TERMINAL keyInsert]; break;
		case NSDeleteFunctionKey:
		    data = [TERMINAL keyDelete]; break;
		case NSHomeFunctionKey: data = [TERMINAL keyHome]; break;
		case NSEndFunctionKey: data = [TERMINAL keyEnd]; break;
		case NSPageUpFunctionKey: data = [TERMINAL keyPageUp]; break;
		case NSPageDownFunctionKey: data = [TERMINAL keyPageDown]; break;

		case NSPrintScreenFunctionKey:
		    break;
		case NSScrollLockFunctionKey:
		case NSPauseFunctionKey:
		    break;
		case NSClearLineFunctionKey:
		    if(![TERMINAL numLock] || [TERMINAL keypadMode])
			data = [TERMINAL keyPFn: 1];
		    break;
	    }

            if (NSF1FunctionKey<=unicode&&unicode<=NSF35FunctionKey)
                data = [TERMINAL keyFunction:unicode-NSF1FunctionKey+1];

	    if (data != nil) {
		send_str = (char *)[data bytes];
		send_strlen = [data length];
	    }
	}
	else if ([[PreferencePanel sharedInstance] option] != OPT_NORMAL &&
		    modflag & NSAlternateKeyMask)
	{
	    NSData *keydat = ((modflag & NSControlKeyMask) && unicode>0)?
	    [keystr dataUsingEncoding:NSUTF8StringEncoding]:
	    [unmodkeystr dataUsingEncoding:NSUTF8StringEncoding];
	    // META combination
	    if (keydat != nil) {
		send_str = (char *)[keydat bytes];
		send_strlen = [keydat length];
	    }
            if ([[PreferencePanel sharedInstance] option] == OPT_ESC) {
		send_pchr = '\e';
//                send_chr=unmodkeystr;
            }
	    else if ([[PreferencePanel sharedInstance] option] == OPT_META && send_str != NULL) 
            {
		int i;
		for (i = 0; i < send_strlen; ++i)
		    send_str[i] |= 0x80;
	    }
	}
	else 
        {
	    int max = [keystr length];
	    NSData *data;

            if (max!=1||[keystr characterAtIndex:0] > 0x7f)
                data = [keystr dataUsingEncoding:[TERMINAL encoding]];
            else
                data = [keystr dataUsingEncoding:NSUTF8StringEncoding];

	    // Check if we are in keypad mode
	    if((modflag & NSNumericPadKeyMask) && (![TERMINAL numLock] || [TERMINAL keypadMode]))
	    {
		switch (unicode)
		{
		    case '=':
			data = [TERMINAL keyPFn: 2];;
			break;
		    case '/':
			data = [TERMINAL keyPFn: 3];
			break;
		    case '*':
			data = [TERMINAL keyPFn: 4];
			break;
		    default:
			data = [TERMINAL keypadData: unicode keystr: keystr];
			break;
		}
	    }

	    // Check if we want to remap the delete key to backspace
	    if((unicode == NSDeleteCharacter) && [self remapDeleteKey])
		data = [TERMINAL keyBackspace];

	    if (data != nil ) {
		send_str = (char *)[data bytes];
		send_strlen = [data length];
	    }

	    if ((modflag & NSNumericPadKeyMask &&
		send_strlen == 1 &&
		send_str[0] == 0x03) || keycode==52)
	    {
		send_str = "\012";  // NumericPad or Laptop Enter -> 0x0a
		send_strlen = 1;
	    }
	    if (modflag & NSControlKeyMask &&
		send_strlen == 1 &&
		send_str[0] == '|')
	    {
		send_str = "\034"; // ^\
		send_strlen = 1;
	    }
	}

	// Make sure we scroll down to the end
	[TEXTVIEW scrollEnd];

	if (EXIT == NO ) 
        {
	    if (send_pchr >= 0) {
		char c = send_pchr;

		[SHELL writeTask:[NSData dataWithBytes:&c length:1]];
	    }
	    if (send_chr >= 0) {
		char c = send_chr;

		[SHELL writeTask:[NSData dataWithBytes:&c length:1]];
	    }
	    if (send_str != NULL) {
		[SHELL writeTask:[NSData dataWithBytes:send_str length:send_strlen]];
	    }

#if USE_CUSTOM_DRAWING
            [TEXTVIEW scrollEnd];
#else
	    // scroll to the end
            //[TEXTVIEW scrollEnd];
            PTYScroller *ptys=(PTYScroller *)[SCROLLVIEW verticalScroller];
            [ptys setUserScroll: NO];
	    //[SCREEN updateScreen];
#endif
	}
    }
}

- (BOOL)willHandleEvent: (NSEvent *) theEvent
{
    // Handle the option-click event
    return (([theEvent type] == NSLeftMouseDown) &&
	    ([theEvent modifierFlags] & NSAlternateKeyMask));       
}

- (void)handleEvent: (NSEvent *) theEvent
{
    // We handle option-click to position the cursor...
    if(([theEvent type] == NSLeftMouseDown) &&
       ([theEvent modifierFlags] & NSAlternateKeyMask))
	[self handleOptionClick: theEvent];
}

- (void) handleOptionClick: (NSEvent *) theEvent
{
    // Here we will attempt to position the cursor to the mouse-click

    NSPoint locationInWindow, locationInTextView, locationInScrollView;
    NSSize fontSize;
    int x, y;

    locationInWindow = [theEvent locationInWindow];
    locationInTextView = [TEXTVIEW convertPoint: locationInWindow fromView: nil];
    locationInScrollView = [SCROLLVIEW convertPoint: locationInWindow fromView: nil];

    fontSize = [SCREEN characterSize];
    x = (locationInTextView.x - fontSize.width)/fontSize.width + 1;
    y = locationInScrollView.y/fontSize.height + 1;

    // NSLog(@"loc_x = %f; loc_y = %f", locationInTextView.x, locationInScrollView.y);
    // NSLog(@"font width = %f, font height = %f", fontSize.width, fontSize.height);
    // NSLog(@"x = %d; y = %d", x, y);


    if(x == [SCREEN cursorX] && y == [SCREEN cursorY])
	return;

    NSData *data;
    int i;
    // now move the cursor up or down
    for(i = 0; i < abs(y - [SCREEN cursorY]); i++)
    {
	if(y < [SCREEN cursorY])
            data = [TERMINAL keyArrowUp:0];
	else
            data = [TERMINAL keyArrowDown:0];
	[SHELL writeTask:[NSData dataWithBytes:[data bytes] length:[data length]]];
    }
    // now move the cursor left or right    
    for(i = 0; i < abs(x - [SCREEN cursorX]); i++)
    {
	if(x < [SCREEN cursorX])
	    data = [TERMINAL keyArrowLeft:0];
	else
	    data = [TERMINAL keyArrowRight:0];
	[SHELL writeTask:[NSData dataWithBytes:[data bytes] length:[data length]]];
    }
    
    // trigger an update of the display.
    [SCREEN updateScreen];
}

// do any idle tasks here
- (void) doIdleTasks
{
    [SCREEN removeOverLine];
}

- (void)insertText:(NSString *)string
{
    NSData *data;
    NSMutableString *mstring;
    int i, max;

//    NSLog(@"insertText: %@",string);
    mstring = [NSMutableString stringWithString:string];
    max = [string length];
    for(i=0; i<max; i++) {
        if ([mstring characterAtIndex:i] == 0xa5) {
            [mstring replaceCharactersInRange:NSMakeRange(i, 1) withString:@"\\"];
        }
    }

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession insertText:%@]",
	  __FILE__, __LINE__, mstring);
#endif

    //if([TERMINAL encoding] != NSUTF8StringEncoding) {
    //    data = [mstring dataUsingEncoding:[TERMINAL encoding]
    //                allowLossyConversion:YES];
    //} else {
    //    char *fs_str = (char *)[mstring fileSystemRepresentation];
    //    data = [NSData dataWithBytes:fs_str length:strlen(fs_str)];
    //}
    
    data = [mstring dataUsingEncoding:[TERMINAL encoding]
		 allowLossyConversion:YES];

    if (data != nil) 
	[SHELL writeTask:data];
}

- (void)insertNewline:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession insertNewline:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [self insertText:@"\n"];
}

- (void)insertTab:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession insertTab:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [self insertText:@"\t"];
}

- (void)moveUp:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession moveUp:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowUp:0]];
}

- (void)moveDown:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession moveDown:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowDown:0]];
}

- (void)moveLeft:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession moveLeft:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowLeft:0]];
}

- (void)moveRight:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession moveRight:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowRight:0]];
}

- (void)pageUp:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession pageUp:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyPageUp]];
}

- (void)pageDown:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession pageDown:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyPageDown]];
}

- (void)paste:(id)sender
{
    NSPasteboard *board;
    NSString *str;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession paste:...]", __FILE__, __LINE__);
#endif

    board = [NSPasteboard generalPasteboard];
    NSParameterAssert(board != nil );
    str = [board stringForType:NSStringPboardType];
    [self pasteString: str];
}

- (void) pasteString: (NSString *) aString
{
    if ([aString length] > 0)
    {
        NSData *strdata = [[aString stringReplaceSubstringFrom:@"\n" to:@"\r"]
                                    dataUsingEncoding:[TERMINAL encoding]
                                allowLossyConversion:YES];
        if (strdata != nil){
	    // Do this in a new thread since we do not want to block the read code.
	    [NSThread detachNewThreadSelector:@selector(writeTask:) toTarget:SHELL withObject:strdata];
	    //[SHELL writeTask:strdata];
	}
    }
    else
	NSBeep();
}

- (void)deleteBackward:(id)sender
{
    unsigned char p = 0x08;	// Ctrl+H

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession deleteBackward:%@]",
	  __FILE__, __LINE__, sender);
#endif

    [SHELL writeTask:[NSData dataWithBytes:&p length:1]];
}

- (void)deleteForward:(id)sender
{
    unsigned char p = 0x7F;	// DEL

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession deleteForward:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[NSData dataWithBytes:&p length:1]];
}

- (void) textViewDidChangeSelection: (NSNotification *) aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession textViewDidChangeSelection]",
	  __FILE__, __LINE__);
#endif

    if([[PreferencePanel sharedInstance] copySelection])
	[TEXTVIEW copy: self];
}

- (void) textViewResized: (PTYTextView *) textView;
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession textViewResized: 0x%x]",
	  __FILE__, __LINE__, textView);
#endif

    [[self parent] windowDidResize: nil];
    [textView scrollEnd];
}

- (void) timerTick:(NSTimer*)sender
{
 //   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    iIdleCount++; oIdleCount++; blink++;
    if (++output>1000) output=1000;
    
    if (antiIdle) 
    {
        if (iIdleCount>=6000)
        {
            [SHELL writeTask:[NSData dataWithBytes:&ai_code length:1]];
            iIdleCount=0;
        }
    }
    if([[tabViewItem tabView] selectedTabViewItem] != tabViewItem) 
        [self setLabelAttribute];

#if USE_CUSTOM_DRAWING
    if (output>10&&dirty) {
	// If the user has not scrolled up, move to the end
//	if([[SCROLLVIEW verticalScroller] floatValue] == 0 	// scroller is at top
//    || [[SCROLLVIEW verticalScroller] floatValue] == 1)	// scroller is at end
        if (![[SCROLLVIEW verticalScroller] userScroll])
	    [TEXTVIEW scrollEnd];
        output=0;
        dirty=NO;
    }
    if (oIdleCount<2) dirty=YES;
    
#else
    if (blink>15) {
	[SCREEN blink];
	blink=0;
    }
    if (oIdleCount<2||dirty) 
    {
        if (output>3) 
        {
            [SCREEN updateScreen];
	    //NSLog(@"floatValue = %f", [[SCROLLVIEW verticalScroller] floatValue]);
            // If the user has not scrolled up, move to the end
	    //	if([[SCROLLVIEW verticalScroller] floatValue] == 0 	// scroller is at top
     //    || [[SCROLLVIEW verticalScroller] floatValue] == 1)	// scroller is at end
	    if (![(PTYScroller *)[SCROLLVIEW verticalScroller] userScroll])
                [TEXTVIEW scrollEnd];
            output=0;
            dirty=NO;
        }
        else dirty=YES;
    }
#endif

//    [pool release];
}

- (void) setLabelAttribute
{
    if ([self exited])
        [tabViewItem setLabelAttributes: deadStateAttribute];
    else if([[tabViewItem tabView] selectedTabViewItem] != tabViewItem) 
    {
        if (oIdleCount>200&&!waiting) {
            waiting=YES;
            if (REFRESHED)
                [tabViewItem setLabelAttributes: idleStateAttribute];
            else
                [tabViewItem setLabelAttributes: normalStateAttribute];
        }
        else if (waiting&&oIdleCount<=200) {
            waiting=NO;
            [tabViewItem setLabelAttributes: newOutputStateAttribute];
        }
    }
    else {
        [tabViewItem setLabelAttributes: chosenStateAttribute];
    }
    [self setBell:NO];
}

- (void) setBell
{
    [self setBell:YES];
}

- (void) setBell: (BOOL) flag
{
    [tabViewItem setBell:flag];
}

- (void) setPreferencesFromAddressBookEntry: (NSDictionary *) aePrefs
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession setPreferencesFromAddressBookEntry:");
#endif
    
    NSColor *colorTable[2][8];
    int i;
    BOOL useBackgroundImage;
    NSString *imageFilePath;

    // colors
    [self setForegroundColor: [aePrefs objectForKey: @"Foreground"]];
    [self setBackgroundColor: [aePrefs objectForKey: @"Background"]];
    if([aePrefs objectForKey: @"SelectionColor"] != nil)
	[self setSelectionColor: [aePrefs objectForKey: @"SelectionColor"]];
    else
	[self setSelectionColor: [AddressBookWindowController defaultSelectionColor]];
    if([aePrefs objectForKey: @"BoldColor"] != nil)
	[self setBoldColor: [aePrefs objectForKey: @"BoldColor"]];
    else
	[self setBoldColor: [AddressBookWindowController defaultBoldColor]];
    if([aePrefs objectForKey: @"AnsiBlackColor"] == nil)
    {
	for(i = 0; i < 8; i++)
	{
	    colorTable[0][i] = [AddressBookWindowController colorFromTable: i highLight: NO];
	    colorTable[1][i] = [AddressBookWindowController colorFromTable: i highLight: YES];
	}
    }
    else
    {
	colorTable[0][0]= [aePrefs objectForKey:@"AnsiBlackColor"];
	colorTable[0][1]= [aePrefs objectForKey:@"AnsiRedColor"];
	colorTable[0][2]= [aePrefs objectForKey:@"AnsiGreenColor"];
	colorTable[0][3]= [aePrefs objectForKey:@"AnsiYellowColor"];
	colorTable[0][4]= [aePrefs objectForKey:@"AnsiBlueColor"];
	colorTable[0][5]= [aePrefs objectForKey:@"AnsiMagentaColor"];
	colorTable[0][6]= [aePrefs objectForKey:@"AnsiCyanColor"];
	colorTable[0][7]= [aePrefs objectForKey:@"AnsiWhiteColor"];
	colorTable[1][0]= [aePrefs objectForKey:@"AnsiHiBlackColor"];
	colorTable[1][1]= [aePrefs objectForKey:@"AnsiHiRedColor"];
	colorTable[1][2]= [aePrefs objectForKey:@"AnsiHiGreenColor"];
	colorTable[1][3]= [aePrefs objectForKey:@"AnsiHiYellowColor"];
	colorTable[1][4]= [aePrefs objectForKey:@"AnsiHiBlueColor"];
	colorTable[1][5]= [aePrefs objectForKey:@"AnsiHiMagentaColor"];
	colorTable[1][6]= [aePrefs objectForKey:@"AnsiHiCyanColor"];
	colorTable[1][7]= [aePrefs objectForKey:@"AnsiHiWhiteColor"];
    }
    for(i=0;i<8;i++) {
        [self setColorTable:i highLight:NO color:colorTable[0][i]];
        [self setColorTable:i highLight:YES color:colorTable[1][i]];
    }

    // set the font
    //[[self SCREEN] setFont: [aePrefs objectForKey:@"Font"] nafont: [aePrefs objectForKey:@"NAFont"]];
    // set the scrolling
    [[self SCROLLVIEW] setVerticalLineScroll: [[self SCREEN] characterSize].height];
    [[self SCROLLVIEW] setVerticalPageScroll: [[self TEXTVIEW] frame].size.height];

    // background image
    useBackgroundImage = [[aePrefs objectForKey:@"UseBackgroundImage"] boolValue];
    imageFilePath = [[aePrefs objectForKey:@"BackgroundImagePath"] stringByExpandingTildeInPath];
    if(useBackgroundImage && [imageFilePath length] > 0)
	[self setBackgroundImagePath: imageFilePath];

    // transparency
    [self setTransparency: [[aePrefs objectForKey: @"Transparency"] floatValue]/100.0];    

    // set up the rest of the preferences
    [self setEncoding: [[aePrefs objectForKey:@"Encoding"] unsignedIntValue]];
    [self setTERM_VALUE: [aePrefs objectForKey:@"Term Type"]];
    [self setAntiCode:[[aePrefs objectForKey:@"AICode"] intValue]];
    [self setAntiIdle:[[aePrefs objectForKey:@"AntiIdle"] boolValue]];
    [self setAutoClose:[[aePrefs objectForKey:@"AutoClose"] boolValue]];
    [self setDoubleWidth:[[aePrefs objectForKey:@"DoubleWidth"] boolValue]];
    [self setRemapDeleteKey: [[[self addressBookEntry] objectForKey: @"RemapDeleteKey"] boolValue]];
    
}

// Contextual menu
- (void) menuForEvent:(NSEvent *)theEvent menu: (NSMenu *) theMenu
{
    NSMenuItem *aMenuItem;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession menuForEvent]", __FILE__, __LINE__);
#endif

    // Clear buffer
    aMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"Clear Buffer",@"iTerm", [NSBundle bundleForClass: [self class]], @"Context menu") action:@selector(clearBuffer:) keyEquivalent:@""];
    [aMenuItem setTarget: [self parent]];
    [theMenu addItem: aMenuItem];
    [aMenuItem release];
    
    // Ask the parent if it has anything to add
    if ([[self parent] respondsToSelector:@selector(menuForEvent: menu:)])
	[[self parent] menuForEvent:theEvent menu: theMenu];    
}

- (PseudoTerminal *) parent
{
    return (parent);
}

- (void) setParent: (PseudoTerminal *) theParent
{
    parent = theParent; // don't retain parent. parent retains self.
}

- (PTYTabViewItem *) tabViewItem
{
    return (tabViewItem);
}

- (void) setTabViewItem: (PTYTabViewItem *) theTabViewItem
{
    [tabViewItem release];
    tabViewItem = [theTabViewItem retain];
}

- (NSString *) uniqueID
{
    return ([self tty]);
}

- (void) setUniqueID: (NSString *)uniqueID
{
    NSLog(@"Not allowed to set unique ID");
}

- (NSString *) name
{
    return (name);
}

- (void) setName: (NSString *) theName
{
    NSMutableString *aMutableString;

    if([name isEqualToString: theName])
	return;
    
    if(name)
    {
	// clear the window title if it is not different
	if([self windowTitle] == nil || [name isEqualToString: [self windowTitle]])
	    [self setWindowTitle: nil];
        [name release];
        name = nil;
    }
    if(theName)
    {
        name = [theName retain];
	// sync the window title if it is not set to something else
	if([self windowTitle] == nil)
	    [self setWindowTitle: theName];
    }
    if([theName length] > 20)
    {
        aMutableString = [[NSMutableString alloc] initWithString: [theName substringWithRange: NSMakeRange(0, 17)]];
        [aMutableString appendString: @"..."];
        [tabViewItem setLabel: aMutableString];
        [self setBell: NO];
        [aMutableString release];
    }
    else {
        [tabViewItem setLabel: theName];
        [self setBell: NO];
    }

    // get the session submenu to be rebuilt
    if([[iTermController sharedInstance] frontPseudoTerminal] == [self parent])
    {
	[[NSNotificationCenter defaultCenter] postNotificationName: @"iTermNameOfSessionDidChange" object: self userInfo: nil];
    }
}

- (NSString *) windowTitle
{
    return (windowTitle);
}

- (void) setWindowTitle: (NSString *) theTitle
{
    [windowTitle autorelease];
    windowTitle = nil;
    
    if(theTitle != nil)
    {
	windowTitle = [theTitle retain];
	if([[self parent] currentSession] == self)
	    [[[self parent] window] setTitle: windowTitle];
    }
}

- (PTYTask *) SHELL
{
    return (SHELL);
}

- (void) setSHELL: (PTYTask *) theSHELL
{
    [SHELL autorelease];
    SHELL = [theSHELL retain];
}

- (VT100Terminal *) TERMINAL
{
    return (TERMINAL);
}

- (void) setTERMINAL: (VT100Terminal *) theTERMINAL
{
    [TERMINAL autorelease];
    TERMINAL = [theTERMINAL retain];
}

- (NSString *) TERM_VALUE
{
    return (TERM_VALUE);
}

- (void) setTERM_VALUE: (NSString *) theTERM_VALUE
{
    [TERM_VALUE autorelease];
    TERM_VALUE = [theTERM_VALUE retain];
}

- (VT100Screen *) SCREEN
{
    return (SCREEN);
}

- (void) setSCREEN: (VT100Screen *) theSCREEN
{
    [SCREEN autorelease];
    SCREEN = [theSCREEN retain];
}

- (NSImage *) image
{
    return ([imageView image]);
}

- (NSView *) view
{
    return (view);
}

- (PTYTextView *) TEXTVIEW
{
    return (TEXTVIEW);
}

- (void) setTEXTVIEW: (PTYTextView *) theTEXTVIEW
{
    [TEXTVIEW autorelease];
    TEXTVIEW = [theTEXTVIEW retain];
}

- (PTYScrollView *) SCROLLVIEW
{
    return (SCROLLVIEW);
}

- (void) setSCROLLVIEW: (PTYScrollView *) theSCROLLVIEW
{
    [SCROLLVIEW autorelease];
    SCROLLVIEW = [theSCROLLVIEW retain];
}

- (void)setEncoding:(NSStringEncoding)encoding
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setEncoding:%d]",
          __FILE__, __LINE__, encoding);
#endif
    [TERMINAL setEncoding:encoding];
}

- (NSString *) tty
{
    return ([SHELL tty]);
}

- (int) number
{
    return ([[tabViewItem tabView] indexOfTabViewItem: tabViewItem]);
}

- (NSString *) backgroundImagePath
{
    return (backgroundImagePath);
}

- (void) setBackgroundImagePath: (NSString *) imageFilePath
{
    [backgroundImagePath release];
    [imageFilePath retain];
    backgroundImagePath = imageFilePath;
    if([backgroundImagePath length] > 0)
    {
	NSImage *anImage = [[NSImage alloc] initByReferencingFile: backgroundImagePath];
	if(anImage != nil)
	{
	    [SCROLLVIEW setDrawsBackground: NO];
	    [imageView setImage: anImage];
	    [anImage setScalesWhenResized: YES];
	    [imageView setImageScaling: NSScaleToFit];
	    [anImage release];
	}
    }
    else
    {
	[imageView setImage: nil];
	[SCROLLVIEW setDrawsBackground: YES];
    }
}


- (NSColor *) foregroundColor
{
    return ([TERMINAL defaultFGColor]);
}

- (void)setForegroundColor:(NSColor*) color
{
    if(color == nil)
        return;

#if USE_CUSTOM_DRAWING
#else
    [TEXTVIEW setTextColor: color];
#endif
    
    if(([TERMINAL defaultFGColor] != color) || 
        ([[TERMINAL defaultFGColor] alphaComponent] != [color alphaComponent]))
    {
        // Change the fg color for future stuff
        [TERMINAL setFGColor: color];
    }
}

- (NSColor *) backgroundColor
{
    return ([TERMINAL defaultBGColor]);
}

- (void)setBackgroundColor:(NSColor*) color
{
    if(color == nil)
        return;
      
    if(([TERMINAL defaultBGColor] != color) || 
        ([[TERMINAL defaultBGColor] alphaComponent] != [color alphaComponent]))
    {
        // Change the bg color for future stuff
        [TERMINAL setBGColor: color];
    }
    
    [[self SCROLLVIEW] setBackgroundColor: color];
}

- (NSColor *) boldColor
{
    return ([TERMINAL defaultBoldColor]);
}

- (void)setBoldColor:(NSColor*) color
{
    [[self TERMINAL] setBoldColor: color];
}

- (NSColor *) selectionColor
{
    return ([TEXTVIEW selectionColor]);
}

- (void) setSelectionColor: (NSColor *) color
{
    [TEXTVIEW setSelectionColor: color];
}

// Changes transparency

- (float) transparency
{
    if([imageView image] != nil)
    {
	return ([imageView transparency]);
    }
    else
    {
	return (1 - [[TERMINAL defaultBGColor] alphaComponent]);
    }
}

- (void)setTransparency:(float)transparency
{
    NSColor *newcolor;

    if([imageView image] != nil)
    {
	[imageView setTransparency: transparency];
    }
    else
    {
	newcolor = [[TERMINAL defaultBGColor] colorWithAlphaComponent:(1 - transparency)];
	if (newcolor != nil && newcolor != [TERMINAL defaultBGColor])
	{
	    [self setBackgroundColor: newcolor];
	    [TEXTVIEW setNeedsDisplay: YES];
	}
    }
}

- (void) setColorTable:(int) index highLight:(BOOL)hili color:(NSColor *) c
{
    [TERMINAL setColorTable:index highLight:hili color:c];
}

- (BOOL) antiIdle
{
    return antiIdle;
}

- (int) antiCode
{
    return ai_code;
}

- (void) setAntiIdle:(BOOL)set
{
    antiIdle=set;
    if (antiIdle) 
        iIdleCount=0;
}

- (void) setAntiCode:(int)code
{
    ai_code=code;
}

- (BOOL) autoClose
{
    return autoClose;
}

- (void) setAutoClose:(BOOL)set
{
    autoClose=set;
}

- (BOOL) doubleWidth
{
    return doubleWidth;
}

- (void) setDoubleWidth:(BOOL)set
{
    doubleWidth=set;
}

- (void)logStart
{
    NSSavePanel *panel;
    int sts;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession logStart:%@]",
          __FILE__, __LINE__);
#endif
    panel = [NSSavePanel savePanel];
    sts = [panel runModalForDirectory:NSHomeDirectory() file:@""];
    if (sts == NSOKButton) {
        BOOL logsts = [SHELL loggingStartWithPath:[panel filename]];
        if (logsts == NO)
            NSBeep();
    }
}

- (void)logStop
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession logStop:%@]",
          __FILE__, __LINE__);
#endif
    [SHELL loggingStop];
}

- (void)clearBuffer
{
    //char formFeed = 0x0c; // ^L
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession clearBuffer:...]", __FILE__, __LINE__);
#endif
    //[TERMINAL cleanStream];

    [SCREEN clearBuffer];
    // tell the shell to clear the screen
    //[SHELL writeTask:[NSData dataWithBytes:&formFeed length:1]];
}

- (void)clearScrollbackBuffer
{
    [SCREEN clearScrollbackBuffer];
}

- (BOOL)refreshed
{
    return REFRESHED;
}

- (void) resetStatus;
{
    waiting = REFRESHED = NO;
}

- (BOOL)exited
{
    return EXIT;
}

- (void) setAddressBookEntry:(NSDictionary*) entry
{
    [addressBookEntry release];
    addressBookEntry = [entry retain];
}

- (NSDictionary *)addressBookEntry
{
    return addressBookEntry;
}

- (BOOL) remapDeleteKey
{
    return (remapDeleteKey);
}

- (void) setRemapDeleteKey: (BOOL) flag
{
    remapDeleteKey = flag;
}

- (NSTextStorage *) textStorage
{
    return ([TEXTVIEW textStorage]);
}

@end

@implementation PTYSession (ScriptingSupport)

// Object specifier
- (NSScriptObjectSpecifier *)objectSpecifier
{
    unsigned index = 0;
    id classDescription = nil;

    NSScriptObjectSpecifier *containerRef = nil;

    NSArray *recipients = [[self parent] sessions];
    index = [recipients indexOfObjectIdenticalTo:self];
    if (index != NSNotFound)
    {
	containerRef     = [[self parent] objectSpecifier];
	classDescription = [containerRef keyClassDescription];
	//create and return the specifier
	return [[[NSIndexSpecifier allocWithZone:[self zone]]
               initWithContainerClassDescription: classDescription
                              containerSpecifier: containerRef
                                             key: @ "sessions"
                                           index: index] autorelease];
    } else {
	// NSLog(@"recipient not found!");
        return nil;
    }

}

// Handlers for supported commands:
-(void)handleExecScriptCommand: (NSScriptCommand *)aCommand
{
    // if we are already doing something, get out.
    if([SHELL pid] > 0)
    {
	NSBeep();
	return;
    }
    
    // Get the command's arguments:
    NSDictionary *args = [aCommand evaluatedArguments];
    NSString *command = [args objectForKey:@"command"];

    NSString *cmd;
    NSArray *arg;

    [iTermController breakDown:command cmdPath:&cmd cmdArgs:&arg];

    [self startProgram:cmd arguments:arg environment:[NSDictionary dictionary]];
    
    return;
}

-(void)handleSelectScriptCommand: (NSScriptCommand *)command
{
    [parent selectSession: self];
}

-(void)handleWriteScriptCommand: (NSScriptCommand *)command
{
    // Get the command's arguments:
    NSDictionary *args = [command evaluatedArguments];
    // optional argument follows (might be nil):
    NSString *contentsOfFile = [args objectForKey:@"contentsOfFile"];
    // optional argument follows (might be nil):
    NSString *text = [args objectForKey:@"text"];
    NSData *data = nil;
    NSString *aString = nil;

    if(text != nil)
    {
	aString = [NSString stringWithFormat:@"%@\n", text];
	data = [aString dataUsingEncoding: [TERMINAL encoding]];
    }

    if(contentsOfFile != nil)
    {
	aString = [NSString stringWithContentsOfFile: contentsOfFile];
	data = [aString dataUsingEncoding: [TERMINAL encoding]];
    }

    if(data != nil && [SHELL pid] > 0)
    {
	int i = 0;
	// wait here until we have had some output
	while([SHELL hasOutput] == NO && i < 5000000)
	{
	    usleep(50000);
	    i += 50000;
	}
	
	// do this in a new thread so that we don't get stuck.
	[NSThread detachNewThreadSelector:@selector(writeTask:) toTarget:SHELL withObject:data];
    }
}

-(void)handleTerminateScriptCommand: (NSScriptCommand *)command
{
    [[self parent] closeSession: self];
}

@end

@implementation PTYSession (Private)

-(void)_waitToWriteToTask: (NSData *) data
{
    int i = 0;
    // wait here until we have had some output
    while([SHELL hasOutput] == NO && i < 5000000)
    {
	usleep(50000);
	i += 50000;
    }
    [SHELL writeTask: data];
}

@end
