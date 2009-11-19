/*
 *  FSThreading.h
 *  FractalStream
 *
 *  Created by Matthew Noonan on 1/21/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */
#import <Cocoa/Cocoa.h>

#define FS_USE_THREADING
#ifndef WINDOWS
#define FS_USE_NSOPERATION
#endif

#ifdef FS_USE_THREADING
	#ifdef FS_USE_NSOPERATION
	
		#define synchronizeTo @synchronized
	
		@interface FSOperation : NSOperation { }
		@end
	
		@interface FSOperationQueue : NSOperationQueue { }
		- (void) go;
		@end
	
	#else
		#define NSOperationQueueDefaultMaxConcurrentOperationCount 2
		#define synchronizeTo @synchronized
		
		@interface FSOperation : NSObject {
			id owner;
			BOOL cancelled;
			NSLock* token;
			NSLock* counter;
		}
		- (void) doMain;
		- (void) setOwner: (id) ow;
		- (void) main;
		- (volatile BOOL) isCancelled;
		- (void) setToken: (NSLock*) tok andCounter: (NSLock*) count;
		@end
		
		
		@interface FSOperationQueue : NSObject {
			NSMutableArray* queue;
			NSConditionLock* lock, *stop;
			volatile BOOL cancelled;
		}
		- (id) init;
		- (void) dealloc;
		- (void) addOperation: (FSOperation*) op;
		- (void) cancelAllOperations;
		- (id) getOperation;
		- (void) go;
		- (volatile BOOL) isCancelled;
		- (void) setMaxConcurrentOperationCount: (int) count;
		- (void) decrement;
		@end


	#endif

#else
	#define NSOperationQueueDefaultMaxConcurrentOperationCount 1
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