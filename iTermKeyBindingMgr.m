/*
 **  iTermKeyBindingMgr.m
 **
 **  Copyright (c) 2002, 2003, 2004
 **
 **  Author: Ujwal S. Sathyam
 **
 **  Project: iTerm
 **
 **  Description: implements the key binding manager.
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

#import <iTerm/iTermKeyBindingMgr.h>

static iTermKeyBindingMgr *singleInstance = nil;

@implementation iTermKeyBindingMgr

+ (id) singleInstance;
{
	if(singleInstance == nil)
	{
		singleInstance = [[iTermKeyBindingMgr alloc] init];
	}
	
	return (singleInstance);
}

- (id) init
{
	self = [super init];
	
	if(!self)
		return (nil);
	
	profiles = [[NSMutableDictionary alloc] init];

	return (self);
}

- (void) dealloc
{
	[profiles release];
	[super dealloc];
}

- (NSDictionary *) profiles
{
	return (profiles);
}

- (void) setProfiles: (NSMutableDictionary *) aDict
{
	if(aDict != nil)
		[profiles setDictionary: aDict];
}

- (NSDictionary *) currentProfile
{
	return (currentProfile);
}

- (void) setCurrentProfile: (NSMutableDictionary *) aDict
{
	currentProfile = aDict;
}

- (int) actionForKeyEvent: (NSEvent *) anEvent escapeSequence: (NSString **) escapeSequence hexCode: (int *) hexCode
{
	return (0);
}

- (int) entryAtIndex: (int) index key: (NSString *) unmodkeystr modifiers: (int *) modifiers
{
	return (0);
}


@end
