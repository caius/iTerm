//
//  PTYSession.m
//  iTerm
//
//  Created by Ujwal Sathyam on Sun Nov 10 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "PTYSession.h"
#import "PTYTask.h"
#import "PTYTextView.h"
#import "VT100Screen.h"
#import "VT100Terminal.h"
#import "PreferencePanel.h"
#import "PseudoTerminal.h"
#import "MainMenu.h"
#import "NSStringITerm.h"

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
    
    iIdleCount=oIdleCount=0;
    waiting=antiIdle=NO;
    
    return (self);
    
}
- (void) dealloc
{

#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYSession dealloc]", __FILE__, __LINE__);
#endif

    if(parent)
        [parent release];
                
    if(TERM_VALUE)
        [TERM_VALUE release];
    
    if(TEXTVIEW)
        [TEXTVIEW release];
        
    if(name)
        [name release];
        
    [super dealloc];    
    
}

// Session specific methods
- (void)initScreen: (NSRect) aRect
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal initScreen]",
          __FILE__, __LINE__);
#endif

    // Allocate a text view
    TEXTVIEW = [[PTYTextView alloc] initWithFrame: aRect];
    [TEXTVIEW setDrawsBackground:NO];
    [TEXTVIEW setEditable:YES];
    [TEXTVIEW setSelectable:YES];
    
    // Allocate screen, shell, and terminal objects
    SHELL = [[PTYTask alloc] init];
    TERMINAL = [[VT100Terminal alloc] init];
    SCREEN = [[VT100Screen alloc] init];
    NSParameterAssert(SHELL != nil && TERMINAL != nil && SCREEN != nil);

    [SCREEN setSession:self];
//    [SCREEN setWindow:[parent window]];
    [self setName:@"Shell"];

    ai_code=0;
    timer =[[NSTimer scheduledTimerWithTimeInterval:0.5
                                             target:self
                                           selector:@selector(timerTick:)
                                           userInfo:nil
                                            repeats:YES] retain];
    antiIdle = NO;
    REFRESHED = NO;
        
}

- (void)startProgram:(NSString *)program
	   arguments:(NSArray *)prog_argv
	 environment:(NSDictionary *)prog_env
{
    NSString *path = program;
    NSMutableArray *argv = [NSMutableArray arrayWithArray:prog_argv];
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:prog_env];

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal startProgram:%@ arguments:%@ environment:%@]",
	  __FILE__, __LINE__, program, prog_argv, prog_env );
#endif
    if ([env objectForKey:TERM_ENVNAME] == nil)
        [env setObject:TERM_VALUE forKey:TERM_ENVNAME];

    if ([env objectForKey:PWD_ENVNAME] == nil)
        [env setObject:[PWD_ENVVALUE stringByExpandingTildeInPath] forKey:PWD_ENVNAME];

    [SHELL setDelegate:self];
    [SHELL launchWithPath:path
		arguments:argv
	      environment:env
		    width:[SCREEN width]
		   height:[SCREEN height]];

}

- (void) handleQuit: (NSNotification *) aNotification
{
    if([aNotification object] == [self parent])
        [self terminate];
}


- (void) terminate
{
#if DEBUG_ALLOC
    NSLog(@"%s(%d):-[PTYSession -terminate]", __FILE__, __LINE__);
#endif
    [SHELL sendSignal: SIGHUP];
    if(SHELL != nil)
        [SHELL release];
    if(TERMINAL != nil)
        [TERMINAL release];
    if(SCREEN != nil)
        [SCREEN release];

    if (timer) {
        [timer invalidate];
        [timer release];
    }  
    
    SHELL    = nil;
    TERMINAL = nil;
    SCREEN   = nil;
    timer = nil;
}

- (void)readTask:(NSData *)data
{
    VT100TCC token;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal readTask:%@]", __FILE__, __LINE__, data );
#endif
    if (data == nil)
    {
        [[self parent] closeSession: self];
        return;
    }

    if ([parent pending]) return;

    oIdleCount=0;
    if (REFRESHED==NO) {
        REFRESHED=YES;
        [parent _drawSessionButtons];
    }
    
    [TERMINAL putStreamData:data];

    [SCREEN beginEditing];

    while ((token = [TERMINAL getNextToken]), 
	   token.type != VT100TCC_NULL &&
	   token.type != VT100TCC_WAIT)
    {
	if (token.type != VT100TCC_SKIP)
	    [SCREEN putToken:token];
    }
    if (token.type == VT100TCC_NOTSUPPORT) {
	NSLog(@"%s(%d):not support token", __FILE__ , __LINE__);
    }
    [SCREEN endEditing];

    [self moveLastLine];
    [SCREEN showCursor];
}

- (void)brokenPipe
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal brokenPipe]", __FILE__, __LINE__);
#endif
    [SHELL sendSignal:SIGKILL];
    [SHELL stop];
    EXIT = YES;

    if (timer) {
        [timer invalidate];
        [timer release];
        timer=nil;
    }
    if ([WINDOW isVisible]) [parent setWindowTitle];
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
    unicode = [keystr characterAtIndex:0];
    iIdleCount=0;
    
    // Check if we are navigating through sessions
    if ((modflag & NSFunctionKeyMask) && (modflag & NSShiftKeyMask)) 
    {
        // function key's
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
            default:
                break;      
        }
    }
    
    if (modflag & NSFunctionKeyMask) {
	NSData *data = nil;
	int f = -1;

	switch(unicode) {
	case NSUpArrowFunctionKey: data = [TERMINAL keyArrowUp]; break;
	case NSDownArrowFunctionKey: data = [TERMINAL keyArrowDown]; break;
	case NSLeftArrowFunctionKey: data = [TERMINAL keyArrowLeft]; break;
	case NSRightArrowFunctionKey: data = [TERMINAL keyArrowRight]; break;

	case NSF1FunctionKey: f = 1; break;
	case NSF2FunctionKey: f = 2; break;
	case NSF3FunctionKey: f = 3; break;
	case NSF4FunctionKey: f = 4; break;
	case NSF5FunctionKey: f = 5; break;
	case NSF6FunctionKey: f = 6; break;
	case NSF7FunctionKey: f = 7; break;
	case NSF8FunctionKey: f = 8; break;
	case NSF9FunctionKey: f = 9; break;
	case NSF10FunctionKey: f = 10; break;
	case NSF11FunctionKey: f = 11; break;
	case NSF12FunctionKey: f = 12; break;
	    break;

	case NSInsertFunctionKey: data = [TERMINAL keyInsert]; break;
#if DEBUG_SCREENDUMP
	case NSDeleteFunctionKey: 
	    NSLog(@"### DEBUG ###\n%@", SCREEN);
	    break;
#else
	case NSDeleteFunctionKey: data = [TERMINAL keyDelete]; break;
#endif
	case NSHomeFunctionKey: data = [TERMINAL keyHome]; break;
	case NSEndFunctionKey: data = [TERMINAL keyEnd]; break;
	case NSPageUpFunctionKey: data = [TERMINAL keyPageUp]; break;
	case NSPageDownFunctionKey: data = [TERMINAL keyPageDown]; break;

	case NSPrintScreenFunctionKey:
	    break;
	case NSScrollLockFunctionKey:
	case NSPauseFunctionKey:
	    break;
	}

	if (f >= 0)
	    data = [TERMINAL keyFunction:f];

	if (data != nil) {
	    send_str = (char *)[data bytes];
	    send_strlen = [data length];
	}
    }
    else {
	NSData *data = [keystr dataUsingEncoding:NSUTF8StringEncoding];
	
	if (data != nil ) {
	    send_str = (char *)[data bytes];
	    send_strlen = [data length];
	}
    }

    if (EXIT == NO ) {
	if (send_pchr >= 0) {
	    char c = send_pchr;
	    
	    [SHELL writeTask:[NSData dataWithBytes:&c length:1]];
	}
	if (send_chr >= 0) {
	    char c = send_chr;
	    
	    [SHELL writeTask:[NSData dataWithBytes:&c length:1]];
	}
	if (send_str != NULL) {
	    [SHELL writeTask:[NSData dataWithBytes:send_str
					    length:send_strlen]];
	}
    }
}

- (void)insertText:(NSString *)string
{
    NSData *data;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal insertText:%@]",
	  __FILE__, __LINE__, string);
#endif

    data = [string dataUsingEncoding:[TERMINAL encoding]
		allowLossyConversion:YES];
    if (data != nil) 
	[SHELL writeTask:data];
}

- (void)insertNewline:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal insertNewline:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [self insertText:@"\n"];
}

- (void)insertTab:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal insertTab:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [self insertText:@"\t"];
}

- (void)moveUp:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal moveUp:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowUp]];
}

- (void)moveDown:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal moveDown:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowDown]];
}

- (void)moveLeft:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal moveLeft:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowLeft]];
}

- (void)moveRight:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal moveRight:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyArrowRight]];
}

- (void)pageUp:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal pageUp:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyPageUp]];
}

- (void)pageDown:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal pageDown:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[TERMINAL keyPageDown]];
}

- (void)paste:(id)sender
{
    NSPasteboard *board;
    NSString *str;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal paste:...]", __FILE__, __LINE__);
#endif

    board = [NSPasteboard generalPasteboard];
    NSParameterAssert(board != nil );
    str = [board stringForType:NSStringPboardType];
    if (str != nil) {
	NSData *strdata = [[str stringReplaceSubstringFrom:@"\n" to:@"\r"]
				 dataUsingEncoding:[TERMINAL encoding]
			      allowLossyConversion:YES];
	if (strdata != nil)
	    [SHELL writeTask:strdata];
    }
}

- (void)deleteBackward:(id)sender
{
    unsigned char p = 0x08;	// Ctrl+H

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal deleteBackward:%@]",
	  __FILE__, __LINE__, sender);
#endif

    [SHELL writeTask:[NSData dataWithBytes:&p length:1]];
}

- (void)deleteForward:(id)sender
{
    unsigned char p = 0x7F;	// DEL

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal deleteForward:%@]",
	  __FILE__, __LINE__, sender);
#endif
    [SHELL writeTask:[NSData dataWithBytes:&p length:1]];
}


// Misc
- (void)moveLastLine
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PTYSession moveLastLine]", __FILE__, __LINE__);
#endif
    [TEXTVIEW scrollRangeToVisible:NSMakeRange([[SCREEN textStorage] length], 0)];
}

- (void) timerTick:(NSTimer*)sender
{

    iIdleCount++; oIdleCount++;
    if (antiIdle) {
        if (iIdleCount>=240) {
            [SHELL writeTask:[NSData dataWithBytes:&ai_code length:1]];
            iIdleCount=0;
        }
    }
    if (oIdleCount>5&&!waiting) {
        waiting=YES;
        [parent _drawSessionButtons];
    }
    else if (waiting&&oIdleCount<=5) {
        waiting=NO;
        [parent _drawSessionButtons];
    }
    [SCREEN blink];
}


// Preferences
- (void)setPreference:(id)preference;
{
    pref=preference;
}


// get/set methods
- (void) setMainMenu:(MainMenu *) theMainMenu
{
    MAINMENU=theMainMenu;
}

- (void) setWindow: (NSWindow *) theWindow
{
    WINDOW = theWindow;
}

- (PseudoTerminal *) parent
{
    return (parent);
}
- (void) setParent: (PseudoTerminal *) theParent
{
    if(parent)
    {
        [parent release];
        parent = nil;
    }
    if(theParent)
    {
        [theParent retain];
        parent = theParent;
    }
}

- (NSString *) name
{
    return (name);
}
- (void) setName: (NSString *) theName
{
    if(name)
    {
        [name release];
        name = nil;
    }
    if(theName)
    {
        [theName retain];
        name = theName;
    }
    [parent _drawSessionButtons];
}

- (PTYTask *) SHELL
{
    return (SHELL);
}
- (void) setSHELL: (PTYTask *) theSHELL
{
    if(SHELL != nil)
        [SHELL release];
    if(theSHELL != nil)
    {
        [theSHELL retain];
        SHELL = theSHELL;
    }
}

- (VT100Terminal *) TERMINAL
{
    return (TERMINAL);
}
- (void) setTERMINAL: (VT100Terminal *) theTERMINAL
{
    if(TERMINAL != nil)
        [TERMINAL release];
    if(theTERMINAL != nil)
    {
        [theTERMINAL retain];
        TERMINAL = theTERMINAL;
    }
}

- (NSString *) TERM_VALUE
{
    return (TERM_VALUE);
}
- (void) setTERM_VALUE: (NSString *) theTERM_VALUE
{
    if(TERM_VALUE != nil)
        [TERM_VALUE release];
    if(theTERM_VALUE != nil)
    {
        [theTERM_VALUE retain];
        TERM_VALUE = theTERM_VALUE;
    }
}

- (VT100Screen *) SCREEN
{
    return (SCREEN);
}
- (void) setSCREEN: (VT100Screen *) theSCREEN
{
    if(SCREEN != nil)
        [SCREEN release];
    if(theSCREEN != nil)
    {
        [theSCREEN retain];
        SCREEN = theSCREEN;
    }
}

- (PTYTextView *) TEXTVIEW
{
    return (TEXTVIEW);
}
- (void) setTEXTVIEW: (PTYTextView *) theTEXTVIEW
{
    if(TEXTVIEW != nil)
        [TEXTVIEW release];
    if(theTEXTVIEW != nil)
    {
        [theTEXTVIEW retain];
        TEXTVIEW = theTEXTVIEW;
    }
}

- (void)setEncoding:(NSStringEncoding)encoding
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setEncoding:%d]",
          __FILE__, __LINE__, encoding);
#endif
    [TERMINAL setEncoding:encoding];
}

- (void)setEncodingUTF8:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setEncodingUTF8:%@]",
          __FILE__, __LINE__, sender);
#endif
    [self setEncoding:NSUTF8StringEncoding];
    [parent setWindowTitle];
}

- (void)setEncodingEUCCN:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setEncodingEUCCN:%@]",
          __FILE__, __LINE__, sender);
#endif
    [self setEncoding:NSStringEUCCNEncoding];
    [parent setWindowTitle];
}

- (void)setEncodingBIG5:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal setEncodingBIG5:%@]",
          __FILE__, __LINE__, sender);
#endif
    [self setEncoding:NSStringBig5Encoding];
    [parent setWindowTitle];
}

- (void)setFGColor:(NSColor*) color
{
    [TEXTVIEW setTextColor: color];
    [TERMINAL setFGColor: color];
}

- (void)setBGColor:(NSColor*) color
{
    //    [TEXTVIEW setBackgroundColor: color];
    [TERMINAL setBGColor: color];
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
    if (antiIdle) iIdleCount=0;
}

- (void) setAntiCode:(int)code
{
    ai_code=code;
}

- (void)logStart:(id)sender
{
    NSSavePanel *panel;
    int sts;

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal logStart:%@]",
          __FILE__, __LINE__, sender);
#endif

    panel = [NSSavePanel savePanel];
    sts = [panel runModalForDirectory:NSHomeDirectory() file:@""];
    if (sts == NSOKButton) {
        BOOL logsts = [SHELL loggingStartWithPath:[panel filename]];
        if (logsts == NO)
            NSBeep();
    }
}

- (void)logStop:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal logStop:%@]",
          __FILE__, __LINE__, sender);
#endif
    [SHELL loggingStop];
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

- (void)clearBuffer:(id)sender
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[PseudoTerminal clearBuffer:...]", __FILE__, __LINE__);
#endif
    [TERMINAL cleanStream];

    [SCREEN beginEditing];
    [SCREEN clearBuffer];
    [SCREEN endEditing];
    [SCREEN showCursor];
}

- (BOOL)refreshed
{
    return REFRESHED;
}

- (void) resetStatus;
{
    waiting=REFRESHED=NO;
}

- (BOOL)idle
{
    return waiting;
}

@end
