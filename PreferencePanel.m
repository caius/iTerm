// $Id: PreferencePanel.m,v 1.28 2003-03-13 18:50:18 yfabian Exp $
/*
 **  PreferencePanel.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Implements the model and controller for the preference panel.
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

#import "PreferencePanel.h"
#import "NSStringITerm.h"

#define NIB_PATH  @"MainMenu"

static NSColor *BACKGROUND;
static NSColor *FOREGROUND;
static NSColor *SELECTION;

static NSString *DEFAULT_FONTNAME = @"Osaka-Mono";
static float     DEFAULT_FONTSIZE = 14;
static NSFont* FONT;

static int   COL   = 80;
static int   ROW   = 25;

static NSString* TERM    =@"xterm";
static NSString* SHELL   =@"/bin/bash --login";
static NSStringEncoding const *encodingList=nil;

static int TRANSPARENCY  =10;

@implementation PreferencePanel

+ (void)initialize
{
    BACKGROUND = [NSColor blackColor];
    FOREGROUND = [[NSColor colorWithCalibratedRed:0.8f
                                            green:0.8f
                                             blue:0.8f
                                            alpha:1.0f]
        retain];
    SELECTION = [NSColor selectedTextBackgroundColor];
    FONT = [[NSFont fontWithName:DEFAULT_FONTNAME
			    size:DEFAULT_FONTSIZE] retain];
}

- (id)init
{
    char *userShell, *thisUser;
#if DEBUG_OBJALLOC
    NSLog(@"%s(%d):-[PreferencePanel init]", __FILE__, __LINE__);
#endif
    if ((self = [super init]) == nil)
        return nil;
        
    // Get the user's default shell
    if((thisUser = getenv("USER")) != NULL)
        SHELL = [[NSString stringWithFormat: @"login -fp %s", thisUser] retain];
    else if((userShell = getenv("SHELL")) != NULL)
        SHELL = [[NSString stringWithCString: userShell] retain];
        
    [self readPreferences];

                 
    return self;
}

- (void)dealloc
{
    if(defaultTerminal != nil)
        [defaultTerminal release];
    if(defaultShell != nil)
        [defaultShell release];    
    if(defaultForeground != nil)
        [defaultForeground release];                        
    if(defaultBackground != nil)
        [defaultBackground release];                        
    if(defaultSelectionColor != nil)
        [defaultSelectionColor release];                        
    if(defaultFont != nil)
        [defaultFont release];                        
    if(defaultNAFont != nil)
        [defaultNAFont release];            
        
    [super dealloc];
}

- (void) readPreferences
{
    prefs = [NSUserDefaults standardUserDefaults];
    encodingList=[NSString availableStringEncodings];

    defaultCol=([prefs integerForKey:@"Col"]?[prefs integerForKey:@"Col"]:COL);
    defaultRow=([prefs integerForKey:@"Row"]?[prefs integerForKey:@"Row"]:ROW);
    defaultTransparency=([prefs stringForKey:@"Transparency"]!=nil?[prefs integerForKey:@"Transparency"]:TRANSPARENCY);
    defaultAntiAlias=[prefs objectForKey:@"AntiAlias"]?[[prefs objectForKey:@"AntiAlias"] boolValue]: YES;

    if(defaultTerminal != nil)
        [defaultTerminal release];
    defaultTerminal=[([prefs objectForKey:@"Terminal"]?[prefs objectForKey:@"Terminal"]:TERM)
                    copy];

    // This is for compatibility with old pref
    if ([[prefs objectForKey:@"Encoding"] isKindOfClass:[NSString class]]) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Upgrade Warning: New language encodings available",@"iTerm",@"Upgrade"),
                        NSLocalizedStringFromTable(@"Please reset all the encoding settings in your preference and address book",@"iTerm",@"Upgrade"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
        defaultEncoding=CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
    }
    else {
        defaultEncoding=[prefs objectForKey:@"Encoding"]?[[prefs objectForKey:@"Encoding"] unsignedIntValue]:CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
    }

    [defaultShell release];    
    defaultShell=[([prefs objectForKey:@"Shell"]?[prefs objectForKey:@"Shell"]:SHELL) copy];

    [defaultForeground release];                        
    defaultForeground=[([prefs objectForKey:@"Foreground"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Foreground"]]:FOREGROUND) copy];
                      
    [defaultBackground release];                        
    defaultBackground=[([prefs objectForKey:@"Background"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Background"]]:BACKGROUND) copy];
                      
    [defaultSelectionColor release];                        
    defaultSelectionColor=[([prefs objectForKey:@"SelectionColor"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"SelectionColor"]]:SELECTION) copy];
                      
    [defaultFont release];                        
    defaultFont=[([prefs objectForKey:@"Font"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Font"]]:FONT) copy];
                      
    [defaultNAFont release];                        
    defaultNAFont=[([prefs objectForKey:@"NAFont"]?
                   [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"NAFont"]]:FONT) copy];
        
    defaultAutoclose=[prefs objectForKey:@"AutoClose"]?[[prefs objectForKey:@"AutoClose"] boolValue]: YES;
    defaultOption=[prefs objectForKey:@"OptionKey"]?[prefs integerForKey:@"OptionKey"]:0;
    defaultTabViewType=[prefs objectForKey:@"TabViewType"]?[prefs integerForKey:@"TabViewType"]:0;
    defaultCopySelection=[[prefs objectForKey:@"CopySelection"] boolValue];
    defaultHideTab=[prefs objectForKey:@"HideTab"]?[[prefs objectForKey:@"HideTab"] boolValue]: YES;
    defaultSilenceBell=[[prefs objectForKey:@"SilenceBell"] boolValue];
    defaultDoubleWidth=[[prefs objectForKey:@"DoubleWidth"] boolValue];
    defaultRemapDeleteKey = [prefs objectForKey:@"RemapDeleteKey"]?[[prefs objectForKey:@"RemapDeleteKey"] boolValue]: YES;
    defaultOpenAddressBook = [prefs objectForKey:@"OpenAddressBook"]?[[prefs objectForKey:@"OpenAddressBook"] boolValue]: NO;
    changingNA=NO;

}

- (void)run
{
    NSStringEncoding const *p=encodingList;
    int r;
    
    [prefPanel center];
    [shell setStringValue:defaultShell];
    [terminal setStringValue:defaultTerminal];
    [encoding removeAllItems];
    r=0;
    while (*p) {
        //        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [encoding addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==defaultEncoding) r=p-encodingList;
        p++;
    }
    [encoding selectItemAtIndex:r];
    
    [background setColor:defaultBackground];
    [foreground setColor:defaultForeground];
    [selectionColor setColor: defaultSelectionColor];
    
    [row setIntValue:defaultRow];
    [col setIntValue:defaultCol];
    [transparency setIntValue:defaultTransparency];
    [transparency_control setIntValue:defaultTransparency];
    [antiAlias setState:defaultAntiAlias?NSOnState:NSOffState];
    
    [fontExample setTextColor:defaultForeground];
    [fontExample setBackgroundColor:defaultBackground];
    [fontExample setFont:defaultFont];
    [fontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultFont fontName], [defaultFont pointSize]]];

    [nafontExample setTextColor:defaultForeground];
    [nafontExample setBackgroundColor:defaultBackground];
    [nafontExample setFont:defaultNAFont];
    [nafontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultNAFont fontName], [defaultNAFont pointSize]]];
    [autoclose setState:defaultAutoclose?NSOnState:NSOffState];
    [optionKey selectCellAtRow:0 column:defaultOption];
    [tabViewType selectCellWithTag: defaultTabViewType];
    [copySelection setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [silenceBell setState:defaultSilenceBell?NSOnState:NSOffState];
    [doubleWidth setState:defaultDoubleWidth?NSOnState:NSOffState];
    [remapDeleteKey setState:defaultRemapDeleteKey?NSOnState:NSOffState];
    [openAddressBook setState:defaultOpenAddressBook?NSOnState:NSOffState];
   
    [NSApp runModalForWindow:prefPanel];
    [prefPanel close];
}

- (IBAction)cancel:(id)sender
{
    [self readPreferences];
    [NSApp abortModal];
}

- (IBAction)changeBackground:(id)sender
{
    [fontExample setBackgroundColor:[sender color]];
}

- (IBAction)changeFontButton:(id)sender
{
    changingNA=NO;

    [[fontExample window] makeFirstResponder:[fontExample window]];
    [[fontExample window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:defaultFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)changeNAFontButton:(id)sender
{
    changingNA=YES;
    [[nafontExample window] makeFirstResponder:[nafontExample window]];
    [[nafontExample window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:defaultNAFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)changeForeground:(id)sender
{
    [fontExample setTextColor:[sender color]];
}

- (void)changeFont:(id)fontManager
{
    if (changingNA) {
        [defaultNAFont autorelease];
        defaultNAFont=[fontManager convertFont:[nafontExample font]];
        [nafontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultNAFont fontName], [defaultNAFont pointSize]]];
        [nafontExample setFont:defaultNAFont];
    }
    else {
        [defaultFont autorelease];
        defaultFont=[fontManager convertFont:[fontExample font]];
        [fontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultFont fontName], [defaultFont pointSize]]];
        [fontExample setFont:defaultFont];
    }
}

- (IBAction)ok:(id)sender
{
    if ([col intValue]<1||[row intValue]<1) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid window size",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
        return;
    }
    
    [defaultBackground autorelease];
    [defaultForeground autorelease];
    [defaultSelectionColor autorelease];
    
    defaultBackground=[[background color] copy];
    defaultForeground=[[foreground color] copy];
    defaultSelectionColor = [[selectionColor color] copy];

    defaultCol=[col intValue];
    defaultRow=[row intValue];
    
    defaultEncoding=encodingList[[encoding indexOfSelectedItem]];
    defaultShell=[shell stringValue];
    defaultTerminal=[terminal stringValue];
    
    defaultTransparency=[transparency intValue];
    defaultAntiAlias = ([antiAlias state]==NSOnState);

    defaultAutoclose=([autoclose state]==NSOnState);
    defaultOption=[optionKey selectedColumn];
    defaultTabViewType=[[tabViewType selectedCell] tag];
    defaultCopySelection=([copySelection state]==NSOnState);
    defaultHideTab=([hideTab state]==NSOnState);
    defaultSilenceBell=([silenceBell state]==NSOnState);
    defaultDoubleWidth=([doubleWidth state]==NSOnState);
    defaultRemapDeleteKey = ([remapDeleteKey state] == NSOnState);
    defaultOpenAddressBook = ([openAddressBook state] == NSOnState);

    [prefs setInteger:defaultCol forKey:@"Col"];
    [prefs setInteger:defaultRow forKey:@"Row"];
    [prefs setObject:defaultTerminal forKey:@"Terminal"];
    [prefs setObject:[NSNumber numberWithUnsignedInt:defaultEncoding] forKey:@"Encoding"];
    [prefs setObject:defaultShell forKey:@"Shell"];
    [prefs setInteger:defaultTransparency forKey:@"Transparency"];
               
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultForeground]
              forKey:@"Foreground"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultBackground]
              forKey:@"Background"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultSelectionColor]
              forKey:@"SelectionColor"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultFont]
              forKey:@"Font"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultNAFont]
              forKey:@"NAFont"];
    [prefs setBool:defaultAutoclose forKey:@"AutoClose"];
    [prefs setInteger:defaultOption forKey:@"OptionKey"];
    [prefs setBool:defaultAntiAlias forKey:@"AntiAlias"];
    [prefs setBool:defaultCopySelection forKey:@"CopySelection"];
    [prefs setBool:defaultHideTab forKey:@"HideTab"];
    [prefs setBool:defaultSilenceBell forKey:@"SilenceBell"];
    [prefs setBool:defaultDoubleWidth forKey:@"DoubleWidth"];
    [prefs setInteger:defaultTabViewType forKey:@"TabViewType"];
    [prefs setBool:defaultRemapDeleteKey forKey:@"RemapDeleteKey"];
    [prefs setBool:defaultOpenAddressBook forKey:@"OpenAddressBook"];
    
    [NSApp stopModal];
    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];

}

- (IBAction)restore:(id)sender
{
    int r;
    NSStringEncoding const *p=encodingList;
    
    if (defaultBackground) [defaultBackground autorelease];
    if (defaultForeground) [defaultForeground autorelease];
    if (defaultFont) [defaultFont autorelease];
    
    defaultBackground=[BACKGROUND copy];
    defaultForeground=[FOREGROUND copy];
    defaultFont=[FONT copy];

    defaultCol=COL;
    defaultRow=ROW;
    
    defaultEncoding=CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
    defaultShell=[SHELL copy];
    defaultTerminal=[TERM copy];
    
    defaultTransparency=TRANSPARENCY;
    defaultAutoclose=YES;
    defaultOption=0;
    defaultHideTab=YES;
    defaultCopySelection=YES;
    defaultSilenceBell=NO;
    defaultDoubleWidth=YES;
    defaultTabViewType = NSTopTabsBezelBorder;
    defaultRemapDeleteKey = YES;
    defaultOpenAddressBook = NO;
    
    [shell setStringValue:defaultShell];
    [terminal setStringValue:defaultTerminal];
    [encoding removeAllItems];
    r=0;
    while (*p) {
        //NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [encoding addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==defaultEncoding) r=p-encodingList;
        p++;
    }
    [encoding selectItemAtIndex:r];
    
    [background setColor:defaultBackground];
    [foreground setColor:defaultForeground];
    
    [row setIntValue:defaultRow];
    [col setIntValue:defaultCol];
    [transparency setIntValue:defaultTransparency];
    
    [fontExample setTextColor:defaultForeground];
    [fontExample setBackgroundColor:defaultBackground];
    [fontExample setFont:defaultFont];
    [fontExample setStringValue:[NSString stringWithFormat:@"%@ %g", [defaultFont fontName], [defaultFont pointSize]]];

    [autoclose setState:defaultAutoclose?NSOnState:NSOffState];
    [optionKey selectCellAtRow:0 column:defaultOption];
    [copySelection setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [silenceBell setState:defaultSilenceBell?NSOnState:NSOffState];
    [doubleWidth setState:defaultDoubleWidth?NSOnState:NSOffState];
    [remapDeleteKey setState:defaultRemapDeleteKey?NSOnState:NSOffState];
    [openAddressBook setState:defaultOpenAddressBook?NSOnState:NSOffState];
    [tabViewType selectCellWithTag: defaultTabViewType];

    
}

- (NSColor*) background
{
    return defaultBackground;
}

- (NSColor*) foreground
{
    return defaultForeground;
}

- (int) col
{
    return defaultCol;
}

- (int) row
{
    return defaultRow;
}

- (NSStringEncoding) encoding
{
    return defaultEncoding;
}

- (NSString*) shell
{
    return defaultShell;
}

- (NSString*) terminalType
{
    return defaultTerminal;
}

- (int) transparency
{
    return defaultTransparency;
}

- (NSFont*) font
{
    return defaultFont;
}

- (NSFont*) nafont
{
    return defaultNAFont;
}

- (BOOL) antiAlias
{
    return defaultAntiAlias;
}

- (BOOL) ai
{
    return NO;
}

- (int) aiCode
{
    return 0;
}

- (BOOL) autoclose
{
    return defaultAutoclose;
}

- (int) option
{
    return defaultOption;
}

- (BOOL) copySelection
{
    return (defaultCopySelection);
}

- (BOOL) hideTab
{
    return (defaultHideTab);
}

- (BOOL) silenceBell
{
    return (defaultSilenceBell);
}

- (BOOL) doubleWidth
{
    return (defaultDoubleWidth);
}

- (NSColor *) selectionColor
{
    return (defaultSelectionColor);
}

- (NSTabViewType) tabViewType
{
    return (defaultTabViewType);
}

- (BOOL)remapDeleteKey
{
    return (defaultRemapDeleteKey);
}

- (BOOL)openAddressBook
{
    return (defaultOpenAddressBook);
}

@end
