/*
 **  FindPanelWindowController.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Implements the find functions.
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

#import <iTerm/iTermController.h>
#import <iTerm/PTYTextView.h>
#import <iTerm/FindPanelWindowController.h>

#define DEBUG_ALLOC	0

static FindPanelWindowController *singleInstance = nil;

@implementation FindPanelWindowController

//
// class methods
//
+ (id) singleInstance
{
    if ( !singleInstance )
    {
	singleInstance = [[self alloc] initWithWindowNibName: @"FindPanel"];
    }

    return singleInstance;
}

- (id) initWithWindowNibName: (NSString *) windowNibName
{
#if DEBUG_ALLOC
    NSLog(@"FindPanelWindowController: -initWithWindowNibName");
#endif

    respondingWindow = [NSApp keyWindow];

    self = [super initWithWindowNibName: windowNibName];

    // We finally set our autosave window frame name and restore the one from the user's defaults.
    [[self window] setFrameAutosaveName: @"FindPanel"];
    [[self window] setFrameUsingName: @"FindPanel"];

    [[self window] setDelegate: self];

    ignoreCase = NO;

    // register as an observer for windows becoming and resigning key
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(respondingWindowFocusDidChange:) name: NSWindowDidBecomeKeyNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(respondingWindowFocusDidChange:) name: NSWindowDidResignKeyNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(respondingWindowFocusDidChange:) name: NSWindowWillCloseNotification object: nil];

    return (self);
}

- (void) dealloc
{
#if DEBUG_ALLOC
    NSLog(@"FindPanelWindowController: -dealloc");
#endif

    [searchString release];
    singleInstance = nil;

    // remove orselves from the notification center
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidBecomeKeyNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowDidResignKeyNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver: self name: NSWindowWillCloseNotification object: nil];

    [super dealloc];
}

// NSWindow delegate methods
- (void)windowWillClose:(NSNotification *)aNotification
{

    [self autorelease];

}

- (void)windowDidLoad
{
    if([searchString length] > 0)
    {
	[searchStringField setStringValue: searchString];
    }
    [caseCheckBox setIntValue: ignoreCase];
}

- (void) respondingWindowFocusDidChange: (NSNotification *) aNotification
{
    if([[aNotification name] isEqualToString: NSWindowDidBecomeKeyNotification] == YES)
    {
	NSWindow *aWindow = [aNotification object];
	id firstResponder = [aWindow firstResponder];

	if([firstResponder isKindOfClass: [PTYTextView class]] == YES)
	{
	    respondingWindow = aWindow;
	}
    }

    if([[aNotification name] isEqualToString: NSWindowWillCloseNotification] == YES)
    {
	NSWindow *aWindow = [aNotification object];
	
	if(respondingWindow == aWindow)
	    respondingWindow = nil;
    }
    
        
}


// action methods
- (IBAction) findNext: (id) sender
{
    searchString = [[searchStringField stringValue] copy];
    if([searchString length] <= 0 || respondingWindow == nil)
    {
	NSBeep();
	return;
    }

    PTYTextView *frontTextView = (PTYTextView *)[respondingWindow firstResponder];
    
    [frontTextView setSearchString: searchString];
    [frontTextView setIgnoreCase: [caseCheckBox intValue]];
    [frontTextView findNext: self];
        
}

- (IBAction) findPrevious: (id) sender
{
    searchString = [[searchStringField stringValue] copy];
    if([searchString length] <= 0 || respondingWindow == nil)
    {
	NSBeep();
	return;
    }
    
    PTYTextView *frontTextView = (PTYTextView *)[respondingWindow firstResponder];

    [frontTextView setSearchString: searchString];
    [frontTextView setIgnoreCase: [caseCheckBox intValue]];
    [frontTextView findPrevious: self];
        
}

// get/set methods
- (id) delegate
{
    return (delegate);
}

- (void) setDelegate: (id) theDelegate
{
    delegate = theDelegate;
}

- (BOOL) ignoreCase
{
    return (ignoreCase);
}

- (void) setIgnoreCase: (BOOL) flag
{
    ignoreCase = flag;
    [caseCheckBox setIntValue: ignoreCase];
}

- (NSString *) searchString
{
    return (searchString);
}

- (void) setSearchString: (NSString *) aString
{
    if(searchString != nil)
    {
	[searchString release];
	searchString = nil;
    }
    if(aString != nil)
    {
	[aString retain];
	searchString = aString;
    }
    
    if([searchString length] > 0)
    {
	[searchStringField setStringValue: searchString];
    }    
}


@end
