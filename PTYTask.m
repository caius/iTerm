// -*- mode:objc -*-
// $Id: PTYTask.m,v 1.52 2008-10-24 05:25:00 yfabian Exp $
//
/*
 **  PTYTask.m
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **	     Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: Implements the interface to the pty session.
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

// Debug option
#define DEBUG_ALLOC           0
#define DEBUG_METHOD_TRACE    0

#include <unistd.h>
#include <util.h>
#include <sys/ioctl.h>

#import <iTerm/PTYTask.h>
#import <iTerm/PreferencePanel.h>

#include <dlfcn.h>
#include <sys/mount.h>
/* Definition stolen from libproc.h */
#define PROC_PIDVNODEPATHINFO 9
//int proc_pidinfo(pid_t pid, int flavor, uint64_t arg,  void *buffer, int buffersize);

struct vinfo_stat {
	uint32_t	vst_dev;	/* [XSI] ID of device containing file */
	uint16_t	vst_mode;	/* [XSI] Mode of file (see below) */
	uint16_t	vst_nlink;	/* [XSI] Number of hard links */
	uint64_t	vst_ino;	/* [XSI] File serial number */
	uid_t		vst_uid;	/* [XSI] User ID of the file */
	gid_t		vst_gid;	/* [XSI] Group ID of the file */
	int64_t		vst_atime;	/* [XSI] Time of last access */
	int64_t		vst_atimensec;	/* nsec of last access */
	int64_t		vst_mtime;	/* [XSI] Last data modification time */
	int64_t		vst_mtimensec;	/* last data modification nsec */
	int64_t		vst_ctime;	/* [XSI] Time of last status change */
	int64_t		vst_ctimensec;	/* nsec of last status change */
	int64_t		vst_birthtime;	/*  File creation time(birth)  */
	int64_t		vst_birthtimensec;	/* nsec of File creation time */
	off_t		vst_size;	/* [XSI] file size, in bytes */
	int64_t		vst_blocks;	/* [XSI] blocks allocated for file */
	int32_t		vst_blksize;	/* [XSI] optimal blocksize for I/O */
	uint32_t	vst_flags;	/* user defined flags for file */
	uint32_t	vst_gen;	/* file generation number */
	uint32_t	vst_rdev;	/* [XSI] Device ID */
	int64_t		vst_qspare[2];	/* RESERVED: DO NOT USE! */
};

struct vnode_info {
	struct vinfo_stat	vi_stat;
	int			vi_type;
	fsid_t			vi_fsid;
	int			vi_pad;
};

struct vnode_info_path {
	struct vnode_info	vip_vi;
	char vip_path[MAXPATHLEN];  /* tail end of it  */
};

struct proc_vnodepathinfo {
	struct vnode_info_path pvi_cdir;
	struct vnode_info_path pvi_rdir;
};

@implementation PTYTask

#define CTRLKEY(c)   ((c)-'A'+1)

static void setup_tty_param(
		struct termios *term,
		struct winsize *win,
		int width,
		int height)
{
	memset(term, 0, sizeof(struct termios));
	memset(win, 0, sizeof(struct winsize));

	term->c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
	term->c_oflag = OPOST | ONLCR;
	term->c_cflag = CREAD | CS8 | HUPCL;
	term->c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;

	term->c_cc[VEOF]	  = CTRLKEY('D');
	term->c_cc[VEOL]	  = -1;
	term->c_cc[VEOL2]	  = -1;
	term->c_cc[VERASE]	  = 0x7f;	// DEL
	term->c_cc[VWERASE]   = CTRLKEY('W');
	term->c_cc[VKILL]	  = CTRLKEY('U');
	term->c_cc[VREPRINT]  = CTRLKEY('R');
	term->c_cc[VINTR]	  = CTRLKEY('C');
	term->c_cc[VQUIT]	  = 0x1c;	// Control+backslash
	term->c_cc[VSUSP]	  = CTRLKEY('Z');
	term->c_cc[VDSUSP]	  = CTRLKEY('Y');
	term->c_cc[VSTART]	  = CTRLKEY('Q');
	term->c_cc[VSTOP]	  = CTRLKEY('S');
	term->c_cc[VLNEXT]	  = -1;
	term->c_cc[VDISCARD]  = -1;
	term->c_cc[VMIN]	  = 1;
	term->c_cc[VTIME]	  = 0;
	term->c_cc[VSTATUS]   = -1;

	term->c_ispeed = B38400;
	term->c_ospeed = B38400;

	win->ws_row = height;
	win->ws_col = width;
	win->ws_xpixel = 0;
	win->ws_ypixel = 0;
}

- (id)init
{
#if DEBUG_ALLOC
	NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif
	if ([super init] == nil)
		return nil;

	PID = (pid_t)-1;
	STATUS = 0;
	DELEGATEOBJECT = nil;
	FILDES = -1;
	TTY = nil;
	LOG_PATH = nil;
	LOG_HANDLE = nil;
	hasOutput = NO;
	writeTimer = nil;
	writeBuffer = [[NSMutableData alloc] init];

	return self;
}

- (void)dealloc
{
#if DEBUG_ALLOC
	NSLog(@"%s: 0x%x", __PRETTY_FUNCTION__, self);
#endif
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	if (writeTimer) {
		[writeTimer invalidate]; [writeTimer release]; writeTimer = nil;
	}
	

	if (PID > 0)
		kill(PID, SIGKILL);

	if (FILDES >= 0)
		close(FILDES);

	[writeBuffer release];
	[dataHandle release];
	[TTY release];
	[PATH release];
	[super dealloc];
}

- (void)launchWithPath:(NSString *)progpath
			 arguments:(NSArray *)args
		   environment:(NSDictionary *)env
				 width:(int)width
				height:(int)height
{
	struct termios term;
	struct winsize win;
	char ttyname[PATH_MAX];
	int sts;

	PATH = [progpath copy];

#if DEBUG_METHOD_TRACE
	NSLog(@"%s(%d):-[launchWithPath:%@ arguments:%@ environment:%@ width:%d height:%d", __FILE__, __LINE__, progpath, args, env, width, height);
#endif
		
	
	setup_tty_param(&term, &win, width, height);
	PID = forkpty(&FILDES, ttyname, &term, &win);
	if (PID == (pid_t)0) {
		const char *path = [[progpath stringByStandardizingPath] cString];
		int max = args == nil ? 0: [args count];
		const char *argv[max + 2];

		argv[0] = path;
		if (args != nil) {
			int i;
			for (i = 0; i < max; ++i)
				argv[i + 1] = [[args objectAtIndex:i] cString];
		}
		argv[max + 1] = NULL;

		if (env != nil ) {
			NSArray *keys = [env allKeys];
			int i, max = [keys count];
			for (i = 0; i < max; ++i) {
				NSString *key, *value;
				key = [keys objectAtIndex:i];
				value = [env objectForKey:key];
				if (key != nil && value != nil) 
					setenv([key cString], [value cString], 1);
			}
		}
		chdir([[[env objectForKey:@"PWD"] stringByExpandingTildeInPath] cString]);
		sts = execvp(path, (char * const *) argv);

		/* exec error */
		fprintf(stdout, "## exec failed ##\n");
		fprintf(stdout, "%s %s\n", path, strerror(errno));

		sleep(1);
		_exit(-1);
	}
	else if (PID < (pid_t)0) {
		NSLog(@"%@ %s", progpath, strerror(errno));
		NSRunCriticalAlertPanel(NSLocalizedStringFromTableInBundle(@"Unable to Fork!",@"iTerm", [NSBundle bundleForClass: [self class]], @"Fork Error"),
						NSLocalizedStringFromTableInBundle(@"iTerm cannot launch the program for this session.",@"iTerm", [NSBundle bundleForClass: [self class]], @"Fork Error"),
						NSLocalizedStringFromTableInBundle(@"Close Session",@"iTerm", [NSBundle bundleForClass: [self class]], @"Fork Error"),
						nil,nil);
		if([DELEGATEOBJECT respondsToSelector:@selector(closeSession:)]) {
			[DELEGATEOBJECT performSelector:@selector(closeSession:) withObject:DELEGATEOBJECT];
		}
		return;
	}

	TTY = [[NSString stringWithCString:ttyname] retain];
	NSParameterAssert(TTY != nil);

	fcntl(FILDES,F_SETFL,O_NONBLOCK);
	dataHandle = [[NSFileHandle alloc] initWithFileDescriptor:FILDES];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(processRead)
			name:NSFileHandleDataAvailableNotification object:dataHandle];
	[dataHandle waitForDataInBackgroundAndNotify];
}

- (void)processRead
{
#if DEBUG_METHOD_TRACE
	NSLog(@"%s(%d):+[PTYTask processRead]", __FILE__, __LINE__);
#endif

	char buf[2048];
	ssize_t bytesread;
	unsigned int length = 0;

	/* Read as much as possible (non-blocking) */
	while((bytesread = read(FILDES, buf, sizeof(buf))) > 0) {
		hasOutput = YES;
		/* Push data to terminal */
		[self readTask:buf length:bytesread];
		length += bytesread;
	}

	/* No more data for us? */
	if(length == 0 || (bytesread < 0 && !(errno == EAGAIN || errno == EINTR))) {
		[self brokenPipe];
		return;
	}	
	
	/* Ask for notifications when more data is available */
	[dataHandle waitForDataInBackgroundAndNotify];
}

- (void)processWrite
{
#if DEBUG_METHOD_TRACE
	NSLog(@"%s(%d):-[PTYTask processWrite] with writeBuffer length %d",
			__FILE__, __LINE__, [writeBuffer length]);
#endif

	/* Write as much of writeBuffer as possible (non-blocking) */
	const char* ptr = [writeBuffer mutableBytes];
	unsigned int toWrite = [writeBuffer length];
	while(toWrite > 0) {
		ssize_t written = write(FILDES, ptr, toWrite);
		if(written < 0) {
			break;
		}
		ptr += written;
		toWrite -= written;
	}

	/* Create a new data object for the leftover bytes */
	NSMutableData* temp = [[NSMutableData alloc] initWithCapacity:toWrite];
	[temp appendBytes:ptr length:toWrite];
	[writeBuffer release];
	writeBuffer = temp;

	/* Remove the old timer */
	if(writeTimer) {
		[writeTimer autorelease];
		writeTimer = nil;
	}

	/* If there's more to write, create a timer to do so */
	if([writeBuffer length] > 0) {
		writeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.001
				target:self selector:@selector(processWrite)
				userInfo:nil repeats:NO] retain];
	}
}

- (BOOL)hasOutput
{
	return hasOutput;
}

- (void)setDelegate:(id)object
{
    DELEGATEOBJECT = object;
}

- (id)delegate
{
    return DELEGATEOBJECT;
}

- (void)readTask:(char*)data length:(unsigned int)length;
{
#if DEBUG_METHOD_TRACE
	NSLog(@"%s(%d):-[PTYTask readTask:%@]", __FILE__, __LINE__, data);
#endif
	if([self logging]) {
		[LOG_HANDLE writeData:[NSData dataWithBytesNoCopy:data length:length freeWhenDone:NO]];
	}
	
	// forward the data to our delegate
	if([DELEGATEOBJECT respondsToSelector:@selector(readTask:length:)]) {
		[DELEGATEOBJECT performSelector:@selector(readTask:length:)
				withObject:(id)data withObject:(id)length];
	}
}

- (void)writeTask:(NSData*)data
{
#if DEBUG_METHOD_TRACE
	NSLog(@"%s(%d):-[PTYTask writeTask:%@]", __FILE__, __LINE__, data);
#endif

	/* Write as much as we can now through the non-blocking pipe */
	[writeBuffer appendData:data];
	[self processWrite];
}

- (void)brokenPipe
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    if([DELEGATEOBJECT respondsToSelector:@selector(brokenPipe)]) {
        [DELEGATEOBJECT brokenPipe];
    }
}

- (void)sendSignal:(int)signo
{
    if (PID >= 0)
		kill(PID, signo);
}

- (void)setWidth:(int)width height:(int)height
{
    struct winsize winsize;
	
    if(FILDES == -1)
		return;
	
    ioctl(FILDES, TIOCGWINSZ, &winsize);
	if (winsize.ws_col != width || winsize.ws_row != height) {
		winsize.ws_col = width;
		winsize.ws_row = height;
		ioctl(FILDES, TIOCSWINSZ, &winsize);
	}
}

- (pid_t)pid
{
    return PID;
}

- (int)wait
{
    if (PID >= 0) 
		waitpid(PID, &STATUS, 0);
	
    return STATUS;
}

- (void)stop
{
    [self sendSignal:SIGKILL];
	usleep(10000);
	if(FILDES >= 0)
		close(FILDES);
    FILDES = -1;
    
    [self wait];
}

- (int)status
{
    return STATUS;
}

- (NSString *)tty
{
    return TTY;
}

- (NSString *)path
{
    return PATH;
}

- (BOOL)loggingStartWithPath:(NSString *)path
{
    [LOG_PATH autorelease];
    LOG_PATH = [[path stringByStandardizingPath ] copy];
	
    [LOG_HANDLE autorelease];
    LOG_HANDLE = [NSFileHandle fileHandleForWritingAtPath:LOG_PATH];
    if (LOG_HANDLE == nil) {
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm createFileAtPath:LOG_PATH
					contents:nil
				  attributes:nil];
		LOG_HANDLE = [NSFileHandle fileHandleForWritingAtPath:LOG_PATH];
    }
    [LOG_HANDLE retain];
    [LOG_HANDLE seekToEndOfFile];
	
    return LOG_HANDLE == nil ? NO:YES;
}

- (void)loggingStop
{
    [LOG_HANDLE closeFile];
	
    [LOG_PATH autorelease];
    [LOG_HANDLE autorelease];
    LOG_PATH = nil;
    LOG_HANDLE = nil;
}

- (BOOL)logging
{
    return LOG_HANDLE == nil ? NO : YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"PTYTask(pid %d, fildes %d)", PID, FILDES];
}

- (NSString *)getWorkingDirectory
{
    static int loadedAttempted = 0;
    static int(*proc_pidinfo)(pid_t pid, int flavor, uint64_t arg,  void *buffer, int buffersize) = NULL;
    if (!proc_pidinfo) {
        if (loadedAttempted) {
            /* Hmm, we can't find the symbols that we need... so lets not try */
            return nil;
        }
        loadedAttempted = 1;

        /* We need to load the function first */
        void* handle = dlopen("libSystem.B.dylib", RTLD_LAZY);
        if (!handle)
            return nil;
        proc_pidinfo = dlsym(handle, "proc_pidinfo");
        if (!proc_pidinfo)
            return nil;
    }

    struct proc_vnodepathinfo vpi;
    int ret;
    /* This only works if the child process is owned by our uid */
    ret = proc_pidinfo(PID, PROC_PIDVNODEPATHINFO, 0, &vpi, sizeof(vpi));
    if (ret <= 0) {
        /* An error occured */
        return nil;
    } else if (ret != sizeof(vpi)) {
        /* Now this is very bad... */
        return nil;
    } else {
        /* All is good */
        NSString *ret = [NSString stringWithUTF8String:vpi.pvi_cdir.vip_path];
        return ret;
    }
}

@end

