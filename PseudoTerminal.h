// -*- mode:objc -*-
// $Id: PseudoTerminal.h,v 1.23 2003-01-06 01:19:08 ujwal Exp $
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

@interface PseudoTerminal : NSWindowController
{
    /// MainMenu reference
    MainMenu *MAINMENU;
    
    /// Terminal Window
    IBOutlet id TABVIEW;
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
    IBOutlet id CONFIG_NAEXAMPLE;
    IBOutlet id CONFIG_TRANSPARENCY;
    IBOutlet id CONFIG_TRANS2;
    IBOutlet id CONFIG_NAME;
    IBOutlet id CONFIG_ANTIALIAS;
    
    // anti-idle
    IBOutlet id AI_PANEL;
    IBOutlet id AI_CODE;
    IBOutlet id AI_ON;
    IBOutlet id WA_ON;
    IBOutlet id OA_ON;
    char ai_code;

       
    // Session list
    NSMutableArray *ptyList;
    int currentSessionIndex;
    PTYSession *currentPtySession;
    NSLock *ptyListLock;
    
    /////////////////////////////////////////////////////////////////////////
    PTYTask *SHELL;
    VT100Terminal *TERMINAL;
    NSString *TERM_VALUE;
    VT100Screen   *SCREEN;
    int WIDTH,HEIGHT;
    NSFont *FONT, *NAFONT;
    PTYTextView *TEXTVIEW;
    BOOL pending;
    float alpha;
    NSFont *configFont, *configNAFont;
    BOOL changingNA;
    BOOL newwin;
    id newwinItem;
    PreferencePanel *pref;
}

+ (PseudoTerminal *)newTerminalWindow: sender;
- (void) newSession: (id) sender;

- (id)init;
- (void)dealloc;
- (void)releaseObjects;

- (void)initWindow:(int)width
            height:(int)height
              font:(NSFont *)font
            nafont:(NSFont *)nafont;
- (void)initSession:(NSString *)title
   foregroundColor:(NSColor *) fg
   backgroundColor:(NSColor *) bg
          encoding:(NSStringEncoding)encoding
              term:(NSString *)term;

- (void) switchSession: (id) sender;
- (void) selectSession: (int) sessionIndex;
- (void) closeSession: (PTYSession*) aSession;
- (IBAction) closeCurrentSession: (id) sender;
- (IBAction) previousSession:(id)sender;
- (IBAction) nextSession:(id)sender;
- (PTYSession *) currentSession;
- (NSString *) currentSessionName;
- (void) setCurrentSessionName: (NSString *) theSessionName;


- (void)startProgram:(NSString *)program;
- (void)startProgram:(NSString *)program
           arguments:(NSArray *)prog_argv;
- (void)startProgram:(NSString *)program
                  arguments:(NSArray *)prog_argv
                environment:(NSDictionary *)prog_env;
- (void)setWindowSize;
- (void)setWindowTitle;
- (void)setWindowTitle: (NSString *)title;
- (void)setAllFont:(NSFont *)font nafont:(NSFont *)nafont;
- (void)setFont:(NSFont *)font nafont:(NSFont *)nafont;


// MainMenu
- (void)setMainMenu:(id) sender;
- (void)clearBuffer:(id)sender;
- (IBAction)logStart:(id)sender;
- (IBAction)logStop:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;

// PTYTextView
- (void)changeFont:(NSFont *)font;

// NSWindow
- (void)windowDidDeminiaturize:(NSNotification *)aNotification;
- (BOOL)windowShouldClose:(NSNotification *)aNotification;
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignMain:(NSNotification *)aNotification;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;
- (void)windowDidResize:(NSNotification *)aNotification;
- (NSWindow *) window;

// Toolbar
- (NSToolbar*) setupToolbar;
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar;
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar;
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar: (BOOL) willBeInserted;

// Contextual menu
- (void) menuForEvent:(NSEvent *)theEvent menu: (NSMenu *) theMenu;

// Close Window
- (BOOL)showCloseWindow;

// NSTabView
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;


// Config Window
- (IBAction)windowConfigOk:(id)sender;
- (IBAction)windowConfigCancel:(id)sender;
- (IBAction)windowConfigFont:(id)sender;
- (IBAction)windowConfigNAFont:(id)sender;
- (IBAction)windowConfigForeground:(id)sender;
- (IBAction)windowConfigBackground:(id)sender;
- (void) resizeWindow:(int) w height:(int)h;
- (BOOL) pending;

// Preferences
- (void)setPreference:(id)pref;


@end

@interface PseudoTerminal (Private)

- (void) _addressbookPopupSelectionDidChange: (id) sender;
- (void) _buildAddressBookMenu: (NSPopUpButton *) aPopUpButton;
- (void) _reloadAddressBookMenu: (NSNotification *) aNotification;
- (void) _executeABMenuCommandInNewTab: (id) sender;
- (void) _executeABMenuCommandInNewWindow: (id) sender;
- (void) _executeABMenuCommand: (int) commandIndex newWindow: (BOOL) theFlag;
- (void) _sessionPopupSelectionDidChange: (id) sender;


@end

