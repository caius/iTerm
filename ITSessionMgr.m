
/*
 **  ITSessionMgr.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: manages an array of sessions.
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

#import "ITSessionMgr.h"
#import "PTYSession.h"

@implementation ITSessionMgr

- (id)init;
{
    self = [super init];
    
    _sessionList = [[NSMutableArray alloc] init];
    _threadLock = [[NSLock alloc] init];
    
    return self;
}

- (void)dealloc;
{
    
    if (_sessionList) {
        [_threadLock lock];

        int i, cnt = [_sessionList count];
        
        for(i = 0; i < cnt; i++)
            [[_sessionList objectAtIndex: i] terminate];
        
        [_sessionList release];
        _sessionList = nil;
        
        [_threadLock unlock];
        [_threadLock release];
            
        [_currentSession release];
    }
    [super dealloc];
}

- (int)currentSessionIndex;
{
    return _currentSessionIndex;
}

- (PTYSession *)currentSession;
{
    return _currentSession;
}

- (void)setCurrentSession:(PTYSession *)session;
{
    [_threadLock lock];
    
    _currentSessionIndex = [_sessionList indexOfObject:session];
    
    if (_currentSessionIndex != NSNotFound)
    {
        [_currentSession autorelease];
        _currentSession = [session retain];    
    }
    [_threadLock unlock];
    
}

- (void)setCurrentSessionIndex:(int)index;
{
    [_threadLock lock];
    
    if (index >= 0 && index < [_sessionList count])
        _currentSessionIndex = index;
    //[self setCurrentSession:[self sessionAtIndex:index]];
    [_threadLock unlock];
    
}

- (NSArray*)sessionList;
{
    return _sessionList;
}

- (void)removeSession:(PTYSession*)session;
{
    [_threadLock lock];
    int removeIndex = [_sessionList indexOfObject:session];
    if (removeIndex != NSNotFound)
    {
        [_sessionList removeObjectAtIndex:removeIndex];

        if (removeIndex >= [_sessionList count])
            removeIndex = [_sessionList count] - 1;
        
        _currentSessionIndex = removeIndex;
    }
    [_threadLock unlock];
}

- (void)insertSession:(PTYSession*)session atIndex:(int)index
{
    [_threadLock lock];
    if (index > [_sessionList count])
        index = [_sessionList count];
    
    [_sessionList insertObject:session atIndex:index];

    if (_currentSessionIndex >= index)
        _currentSessionIndex = _currentSessionIndex+1;
    
    [_threadLock unlock];
}

- (unsigned)numberOfSessions;
{
    [_threadLock lock];
    int n = [_sessionList count];
    [_threadLock unlock];
    
    return n;
}

- (void)replaceSessionAtIndex:(int)index withSession:(PTYSession*)session;
{
    [_threadLock lock];

    [_sessionList replaceObjectAtIndex:index withObject:session];
    
    [_threadLock unlock];
}

- (PTYSession*)sessionAtIndex:(unsigned)index;
{
    if (index >= 0 && index < [_sessionList count])
        return [_sessionList objectAtIndex:index];
    
    return nil;
}

- (int)indexOfSession: (PTYSession *)aSession;
{
	return ([_sessionList indexOfObject: aSession]);
}


- (BOOL)containsSession:(PTYSession *)session;
{
    return [_sessionList containsObject:session];
}

- (void) acquireLock
{
	[_threadLock lock];
}

- (void) releaseLock
{
	[_threadLock unlock];
}


@end
