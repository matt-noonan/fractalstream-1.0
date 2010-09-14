
/* This object is the operation of running the dynamics on one tile */


#import "FSWorker.h"


@implementation FSWorker

- (id) initWithKernelData: (FSKernelData) newData {
	self = [super init];
	data = newData;
	data.result = (char*) malloc(data.size);
	return self;
}

- (void) dealloc {
	free(data.result);
	[super dealloc];
}

- (void) main {
	[(FSKernel*) data.kernel runWithData: &data];
	[self retain];
	[data.manager 
		performSelectorOnMainThread: @selector(processResults:) 
		withObject: self
		waitUntilDone: YES
	 ];
}

- (FSKernelData*) dataPtr { return &data; }

@end
