
/* Responsible for generating an NSImage of the current dynamical view */

#import "FSDynamics.h"


@implementation FSDynamics

- (id) init {
	self = [super init];
	width = 128;
	height = 128;
	dynamicsImage = nil;
	lastBitmap = nil;
	batch = 0;
	return self;
}

- (void) dealloc {
	free(rgb);
	[super dealloc];
}

- (NSImage*) image { return dynamicsImage; }
- (NSBitmapImageRep*) bitmap { return lastBitmap; }
- (int) getBatchIdentifier { completedWorkers = 0; return ++batch; } // should only run on main thread

- (void) setWidth: (int) w height: (int) h {
	NSLog(@"!!!!! [FSDynamics setWidth: height:] deprecated\n");
}

- (NSBitmapImageRep*) getBitmapWithWidth: (int) w height: (int) h {
	lastBitmap = [[NSBitmapImageRep	alloc]
			  initWithBitmapDataPlanes: (unsigned char**) NULL
			  pixelsWide: w
			  pixelsHigh: h
			  bitsPerSample: 8
			  samplesPerPixel: 4
			  hasAlpha: YES
			  isPlanar: NO
			  colorSpaceName: NSDeviceRGBColorSpace
			  bitmapFormat: 0
			  bytesPerRow: 0
			  bitsPerPixel: 32
	];
	memset([lastBitmap bitmapData], 0x00, [lastBitmap bytesPerRow]*[lastBitmap pixelsHigh]);
	return lastBitmap;
}

- (void) processResults: (FSWorker*) worker { // should only run on main thread
	unsigned char r,g,b;
	FSKernelData* data;
	unsigned char* bitmapdata;
	int bpr;
	int index;
	int i, j, k;
	
	data = [worker dataPtr];
	if(data -> batch != batch) return;
	
	bitmapdata = [data->bitmap bitmapData];
	bpr = [data->bitmap bytesPerRow];

	
	index = 0;
	for(i = 0; i < data -> dim[1]; i++) {
		for(j = 0; j < data -> dim[0]; j++) {
			g = b = 0;
			k = ((int*)&(data->result[index]))[0];
			index += sizeof(int);
			index += sizeof(double);
			if(k == -1) {
				r = g = b = 0;
			}
			else if(((double*)&(data->result[index]))[0] > 0.0) { 
				b = 0;
				g = r =  50 + 20*(k%10);
			}
			else {
				b = 50 + 20*(k%10);
				r = g = 0;
			}
			bitmapdata[4*(j + data->offset[0]) + bpr*(i + data->offset[1]) + 0] = r;
			bitmapdata[4*(j + data->offset[0]) + bpr*(i + data->offset[1]) + 1] = g;
			bitmapdata[4*(j + data->offset[0]) + bpr*(i + data->offset[1]) + 2] = b;
			bitmapdata[4*(j + data->offset[0]) + bpr*(i + data->offset[1]) + 3] = 0xff;
			index += sizeof(double);
		}
	}
	
	if(dynamicsImage) [dynamicsImage release];

	dynamicsImage = [[NSImage alloc] initWithSize: NSMakeSize([data->bitmap pixelsWide], [data->bitmap pixelsHigh])];
	[dynamicsImage addRepresentation: data -> bitmap];
	
	[worker release];
	++completedWorkers;
	
	[[NSNotificationCenter defaultCenter] 
		postNotificationName: @"Dynamics image updated"
		object: self
	 ];
	
	if(completedWorkers == data->workers)
		[[NSNotificationCenter defaultCenter] 
			 postNotificationName: @"Dynamics image completed"
			 object: self
		 ];
	
	
}

@end
