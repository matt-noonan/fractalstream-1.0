//
//  FSScene.m
//  FractalStream
//
//  Created by Matt Noonan on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FSScene.h"


@implementation FSScene

- (id) init {
	self = [super init];
	parameters = [[NSMutableArray alloc] init];
	nParameters = 1;
	return self;
}

- (id) initWithScene: (FSScene*) scene pushingParameter: (FSComplexNumber*) Z {
	self = [super init];
	parameters = [[scene parameters] copy];
	[parameters addObject: Z];
	nParameters = 1;
	return self;
}

- (void) dealloc {
	[parameters release];
	[super dealloc];
}

- (double*) center { return center; }
- (double*) pixelSize { return pixelSize; }
- (BOOL) isConformal { return conformal; }
- (FSKernel*) kernel { return kernel; }
- (NSArray*) parameters { return parameters; }
- (NSArray*) annotations { return annotations; }
- (int) plane { return activePlane; }

- (void) setKernel: (FSKernel*) k centerX: (double) x Y: (double) y scale: (double) dz {
	kernel = k; center[0] = x; center[1] = y; pixelSize[0] = pixelSize[1] = dz; conformal = YES;
}

- (BOOL) canPushParameter { return ([parameters length] == nParameters)? NO : YES; }

@end
