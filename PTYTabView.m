//
//  PTYTabView.m
//  iTerm
//
//  Created by Ujwal Sathyam on Thu Dec 19 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "PTYTabView.h"
#import "PseudoTerminal.h"

#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0


@implementation PTYTabView

- (id)initWithFrame: (NSRect) aRect
{
#if DEBUG_ALLOC
    NSLog(@"PTYTabView: -initWithFrame");
#endif

    return [super initWithFrame: aRect];
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"PTYTabView: -dealloc");
#endif
        
    [super dealloc];
}


// build a conextual menu displaying the current tabs
- (NSMenu *) menuForEvent: (NSEvent *) theEvent
{
    int i;
    NSMenuItem *aMenuItem, *anotherMenuItem;
    NSMenu *cMenu, *aMenu;

    // Create a menu with a submenu to navigate between tabs
    cMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    anotherMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTable(@"Select",@"iTerm",@"Context menu") action:nil keyEquivalent:@""];
    [cMenu addItem: anotherMenuItem];
    [anotherMenuItem release];

    aMenu = [[NSMenu alloc] initWithTitle:@""];
    
    for (i = 0; i < [self numberOfTabViewItems]; i++)
    {
        aMenuItem = [[NSMenuItem alloc] initWithTitle:[[self tabViewItemAtIndex: i] label]
                            action:@selector(selectTab:) keyEquivalent:@""];
        [aMenuItem setRepresentedObject: [[self tabViewItemAtIndex: i] identifier]];
        [aMenu addItem: aMenuItem];
        [aMenuItem release];
    }
    [anotherMenuItem setSubmenu: aMenu];
    [aMenu release];
    
    // Ask our delegate if it has anything to add
    id delegate = [self delegate];
    if([delegate respondsToSelector: @selector(tabViewContextualMenu: menu:)])
	[delegate tabViewContextualMenu: theEvent menu: cMenu];

    return (cMenu);
}

// selects a tab from the contextual menu
- (void) selectTab: (id) sender
{
    [self selectTabViewItemWithIdentifier: [sender representedObject]];
}

@end
