
/*
	FSWorkerManager takes requests for the dyanmics on some region, splits the task into
		subtasks, and executes the subtasks on multiple threads.  The subtasks (individual
		tiles in the FSViewer) are handled by FSWorker objects
*/

#import "FSWorkerManager.h"


@implementation FSWorkerManager

@synthesize logBoxSize;

- (id) init {
	self = [super init];
	queue = [[NSOperationQueue alloc] init];
	batch = 0;
	logBoxDim = 6;
	testKernel = [[FSKernel alloc] initWithFunction: (void*)NULL];
	return self;
}



- (void) processData: (FSKernelData) data {  // should only run on the main thread!
	int fullDim[2];
	int boxDim[2];
	int i,j;
	double z0;
	double z[2];
	int offset[2];
	double boxSize;
	FSWorker* worker;
	
	//test
	data.kernel = testKernel;
	logBoxDim = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"workUnitSize"] intValue];
	if(logBoxDim < 4) logBoxDim = 4;
	if(logBoxDim > 10) logBoxDim = 10;
	
	offset[0] = offset[1] = 0;
	++batch;
	boxSize = (double)(1 << logBoxDim);
	fullDim[0] = data.dim[0];
	fullDim[1] = data.dim[1];
	boxDim[0] = (fullDim[0] >> logBoxDim) + ((fullDim[0] % (1 << logBoxDim))?1:0);
	boxDim[1] = (fullDim[1] >> logBoxDim) + ((fullDim[1] % (1 << logBoxDim))?1:0);
	z[0] = z0 = data.z[0];
	z[1] = data.z[1];
	data.workers = boxDim[0]*boxDim[1];
	data.workerID = 0;
//	NSLog(@"launching %i workers, %i, %i, %i\n", boxDim[0]*boxDim[1], fullDim[0], logBoxDim, fullDim[0] >> logBoxDim);
	for(i = 0; i < boxDim[1]; i++) {
		z[0] = z0;
		offset[0] = 0;
		for(j = 0; j < boxDim[0]; j++) {
			data.offset[0] = offset[0] << logBoxDim; data.offset[1] = offset[1] << logBoxDim;
			data.dim[0] = data.dim[1] = (1 << logBoxDim);
			if((j == boxDim[0] - 1) && (fullDim[0] % (1 << logBoxDim)))
				data.dim[0] = fullDim[0] % (1 << logBoxDim);
			if((i == boxDim[1] - 1) && (fullDim[1] % (1 << logBoxDim)))
				data.dim[1] = fullDim[1] % (1 << logBoxDim);
			data.size = (sizeof(int) + 2*sizeof(double)) * data.dim[0] * data.dim[1];
			data.z[0] = z[0]; data.z[1] = z[1];
			worker = [[FSWorker alloc] initWithKernelData: data];
			[queue addOperation: worker];
			[worker release];
			z[0] += data.dz[0] * (double) data.dim[0];
			++offset[0];
			data.workerID++;
		}
		z[1] += data.dz[1] * (double) data.dim[1];
		++offset[1];
	}
}


@end
