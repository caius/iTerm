//
//  PTYSession.h
//  iTerm
//
//  Created by Ujwal Sathyam on Sun Nov 10 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class PTYTask;
@class PTYTextView;
@class VT100Screen;
@class VT100Terminal;
@class PreferencePanel;
@class PseudoTerminal;
@class MainMenu;

@interface PTYSession : NSResponder {
    
    /// MainMenu reference
    MainMenu *MAINMENU;
    
    /// Terminal Window
    NSWindow *WINDOW;

    PseudoTerminal *parent;  // parent controller
    NSString *name;
    
    // anti-idle
    char ai_code;

    PTYTask *SHELL;
    VT100Terminal *TERMINAL;
    NSString *TERM_VALUE;
    VT100Screen   *SCREEN;
    BOOL EXIT;
    PTYTextView *TEXTVIEW;
    NSTimer *timer;
    int	iIdleCount,oIdleCount;
    BOOL REFRESHED;
    BOOL antiIdle;
    BOOL waiting;
    float alpha;
    NSFont *configFont;
    PreferencePanel *pref;

}

// init/dealloc
- (id) init;
- (void) dealloc;

// Session specific methods
- (void)initScreen: (NSRect) aRect;
- (void)startProgram:(NSString *)program
	   arguments:(NSArray *)prog_argv
	 environment:(NSDictionary *)prog_env;
- (void) handleQuit: (NSNotification *) aNotification;
- (void) terminate;
- (void) timerTick:(NSTimer*)sender;
            
// Preferences
- (void)setPreference:(id)preference;

// PTYTask
- (void)readTask:(NSData *)data;
- (void)brokenPipe;

// PTYTextView
- (void)keyDown:(NSEvent *)event;
- (void)insertText:(NSString *)string;
- (void)insertNewline:(id)sender;
- (void)insertTab:(id)sender;
- (void)moveUp:(id)sender;
- (void)moveDown:(id)sender;
- (void)moveLeft:(id)sender;
- (void)moveRight:(id)sender;
- (void)pageUp:(id)sender;
- (void)pageDown:(id)sender;
- (void)paste:(id)sender;
- (void)deleteBackward:(id)sender;
- (void)deleteForward:(id)sender;


// Misc
- (void)moveLastLine;


// get/set methods
- (void) setMainMenu: (MainMenu *) theMainMenu;
- (void) setWindow: (NSWindow *) theWindow;
- (PseudoTerminal *) parent;
- (void) setParent: (PseudoTerminal *) theParent;
- (NSString *) name;
- (void) setName: (NSString *) theName;
- (PTYTask *) SHELL;
- (void) setSHELL: (PTYTask *) theSHELL;
- (VT100Terminal *) TERMINAL;
- (void) setTERMINAL: (VT100Terminal *) theTERMINAL;
- (NSString *) TERM_VALUE;
- (void) setTERM_VALUE: (NSString *) theTERM_VALUE;
- (VT100Screen *) SCREEN;
- (void) setSCREEN: (VT100Screen *) theSCREEN;
- (PTYTextView *) TEXTVIEW;
- (void) setTEXTVIEW: (PTYTextView *) theTEXTVIEW;
- (void)setEncoding:(NSStringEncoding)encoding;
- (BOOL) antiIdle;
- (int) antiCode;
- (void) setAntiIdle:(BOOL)set;
- (void) setAntiCode:(int)code;

// MainMenu
- (void)clearBuffer:(id)sender;
- (void)setEncodingUTF8:(id)sender;
- (void)setEncodingEUCCN:(id)sender;
- (void)setEncodingBIG5:(id)sender;
- (void)logStart:(id)sender;
- (void)logStop:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
- (void)setFGColor:(NSColor*) color;
- (void)setBGColor:(NSColor*) color;

// Session status

- (BOOL)refreshed;
- (BOOL)idle;
- (void) resetStatus;

@end
