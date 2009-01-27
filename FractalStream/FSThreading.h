/*
 *  FSThreading.h
 *  FractalStream
 *
 *  Created by Matthew Noonan on 1/21/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

/* Undefine the following symbol to target 10.4 and older, Cocotron, etc.
	Re-implement FSOperation classes using pthreads or NSThread for GNUStep. */
#define FS_USE_THREADING

#ifdef FS_USE_THREADING
	#define synchronizeTo @synchronized
	
	@interface FSOperation : NSOperation { }
	@end
	
	@interface FSOperationQueue : NSOperationQueue { }
	- (void) go;
	@end

#else
	#define NSOperationQueueDefaultMaxConcurrentOperationCount 2
	#define synchronizeTo if

	@interface FSOperation : NSObject {
		id owner;
	}
	- (void) doMain;
	- (void) setOwner: (id) ow;
	- (void) main;
	- (BOOL) isCancelled;
	@end

	@interface FSOperationQueue : NSObject {
		NSMutableArray* opArray;
		FSOperation* op;
	}
	- (id) init;
	- (void) addOperation: (FSOperation*) op;
	- (void) cancelAllOperations;
	- (void) go;
	- (void) setMaxConcurrentOperationCount: (int) count;
	@end

#endif