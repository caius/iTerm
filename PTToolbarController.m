//
//  PTToolbarController.m
//  iTerm
//
//  Created by Steve Gehrman on Mon Aug 11 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "PTToolbarController.h"
#import "iTermController.h"
#import "PseudoTerminal.h"

NSString *NewToolbarItem = @"New";
NSString *ABToolbarItem = @"Address";
NSString *CloseToolbarItem = @"Close";
NSString *ConfigToolbarItem = @"Config";

@interface PTToolbarController (Private)
- (void)setupToolbar;
- (void)buildToolbarItemPopUpMenu:(NSToolbarItem *)toolbarItem forToolbar:(NSToolbar *)toolbar;
- (NSToolbarItem*)toolbarItemWithIdentifier:(NSString*)identifier;
@end

@implementation PTToolbarController

- (id)initWithPseudoTerminal:(PseudoTerminal*)terminal;
{
    self = [super init];
    
    _pseudoTerminal = terminal; // don't retain;
    
    // Add ourselves as an observer for notifications to reload the addressbook.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(reloadAddressBookMenu:)
                                                 name: @"Reload AddressBook"
                                               object: nil];
    
    [self setupToolbar];
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_toolbar release];
    [super dealloc];
}

- (NSArray *)toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray* itemIdentifiers= [[[NSMutableArray alloc]init] autorelease];
    
    [itemIdentifiers addObject: NewToolbarItem];
    [itemIdentifiers addObject: ABToolbarItem];
    [itemIdentifiers addObject: ConfigToolbarItem];
    [itemIdentifiers addObject: NSToolbarSeparatorItemIdentifier];
    [itemIdentifiers addObject: NSToolbarCustomizeToolbarItemIdentifier];
    [itemIdentifiers addObject: CloseToolbarItem];
    [itemIdentifiers addObject: NSToolbarFlexibleSpaceItemIdentifier];
    
    return itemIdentifiers;
}

- (NSArray *)toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray* itemIdentifiers = [[[NSMutableArray alloc]init] autorelease];
    
    [itemIdentifiers addObject: NewToolbarItem];
    [itemIdentifiers addObject: ABToolbarItem];
    [itemIdentifiers addObject: ConfigToolbarItem];
    [itemIdentifiers addObject: NSToolbarCustomizeToolbarItemIdentifier];
    [itemIdentifiers addObject: CloseToolbarItem];
    [itemIdentifiers addObject: NSToolbarFlexibleSpaceItemIdentifier];
    [itemIdentifiers addObject: NSToolbarSpaceItemIdentifier];
    [itemIdentifiers addObject: NSToolbarSeparatorItemIdentifier];
    
    return itemIdentifiers;
}

- (NSToolbarItem *)toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
    NSString *imagePath;
    NSImage *anImage;
    
    if ([itemIdent isEqual: ABToolbarItem]) 
    {
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"Bookmarks",@"iTerm", thisBundle, @"Toolbar Item:Bookmarks")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"Bookmarks",@"iTerm", thisBundle, @"Toolbar Item:Bookmarks")];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Open the bookmarks",@"iTerm", thisBundle, @"Toolbar Item Tip:Bookmarks")];
        imagePath = [thisBundle pathForResource:@"addressbook"
                                         ofType:@"png"];
        anImage = [[NSImage alloc] initByReferencingFile: imagePath];
        [toolbarItem setImage: anImage];
        [anImage release];
        [toolbarItem setTarget: [iTermController sharedInstance]];
        [toolbarItem setAction: @selector(showABWindow:)];
    }
    else if ([itemIdent isEqual: CloseToolbarItem]) 
    {
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", thisBundle, @"Toolbar Item: Close Session")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"Close",@"iTerm", thisBundle, @"Toolbar Item: Close Session")];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Close the current session",@"iTerm", thisBundle, @"Toolbar Item Tip: Close")];
        imagePath = [thisBundle pathForResource:@"close"
                                         ofType:@"png"];
        anImage = [[NSImage alloc] initByReferencingFile: imagePath];
        [toolbarItem setImage: anImage];
        [anImage release];
        [toolbarItem setTarget: nil];
        [toolbarItem setAction: @selector(closeCurrentSession:)];
    }
    else if ([itemIdent isEqual: ConfigToolbarItem]) 
    {
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"Configure",@"iTerm", thisBundle, @"Toolbar Item:Configure") ];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"Configure",@"iTerm", thisBundle, @"Toolbar Item:Configure") ];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Configure current window",@"iTerm", thisBundle, @"Toolbar Item Tip:Configure")];
        imagePath = [thisBundle pathForResource:@"config"
                                         ofType:@"png"];
        anImage = [[NSImage alloc] initByReferencingFile: imagePath];
        [toolbarItem setImage: anImage];
        [anImage release];
        [toolbarItem setTarget: nil];
        [toolbarItem setAction: @selector(showConfigWindow:)];
    } 
    else if ([itemIdent isEqual: NewToolbarItem])
    {
        NSPopUpButton *aPopUpButton;
        
        if([toolbar sizeMode] == NSToolbarSizeModeSmall)
            aPopUpButton = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0.0, 0.0, 40.0, 24.0) pullsDown: YES];
        else
            aPopUpButton = [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0.0, 0.0, 48.0, 32.0) pullsDown: YES];
        
        [aPopUpButton setTarget: nil];
        [aPopUpButton setBordered: NO];
        [[aPopUpButton cell] setArrowPosition:NSPopUpArrowAtBottom];
        [toolbarItem setView: aPopUpButton];
        // Release the popup button since it is retained by the toolbar item.
        [aPopUpButton release];
        
        // build the menu
        [self buildToolbarItemPopUpMenu: toolbarItem forToolbar: toolbar];
        
        [toolbarItem setMinSize:[aPopUpButton bounds].size];
        [toolbarItem setMaxSize:[aPopUpButton bounds].size];
        [toolbarItem setLabel: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", thisBundle, @"Toolbar Item:New")];
        [toolbarItem setPaletteLabel: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", thisBundle, @"Toolbar Item:New")];
        [toolbarItem setToolTip: NSLocalizedStringFromTableInBundle(@"Open a new session",@"iTerm", thisBundle, @"Toolbar Item:New")];
    }
    else
        toolbarItem=nil;
    
    return toolbarItem;
}

@end

@implementation PTToolbarController (Private)

- (void)setupToolbar;
{        
    _toolbar = [[NSToolbar alloc] initWithIdentifier: @"Terminal Toolbar"];
    [_toolbar setVisible:true];
    [_toolbar setDelegate:self];
    [_toolbar setAllowsUserCustomization:YES];
    [_toolbar setAutosavesConfiguration:YES];
    [_toolbar setDisplayMode:NSToolbarDisplayModeDefault];
    [_toolbar insertItemWithItemIdentifier: NewToolbarItem atIndex:0];
    [_toolbar insertItemWithItemIdentifier: ABToolbarItem atIndex:1];
    [_toolbar insertItemWithItemIdentifier: ConfigToolbarItem atIndex:2];
    [_toolbar insertItemWithItemIdentifier: NSToolbarFlexibleSpaceItemIdentifier atIndex:3];
    [_toolbar insertItemWithItemIdentifier: NSToolbarCustomizeToolbarItemIdentifier atIndex:4];
    [_toolbar insertItemWithItemIdentifier: NSToolbarSeparatorItemIdentifier atIndex:5];
    [_toolbar insertItemWithItemIdentifier: CloseToolbarItem atIndex:6];
    
    [[_pseudoTerminal window] setToolbar:_toolbar];
}

- (void)buildToolbarItemPopUpMenu:(NSToolbarItem *)toolbarItem forToolbar:(NSToolbar *)toolbar
{
    NSPopUpButton *aPopUpButton;
    NSMenuItem *item;
    NSMenu *aMenu;
    id newwinItem;
    NSString *imagePath;
    NSImage *anImage;
    NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
    BOOL newwin = [[NSUserDefaults standardUserDefaults] boolForKey:@"SESSION_IN_NEW_WINDOW"];
    
    if (toolbarItem == nil)
        return;
    
    aPopUpButton = (NSPopUpButton *)[toolbarItem view];
    //[aPopUpButton setAction: @selector(_addressbookPopupSelectionDidChange:)];
    [aPopUpButton setAction: nil];
    [aPopUpButton removeAllItems];
    [aPopUpButton addItemWithTitle: @""];
    
    [[iTermController sharedInstance] buildAddressBookMenu: [aPopUpButton menu] forTerminal: (newwin?nil:_pseudoTerminal)];
    
    [[aPopUpButton menu] addItem: [NSMenuItem separatorItem]];
    [[aPopUpButton menu] addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Open in a new window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New") action: @selector(toggleNewWindowState:) keyEquivalent: @""];
    newwinItem=[aPopUpButton lastItem];
    [newwinItem setTarget:self];    
    [newwinItem setState:(newwin ? NSOnState : NSOffState)];    
    
    // Now set the icon
    item = [[aPopUpButton cell] menuItem];
    imagePath = [thisBundle pathForResource:@"newwin"
                                     ofType:@"png"];
    anImage = [[NSImage alloc] initByReferencingFile: imagePath];
    [toolbarItem setImage: anImage];
    [anImage release];
    [anImage setScalesWhenResized:YES];
    if([toolbar sizeMode] == NSToolbarSizeModeSmall)
        [anImage setSize:NSMakeSize(24.0, 24.0)];
    else
        [anImage setSize:NSMakeSize(30.0, 30.0)];
    
    [item setImage:anImage];
    [item setOnStateImage:nil];
    [item setMixedStateImage:nil];
    [aPopUpButton setPreferredEdge:NSMinXEdge];
    [[[aPopUpButton menu] menuRepresentation] setHorizontalEdgePadding:0.0];
    
    // build a menu representation for text only.
    item = [[NSMenuItem alloc] initWithTitle: NSLocalizedStringFromTableInBundle(@"New",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item:New") action: nil keyEquivalent: @""];
    aMenu = [[NSMenu alloc] initWithTitle: @"Bookmarks"];
    [[iTermController sharedInstance] buildAddressBookMenu: aMenu forTerminal: (newwin?nil:_pseudoTerminal)];
    [aMenu addItem: [NSMenuItem separatorItem]];
    [aMenu addItemWithTitle: NSLocalizedStringFromTableInBundle(@"Open in a new window",@"iTerm", [NSBundle bundleForClass: [self class]], @"Toolbar Item: New") action: @selector(toggleNewWindowState:) keyEquivalent: @""];
    newwinItem=[aMenu itemAtIndex: ([aMenu numberOfItems] - 1)];
    [newwinItem setState:(newwin ? NSOnState : NSOffState)];
    [newwinItem setTarget:self];
    
    [item setSubmenu: aMenu];
    [aMenu release];
    [toolbarItem setMenuFormRepresentation: item];
    [item release];
}

// Reloads the addressbook entries into the popup toolbar item
- (void)reloadAddressBookMenu:(NSNotification *)aNotification
{
    NSToolbarItem *aToolbarItem = [self toolbarItemWithIdentifier:NewToolbarItem];
    
    if (aToolbarItem )
        [self buildToolbarItemPopUpMenu: aToolbarItem forToolbar:_toolbar];
}

- (void)toggleNewWindowState: (id) sender
{
    BOOL set = [[NSUserDefaults standardUserDefaults] boolForKey:@"SESSION_IN_NEW_WINDOW"];
    [[NSUserDefaults standardUserDefaults] setBool:!set forKey:@"SESSION_IN_NEW_WINDOW"];    
    
    [self reloadAddressBookMenu: nil];
}

- (NSToolbarItem*)toolbarItemWithIdentifier:(NSString*)identifier
{
    NSArray *toolbarItemArray;
    NSToolbarItem *aToolbarItem;
    int i;
    
    toolbarItemArray = [_toolbar items];
    
    // Find the addressbook popup item and reset it
    for (i = 0; i < [toolbarItemArray count]; i++)
    {
        aToolbarItem = [toolbarItemArray objectAtIndex: i];
        
        if ([[aToolbarItem itemIdentifier] isEqual: identifier])
            return aToolbarItem;
    }

return nil;
}


@end
