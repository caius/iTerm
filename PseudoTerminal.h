// -*- mode:objc -*-
// $Id: PseudoTerminal.h,v 1.51 2003-05-17 06:40:50 ujwal Exp $
/*
 **  PseudoTerminal.h
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
    IBOutlet id CONFIG_SELECTION;
    IBOutlet id CONFIG_BOLD;
    
    // anti-idle
    IBOutlet id AI_CODE;
    IBOutlet id AI_ON;
    char ai_code;

       
    // Session list
    NSMutableArray *ptyList;
    int currentSessionIndex;
    PTYSession *currentPtySession;
    NSLock *ptyListLock;
    unsigned int windowNumber;
    
    /////////////////////////////////////////////////////////////////////////
    int WIDTH,HEIGHT;
    NSFont *FONT, *NAFONT;
    BOOL pending;
    float alpha;
    NSFont *configFont, *configNAFont;
    BOOL changingNA;
    BOOL newwin;
    PreferencePanel *pref;
    BOOL tabViewDragOperationInProgress;
    BOOL resizeInProgress;
    BOOL windowInited;
}

- (void) newSession: (id) sender;

- (id)init;
- (void)dealloc;
- (void)releaseObjects;

- (void)initWindow:(int)width
            height:(int)height
              font:(NSFont *)font
            nafont:(NSFont *)nafont;
- (void)setupSession: (PTYSession *) aSession title: (NSString *)title;
- (void) insertSession: (PTYSession *) aSession atIndex: (int) index;
- (void) switchSession: (id) sender;
- (void) selectSession: (PTYSession *) aSession;
- (void) selectSessionAtIndex: (int) sessionIndex;
- (void) closeSession: (PTYSession*) aSession;
- (IBAction) closeCurrentSession: (id) sender;
- (IBAction) previousSession:(id)sender;
- (IBAction) nextSession:(id)sender;
- (IBAction) saveSession:(id)sender;
- (PTYSession *) currentSession;
- (int) currentSessionIndex;
- (NSString *) currentSessionName;
- (void) setCurrentSessionName: (NSString *) theSessionName;


- (void)startProgram:(NSString *)program;
- (void)startProgram:(NSString *)program
           arguments:(NSArray *)prog_argv;
- (void)startProgram:(NSString *)program
                  arguments:(NSArray *)prog_argv
                environment:(NSDictionary *)prog_env;
- (void)setWindowSize: (BOOL) resizeContentFrames;
- (void)setWindowTitle;
- (void)setWindowTitle: (NSString *)title;
- (void)setAllFont:(NSFont *)font nafont:(NSFont *)nafont;


// MainMenu
- (void)setMainMenu:(id) sender;
- (void)clearBuffer:(id)sender;
- (void)clearScrollbackBuffer:(id)sender;
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
- (void)tabView:(NSTabView *)tabView willRemoveTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)tabView willAddTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)tabView willInsertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(int) index;
- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView;
- (void)tabViewWillPerformDragOperation:(NSTabView *)tabView;
- (void)tabViewDidPerformDragOperation:(NSTabView *)tabView;
- (void)tabViewContextualMenu: (NSEvent *)theEvent menu: (NSMenu *)theMenu;
- (void) closeTabContextualMenuAction: (id) sender;
- (void) moveTabToNewWindowContextualMenuAction: (id) sender;


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
- (id) preference;


@end

@interface PseudoTerminal (KeyValueCoding)

// accessors for attributes:
-(int)columns;
-(void)setColumns: (int)columns;
-(int)rows;
-(void)setRows: (int)rows;

// accessors for to-many relationships:
-(NSArray*)sessions;
-(void)setSessions: (NSArray*)sessions;

// accessors for to-many relationships:
// (See NSScriptKeyValueCoding.h)
-(id)valueInSessionsAtIndex:(unsigned)index;
-(id)valueWithName: (NSString *)uniqueName inPropertyWithKey: (NSString*)propertyKey;
-(id)valueWithID: (NSString *)uniqueID inPropertyWithKey: (NSString*)propertyKey;
-(void)replaceInSessions:(PTYSession *)object atIndex:(unsigned)index;
-(void)addInSessions:(PTYSession *)object;
-(void)insertInSessions:(PTYSession *)object;
-(void)insertInSessions:(PTYSession *)object atIndex:(unsigned)index;
-(void)removeFromSessionsAtIndex:(unsigned)index;

- (BOOL)windowInited;
- (void) setWindowInited: (BOOL) flag;

// a class method to provide the keys for KVC:
+(NSArray*)kvcKeys;

@end

@interface PseudoTerminal (ScriptingSupport)

// Object specifier
- (NSScriptObjectSpecifier *)objectSpecifier;

-(void)handleLaunchScriptCommand: (NSScriptCommand *)command;

@end

@interface PseudoTerminal (Private)

- (void) _buildToolbarItemPopUpMenu: (NSToolbarItem *) toolbarItem forToolbar: (NSToolbar *)toolbar;
- (void) _reloadAddressBookMenu: (NSNotification *) aNotification;
- (void) _toggleNewWindowState: (id) sender;

@end

