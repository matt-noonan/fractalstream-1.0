
/* FSEditController manages the interface for the script editor. */

#import "FSEditController.h"



@implementation FSEditController

- (id) init {
	self = [super init];
	manager = [[FSWorkerManager alloc] init];
	return self;
}

- (void) dealloc {
	[manager release];
	[super dealloc];
}

- (IBAction) compile: (id) sender {
	FSKernelData data;
	
	data.z[0] = -2.0;
	data.z[1] = 2.0;
	
	data.dz[0] = 4.0 / 128.0;
	data.dz[1] = - 4.0 / 128.0;
	
	data.dim[0] = 128;
	data.dim[1] = 128;
	
	data.manager = data.owner = self;
	
	[manager processData: data];
}

- (IBAction) displayHelp: (id) sender {
	[[NSWorkspace sharedWorkspace] 
		openFile: [[NSBundle mainBundle] 
			pathForResource: @"Interacting with FractalStream" ofType: @"pdf"
		]
	 ];
}

- (void) processResults: (FSWorker*) worker {
	FSKernelData* data;
	int x,y;
	int i,j,index,jndex;
	char s[65*66+2];
	data = (FSKernelData*) [worker dataPtr];
	x = (int)((data->z[0] - -2.0)/data->dz[0]);
	y = (int)((data->z[1] - 2.0)/data->dz[1]);
	index = jndex = 0;
	
	s[jndex++] = '\n';
	for(i = 0; i < 64; i++) s[jndex++] = '-'; s[jndex++] = '\n';
	for(i = 0; i < 64; i++) {
		for(j = 0; j < 64; j++) {
			test[i][j] = ((int*)&(data->result[index]))[0] == 100? ' ' : '*';
			index += sizeof(int) + 2*sizeof(double);
			s[jndex++] = test[i][j];
		}
		s[jndex++] = '\n';
	}
	for(i = 0; i < 64; i++) s[jndex++] = '-'; s[jndex++] = '\n';
	s[jndex] = 0;
	NSLog(@"%s", s);
}


@end
