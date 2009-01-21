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
	@end

#else
	
	@implementation FSOperation
	@end
	
	@implementation FSOperationQueue
	- (id) init {
		self = [super init];
		opArray = [[NSMutableArray alloc] init];
	}
	
	- (void) addOperation: (FSOperation*) op {
		[opArray addObject: op];
	}
	
	- (void) cancelAllOperations {
		[opArray release];
		opArray = [[NSMutableArray alloc] init];
	}
	@end

#endif