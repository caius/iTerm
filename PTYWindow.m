/* -*- mode:objc -*- */
/* Japanese Terminal Program    2001 Copyright(C) Kiichi Kusama */
/* $Id: PTYWindow.m,v 1.1 2002-12-07 20:03:48 ujwal Exp $ */
/* Incorporated into iTerm.app by Ujwal S. Sathyam */

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
