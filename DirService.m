//
//  DirService.m
//  iTerm
//
//  Created by David Nedrow on 3/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "DirService.h"

@interface DirService (PrivateMethods )
tDirReference     dsRef = nil;
tDirNodeReference dsSearchNodeRef = nil;
- (void) cleanup;
@end

@implementation DirService

+ (id) sharedInstance {
	static DirService* shared = nil;
	if(!shared)
		shared = [DirService new];
	return shared;
}

- (id) init {
	tDirStatus        dsStatus;
	if ((self = [super init])) {
		
		dsStatus = dsOpenDirService( &dsRef );
		if( dsStatus != eDSNoErr ) {
			[self cleanup];
			return nil;
		}
/*		dsStatus = OpenSearchNode( dsRef, &dsSearchNodeRef );
		if( dsStatus != eDSNoErr ) {
			[self cleanup];
			return nil;
		}		*/
		return self;
	} else {
		return nil;
	}
}

- (void) dealloc {
	[self cleanup];
	[super dealloc];
}

- (void) cleanup {
	if (dsSearchNodeRef) dsCloseDirNode( dsSearchNodeRef );
	dsSearchNodeRef = 0;
	if (dsRef) dsCloseDirService(dsRef);
	dsRef = 0;
}

- (void) getNode {
	
}

@end
