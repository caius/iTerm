// -*- mode:objc -*-
// $Id: MainMenu.m,v 1.1.1.1 2002-11-26 04:56:47 ujwal Exp $
//
//  MainMenu.m
//  JTerminal
//
//  Created by kuma on Sun Apr 21 2002.
//  Copyright (c) 2001 Kiichi Kusama. All rights reserved.
//


// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#import "MainMenu.h"
#import "PreferencePanel.h"
#import "PseudoTerminal.h"
#import "NSStringITerm.h"


#define DEFAULT_FONTNAME  @"Osaka-Mono"
#define DEFAULT_FONTSIZE  12

static NSString* ADDRESS_BOOK_FILE = @"~/Library/Application Support/iTerm Address Book";
static NSImage *waitImage=nil;
static NSImage *normImage=nil;
static BOOL newWindow=YES;

@implementation MainMenu

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu applicationWillFinishLaunching]",
          __FILE__, __LINE__);
#endif
    [self initAddressBook];
    waitImage=[[NSImage imageNamed: @"iTerm-wait"] retain];
    normImage=[[NSImage imageNamed: @"iTerm"] retain];
    terminalWindows = [[NSMutableArray alloc] init];
//  [self showQOWindow:self];

}

- (BOOL) applicationShouldTerminate: (NSNotification *) theNotification
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu applicationShouldTerminate]",
          __FILE__, __LINE__);
#endif

    [terminalWindows removeAllObjects];
    terminalWindows = nil;

    return (YES);
}


- (BOOL)applicationOpenUntitledFile:(NSApplication *)app
{
    [self newWindow:nil];
    
    return YES;
}

- (IBAction)newWindow:(id)sender
{
    PseudoTerminal *term;
    NSString *cmd;
    NSArray *arg;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu newWindow]",
          __FILE__, __LINE__);
#endif

    term = [PseudoTerminal newTerminalWindow: self];
    [term setPreference:PREF_PANEL];
    [MainMenu breakDown:[PREF_PANEL shell] cmdPath:&cmd cmdArgs:&arg];
    //        NSLog(@"%s(%d):-[PseudoTerminal ready to run:%@ arguments:%@]", __FILE__, __LINE__, cmd, arg );
    [term initWindow:[PREF_PANEL col]
              height:[PREF_PANEL row]
                font:[PREF_PANEL font]];
    [term initSession:nil
     foregroundColor:[PREF_PANEL foreground]
     backgroundColor:[PREF_PANEL background]
            encoding:[PREF_PANEL encoding]
                term:[PREF_PANEL terminalType]];
    [term setWindowSize];
    [term startProgram:cmd arguments:arg];
    [[term window] setAlphaValue:1.0-[PREF_PANEL transparency]/100.0];
    [term setCurrentSessionName:nil];
    [term autorelease];
}

- (IBAction)newSession:(id)sender
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu newSession]",
          __FILE__, __LINE__);
#endif
    if(FRONT == nil)
        [self newWindow:nil];
    else
        [FRONT newSession: self];
}


//Quick open window
- (IBAction)showQOWindow:(id)sender
{
    int r;
    PseudoTerminal *term;
    NSString *cmd;
    NSArray *arg;
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu showQOWindow:%@]",
          __FILE__, __LINE__, sender);
#endif
    [QO_PANEL center];
    [QO_DIR setStringValue:[@"~"  stringByExpandingTildeInPath]];
    r= [NSApp runModalForWindow:QO_PANEL];
    [QO_PANEL close];
    if (r == 50) {
        [self showABWindow: self];
    }
    else if (r == NSRunStoppedResponse) {
        NSDictionary *env=[NSDictionary dictionaryWithObject:[QO_DIR stringValue] forKey:@"PWD"];
        if (newWindow) {
            term = [PseudoTerminal newTerminalWindow: self];
            [term setPreference:PREF_PANEL];
            [term initWindow:[PREF_PANEL col]
                      height:[PREF_PANEL row]
                        font:[PREF_PANEL font]];
        }
        else term=FRONT;
        
        [MainMenu breakDown:[QO_COMMAND stringValue] cmdPath:&cmd cmdArgs:&arg];
//        NSLog(@"%s(%d):-[PseudoTerminal ready to run:%@ arguments:%@]", __FILE__, __LINE__, cmd, arg );
        [term initSession:nil
         foregroundColor:[PREF_PANEL foreground]
         backgroundColor:[PREF_PANEL background]
                encoding:[PREF_PANEL encoding]
                    term:[PREF_PANEL terminalType]];
        [[term currentSession] startProgram:cmd arguments:arg environment:env];
        if (newWindow) {
            [term setWindowSize];
            [[term window] setAlphaValue:1.0-[PREF_PANEL transparency]/100.0];
        };
        [term setCurrentSessionName:nil];
        
    }
}

- (IBAction)windowQOOk:(id)sender
{
    newWindow=(sender==QO_NewWindow);
    [NSApp stopModal];
}

- (IBAction)windowQOCancel:(id)sender
{
    [NSApp abortModal];
}

- (IBAction)windowQOType:(id)sender
{
    int n;

    n = [QO_TYPE selectedColumn];
    switch (n) {
        case 0:
            [QO_COMMAND setStringValue:[PREF_PANEL shell]];
            break;
        case 1:
            [QO_COMMAND setStringValue:@"/usr/bin/telnet"];
            break;
        case 2:
            [QO_COMMAND setStringValue:@"/usr/bin/ssh"];
            break;
        case 3:
            [QO_COMMAND setStringValue:@"/usr/bin/ftp"];
            break;
    }
}

- (IBAction)windowQOAddressBook:(id)sender
{
    [NSApp stopModalWithCode: 50];
    
}

// Address book window
- (IBAction)showABWindow:(id)sender
{
    int r;
    PseudoTerminal *term;
    NSString *cmd;
    NSArray *arg;
    NSDictionary *entry;
    NSString *enc;
    NSStringEncoding encoding;
    
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu showABWindow:%@]",
          __FILE__, __LINE__, sender);
#endif

//    [self initAddressBook];
//    NSLog(@"showABWindow: %d\n%@",[addressBook count], addressBook);

    [AB_PANEL center];
    r= [NSApp runModalForWindow:AB_PANEL];
    [AB_PANEL close];
    if (r == 50) {
        [self showQOWindow: self];
    }
    else if (r == NSRunStoppedResponse) {
        entry = [addressBook objectAtIndex:[adTable selectedRow]];
        [MainMenu breakDown:[entry objectForKey:@"Command"] cmdPath:&cmd cmdArgs:&arg];
//        NSLog(@"%s(%d):-[PseudoTerminal ready to run:%@ arguments:%@]", __FILE__, __LINE__, cmd, arg );
        enc=[entry objectForKey:@"Encoding"];
        if ([enc compare:@"Chinese (GB)"]==NSOrderedSame)
            encoding=NSStringEUCCNEncoding;
        else if ([enc compare:@"Chinese (Big 5)"]==NSOrderedSame)
            encoding=NSStringBig5Encoding;
        else //([enc compare:@"Unicode"]==NSOrderedSame)
            encoding=NSUTF8StringEncoding;

        if (newWindow) {
            term = [PseudoTerminal newTerminalWindow: self];
            [term setPreference:PREF_PANEL];
            [term initWindow:[[entry objectForKey:@"Col"]intValue]
                      height:[[entry objectForKey:@"Row"] intValue]
                        font:[entry objectForKey:@"Font"]];
        }
        else term=FRONT;
        [term initSession:[entry objectForKey:@"Name"]
         foregroundColor:[entry objectForKey:@"Foreground"]
         backgroundColor:[entry objectForKey:@"Background"]
                encoding:encoding
                    term:[entry objectForKey:@"Term Type"]];

        NSDictionary *env=[NSDictionary dictionaryWithObject:([entry objectForKey:@"Directory"]?[entry objectForKey:@"Directory"]:@"~")  forKey:@"PWD"];
            
        [[term currentSession] startProgram:cmd arguments:arg environment:env];
        enc=[entry objectForKey:@"Encoding"];
        if ([enc compare:@"Unicode"]==NSOrderedSame)
            [[term currentSession] setEncodingUTF8:sender];
        else if ([enc compare:@"Chinese (GB)"]==NSOrderedSame) 
            [[term currentSession] setEncodingEUCCN:sender];
        else if ([enc compare:@"Chinese (Big 5)"]==NSOrderedSame)
            [[term currentSession] setEncodingBIG5:sender];
       
        [[term currentSession] setFGColor:[entry objectForKey:@"Foreground"]];
        [[term currentSession] setBGColor:[entry objectForKey:@"Background"]];
        if (newWindow) {
            [term setWindowSize];
            [[term window] setAlphaValue:1.0-[PREF_PANEL transparency]/100.0];
        };
        [term setCurrentSessionName:[entry objectForKey:@"Name"]];
        
    }
}

- (IBAction)adbAddEntry:(id)sender
{
    int r;
    
    [AE_PANEL center];
    [adName setStringValue:@""];
    [adCommand setStringValue:[PREF_PANEL shell]];
    [adEncoding selectItemAtIndex:0];
    [adTermType selectItemAtIndex:0];
    [adRow setIntValue:[PREF_PANEL row]];
    [adCol setIntValue:[PREF_PANEL col]];
    [adForeground setColor:[PREF_PANEL foreground]];
    [adBackground setColor:[PREF_PANEL background]];
    [adDir setStringValue:[@"~"  stringByExpandingTildeInPath]];

    aeFont=[[[PREF_PANEL font] copy] retain];
    [adTextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeFont fontName], [aeFont pointSize]]];
    [adTextExample setFont:aeFont];
    [adTextExample setTextColor:[PREF_PANEL foreground]];
    [adTextExample setBackgroundColor:[PREF_PANEL background]];

    [adTransparency setIntValue:[PREF_PANEL transparency]];
    [adTransparency2 setIntValue:[PREF_PANEL transparency]];

    r= [NSApp runModalForWindow:AE_PANEL];
    [AE_PANEL close];
    if (r == NSRunStoppedResponse) {
        NSDictionary *ae;

        ae=[[NSDictionary alloc] initWithObjectsAndKeys:
            [adName stringValue],@"Name",
            [adCommand stringValue],@"Command",
            [adEncoding stringValue],@"Encoding",
            [adForeground color],@"Foreground",
            [adBackground color],@"Background",
            [adRow stringValue],@"Row",
            [adCol stringValue],@"Col",
            [NSNumber numberWithInt:[adTransparency intValue]],@"Transparency",
            [adTermType stringValue],@"Term Type",
            [adDir stringValue],@"Directory",
            aeFont,@"Font", 
            NULL];
        [addressBook addObject:ae];
//        NSLog(@"%s(%d):-[Address entry added:%@]",
//              __FILE__, __LINE__, ae );
        [adTable reloadData];
        [ae release];

    }
    
}

- (IBAction)adbCancel:(id)sender
{
    [NSApp abortModal];
}

- (IBAction)adbEditEntry:(id)sender
{
    int r;
    id entry;

    if ([adTable selectedRow]<0) return
    [AE_PANEL center];
    entry=[addressBook objectAtIndex:[adTable selectedRow]];
    [adName setStringValue:[entry objectForKey:@"Name"]];
    [adCommand setStringValue:[entry objectForKey:@"Command"]];
    [adEncoding setStringValue:[entry objectForKey:@"Encoding"]];
    if ([entry objectForKey:@"Term Type"])
        [adTermType setStringValue:[entry objectForKey:@"Term Type"]];
    else
        [adTermType selectItemAtIndex:0];
    [adForeground setColor:[entry objectForKey:@"Foreground"]];
    [adBackground setColor:[entry objectForKey:@"Background"]];
    [adRow setStringValue:[entry objectForKey:@"Row"]];
    [adCol setStringValue:[entry objectForKey:@"Col"]];
    if ([entry objectForKey:@"Transparency"]) {
        [adTransparency setIntValue:[[entry objectForKey:@"Transparency"] intValue]];
        [adTransparency2 setIntValue:[[entry objectForKey:@"Transparency"] intValue]];
    }
    else {
        [adTransparency setIntValue:0];
        [adTransparency2 setIntValue:0];
    }
    if ([entry objectForKey:@"Directory"]) {
        [adDir setStringValue:[entry objectForKey:@"Directory"]];
    }
    else {
        [adDir setStringValue:[@"~"  stringByExpandingTildeInPath]];
    }
    
    aeFont=[entry objectForKey:@"Font"];
    [adTextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeFont fontName], [aeFont pointSize]]];
    [adTextExample setTextColor:[entry objectForKey:@"Foreground"]];
    [adTextExample setBackgroundColor:[entry objectForKey:@"Background"]];
    [adTextExample setFont:aeFont];
    
    r= [NSApp runModalForWindow:AE_PANEL];
    [AE_PANEL close];
    if (r == NSRunStoppedResponse) {
        NSDictionary *ae;

        ae=[[NSDictionary alloc] initWithObjectsAndKeys:
            [adName stringValue],@"Name",
            [adCommand stringValue],@"Command",
            [adEncoding stringValue],@"Encoding",
            [adForeground color],@"Foreground",
            [adBackground color],@"Background",
            [adRow stringValue],@"Row",
            [adCol stringValue],@"Col",
            [NSNumber numberWithInt:[adTransparency intValue]],@"Transparency",
            [adTermType stringValue],@"Term Type",
            [adDir stringValue],@"Directory",
            aeFont,@"Font", 
            NULL];
        [addressBook replaceObjectAtIndex:[adTable selectedRow] withObject:ae];
//        NSLog(@"%s(%d):-[Address entry replaced:%@]",
//              __FILE__, __LINE__, ae );
        [adTable reloadData];
        [ae release];
    }
}

- (IBAction)adbGotoQuickOpen:(id)sender
{
    [NSApp stopModalWithCode: 50];
}

- (IBAction)adbOk:(id)sender
{
    if ([adTable selectedRow]!=-1) {
        [self saveAddressBook];
        newWindow=(sender==adNewWindow);
        [NSApp stopModal];
    }
}

- (IBAction)adbRemoveEntry:(id)sender
{
    NSBeginAlertSheet(
                      NSLocalizedStringFromTable(@"Do you really want to remove this item?",@"iTerm",@"Removal Alert"),
                      NSLocalizedStringFromTable(@"Cancel",@"iTerm",@"Cancel"),
                      NSLocalizedStringFromTable(@"Remove",@"iTerm",@"Remove"),
                      nil,
                      AB_PANEL,               // window sheet is attached to
                      self,                   // we'll be our own delegate
                      @selector(sheetDidEnd:returnCode:contextInfo:),     // did-end selector
                      NULL,                   // no need for did-dismiss selector
                      sender,                 // context info
                      NSLocalizedStringFromTable(@"There is no undo for this operation.",@"iTerm",@"Removal Alert"),
                      nil);                   // no parameters in message
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if ( returnCode == NSAlertAlternateReturn) {
        [addressBook removeObjectAtIndex:[adTable selectedRow]];
        [adTable reloadData];
    }
}

// address entry window
- (IBAction)adEditBackground:(id)sender
{
    [adTextExample setBackgroundColor:[adBackground color]];
//    [[NSColorPanel sharedColorPanel] close];
}

- (IBAction)adEditCancel:(id)sender
{
    [NSApp abortModal];
    [[NSColorPanel sharedColorPanel] close];
    [[NSFontPanel sharedFontPanel] close];
}

- (IBAction)adEditFont:(id)sender
{
    [[adTextExample window] makeFirstResponder:[adTextExample window]];
    [[NSFontManager sharedFontManager] setSelectedFont:aeFont isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (IBAction)adEditForeground:(id)sender
{
    [adTextExample setTextColor:[sender color]];
//    [[NSColorPanel sharedColorPanel] close];
}

- (IBAction)adEditOK:(id)sender
{
    if ([adCol intValue]>150||[adCol intValue]<10||[adRow intValue]>150||[adRow intValue]<3) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid window size",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
    }
    else {
        [NSApp stopModal];
        [[NSColorPanel sharedColorPanel] close];
        [[NSFontPanel sharedFontPanel] close];
    }
}

- (NSPanel *)aePanel
{
    return AE_PANEL;
}


- (void)changeFont:(id)fontManager
{
    [aeFont autorelease];
    aeFont=[fontManager convertFont:[adTextExample font]];
    [adTextExample setStringValue:[NSString stringWithFormat:@"%@ %g", [aeFont fontName], [aeFont pointSize]]];
    [adTextExample setFont:aeFont];
}

// Table data source
- (int)numberOfRowsInTableView:(NSTableView*)table
{
    return [addressBook count];
}

// this message is called for each row of the table
- (id)tableView:(NSTableView*)table objectValueForTableColumn:(NSTableColumn*)col
                                                          row:(int)rowIndex
{
    NSDictionary *theRecord;

    NSParameterAssert(rowIndex >= 0 && rowIndex < [addressBook count]);
    theRecord = [addressBook objectAtIndex:rowIndex];
    return [theRecord objectForKey:[col identifier]];
}

// this message is called when the user double-clicks on a row in the table
- (void)tableView:(NSTableView*)table  setObjectValue:(id)object
                                       forTableColumn:(NSTableColumn*)col
                                                  row:(int)rowIndex
{
    [self saveAddressBook];
    [NSApp stopModal];
}


/// About window

- (IBAction)showAbout:(id)sender
{
//    [NSApp orderFrontStandardAboutPanel:nil];
    [NSApp runModalForWindow:ABOUT];
    [ABOUT close];
}

- (IBAction)aboutOK:(id)sender
{
    [NSApp stopModal];
}

// Preference Panel
- (IBAction)showPrefWindow:(id)sender
{
//    PreferencePanel *pref=[[PreferencePanel alloc] init];
    [PREF_PANEL run];
//    [pref dealloc];
}

// Utility
+ (void) breakDown:(NSString *)cmdl cmdPath: (NSString **) cmd cmdArgs: (NSArray **) path
{
    int i,j,k,qf;
    char tmp[100];
    const char *s;
    NSMutableArray *p;

    p=[[NSMutableArray alloc] init];

    s=[cmdl cString];

    i=j=qf=0;
    k=-1;
    while (i<=strlen(s)) {
        if (qf) {
            if (s[i]=='\"') {
                qf=0;
            }
            else {
                tmp[j++]=s[i];
            }
        }
        else {
            if (s[i]=='\"') {
                qf=1;
            }
            else if (s[i]==' ' || s[i]=='\t' || s[i]=='\n'||s[i]==0) {
                tmp[j]=0;
                if (k==-1) {
                    *cmd=[[NSString alloc] initWithCString:tmp];
                }
                else
                    [p addObject:[NSString stringWithCString:tmp]];
                j=0;
                k++;
                while (s[i+1]==' '||s[i+1]=='\t'||s[i+1]=='\n'||s[i+1]==0) i++;
            }
            else {
                tmp[j++]=s[i];
            }
        }
        i++;
    }

    *path = [[NSArray alloc] initWithArray:p];
}

- (void) initAddressBook
{

#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[MainMenu initAddressBook]",
          __FILE__, __LINE__);
#endif

    if (addressBook!=nil) return;

    addressBook = [[NSUnarchiver unarchiveObjectWithFile: [ADDRESS_BOOK_FILE stringByExpandingTildeInPath]] retain];
    if (addressBook == nil) {
        NSLog(@"No file loaded");
        addressBook=[[NSMutableArray array] retain];
    }
//    NSLog(@ "initAddressBook: %d\n%@",[addressBook count], addressBook);

}    

- (void) saveAddressBook
{
    if (![NSArchiver archiveRootObject:addressBook toFile:[ADDRESS_BOOK_FILE stringByExpandingTildeInPath]]) {
        NSLog(@"Save failed");
    }
}

- (void) setFrontPseudoTerminal: (PseudoTerminal *) thePseudoTerminal
{
    FRONT = thePseudoTerminal;
}

- (PseudoTerminal *) frontPseudoTerminal
{
    return (FRONT);
}

- (void) addTerminalWindow: (PseudoTerminal *) theTerminalWindow
{
    if(theTerminalWindow)
        [terminalWindows addObject: theTerminalWindow];
}

- (void) removeTerminalWindow: (PseudoTerminal *) theTerminalWindow
{
    if(theTerminalWindow)
        [terminalWindows removeObject: theTerminalWindow];
    if(FRONT == theTerminalWindow)
        FRONT = nil;
}




@end
