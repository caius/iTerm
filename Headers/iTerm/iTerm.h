/*
 **  iTerm.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Sathyam
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: header file for iTerm.app.
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

#ifndef _ITERM_H_
#define _ITERM_H_

#define USE_CUSTOM_LAYOUT	0	// for custom typesetter and layout in text system


#define USE_CUSTOM_DRAWING	1

#if USE_CUSTOM_DRAWING
#define DEBUG_USE_ARRAY		1
#define DEBUG_USE_BUFFER	0
#else
#define DEBUG_USE_ARRAY		0
#define DEBUG_USE_BUFFER	1
#endif


#define NSLogRect(aRect)	NSLog(@"Rect = %f,%f,%f,%f", (aRect).origin.x, (aRect).origin.y, (aRect).size.width, (aRect).size.height)

#endif // _ITERM_H_
