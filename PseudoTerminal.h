// -*- mode:objc -*-
// $Id: PseudoTerminal.h,v 1.1.1.1 2002-11-26 04:56:47 ujwal Exp $
//
//  PseudoTerminal.h
//  JTerminal
//
//  Created by kuma on Thu Nov 22 2001.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PreferencePanel.h"
#import "MainMenu.h"
#import "PTYTask.h"
#import "PTYTextView.h"
#import "VT100Terminal.h"
#import "VT100Screen.h"
#import "PTYSession.h"

@interface PseudoTerminal : NSResponder
{
    /// MainMenu reference
    MainMenu *MAINMENU;
    
    /// Terminal Window
    IBOutlet id SCROLLVIEW;	// PTYScrollView
    IBOutlet id WINDOW;

    // config window
    IBOutlet id CONFIG_PANEL;
    IBOutlet id CONFIG_COL;
    IBOutlet id CONFIG_ROW;
    IBOutlet id CONFIG_ENCODING;
    IBOutlet id CONFIG_BACKGROUND;
    IBOutlet id CONFIG_FOREGROUND;
    IBOutlet id CONFIG_EXAMPLE;
    IBOutlet id CONFIG_TRANSPARENCY;
    IBOutlet id CONFIG_TRANS2;
    IBOutlet id CONFIG_NAME;
    
    // anti-idle
    IBOutlet id AI_PANEL;
    IBOutlet id AI_CODE;
    IBOutlet id AI_ON;
    IBOutlet id WA_ON;
    IBOutlet id OA_ON;
    char ai_code;

    // Contextual Menu
    id cMenu;
    
    // Session list
    NSMutableArray *ptyList;
    NSMutableArray *buttonList;
    int currentSessionIndex;
    PTYSession *currentPtySession;
    NSLock *ptyListLock;
    
    /////////////////////////////////////////////////////////////////////////
    PTYTask *SHELL;
    VT100Terminal *TERMINAL;
    NSString *TERM_VALUE;
    VT100Screen   *SCREEN;
    int WIDTH,HEIGHT;
    NSFont *FONT;
    BOOL EXIT;
    PTYTextView *TEXTVIEW;
    BOOL pending;
    float alpha;
    NSFont *configFont;
    PreferencePanel *pref;
}

+ (PseudoTerminal *)newTerminalWindow: sender;
- (void) newSession: (id) sender;

- (id)init;
- (void)dealloc;
- (void)releaseObjects;

- (void)initWindow:(int)width
            height:(int)height
              font:(NSFont *)font;
- (void)initSession:(NSString *)title
   foregroundColor:(NSColor *) fg
   backgroundColor:(NSColor *) bg
          encoding:(NSStringEncoding)encoding
              term:(NSString *)term;

- (void) switchSession: (id) sender;
- (void) selectSession: (int) sessionIndex;
- (void) closeSession: (PTYSession *)theSession;
- (IBAction) previousSession:(id)sender;
- (IBAction) nextSession:(id)sender;
- (PTYSession *) currentSession;
- (NSString *) currentSessionName;
- (void) setCurrentSessionName: (NSString *) theSessionName;


- (void)startProgram:(NSString *)program;
- (void)startProgram:(NSString *)program
           arguments:(NSArray *)prog_argv;

- (void)setWindowSize;
- (void)setWindowTitle;
- (void)setWindowTitle: (NSString *)title;
- (void)setAllFont:(NSFont *)font;
- (void)setFont:(NSFont *)font;

// MainMenu
- (void)setMainMenu:(id) sender;

// PTYTextView
- (void)keyDown:(NSEvent *)theEvent;
- (void)changeFont:(NSFont *)font;

// NSWindow
- (void)windowDidDeminiaturize:(NSNotification *)aNotification;
- (BOOL)windowShouldClose:(NSNotification *)aNotification;
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignMain:(NSNotification *)aNotification;
- (void)windowDidResize:(NSNotification *)aNotification;
- (NSWindow *) window;

// Toolbar
- (NSToolbar*) setupToolbar;
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar;
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar;
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar: (BOOL) willBeInserted;

// Close Window
- (BOOL)showCloseWindow;


// Config Window
- (IBAction)windowConfigOk:(id)sender;
- (IBAction)windowConfigCancel:(id)sender;
- (IBAction)windowConfigFont:(id)sender;
- (IBAction)windowConfigForeground:(id)sender;
- (IBAction)windowConfigBackground:(id)sender;
- (void) resizeWindow:(int) w height:(int)h;
- (BOOL) pending;

// Preferences
- (void)setPreference:(id)pref;

- (void) _drawSessionButtons;

@end
