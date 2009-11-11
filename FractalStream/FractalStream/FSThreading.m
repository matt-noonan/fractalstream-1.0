//
//  FSThreading.m
//  FractalStream
//
//  Created by Matthew Noonan on 1/21/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSThreading.h"


#ifdef FS_USE_THREADING
#ifdef FS_USE_NSOPERATION
	@implementation FSOperation
	@end
	
	@implementation FSOperationQueue
	- (void) go { return; }
	@end
#else

	@implementation FSOperation
	- (id) init {
		self = [super init];
		cancelled = NO;
		owner = nil;
		token = nil;
		return self;
	}
	- (void) doMain {
		[self main];
	}
	- (void) setOwner: (id) ow { owner = ow; }
	- (void) main { return; }
	- (volatile BOOL) isCancelled { 
		return (cancelled || [owner isCancelled])?  YES : NO;
	}
	- (void) cancel { cancelled = YES; }
	- (void) setToken: (NSLock*) tok andCounter: (NSLock*) count { token = tok; counter = count; }
	@end
	
	
	@implementation FSOperationQueue
	- (id) init {
		int i;
		self = [super init];
		queue = [[NSMutableArray alloc] init];
		lock = [[NSConditionLock alloc] initWithCondition: 0];
		stop = [[NSLock alloc] init];
		[stop lock];
		for(i = 0; i < NSOperationQueueDefaultMaxConcurrentOperationCount; i++) 
			[NSThread detachNewThreadSelector: @selector(runQueue) toTarget: self withObject: nil];
		cancelled = NO;
		return self;
	}
	
	- (void) addOperation: (FSOperation*) Op {
		[lock lock];
		cancelled = NO;
		[Op setOwner: self];
		[queue addObject: Op];
		[lock unlockWithCondition: 1];
	}
	
	- (id) getOperation {
		id ob;
		if(cancelled || ([queue count] == 0)) return nil;
		[lock lock];
		ob = [[queue objectAtIndex: 0] retain];
		[queue removeObjectAtIndex: 0];
		[lock unlockWithCondition: ([queue count] > 0)? 1 : 0];
		return ob;
	}
	
	- (void) cancelAllOperations {
		NSEnumerator* en;
		id ob;
		cancelled = YES;
		[lock lock];
		en = [queue objectEnumerator];
		while(ob = [en nextObject]) [ob cancel];
		[lock unlockWithCondition: ([queue count] > 0)? 1 : 0];
	}
	
	- (void) dealloc { 
		[stop unlock];
		[self cancelAllOperations];
		[lock release];
		[super dealloc];
	}
	
	- (void) go { 
		cancelled = NO;
	}
	
	- (volatile BOOL) isCancelled { return cancelled; }
	
	- (void) runQueue {
		id ob;
		NSAutoreleasePool* pool;
		pool = [[NSAutoreleasePool alloc] init];
		while([stop tryLock] == NO) {
			ob = [self getOperation];
			while(ob == nil) { [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.25]]; ob = [self getOperation]; }
			[ob doMain];
			[ob release];
		}
		[stop unlock];
		[pool release];
	}
	
	- (void) setMaxConcurrentOperationCount: (int) count { return; }
	@end

#endif
#else
	
	@implementation FSOperation
	- (void) doMain {
		[self main];
		[owner performSelectorOnMainThread: @selector(go) withObject: nil waitUntilDone: NO];
	}
	- (void) setOwner: (id) ow { owner = ow; }
	- (void) main { return; }
	- (BOOL) isCancelled { return NO; }
	@end
	
	@implementation FSOperationQueue
	- (id) init {
		self = [super init];
		opArray = [[NSMutableArray alloc] init];
		op = nil;
		return self;
	}
	
	- (void) addOperation: (FSOperation*) Op {
		[Op setOwner: self];
		[opArray addObject: Op];
	}
	
	- (void) cancelAllOperations {
		[opArray release];
		opArray = [[NSMutableArray alloc] init];
		op = nil;
	}
	
	- (void) go {
		if(op) [opArray removeObjectAtIndex: 0];
		if([opArray count] > 0) {
			op = [opArray objectAtIndex: 0];
			[op performSelectorOnMainThread: @selector(doMain) withObject: nil waitUntilDone: NO];
		}
		else op = nil;
	}
	
	- (void) setMaxConcurrentOperationCount: (int) count { return; }
	
	@end

#endif