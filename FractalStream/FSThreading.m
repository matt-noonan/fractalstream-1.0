//
//  FSThreading.m
//  FractalStream
//
//  Created by Matthew Noonan on 1/21/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSThreading.h"


#ifdef FS_USE_THREADING
	
	@implementation FSOperation
	@end
	
	@implementation FSOperationQueue
	- (void) go { return; }
	@end

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