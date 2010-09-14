
/* 
	FSKernel is a wrapper around the C function which implements the action of a 
		user's script on a single initial value.
*/

#import "FSKernel.h"


@implementation FSKernel

- (id) initWithFunction: (void*) f {
	self = [super init];
	kernelFunction = f;
	isActive = YES;
	return self;
}

- (void) runWithData: (FSKernelData*) data {
	int i,j,k,index;
	double z[2], Z[2], t, c[2];
	int count;
	
	z[0] = data->z[0]; z[1] = data->z[1];
	index = 0;
	for(i = 0; i < data->dim[1]; i++) {
		z[0] = data->z[0]; 
		for(j = 0; j < data->dim[0]; j++) {
			Z[0] = 0.0; Z[1] = 0.0;
			for(k = 0; k < 1000; k++) {
				t = Z[0]*Z[0] - Z[1]*Z[1] + z[0];
				Z[1] = 2*Z[0]*Z[1] + z[1];
				Z[0] = t;
				if(Z[0]*Z[0] + Z[1]*Z[1] > 100.0) break;
			}
			if(k == 1000) k = -1;
			((int*)&(data->result[index]))[0] = k; index += sizeof(int);
			((double*)&(data->result[index]))[0] = Z[0]; index += sizeof(double);
			((double*)&(data->result[index]))[0] = Z[1]; index += sizeof(double);
			
			z[0] += data->dz[0];
		}
		z[1] += data->dz[1];
	}
}

- (BOOL) isActive { return isActive; }
- (void) setActive: (BOOL) active { isActive = active; }

- (NSArray*) planes { 
	FSVariable *c, *z;
	c = [[FSVariable alloc] initWithName: @"c" real: 0.0 imag: 0.0];
	z = [[FSVariable alloc] initWithName: @"z" real: 0.0 imag: 0.0];
	return [NSArray arrayWithObjects: c, z, nil];
}
- (NSArray*) parameters { return nil; }
- (NSArray*) defaults { return nil; }
- (NSArray*) probes { return nil; }

@end
