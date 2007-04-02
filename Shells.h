// -*- mode:objc -*-
// $Id: Shells.h,v 1.3 2007-04-02 17:48:45 dnedrow Exp $
//
/*!
	@class Shells
	
	@abstract This class encapsulates access to /etc/shells
	
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

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@interface Shells : NSObject {

}

+ (id) sharedInstance;

/*!
	@function getShells
	@abstract Gets the list of shells
	@discussion This method is used to retrieve shells listed in /etc/shells.
	@return NSSet of shells. Caller should check set size.
*/
- (NSSet *) getShells;

@end
