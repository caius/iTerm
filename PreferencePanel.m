// $Id: PreferencePanel.m,v 1.42 2003-04-30 00:26:43 ujwal Exp $
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

static NSColor *iTermBackground;
static NSColor *iTermForeground;
static NSColor *iTermSelection;
static NSColor *iTermBold;
static NSColor* iTermColorTable[2][8];
static NSColor *xtermBackground;
static NSColor *xtermForeground;
static NSColor *xtermSelection;
static NSColor *xtermBold;
static NSColor* xtermColorTable[2][8];

static NSString *DEFAULT_FONTNAME = @"Osaka-Mono";
static float     DEFAULT_FONTSIZE = 14;
static NSFont* FONT;

static int   COL   = 80;
static int   ROW   = 25;
static unsigned int  SCROLLBACK = 100000;

static NSString* TERM    =@"xterm";
static NSString* SHELL   =@"/bin/bash --login";
static NSStringEncoding const *encodingList=nil;

static int TRANSPARENCY  =10;

@implementation PreferencePanel

+ (void)initialize
{
    int i;
    
    iTermBackground = [[NSColor blackColor] retain];
    iTermForeground = [[NSColor colorWithCalibratedRed:0.8f
                                            green:0.8f
                                             blue:0.8f
                                            alpha:1.0f]
        retain];
    iTermSelection = [[NSColor colorWithCalibratedRed:0.45f
                                               green:0.5f
                                                blue:0.55f
                                               alpha:1.0f]
        retain];

    iTermBold = [[NSColor redColor] retain];

    xtermBackground = [[NSColor whiteColor] retain];
    xtermForeground = [[NSColor blackColor] retain];
    xtermSelection = [NSColor selectedTextBackgroundColor];
    xtermBold = [[NSColor redColor] retain];
    
    xtermColorTable[0][0]  = [[NSColor blackColor] retain];
    xtermColorTable[0][1]  = [[NSColor redColor] retain];
    xtermColorTable[0][2]  = [[NSColor greenColor] retain];
    xtermColorTable[0][3] = [[NSColor yellowColor] retain];
    xtermColorTable[0][4] = [[NSColor blueColor] retain];
    xtermColorTable[0][5] = [[NSColor magentaColor] retain];
    xtermColorTable[0][6]  = [[NSColor cyanColor] retain];
    xtermColorTable[0][7]  = [[NSColor whiteColor] retain];
    iTermColorTable[0][0]  = [[NSColor colorWithCalibratedRed:0.0f
                                                                 green:0.0f
                                                                  blue:0.0f
                                                                 alpha:1.0f]
        retain];
    iTermColorTable[0][1]  = [[NSColor colorWithCalibratedRed:0.7f
                                                        green:0.0f
                                                         blue:0.0f
                                                        alpha:1.0f]
        retain];
    iTermColorTable[0][2]  = [[NSColor colorWithCalibratedRed:0.0f
                                                        green:0.7f
                                                         blue:0.0f
                                                        alpha:1.0f]
        retain];
    iTermColorTable[0][3] = [[NSColor colorWithCalibratedRed:0.7f
                                                       green:0.7f
                                                        blue:0.0f
                                                       alpha:1.0f]
        retain];
    iTermColorTable[0][4] = [[NSColor colorWithCalibratedRed:0.0f
                                                       green:0.0f
                                                        blue:0.7f
                                                       alpha:1.0f]
        retain];
    iTermColorTable[0][5] = [[NSColor colorWithCalibratedRed:0.7f
                                                       green:0.0f
                                                        blue:0.7f
                                                       alpha:1.0f]
        retain];
    iTermColorTable[0][6]  = [[NSColor colorWithCalibratedRed:0.45f
                                                        green:0.45f
                                                         blue:0.7f
                                                        alpha:1.0f]
        retain];
    iTermColorTable[0][7]  = [[NSColor colorWithCalibratedRed:0.7f
                                                        green:0.7f
                                                         blue:0.7f
                                                        alpha:1.0f]
        retain];
    
    for (i=0;i<8;i++) {
        xtermColorTable[1][i]=[[PreferencePanel highlightColor:xtermColorTable[0][i]] retain];
        iTermColorTable[1][i]=[[PreferencePanel highlightColor:iTermColorTable[0][i]] retain];
    }
    
    FONT = [[NSFont fontWithName:DEFAULT_FONTNAME
			    size:DEFAULT_FONTSIZE] retain];
}

+ (NSColor *) highlightColor:(NSColor *)color
{

    color=[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    if ([color brightnessComponent]>0.5) {
        if ([color brightnessComponent]>0.81) {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]-0.3
                                            alpha:[color alphaComponent]];
            //                color=[color shadowWithLevel:0.2];
        }
        else {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]+0.3
                                            alpha:[color alphaComponent]];
        }
        //            color=[color highlightWithLevel:0.2];
    }
    else {
        if ([color brightnessComponent]>0.19) {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]-0.3
                                            alpha:[color alphaComponent]];
            //                color=[color shadowWithLevel:0.2];
        }
        else {
            color=[NSColor colorWithCalibratedHue:[color hueComponent]
                                       saturation:[color saturationComponent]
                                       brightness:[color brightnessComponent]+0.3
                                            alpha:[color alphaComponent]];
            //                color=[color highlightWithLevel:0.2];
        }
    }

    return color;
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
    int i;
    
    [defaultTerminal release];
    [defaultShell release];
    [defaultForeground release];
    [defaultBackground release];
    [defaultSelectionColor release];
    [defaultFont release];
    [defaultNAFont release];
    for(i=0;i<8;i++) {
        [defaultColorTable[0][i] release];
        [defaultColorTable[1][i] release];
    }
    [super dealloc];
}

- (void) readPreferences
{
    int i;
    
    prefs = [NSUserDefaults standardUserDefaults];
    encodingList=[NSString availableStringEncodings];

    defaultCol=([prefs integerForKey:@"Col"]?[prefs integerForKey:@"Col"]:COL);
    defaultRow=([prefs integerForKey:@"Row"]?[prefs integerForKey:@"Row"]:ROW);
    defaultScrollback=([prefs objectForKey:@"Scrollback"]?[prefs integerForKey:@"Scrollback"]:SCROLLBACK);
    defaultTransparency=([prefs stringForKey:@"Transparency"]!=nil?[prefs integerForKey:@"Transparency"]:TRANSPARENCY);
    defaultAntiAlias=[prefs objectForKey:@"AntiAlias"]?[[prefs objectForKey:@"AntiAlias"] boolValue]: YES;

    if(defaultTerminal != nil)
        [defaultTerminal release];
    defaultTerminal=[([prefs objectForKey:@"Terminal"]?[prefs objectForKey:@"Terminal"]:TERM)
                    copy];

    // This is for compatibility with old pref
    if ([[prefs objectForKey:@"Encoding"] isKindOfClass:[NSString class]]) {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Upgrade Warning: New language encodings available",@"iTerm", [NSBundle bundleForClass: [self class]], @"Upgrade"),
                        NSLocalizedStringFromTableInBundle(@"Please reset all the encoding settings in your preference and address book",@"iTerm", [NSBundle bundleForClass: [self class]], @"Upgrade"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
        defaultEncoding=CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
    }
    else {
        defaultEncoding=[prefs objectForKey:@"Encoding"]?[[prefs objectForKey:@"Encoding"] unsignedIntValue]:CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
    }

    [defaultShell release];    
    defaultShell=[([prefs objectForKey:@"Shell"]?[prefs objectForKey:@"Shell"]:SHELL) copy];

    defaultColorScheme = [prefs integerForKey: @"ColorScheme"];
    
    [defaultForeground release];                        
    defaultForeground=[([prefs objectForKey:@"Foreground"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Foreground"]]:iTermForeground) copy];
                      
    [defaultBackground release];                        
    defaultBackground=[([prefs objectForKey:@"Background"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Background"]]:iTermBackground) copy];
                      
    [defaultSelectionColor release];                        
    defaultSelectionColor=[([prefs objectForKey:@"SelectionColor"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"SelectionColor"]]:iTermSelection) copy];

    [defaultBoldColor release];
    defaultBoldColor=[([prefs objectForKey:@"BoldColor"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"BoldColor"]]:iTermBold) copy];    
                      
    [defaultFont release];                        
    defaultFont=[([prefs objectForKey:@"Font"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Font"]]:FONT) copy];
    if(defaultFont == nil)
	defaultFont = [[NSFont userFixedPitchFontOfSize: 12] copy];
                      
    [defaultNAFont release];                        
    defaultNAFont=[([prefs objectForKey:@"NAFont"]?
                   [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"NAFont"]]:FONT) copy];
    if(defaultNAFont == nil)
	defaultNAFont = [[NSFont userFixedPitchFontOfSize: 12] copy];
        
    defaultAutoclose=[prefs objectForKey:@"AutoClose"]?[[prefs objectForKey:@"AutoClose"] boolValue]: YES;
    defaultOption=[prefs objectForKey:@"OptionKey"]?[prefs integerForKey:@"OptionKey"]:0;
    defaultTabViewType=[prefs objectForKey:@"TabViewType"]?[prefs integerForKey:@"TabViewType"]:0;
    defaultCopySelection=[[prefs objectForKey:@"CopySelection"] boolValue];
    defaultHideTab=[prefs objectForKey:@"HideTab"]?[[prefs objectForKey:@"HideTab"] boolValue]: YES;
    defaultSilenceBell=[[prefs objectForKey:@"SilenceBell"] boolValue];
    defaultDoubleWidth=[[prefs objectForKey:@"DoubleWidth"] boolValue];
    defaultRemapDeleteKey = [prefs objectForKey:@"RemapDeleteKey"]?[[prefs objectForKey:@"RemapDeleteKey"] boolValue]: YES;
    defaultOpenAddressBook = [prefs objectForKey:@"OpenAddressBook"]?[[prefs objectForKey:@"OpenAddressBook"] boolValue]: NO;
    defaultPromptOnClose = [prefs objectForKey:@"PromptOnClose"]?[[prefs objectForKey:@"PromptOnClose"] boolValue]: YES;
    changingNA=NO;
    if ([prefs objectForKey:@"AnsiBlack"]) {
        defaultColorTable[0][0]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiBlack"]] copy];
        defaultColorTable[0][1]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiRed"]] copy];
        defaultColorTable[0][2]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiGreen"]] copy];
        defaultColorTable[0][3]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiYellow"]] copy];
        defaultColorTable[0][4]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiBlue"]] copy];
        defaultColorTable[0][5]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiMagenta"]] copy];
        defaultColorTable[0][6]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiCyan"]] copy];
        defaultColorTable[0][7]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiWhite"]] copy];
        defaultColorTable[1][0]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiBlack"]] copy];
        defaultColorTable[1][1]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiRed"]] copy];
        defaultColorTable[1][2]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiGreen"]] copy];
        defaultColorTable[1][3]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiYellow"]] copy];
        defaultColorTable[1][4]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiBlue"]] copy];
        defaultColorTable[1][5]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiMagenta"]] copy];
        defaultColorTable[1][6]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiCyan"]] copy];
        defaultColorTable[1][7]=[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"AnsiHiWhite"]] copy];
    }
    else {
        for(i=0;i<8;i++) {
            defaultColorTable[0][i]=[iTermColorTable[0][i] copy];
            defaultColorTable[1][i]=[iTermColorTable[1][i] copy];
        }
    }
}

- (void)run
{
    NSStringEncoding const *p=encodingList;
    int r;
    
    // Load our bundle
    if ([NSBundle loadNibNamed:@"PreferencePanel" owner:self] == NO)
	return;
    
    [prefPanel center];
    if(defaultShell != nil)
	[shell setStringValue:defaultShell];
    if(defaultTerminal != nil)
	[terminal setStringValue:defaultTerminal];
    [encoding removeAllItems];
    [tabSelector removeAllItems];
    [tabSelector addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Display",@"iTerm", [NSBundle bundleForClass: [self class]], @"PreferencePanel")];
    [tabSelector addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Shell",@"iTerm", [NSBundle bundleForClass: [self class]], @"PreferencePanel")];
    [tabSelector addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Emulation",@"iTerm", [NSBundle bundleForClass: [self class]], @"PreferencePanel")];
    [tabSelector addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Color",@"iTerm", [NSBundle bundleForClass: [self class]], @"PreferencePanel")];
    [tabSelector selectItemAtIndex:0];
    [prefTab selectTabViewItemAtIndex:0];
    
    r=0;
    while (*p) {
        //        NSLog(@"%@",[NSString localizedNameOfStringEncoding:*p]);
        [encoding addItemWithObjectValue:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==defaultEncoding) r=p-encodingList;
        p++;
    }
    [encoding selectItemAtIndex:r];

    [colorScheme selectItemAtIndex: defaultColorScheme];
    
    [background setColor:defaultBackground];
    [foreground setColor:defaultForeground];
    [selectionColor setColor: defaultSelectionColor];
    [boldColor setColor: defaultBoldColor];
    [ansiBlack setColor:defaultColorTable[0][0]];
    [ansiRed setColor:defaultColorTable[0][1]];
    [ansiGreen setColor:defaultColorTable[0][2]];
    [ansiYellow setColor:defaultColorTable[0][3]];
    [ansiBlue setColor:defaultColorTable[0][4]];
    [ansiMagenta setColor:defaultColorTable[0][5]];
    [ansiCyan setColor:defaultColorTable[0][6]];
    [ansiWhite setColor:defaultColorTable[0][7]];
    [ansiHiBlack setColor:defaultColorTable[1][0]];
    [ansiHiRed setColor:defaultColorTable[1][1]];
    [ansiHiGreen setColor:defaultColorTable[1][2]];
    [ansiHiYellow setColor:defaultColorTable[1][3]];
    [ansiHiBlue setColor:defaultColorTable[1][4]];
    [ansiHiMagenta setColor:defaultColorTable[1][5]];
    [ansiHiCyan setColor:defaultColorTable[1][6]];
    [ansiHiWhite setColor:defaultColorTable[1][7]];
    
    [row setIntValue:defaultRow];
    [col setIntValue:defaultCol];
    [scrollbackLines setIntValue:defaultScrollback];
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
    [promptOnClose setState:defaultPromptOnClose?NSOnState:NSOffState];
   
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
    [nafontExample setBackgroundColor:[sender color]];
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
    [nafontExample setTextColor:[sender color]];
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
    int i;
    
    if ([col intValue]<1||[row intValue]<1) {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Wrong Input",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"Please enter a valid window size",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
        return;
    }
    
    [defaultBackground autorelease];
    [defaultForeground autorelease];
    [defaultSelectionColor autorelease];
    [defaultBoldColor autorelease];
    [defaultShell autorelease];
    [defaultTerminal autorelease];
    for(i=0;i<8;i++) {
        [defaultColorTable[0][i] autorelease];
        [defaultColorTable[1][i] autorelease];
    }

    defaultColorScheme = [colorScheme indexOfSelectedItem];
    defaultBackground=[[background color] copy];
    defaultForeground=[[foreground color] copy];
    defaultSelectionColor = [[selectionColor color] copy];
    defaultBoldColor = [[boldColor color] copy];
    defaultColorTable[0][0] = [[ansiBlack color] copy];
    defaultColorTable[0][1] = [[ansiRed color] copy];
    defaultColorTable[0][2] = [[ansiGreen color] copy];
    defaultColorTable[0][3] = [[ansiYellow color] copy];
    defaultColorTable[0][4] = [[ansiBlue color] copy];
    defaultColorTable[0][5] = [[ansiMagenta color] copy];
    defaultColorTable[0][6] = [[ansiCyan color] copy];
    defaultColorTable[0][7] = [[ansiWhite color] copy];
    defaultColorTable[1][0] = [[ansiHiBlack color] copy];
    defaultColorTable[1][1] = [[ansiHiRed color] copy];
    defaultColorTable[1][2] = [[ansiHiGreen color] copy];
    defaultColorTable[1][3] = [[ansiHiYellow color] copy];
    defaultColorTable[1][4] = [[ansiHiBlue color] copy];
    defaultColorTable[1][5] = [[ansiHiMagenta color] copy];
    defaultColorTable[1][6] = [[ansiHiCyan color] copy];
    defaultColorTable[1][7] = [[ansiHiWhite color] copy];
    
    defaultCol=[col intValue];
    defaultRow=[row intValue];
    defaultScrollback=[scrollbackLines intValue];
    
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
    defaultPromptOnClose = ([promptOnClose state] == NSOnState);

    [prefs setInteger:defaultCol forKey:@"Col"];
    [prefs setInteger:defaultRow forKey:@"Row"];
    [prefs setInteger:defaultScrollback forKey:@"Scrollback"];
    [prefs setObject:defaultTerminal forKey:@"Terminal"];
    [prefs setObject:[NSNumber numberWithUnsignedInt:defaultEncoding] forKey:@"Encoding"];
    [prefs setObject:defaultShell forKey:@"Shell"];
    [prefs setInteger:defaultTransparency forKey:@"Transparency"];

    [prefs setInteger:defaultColorScheme forKey:@"ColorScheme"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultForeground]
              forKey:@"Foreground"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultBackground]
              forKey:@"Background"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultSelectionColor]
              forKey:@"SelectionColor"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultBoldColor]
              forKey:@"BoldColor"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][0]]
              forKey:@"AnsiBlack"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][1]]
              forKey:@"AnsiRed"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][2]]
              forKey:@"AnsiGreen"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][3]]
              forKey:@"AnsiYellow"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][4]]
              forKey:@"AnsiBlue"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][5]]
              forKey:@"AnsiMagenta"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][6]]
              forKey:@"AnsiCyan"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[0][7]]
              forKey:@"AnsiWhite"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][0]]
              forKey:@"AnsiHiBlack"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][1]]
              forKey:@"AnsiHiRed"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][2]]
              forKey:@"AnsiHiGreen"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][3]]
              forKey:@"AnsiHiYellow"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][4]]
              forKey:@"AnsiHiBlue"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][5]]
              forKey:@"AnsiHiMagenta"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][6]]
              forKey:@"AnsiHiCyan"];
    [prefs setObject:[NSArchiver archivedDataWithRootObject:defaultColorTable[1][7]]
              forKey:@"AnsiHiWhite"];
    

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
    [prefs setBool:defaultPromptOnClose forKey:@"PromptOnClose"];
    
    [NSApp stopModal];
    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];

}

- (IBAction)restore:(id)sender
{
    int r,i;
    NSStringEncoding const *p=encodingList;
    
    [defaultBackground autorelease];
    [defaultForeground autorelease];
    [defaultSelectionColor autorelease];
    [defaultBoldColor autorelease];
    [defaultFont autorelease];
    for(i=0;i<8;i++) {
        [defaultColorTable[0][i] autorelease];
        [defaultColorTable[1][i] autorelease];
    }

    defaultColorScheme = 0; // Custom
    defaultBackground=[iTermBackground copy];
    defaultForeground=[iTermForeground copy];
    defaultSelectionColor=[iTermSelection copy];
    defaultBoldColor=[iTermBold copy];
    defaultFont=[FONT copy];
    for(i=0;i<8;i++) {
        defaultColorTable[0][i]=[iTermColorTable[0][i] copy];
        defaultColorTable[1][i]=[iTermColorTable[1][i] copy];
    }
    
    defaultCol=COL;
    defaultRow=ROW;
    defaultScrollback=SCROLLBACK;
    
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


    [colorScheme selectItemAtIndex: defaultColorScheme];
    [background setColor:defaultBackground];
    [foreground setColor:defaultForeground];
    [selectionColor setColor: defaultSelectionColor];
    [ansiBlack setColor:defaultColorTable[0][0]];
    [ansiRed setColor:defaultColorTable[0][1]];
    [ansiGreen setColor:defaultColorTable[0][2]];
    [ansiYellow setColor:defaultColorTable[0][3]];
    [ansiBlue setColor:defaultColorTable[0][4]];
    [ansiMagenta setColor:defaultColorTable[0][5]];
    [ansiCyan setColor:defaultColorTable[0][6]];
    [ansiWhite setColor:defaultColorTable[0][7]];
    [ansiHiBlack setColor:defaultColorTable[1][0]];
    [ansiHiRed setColor:defaultColorTable[1][1]];
    [ansiHiGreen setColor:defaultColorTable[1][2]];
    [ansiHiYellow setColor:defaultColorTable[1][3]];
    [ansiHiBlue setColor:defaultColorTable[1][4]];
    [ansiHiMagenta setColor:defaultColorTable[1][5]];
    [ansiHiCyan setColor:defaultColorTable[1][6]];
    [ansiHiWhite setColor:defaultColorTable[1][7]];
    
    [row setIntValue:defaultRow];
    [col setIntValue:defaultCol];
    [scrollbackLines setIntValue:defaultScrollback];
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
    [promptOnClose setState:defaultPromptOnClose?NSOnState:NSOffState];
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

- (unsigned int) scrollbackLines
{
    return defaultScrollback;
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

- (NSColor *) boldColor
{
    return (defaultBoldColor);
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

- (BOOL)promptOnClose
{
    return (defaultPromptOnClose);
}

- (IBAction)editColorScheme: (id) sender
{
    // set the color scheme to custom
    [colorScheme selectItemAtIndex: 0];
}

- (IBAction)changeColorScheme:(id)sender
{
    int i;
    
    switch ([sender indexOfSelectedItem]) {
        case 0:
            break;
        case 1:
            [defaultBackground autorelease];
            [defaultForeground autorelease];
            [defaultSelectionColor autorelease];
            defaultForeground=[iTermForeground copy];
            defaultBackground=[iTermBackground copy];
            defaultSelectionColor=[iTermSelection copy];
            [fontExample setBackgroundColor:defaultBackground];
            [nafontExample setBackgroundColor:defaultBackground];
            [fontExample setTextColor:defaultForeground];
            [nafontExample setTextColor:defaultForeground];
            
            for(i=0;i<8;i++) {
                defaultColorTable[0][i]=[iTermColorTable[0][i] copy];
                defaultColorTable[1][i]=[iTermColorTable[1][i] copy];
            }
            break;
        case 2:
            [defaultBackground autorelease];
            [defaultForeground autorelease];
            [defaultSelectionColor autorelease];
            defaultForeground=[xtermForeground copy];
            defaultBackground=[xtermBackground copy];
            defaultSelectionColor=[xtermSelection copy];
            [fontExample setBackgroundColor:defaultBackground];
            [nafontExample setBackgroundColor:defaultBackground];
            [fontExample setTextColor:defaultForeground];
            [nafontExample setTextColor:defaultForeground];

            for(i=0;i<8;i++) {
                defaultColorTable[0][i]=[xtermColorTable[0][i] copy];
                defaultColorTable[1][i]=[xtermColorTable[1][i] copy];
            }
            break;
    }
   if ([sender indexOfSelectedItem]) {
       [background setColor:defaultBackground];
       [foreground setColor:defaultForeground];
       [selectionColor setColor: defaultSelectionColor];
       [ansiBlack setColor:defaultColorTable[0][0]];
       [ansiRed setColor:defaultColorTable[0][1]];
       [ansiGreen setColor:defaultColorTable[0][2]];
       [ansiYellow setColor:defaultColorTable[0][3]];
       [ansiBlue setColor:defaultColorTable[0][4]];
       [ansiMagenta setColor:defaultColorTable[0][5]];
       [ansiCyan setColor:defaultColorTable[0][6]];
       [ansiWhite setColor:defaultColorTable[0][7]];
       [ansiHiBlack setColor:defaultColorTable[1][0]];
       [ansiHiRed setColor:defaultColorTable[1][1]];
       [ansiHiGreen setColor:defaultColorTable[1][2]];
       [ansiHiYellow setColor:defaultColorTable[1][3]];
       [ansiHiBlue setColor:defaultColorTable[1][4]];
       [ansiHiMagenta setColor:defaultColorTable[1][5]];
       [ansiHiCyan setColor:defaultColorTable[1][6]];
       [ansiHiWhite setColor:defaultColorTable[1][7]];
   }        
}

- (IBAction)changeTab:(id)sender
{
    [prefTab selectTabViewItemAtIndex:[sender indexOfSelectedItem]];
}

- (NSColor *) colorFromTable:(int)index highLight:(BOOL)hili
{
    if (index<8)
        return defaultColorTable[hili?1:0][index];
    else return nil;
}


@end
