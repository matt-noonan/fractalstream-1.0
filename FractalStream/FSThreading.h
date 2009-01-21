/*
 *  FSThreading.h
 *  FractalStream
 *
 *  Created by Matthew Noonan on 1/21/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#define FS_USE_THREADING

#ifdef FS_USE_THREADING
	#define synchronizeTo @synchronized
	
	@interface FSOperation : NSOperation { }
	@end
	
	@interface FSOperationQueue : NSOperationQueue { }
	@end

#else
	#define synchronizeTo if
	@interface FSOperation : NSObject {
	}
	@end

	@interface FSOperationQueue : NSObject {
		NSMutableArray* opArray;
	}
	@end

#endif