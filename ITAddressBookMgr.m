
/*
 **  ITAddressBookMgr.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: keeps track of the address book data.
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

#import "ITAddressBookMgr.h"

#import <iTerm/Tree.h>
#import <iTerm/iTermTerminalProfileMgr.h>
#import <iTerm/iTermKeyBindingMgr.h>
#import <iTerm/iTermDisplayProfileMgr.h>


#define SAFENODE(n) 		((TreeNode*)((n)?(n):(bookmarks)))


static TreeNode *defaultBookmark = nil;

@implementation ITAddressBookMgr

+ (id)sharedInstance;
{
    static ITAddressBookMgr* shared = nil;
    
    if (!shared)
        shared = [[ITAddressBookMgr alloc] init];
    
    return shared;
}

- (id)init;
{
    self = [super init];
            
    return self;
}

- (void)dealloc;
{
	[bookmarks release];
    [super dealloc];
}

- (void) setBookmarks: (NSDictionary *) aDict
{
	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, aDict);
	bookmarks = [TreeNode treeFromDictionary: aDict];
	[bookmarks setIsLeaf: NO];
	[bookmarks retain];
	
	// make sure we have a default bookmark
	if([self _checkForDefaultBookmark: bookmarks defaultBookmark: &defaultBookmark] == NO)
	{
		NSMutableDictionary *aDict;
		char *userShell, *thisUser;
		NSString *shell;
		NSString *aName;
		TreeNode *childNode;
				
		aDict = [[NSMutableDictionary alloc] init];
		
		// Get the user's default shell
		if((thisUser = getenv("USER")) != NULL) {
			shell = [NSString stringWithFormat: @"login -fp %s", thisUser];
		} else if((userShell = getenv("SHELL")) != NULL) {
			shell = [NSString stringWithCString: userShell];
		} else {
			shell = @"/bin/bash --login";
		}
		
		aName = NSLocalizedStringFromTableInBundle(@"Default",@"iTerm", [NSBundle bundleForClass: [self class]],
												   @"Terminal Profiles");
		[aDict setObject: aName forKey: KEY_NAME];
		[aDict setObject: shell forKey: KEY_COMMAND];
		[aDict setObject: shell forKey: KEY_DESCRIPTION];
		[aDict setObject: NSHomeDirectory() forKey: KEY_WORKING_DIRECTORY];
		[aDict setObject: [[iTermTerminalProfileMgr singleInstance] defaultProfileName] forKey: KEY_TERMINAL_PROFILE];
		[aDict setObject: [[iTermKeyBindingMgr singleInstance] globalProfileName] forKey: KEY_KEYBOARD_PROFILE];
		[aDict setObject: [[iTermDisplayProfileMgr singleInstance] defaultProfileName] forKey: KEY_DISPLAY_PROFILE];
		[aDict setObject: @"Yes" forKey: KEY_DEFAULT_BOOKMARK];

		childNode = [[TreeNode alloc] initWithData: aDict parent: nil children: [NSArray array]];
		[childNode setIsLeaf: YES];
		[bookmarks insertChild: childNode atIndex: [bookmarks numberOfChildren]];
		[aDict release];
		[childNode release];
		
		defaultBookmark = childNode;
		
	}
		
}

- (NSDictionary *) bookmarks
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	
	return ([bookmarks dictionary]);
}

- (BOOL) mayDeleteBookmarkNode: (TreeNode *) aNode
{
	return (![defaultBookmark isDescendantOfNode: aNode]);
}

// Model for NSOutlineView tree structure

- (id) child:(int)index ofItem:(id)item
{	
	return ([SAFENODE(item) childAtIndex: index]);
}

- (BOOL) isExpandable:(id)item
{
	//NSLog(@"%s: %@", __PRETTY_FUNCTION__, item);
	return (![SAFENODE(item) isLeaf]);
}

- (int) numberOfChildrenOfItem:(id)item
{
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	return ([SAFENODE(item) numberOfChildren]);
}

- (id) objectForKey: (id) key inItem: (id) item
{
	NSDictionary *data = [SAFENODE(item) nodeData];
	
	return ([data objectForKey: key]);
}

- (void) setObjectValue: (id) object forKey: (id) key inItem: (id) item
{
	NSMutableDictionary *aDict;
	
	aDict = [[NSMutableDictionary alloc] initWithDictionary: [SAFENODE(item) nodeData]];
	[aDict setObject: object forKey: key];
	[SAFENODE(item) setNodeData: aDict];
	[aDict release];
}

- (void) addFolder: (NSString *) folderName toNode: (TreeNode *) aNode
{
	TreeNode *targetNode, *childNode;
	NSMutableDictionary *aDict;
	
	// NSLog(@"%s: %@", __PRETTY_FUNCTION__, folderName);
	
	targetNode = SAFENODE(aNode);
	
	aDict = [[NSMutableDictionary alloc] init];
	[aDict setObject: folderName forKey: KEY_NAME];
	[aDict setObject: @"" forKey: KEY_DESCRIPTION];
	
	childNode = [[TreeNode alloc] initWithData: aDict parent: nil children: [NSArray array]];
	[childNode setIsLeaf: NO];
	[targetNode insertChild: childNode atIndex: [targetNode numberOfChildren]];
	[aDict release];
	[childNode release];
	
}

- (void) addBookmarkWithData: (NSDictionary *) data toNode: (TreeNode *) aNode;
{
	TreeNode *targetNode, *childNode;
	NSMutableDictionary *aDict;
		
	//NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if(data == nil)
		return;
	
	targetNode = SAFENODE(aNode);
	
	aDict = [[NSMutableDictionary alloc] initWithDictionary: data];
	
	childNode = [[TreeNode alloc] initWithData: aDict parent: nil children: [NSArray array]];
	[childNode setIsLeaf: YES];
	[targetNode insertChild: childNode atIndex: [targetNode numberOfChildren]];
	[aDict release];
	[childNode release];
	

}

- (void) setBookmarkWithData: (NSDictionary *) data forNode: (TreeNode *) aNode
{
	NSMutableDictionary *aDict;
	
	aDict = [[NSMutableDictionary alloc] initWithDictionary: [SAFENODE(aNode) nodeData]];
	[aDict addEntriesFromDictionary: data];
	[SAFENODE(aNode) setNodeData: aDict];
	[aDict release];
}

- (void) deleteBookmarkNode: (TreeNode *) aNode
{
	[aNode removeFromParent];
}

- (TreeNode *) rootNode
{
	return (bookmarks);
}

- (NSDictionary *) defaultBookmarkData
{
	return ([defaultBookmark nodeData]);
}

@end

@implementation ITAddressBookMgr (Private);

- (BOOL) _checkForDefaultBookmark: (TreeNode *) rootNode defaultBookmark: (TreeNode **) aNode
{
	BOOL haveDefaultBookmark = NO;
	NSEnumerator *entryEnumerator;
	NSDictionary *dataDict;
	TreeNode *entry;
	
	dataDict = [rootNode nodeData];

	entryEnumerator = [[rootNode children] objectEnumerator];
	while ((entry = [entryEnumerator nextObject]))
	{
		if([entry isGroup])
			haveDefaultBookmark = [self _checkForDefaultBookmark: entry defaultBookmark: aNode];
		else
		{
			dataDict = [entry nodeData];
			if([[dataDict objectForKey: KEY_DEFAULT_BOOKMARK] isEqualToString: @"Yes"])
			{
				if(aNode)
					*aNode = entry;
				haveDefaultBookmark = YES;
			}			
		}
		if(haveDefaultBookmark)
			break;
	}

	return (haveDefaultBookmark);
}

@end

