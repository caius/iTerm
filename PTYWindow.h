/* -*- mode:objc -*- */
/* Japanese Terminal Program    2001 Copyright(C) Kiichi Kusama */
/* $Id: PTYWindow.h,v 1.1 2002-12-07 20:03:48 ujwal Exp $ */
/* Incorporated into iTerm.app by Ujwal S. Sathyam */


#import <Cocoa/Cocoa.h>

@interface PTYWindow : NSWindow 
{
}

- (float)_transparency;
- initWithContentRect:(NSRect)contentRect 
            styleMask:(unsigned int)aStyle 
	      backing:(NSBackingStoreType)bufferingType 
		defer:(BOOL)flag;
@end
