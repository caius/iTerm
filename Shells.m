// -*- mode:objc -*-
// $Id: Shells.m,v 1.2 2007-04-02 16:30:20 dnedrow Exp $
//
/*!
@class Shells

This class encapsulates access to /etc/shells

Copyright (c) 2007

Author: David E. Nedrow

Project: iTerm

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "Shells.h"

/*!
@interface Shells (PrivateMethods )
@abstract Category extends Shells with private methods
@discussion Any methods that should not be exposed to the 'outside world'
by being included in the class header file should be declared here and 
implemented in the implementation section.
*/
@interface Shells (PrivateMethods )
NSString *shellsPath = @"/etc/shells";
NSString *shells;
- (BOOL) loadShells;
@end

@implementation Shells

+ (id) sharedInstance {
	static Shells* shared = nil;
	if(!shared)
		shared = [Shells new];
	return shared;
}

- (id) init {
	if ((self = [super init])) {
		[self loadShells];
		return self;
	} else {
		return nil;
	}
}

- (void) dealloc {
	[super dealloc];
}

- (BOOL) loadShells {
	
	shells = [NSString stringWithContentsOfFile:shellsPath];
	if (!shells) return (NO);
	
	return (YES);
}

- (NSSet *) getShells {
	if (!shells) {
		return (NULL);
	}

	NSArray *shellArray = [shells componentsSeparatedByString:@"\n"];
	NSEnumerator *shellEnum = [shellArray objectEnumerator];
	NSMutableSet *shellSet;
	NSString *shell;
	
	while((shell = [shellEnum nextObject])) {
		// Get rid of commented lines
		if (![shell hasPrefix:@"#"]) {
			[shellSet addObject:shell];
		}
	}
	
	return shellSet;
}

@end
