/*
 **  iTermScriptCommand.m
 **
 **  Copyright (c) 2003
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: Implements Applescript support for iTerm.
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


#import "iTermScriptCommand.h"
#import "MainMenu.h"


@implementation iTermScriptCommand

- (id)scriptError:(int)errorNumber description:(NSString *)description
{
    NSLog(@"Script error!");
    [self setScriptErrorNumber: errorNumber];
    [self setScriptErrorString: description];
    return nil;
}

- (id)performDefaultImplementation
{

    if([[[self commandDescription] commandName] isEqualToString: @"LaunchSession"])
    {
	NSArray *abArray;
	NSString *abSessionName;
	int abSessionTarget, i;
	BOOL aBool = NO;
	MainMenu *delegate;

	delegate = (MainMenu *)[NSApp delegate];

	// get the name of the session to be launched
	abSessionName = [self directParameter];

	// search for the session in the addressbook
	abArray = [delegate addressBookNames];
	for (i = 0; i < [abArray count]; i++)
	{
	    if([[abArray objectAtIndex: i] caseInsensitiveCompare: abSessionName] == NSOrderedSame)
	    {
		aBool = YES;
		break;
	    }
	}

	// execute the session in the appropriate target
	if(aBool)
	{
	    abSessionTarget = [[[self evaluatedArguments] objectForKey: @"target"] intValue];
	    if(abSessionTarget == 'TAB ')
		[delegate executeABCommandAtIndex: i inTerminal: [delegate frontPseudoTerminal]];
	    else if (abSessionTarget == 'TERM')
		[delegate executeABCommandAtIndex: i inTerminal: nil];
	}
	else if([abSessionName caseInsensitiveCompare: @"Default Session"] == NSOrderedSame)
	{
	    // Open a default session
	    abSessionTarget = [[[self evaluatedArguments] objectForKey: @"target"] intValue];
	    if(abSessionTarget == 'TAB ')
		[delegate newSession: self];
	    else if (abSessionTarget == 'TERM')
		[delegate newWindow: self];
	    
	}
	
    }

    return (nil);
}


@end
