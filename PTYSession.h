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
@class PTYScrollView;
@class VT100Screen;
@class VT100Terminal;
@class PreferencePanel;
@class PseudoTerminal;
@class MainMenu;
@class PTYTabViewItem;

@interface PTYSession : NSResponder {
    
    /// MainMenu reference
    MainMenu *MAINMENU;
    
    /// Terminal Window
    NSWindow *WINDOW;

    // Owning tab view item
    PTYTabViewItem *tabViewItem;
    
    // tab label attributes
    NSDictionary *normalStateAttribute;
    NSDictionary *chosenStateAttribute;
    NSDictionary *idleStateAttribute;
    NSDictionary *newOutputStateAttribute;
    NSDictionary *deadStateAttribute;

    
    PseudoTerminal *parent;  // parent controller
    NSString *name;
    
    // anti-idle
    char ai_code;

    PTYTask *SHELL;
    VT100Terminal *TERMINAL;
    NSString *TERM_VALUE;
    VT100Screen   *SCREEN;
    BOOL EXIT;
    PTYScrollView *SCROLLVIEW;
    PTYTextView *TEXTVIEW;
    NSTimer *timer;
    int	iIdleCount,oIdleCount;
    BOOL REFRESHED;
    BOOL antiIdle;
    BOOL waiting;
    BOOL autoClose;
    BOOL doubleWidth;
    NSFont *configFont;
    PreferencePanel *pref;
    NSDictionary *addressBookEntry;
}

// init/dealloc
- (id) init;
- (void) dealloc;

// Session specific methods
- (void)initScreen: (NSRect) aRect;
- (void)startProgram:(NSString *)program
	   arguments:(NSArray *)prog_argv
	 environment:(NSDictionary *)prog_env;
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
- (void) pasteString: (NSString *) aString;
- (void)deleteBackward:(id)sender;
- (void)deleteForward:(id)sender;
- (void) textViewDidChangeSelection: (NSNotification *) aNotification;


// Misc
- (void)moveLastLine;

// Contextual menu
- (void) menuForEvent:(NSEvent *)theEvent menu: (NSMenu *) theMenu;


// get/set methods
- (void) setMainMenu: (MainMenu *) theMainMenu;
- (void) setWindow: (NSWindow *) theWindow;
- (PseudoTerminal *) parent;
- (void) setParent: (PseudoTerminal *) theParent;
- (PTYTabViewItem *) tabViewItem;
- (void) setTabViewItem: (PTYTabViewItem *) theTabViewItem;
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
- (PTYScrollView *) SCROLLVIEW;
- (void) setSCROLLVIEW: (PTYScrollView *) theSCROLLVIEW;
- (void)setEncoding:(NSStringEncoding)encoding;
- (BOOL) antiIdle;
- (int) antiCode;
- (void) setAntiIdle:(BOOL)set;
- (void) setAntiCode:(int)code;
- (BOOL) autoClose;
- (void) setAutoClose:(BOOL)set;
- (BOOL) doubleWidth;
- (void) setDoubleWidth:(BOOL)set;
- (NSDictionary *) addressBookEntry;
- (void) setAddressBookEntry:(NSDictionary*) entry;

- (void)clearBuffer;
- (void)logStart;
- (void)logStop;
- (void)setFGColor:(NSColor*) color;
- (void)setBGColor:(NSColor*) color;
- (void)setBackgroundAlpha:(float)bgAlpha;

// Session status

- (void)resetStatus;
- (BOOL)exited;
- (void)setLabelAttribute;

@end
