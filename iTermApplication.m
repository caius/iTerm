//
//  iTermApplication.m
//  iTerm
//
//  Created by Ujwal Setlur on Sat Apr 10 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "iTermApplication.h"
#import <iTerm/iTermController.h>
#import <iTerm/PTYWindow.h>
#import <iTerm/PseudoTerminal.h>
#import <iTerm/PTYSession.h>


@implementation iTermApplication

// override to catch key mappings with command key down
- (void)sendEvent:(NSEvent *)anEvent
{
	id aWindow;
	PseudoTerminal *currentTerminal;
	PTYSession *currentSession;
	
	if([anEvent type] == NSKeyDown && ([anEvent modifierFlags] & NSCommandKeyMask))
	{
		
		aWindow = [self keyWindow];
		
		if([aWindow isKindOfClass: [PTYWindow class]])
		{
						
			currentTerminal = [[iTermController sharedInstance] currentTerminal];
			currentSession = [currentTerminal currentSession];
			
			if([currentSession hasKeyMappingForEvent: anEvent])
				[currentSession keyDown: anEvent];
			else
				[super sendEvent: anEvent];
		}
	}
	else
		[super sendEvent: anEvent];
}

@end
