//
//  PTYTabView.m
//  iTerm
//
//  Created by Ujwal Sathyam on Thu Dec 19 2002.
//  Copyright (c) 2002 __MyCompanyName__. All rights reserved.
//

#import "PTYTabView.h"

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
    NSMenuItem *aMenuItem;
    NSMenu *cMenu;
    
    cMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    
    for (i = 0; i < [self numberOfTabViewItems]; i++)
    {
        aMenuItem = [[NSMenuItem alloc] initWithTitle:[[self tabViewItemAtIndex: i] label]
                            action:@selector(selectTab:) keyEquivalent:@""];
        [aMenuItem setRepresentedObject: [[self tabViewItemAtIndex: i] identifier]];
        [cMenu addItem: aMenuItem];
        [aMenuItem release];
    }
    return (cMenu);
}

// selects a tab from the contextual menu
- (void) selectTab: (id) sender
{
    [self selectTabViewItemWithIdentifier: [sender representedObject]];
}

@end
