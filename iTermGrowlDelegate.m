// -*- mode:objc -*-
// $Id: iTermGrowlDelegate.m,v 1.1 2006-08-03 01:49:15 dnedrow Exp $
//
/*
 **  iTermGrowlDelegate.m
 **
 **  Copyright (c) 2006
 **
 **  Author: David E. Nedrow
 **
 **  Project: iTerm
 **
 **  Description: Implements the delegate for Growl notifications.
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

#import "iTermGrowlDelegate.h"

@implementation iTermGrowlDelegate

+ (id) sharedInstance {
	static iTermGrowlDelegate* shared = nil;
	if(!shared)
		shared = [iTermGrowlDelegate new];
	return shared;
}

- (id) init {
	if ((self = [super init])) {
		
		notifications = [NSArray arrayWithObjects:@"Bells",
			@"Broken Pipes",
			@"Miscellaneous",
			@"Idle",
			@"New Output",
			nil];
		
		[GrowlApplicationBridge setGrowlDelegate:self];
		[self registrationDictionaryForGrowl];

		return self;
	} else {
		return nil;
	}
}

- (void) dealloc {
	[super dealloc];
}

- (void) growlNotify: (NSString *) title {
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermGrowlDelegate growlTest]",  __FILE__, __LINE__);
#endif
	[GrowlApplicationBridge 
		notifyWithTitle:title
			description:nil
	   notificationName:DefaultNotificationName
			   iconData:nil
			   priority:0
			   isSticky:NO
		   clickContext:nil];
}

- (void) growlNotify: (NSString *) title withDescription: (NSString *) description {
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermGrowlDelegate growlTest]",  __FILE__, __LINE__);
#endif
	[GrowlApplicationBridge 
		notifyWithTitle:title
			description:description
	   notificationName:DefaultNotificationName
			   iconData:nil
			   priority:0
			   isSticky:NO
		   clickContext:nil];
}

- (void) growlNotify: (NSString *) title withDescription: (NSString *) description andNotification: (NSString *) notification {
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):-[iTermGrowlDelegate growlTest]",  __FILE__, __LINE__);
#endif
	[GrowlApplicationBridge 
		notifyWithTitle:title
			description:description
	   notificationName:notification
			   iconData:nil
			   priority:0
			   isSticky:NO
		   clickContext:nil];
}

- (NSDictionary *) registrationDictionaryForGrowl {
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		GrowlAppName, GROWL_APP_NAME,
		notifications, GROWL_NOTIFICATIONS_ALL,
		notifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	
	return regDict;
}

@end
