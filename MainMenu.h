// -*- mode:objc -*-
// $Id: MainMenu.h,v 1.1.1.1 2002-11-26 04:56:45 ujwal Exp $
//
//  MainMenu.h
//  JTerminal
//
//  Created by kuma on Sun Apr 21 2002.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PseudoTerminal;

@interface MainMenu : NSObject
{
    /// quick open window
    IBOutlet id QO_PANEL;
    IBOutlet id QO_COMMAND;
    IBOutlet id QO_TYPE;
    IBOutlet id QO_DIR;
    IBOutlet id QO_NewWindow;
    IBOutlet id QO_NewTab;
    
    // address book window
    IBOutlet id AB_PANEL;
    IBOutlet NSTableView *adTable;

    // address entry window
    IBOutlet id AE_PANEL;
    IBOutlet NSColorWell *adBackground;
    IBOutlet NSTextField *adCommand;
    IBOutlet NSComboBox *adEncoding;
    IBOutlet NSColorWell *adForeground;
    IBOutlet NSTextField *adName;
    IBOutlet NSTextField *adTextExample;
    IBOutlet id adRow;
    IBOutlet id adCol;
    IBOutlet id adTransparency;
    IBOutlet id adTransparency2;
    IBOutlet id adTermType;
    IBOutlet id adDir;
    IBOutlet id adNewWindow;
    
    NSFont* aeFont;

    // preference window
    IBOutlet id PREF_PANEL;

    // about window
    IBOutlet id ABOUT;
    // address book data
    NSMutableArray *addressBook;

    // PseudoTerminal objects
    NSMutableArray *terminalWindows;
    id FRONT;
    
}

// NSApplication Delegate methods
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification;
- (BOOL) applicationShouldTerminate: (NSNotification *) theNotification;
- (BOOL)applicationOpenUntitledFile:(NSApplication *)app;

- (IBAction)newWindow:(id)sender;
- (IBAction)newSession:(id)sender;

// Quick Open Window
- (IBAction)showQOWindow:(id)sender;
- (IBAction)windowQOOk:(id)sender;
- (IBAction)windowQOCancel:(id)sender;
- (IBAction)windowQOType:(id)sender;

// Address book window
- (IBAction)showABWindow:(id)sender;
- (IBAction)adbAddEntry:(id)sender;
- (IBAction)adbCancel:(id)sender;
- (IBAction)adbEditEntry:(id)sender;
- (IBAction)adbGotoQuickOpen:(id)sender;
- (IBAction)adbOk:(id)sender;

// Address entry window
- (IBAction)adbRemoveEntry:(id)sender;
- (IBAction)adEditBackground:(id)sender;
- (IBAction)adEditCancel:(id)sender;
- (IBAction)adEditFont:(id)sender;
- (IBAction)adEditForeground:(id)sender;
- (IBAction)adEditOK:(id)sender;
- (void)changeFont:(id)fontManager;
- (NSPanel *)aePanel;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
// About window
- (IBAction)showAbout:(id)sender;
- (IBAction)aboutOK:(id)sender;

// Utility methods
+ (void) breakDown:(NSString *)cmdl cmdPath: (NSString **) cmd cmdArgs: (NSArray **) path;
- (void) initAddressBook;
- (void) saveAddressBook;
- (void) setFrontPseudoTerminal: (PseudoTerminal *) thePseudoTerminal;
- (PseudoTerminal *) frontPseudoTerminal;
- (void) addTerminalWindow: (PseudoTerminal *) theTerminalWindow;
- (void) removeTerminalWindow: (PseudoTerminal *) theTerminalWindow;

// Preference Panel
- (IBAction)showPrefWindow:(id)sender;

@end
