/*
	FSKernelManager handles the collection of kernels (compiled scripts) which have been
		loaded or compiled in this run of the program.  There should be only one instance
		of FSKernelManager at a time, shared across all open documents.
*/

#import "FSKernelManager.h"


@implementation FSKernelManager

- (id) init {
	self = [super init];
	kernelArray = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc {
	[kernelArray release];
	[super dealloc];
}

- (int) createKernelForFunction: (void*) kernelPtr {
	FSKernel* k;
	k = [[FSKernel alloc] initWithFunction: kernelPtr];
	[kernelArray addObject: k];
	[k release];
}

- deprecateKernel: (int) kernel { [[kernelArray objectAtIndex: kernel] setActive: NO]; }

- (void*) kernel: (int) kernel { return [kernelArray objectAtIndex: kernel]; }

@end
