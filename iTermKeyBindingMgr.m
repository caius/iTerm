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
	NSEnumerator *keyEnumerator;
	
	if(aDict != nil)
		[profiles setDictionary: aDict];
	keyEnumerator = [profiles keyEnumerator];
	currentProfile = [profiles objectForKey: [keyEnumerator nextObject]];
	if(currentProfile == nil)
	{
		currentProfile = [[NSMutableDictionary alloc] init];
		[profiles setObject: currentProfile forKey: [NSString stringWithFormat: @"Profile %d", [profiles count]]];
		[currentProfile release];
	}
}

- (NSDictionary *) currentProfile
{
	return (currentProfile);
}

- (void) setCurrentProfile: (NSMutableDictionary *) aDict
{
	currentProfile = aDict;
}

- (void) addProfileWithName: (NSString *) aString
{
	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, aString);
	if([aString length] > 0)
	{
		NSEnumerator *keyEnumerator;
		NSDictionary *firstProfile, *newProfile;
		
		keyEnumerator = [profiles keyEnumerator];
		firstProfile = [profiles objectForKey: [keyEnumerator nextObject]];
		newProfile = [[NSMutableDictionary alloc] initWithDictionary: firstProfile];
		[profiles setObject: newProfile forKey: aString];
		[newProfile release];		
	}
}

- (void) deleteProfileWithName: (NSString *) aString
{
	if([aString length] > 0)
	{
		[profiles removeObjectForKey: aString];
	}
}

- (int) numberOfEntriesInProfile: (NSString *) profileName
{
	NSDictionary *aProfile;
	
	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, profileName);
	
	if([profileName length] > 0)
	{
		aProfile = [profiles objectForKey: profileName];
		return ([aProfile count]);
	}
	else
		return (0);
}


- (void) addEntryForKeyCode: (unsigned int) hexCode 
				  modifiers: (unsigned int) modifiers
					 action: (unsigned int) action
					   text: (NSString *) text
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void) addEntryForKey: (unsigned int) key 
			  modifiers: (unsigned int) modifiers
				 action: (unsigned int) action
				   text: (NSString *) text
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
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
