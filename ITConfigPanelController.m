/*
 **  ITConfigPanelController.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: controls the config sheet.
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

#import "ITConfigPanelController.h"
#import "ITViewLocalizer.h"
#import "ITAddressBookMgr.h"
#import "iTermController.h"
#import "PTYSession.h"
#import "PseudoTerminal.h"
#import "VT100Screen.h"
#import "PTYTextView.h"
#import "PTYScrollView.h"
#import "ITSessionMgr.h"

@interface ITConfigPanelController (Private)
- (void)showConfigWindow:(PseudoTerminal*)pseudoTerminal parentWindow:(NSWindow*)parentWindow;
@end

@implementation ITConfigPanelController

+ (void)show:(PseudoTerminal*)pseudoTerminal parentWindow:(NSWindow*)parentWindow;
{
    // controller will be deleted when closed
    ITConfigPanelController* controller = [[ITConfigPanelController alloc] initWithWindowNibName:@"ITConfigPanel"];
    [controller showConfigWindow:pseudoTerminal parentWindow:parentWindow];
}

- (id)init;
{
    self = [super init];
    
    return self;
}

- (void)dealloc;
{
    [super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
    // since this NSWindowController doesn't have a document, the releasing is not automatic when the window closes
    [self autorelease];
}

- (void)windowDidLoad;
{
    [ITViewLocalizer localizeWindow:[self window] table:@"configPanel" bundle:[NSBundle bundleForClass: [self class]]];
}

@end

@implementation ITConfigPanelController (Private)

- (IBAction)windowConfigOk:(id)sender
{
    
    if ([CONFIG_COL intValue] < 1 || [CONFIG_ROW intValue] < 1)
    {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Wrong Input",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"Please enter a valid window size",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
    }
    else if ([AI_CODE intValue] > 255 || [AI_CODE intValue] < 0) 
    {
        NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Wrong Input",@"iTerm", [NSBundle bundleForClass: [self class]], @"wrong input"),
                        NSLocalizedStringFromTableInBundle(@"Please enter a valid code (0~255)",@"iTerm", [NSBundle bundleForClass: [self class]], @"Anti-Idle: wrong input"),
                        NSLocalizedStringFromTableInBundle(@"OK",@"iTerm", [NSBundle bundleForClass: [self class]], @"OK"),
                        nil,nil);
    }
    else
    {
        PTYSession* currentSession = [_pseudoTerminal currentSession];
        
        [currentSession setEncoding:[[iTermController sharedInstance] encodingList][[CONFIG_ENCODING indexOfSelectedItem]]];
        
        if ((configFont != nil && [[currentSession SCREEN] font] != configFont) ||
            (configNAFont != nil && [[currentSession SCREEN] nafont] != configNAFont)) 
        {
            [_pseudoTerminal setAllFont:configFont nafont:configNAFont];
            [_pseudoTerminal resizeWindow:[CONFIG_COL intValue] height:[CONFIG_ROW intValue]];
        }
        
        // resiz the window if asked for
        if(([_pseudoTerminal width] != [CONFIG_COL intValue]) || ([_pseudoTerminal height] != [CONFIG_ROW intValue]))
            [_pseudoTerminal resizeWindow:[CONFIG_COL intValue] height:[CONFIG_ROW intValue]];
        
        // set the anti-alias if it has changed
        if([CONFIG_ANTIALIAS state] != [[currentSession TEXTVIEW] antiAlias])
        {
            PTYSession *aSession;
            ITSessionMgr* sessionMgr = [_pseudoTerminal sessionMgr];
            int i, cnt = [sessionMgr numberOfSessions];
            
            for(i=0; i<cnt; i++)
            {
                aSession = [sessionMgr sessionAtIndex: i];
                [[aSession TEXTVIEW] setAntiAlias: [CONFIG_ANTIALIAS state]];
            }
            
            [[currentSession TEXTVIEW] setNeedsDisplay: YES];
        }
        
        // set the selection color if it has changed
        if([[currentSession TEXTVIEW] selectionColor] != [CONFIG_SELECTION color])
            [[currentSession TEXTVIEW] setSelectionColor: [CONFIG_SELECTION color]];
        
        // set the bold color if it has changed
        if([[currentSession TERMINAL] defaultBoldColor] != [CONFIG_BOLD color])
            [[currentSession TERMINAL] setBoldColor: [CONFIG_BOLD color]];

	if((100-[[[currentSession TERMINAL] defaultBGColor] alphaComponent]*100 != [CONFIG_TRANSPARENCY intValue]))
	{
            [currentSession setTransparency:  [CONFIG_TRANSPARENCY floatValue]/100.0];
	}
        
        if(([[currentSession TERMINAL] defaultFGColor] != [CONFIG_FOREGROUND color]) || 
           ([[currentSession TERMINAL] defaultBGColor] != [CONFIG_BACKGROUND color]))
        {
            NSColor *bgColor;
            
            // set the background color for the scrollview with the appropriate transparency
            bgColor = [[CONFIG_BACKGROUND color] colorWithAlphaComponent: (1-[CONFIG_TRANSPARENCY intValue]/100.0)];
            [[currentSession SCROLLVIEW] setBackgroundColor: bgColor];
            [currentSession setForegroundColor:  [CONFIG_FOREGROUND color]];
            [currentSession setBackgroundColor:  bgColor];
            [[currentSession TEXTVIEW] setNeedsDisplay:YES];
        }

        [[currentSession SCREEN] updateScreen];
        
        [[currentSession TEXTVIEW] scrollEnd];
        [_pseudoTerminal setCurrentSessionName: [CONFIG_NAME stringValue]]; 
                
        [currentSession setAntiCode:[AI_CODE intValue]];
        [currentSession setAntiIdle:([AI_ON state]==NSOnState)];
        
        [[self window] orderOut:self];
        [NSApp endSheet:[self window] returnCode:NSCancelButton];

        [[NSColorPanel sharedColorPanel] close];
        [[NSFontPanel sharedFontPanel] close];
    }
}

- (IBAction)windowConfigCancel:(id)sender
{
    [[self window] orderOut:self];
    [NSApp endSheet:[self window] returnCode:NSCancelButton];

    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];
}

- (IBAction)windowConfigFont:(id)sender
{
    changingNA=NO;
    [[CONFIG_EXAMPLE window] makeFirstResponder:[CONFIG_EXAMPLE window]];
    [[CONFIG_EXAMPLE window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:configFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)windowConfigNAFont:(id)sender
{
    changingNA=YES;
    [[CONFIG_NAEXAMPLE window] makeFirstResponder:[CONFIG_NAEXAMPLE window]];
    [[CONFIG_NAEXAMPLE window] setDelegate:self];
    [[NSFontManager sharedFontManager] setSelectedFont:configNAFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)windowConfigForeground:(id)sender
{
    [CONFIG_EXAMPLE setTextColor:[CONFIG_FOREGROUND color]];
    [CONFIG_NAEXAMPLE setTextColor:[CONFIG_FOREGROUND color]];
}

- (IBAction)windowConfigBackground:(id)sender
{
    [CONFIG_EXAMPLE setBackgroundColor:[CONFIG_BACKGROUND color]];
    [CONFIG_NAEXAMPLE setBackgroundColor:[CONFIG_BACKGROUND color]];
}

- (void)changeFont:(id)sender
{
    if (changingNA)
    {
        configNAFont=[[NSFontManager sharedFontManager] convertFont:configNAFont];
        if (configNAFont!=nil)
        {
            [CONFIG_NAEXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configNAFont fontName], [configNAFont pointSize]]];
            [CONFIG_NAEXAMPLE setFont:configNAFont];
        }
    }
    else
    {
        configFont=[[NSFontManager sharedFontManager] convertFont:configFont];
        if (configFont!=nil) 
        {
            [CONFIG_EXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configFont fontName], [configFont pointSize]]];
            [CONFIG_EXAMPLE setFont:configFont];
        }
    }
}

- (void)showConfigWindow:(PseudoTerminal*)pseudoTerminal parentWindow:(NSWindow*)parentWindow;
{
    [self window]; // force window to load
    int r;
    NSStringEncoding const *p=[[iTermController sharedInstance] encodingList];
    
    _pseudoTerminal = pseudoTerminal; // don't retain
  
    PTYSession* currentSession = [_pseudoTerminal currentSession];

    [CONFIG_FOREGROUND setColor:[[currentSession TERMINAL] defaultFGColor]];
    [CONFIG_BACKGROUND setColor:[[currentSession TERMINAL] defaultBGColor]];
    [CONFIG_BACKGROUND setEnabled: ([currentSession image] == nil)?YES:NO];
    [CONFIG_SELECTION setColor:[[currentSession TEXTVIEW] selectionColor]];
    [CONFIG_BOLD setColor: [[currentSession TERMINAL] defaultBoldColor]];
    configFont=[[currentSession SCREEN] font];
    [CONFIG_EXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configFont fontName], [configFont pointSize]]];
    [CONFIG_EXAMPLE setTextColor:[[currentSession TERMINAL] defaultFGColor]];
    [CONFIG_EXAMPLE setBackgroundColor:[[currentSession TERMINAL] defaultBGColor]];
    [CONFIG_EXAMPLE setFont:configFont];
    configNAFont=[[currentSession SCREEN] nafont];
    [CONFIG_NAEXAMPLE setStringValue:[NSString stringWithFormat:@"%@ %g", [configNAFont fontName], [configNAFont pointSize]]];
    [CONFIG_NAEXAMPLE setTextColor:[[currentSession TERMINAL] defaultFGColor]];
    [CONFIG_NAEXAMPLE setBackgroundColor:[[currentSession TERMINAL] defaultBGColor]];
    [CONFIG_NAEXAMPLE setFont:configNAFont];
    [CONFIG_COL setIntValue:[_pseudoTerminal width]];
    [CONFIG_ROW setIntValue:[_pseudoTerminal height]];
    [CONFIG_NAME setStringValue:[_pseudoTerminal currentSessionName]];
    [CONFIG_ENCODING removeAllItems];
    r=0;
    while (*p) 
    {
        [CONFIG_ENCODING addItemWithTitle:[NSString localizedNameOfStringEncoding:*p]];
        if (*p==[[currentSession TERMINAL] encoding]) 
            r = p-[[iTermController sharedInstance] encodingList];
        p++;
    }
    [CONFIG_ENCODING selectItemAtIndex:r];
    [CONFIG_TRANSPARENCY setIntValue:(int)([currentSession transparency]*100)];
    [CONFIG_TRANS2 setIntValue:(int)([currentSession transparency]*100)];
    [AI_ON setState:[currentSession antiIdle]?NSOnState:NSOffState];
    [AI_CODE setIntValue:[currentSession antiCode]];
    
    [CONFIG_ANTIALIAS setState: [[currentSession TEXTVIEW] antiAlias]];
    
    [NSApp beginSheet: [self window]
       modalForWindow: parentWindow
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];        
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[self window] close];
}

@end
