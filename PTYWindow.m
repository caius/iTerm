/* -*- mode:objc -*- */
/* $Id: PTYWindow.m,v 1.2 2003-02-12 07:52:47 ujwal Exp $ */
/* Incorporated into iTerm.app by Ujwal S. Sathyam */
/*
 **  PTYWindow.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: NSWindow subclass. Implements transparency.
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


#import "PTYWindow.h"

#define DEBUG_METHOD_TRACE	0

extern void _NSSetWindowOpacity(int windowNumber, BOOL isOpaque);

@implementation PTYWindow

- (float)_transparency 
{
    return 0.999999; 
}

- initWithContentRect:(NSRect)contentRect
	    styleMask:(unsigned int)aStyle
	      backing:(NSBackingStoreType)bufferingType 
		defer:(BOOL)flag
{
#if DEBUG_METHOD_TRACE
    NSLog(@"%s(%d):+[PTYWindow initWithContentRect]",
          __FILE__, __LINE__);
#endif

    if ((self = [super initWithContentRect:contentRect
				 styleMask:aStyle
				   backing:bufferingType 
				     defer:flag])
	!= nil) 
    {
        _NSSetWindowOpacity([self windowNumber], 0);
    }
    return self;
}

@end
