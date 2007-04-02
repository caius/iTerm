// -*- mode:objc -*-
// $Id: iTermSecurityMgr.m,v 1.1 2007-04-02 17:51:12 dnedrow Exp $
//
/*!
	@class iTermSecurityMgr
	
	This class is used for various security related activities.
	
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

#import "iTermSecurityMgr.h"

/*!
	@interface iTermSecurityMgr (PrivateMethods )
	@abstract Category extends iTermSecurityMgr with private methods
	@discussion Any methods that should not be exposed to the 'outside world'
	by being included in the class header file should be declared here and 
	implemented in the implementation section.
 */
@interface
	iTermSecurityMgr (PrivateMethods )

  // - (void) examplePrivateMethodDeclaration;
@end

@implementation iTermSecurityMgr

+ (id) sharedInstance {
	static iTermSecurityMgr* shared = nil;
	if(!shared)
		shared = [iTermSecurityMgr new];
	return shared;
}

- (id) init {
	if ((self = [super init])) {
		return self;
	} else {
		return nil;
	}
}

- (void) dealloc {
	[super dealloc];
}

/*!
	@function isShellValid
	@abstract Determine whether the user shell is valid
	@discussion This method is used to determine whether the shell defined via
	NetInfo is also listed in /etc/shells.
	@return TRUE if user shell in NetInfo is listed in /etc/shells
 */
- (BOOL) isShellValid {
	NSSet *shellSet = [[Shells sharedInstance] getShells];
	NSString *shell;

	// No shells? No go.
	if (([shellSet count] <= 0)) {
		return (NO);
	}

	NSEnumerator *nse = [shellSet objectEnumerator];
	
	while((shell = [nse nextObject])) {
		NSLog(shell);
	}
	
	return YES;
}

@end
