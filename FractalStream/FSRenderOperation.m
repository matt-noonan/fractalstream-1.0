//
//  FSRenderOperation.m
//  FractalStream
//
//  Created by Matthew Noonan on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSRenderOperation.h"


@implementation FSRenderOperation

- (id) initWithUnit: (FSRenderUnit) newUnit colorizer: (FSColorizer*) col {
	self = [super init];
	unit = newUnit;
	unit.result = (double*) malloc(sizeof(double) * (unit.dimension[0] * unit.dimension[1] * 3));
	colorizer = col;
	return self;
}

- (void) dealloc {
	if(unit.freeResults == YES) free(unit.result);
	[super dealloc];
}

- (FSRenderUnit*) unit { return &unit; }

- (void) main {
	int row, i;
	double in[512];	
	[unit.queueLock lock];
	[unit.queueLock unlockWithCondition: [unit.queueLock condition] + 1];
	
	for(i = 0; i < unit.settings + 6; i++) in[i] = unit.setting[i];
	for(row = 0; row < unit.dimension[1]; row++) {
		in[0] = unit.origin[0] + unit.offset[0];
		in[1] = unit.origin[1] + unit.offset[1] + unit.step[1] * (double) row;
		in[2] = unit.step[0];
		in[3] = unit.viewerData -> par[0];
		in[4] = unit.viewerData -> par[1];
		in[5] = unit.viewerData -> pixelSize;
		(unit.viewerData -> kernel)(unit.viewerData -> program, in, unit.dimension[0], &(unit.result[3 * row * unit.dimension[0]]), 
			unit.viewerData -> maxIters, unit.viewerData -> maxRadius, unit.viewerData -> minRadius);
		if([self isCancelled] == YES) break;
	}
	unit.finished = [self isCancelled]? NO : YES;
	unit.freeResults = YES;
	if(unit.finished == NO) {
		[unit.queueLock lock];
		[unit.queueLock unlockWithCondition: [unit.queueLock condition] - 1];
	}
	else {
		[colorizer colorUnit: &unit];
		unit.freeResults = YES;
		[unit.owner performSelectorOnMainThread: @selector(renderOperationFinished:) withObject: [self retain] waitUntilDone: NO];
		[unit.queueLock lock];
		[unit.queueLock unlockWithCondition: [unit.queueLock condition] - 1];
	}
		//	[unit.owner renderOperationFinished: self];
}


@end
