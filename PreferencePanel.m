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
//    BACKGROUND  = [[NSColor textBackgroundColor] retain];
//    FOREGROUND  = [[NSColor textColor] retain];
    BACKGROUND = [NSColor blackColor];
    FOREGROUND = [NSColor whiteColor];
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

    prefs = [NSUserDefaults standardUserDefaults];
    encodingList=[NSString availableStringEncodings];

    defaultCol=([prefs integerForKey:@"Col"]?[prefs integerForKey:@"Col"]:COL);
    defaultRow=([prefs integerForKey:@"Row"]?[prefs integerForKey:@"Row"]:ROW);
    defaultTransparency=([prefs stringForKey:@"Transparency"]!=nil?[prefs integerForKey:@"Transparency"]:TRANSPARENCY);
    defaultAntiAlias=[prefs objectForKey:@"AntiAlias"]?[[prefs objectForKey:@"AntiAlias"] boolValue]: YES;

    defaultTerminal=[[([prefs objectForKey:@"Terminal"]?[prefs objectForKey:@"Terminal"]:TERM)
                    copy] retain];

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
    
    defaultShell=[[([prefs objectForKey:@"Shell"]?[prefs objectForKey:@"Shell"]:SHELL)
                 copy] retain];
                    
    defaultForeground=[[([prefs objectForKey:@"Foreground"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Foreground"]]:FOREGROUND)
                      copy] retain];
    defaultBackground=[[([prefs objectForKey:@"Background"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Background"]]:BACKGROUND)
                      copy] retain];
    defaultSelectionColor=[[([prefs objectForKey:@"SelectionColor"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"SelectionColor"]]:SELECTION)
                      copy] retain];
    defaultFont=[[([prefs objectForKey:@"Font"]?
    [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"Font"]]:FONT)
                      copy] retain];
    defaultNAFont=[[([prefs objectForKey:@"NAFont"]?
                   [NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:@"NAFont"]]:FONT)
        copy] retain];
    defaultAutoclose=[prefs objectForKey:@"AutoClose"]?[[prefs objectForKey:@"AutoClose"] boolValue]: YES;
    defaultOption=[prefs objectForKey:@"OptionKey"]?[prefs integerForKey:@"OptionKey"]:0;
    defaultCopySelection=[[prefs objectForKey:@"CopySelection"] boolValue];
    defaultHideTab=[prefs objectForKey:@"HideTab"]?[[prefs objectForKey:@"HideTab"] boolValue]: YES;
    defaultSilenceBell=[[prefs objectForKey:@"SilenceBell"] boolValue];
    defaultDoubleWidth=[[prefs objectForKey:@"DoubleWidth"] boolValue];
    changingNA=NO;
                 
    return self;
}

- (void)dealloc
{
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
    [copySelection setState:defaultCopySelection?NSOnState:NSOffState];
    [hideTab setState:defaultHideTab?NSOnState:NSOffState];
    [silenceBell setState:defaultSilenceBell?NSOnState:NSOffState];
    [doubleWidth setState:defaultDoubleWidth?NSOnState:NSOffState];
   
    [NSApp runModalForWindow:prefPanel];
    [prefPanel close];
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
    if ([col intValue]>150||[col intValue]<10||[row intValue]>150||[row intValue]<3) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Wrong Input",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"Please enter a valid window size",@"iTerm",@"wrong input"),
                        NSLocalizedStringFromTable(@"OK",@"iTerm",@"OK"),
                        nil,nil);
        return;
    }
    
    [defaultBackground autorelease];
    [defaultForeground autorelease];
    [defaultSelectionColor autorelease];
    
    defaultBackground=[[[background color] copy] retain];
    defaultForeground=[[[foreground color] copy] retain];
    defaultSelectionColor = [[[selectionColor color] copy] retain];

    defaultCol=[col intValue];
    defaultRow=[row intValue];
    
    defaultEncoding=encodingList[[encoding indexOfSelectedItem]];
    defaultShell=[shell stringValue];
    defaultTerminal=[terminal stringValue];
    
    defaultTransparency=[transparency intValue];
    defaultAntiAlias = ([antiAlias state]==NSOnState);

    defaultAutoclose=([autoclose state]==NSOnState);
    defaultOption=[optionKey selectedColumn];
    defaultCopySelection=([copySelection state]==NSOnState);
    defaultHideTab=([hideTab state]==NSOnState);
    defaultSilenceBell=([silenceBell state]==NSOnState);
    defaultDoubleWidth=([doubleWidth state]==NSOnState);

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
    
    defaultBackground=[[BACKGROUND copy] retain];
    defaultForeground=[[FOREGROUND copy] retain];
    defaultFont=[[FONT copy] retain];

    defaultCol=COL;
    defaultRow=ROW;
    
    defaultEncoding=CFStringConvertEncodingToNSStringEncoding(CFStringGetSystemEncoding());
    defaultShell=[[SHELL copy] retain];
    defaultTerminal=[[TERM copy] retain];
    
    defaultTransparency=TRANSPARENCY;
    defaultAutoclose=YES;
    defaultOption=0;
    defaultHideTab=YES;
    defaultCopySelection=YES;
    defaultSilenceBell=NO;
    defaultDoubleWidth=YES;
    
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

@end
