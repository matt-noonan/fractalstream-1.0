
/* Data required by an FSKernel to define a region of the plane. */

typedef struct {
	double z[2];
	int dim[2];
	double dz[2];
	int offset[2];
	char* result;
	int batch;
	int workers;
	int workerID;
	int size;
	id kernel;
	NSArray* parameters;
	int plane;
	id manager;
	id owner;
	NSBitmapImageRep* bitmap;
} FSKernelData;