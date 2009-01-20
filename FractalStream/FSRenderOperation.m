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
	unit.result = (double*) malloc(sizeof(double) * unit.dimension[0] * unit.dimension[1] * 3);
	colorizer = col;
	return self;
}

- (void) dealloc {
	if(unit.freeResults == YES) free(unit.result);
	NSLog(@"FSRenderOperation %@ deallocing.\n", self);
	[super dealloc];
}

- (FSRenderUnit*) unit { return &unit; }

- (void) main {
	int row, i;
	double in[512];	
		
	NSLog(@"FSRenderOperation %@ ready to go.\n", self);
	for(i = 0; i < unit.settings; i++) in[6 + i] = unit.setting[i];
	for(row = 0; row < unit.dimension[1]; row++) {
		in[0] = unit.origin[0];
		in[1] = unit.origin[1] + unit.step[1] * (double) row;
		in[2] = unit.step[0];
		in[3] = unit.viewerData -> par[0];
		in[4] = unit.viewerData -> par[1];
		in[5] = unit.viewerData -> pixelSize;
		(unit.viewerData -> kernel)(unit.viewerData -> program, in, unit.dimension[0], &(unit.result[3 * row * unit.dimension[0]]), 
			unit.viewerData -> maxIters, unit.viewerData -> maxRadius, unit.viewerData -> minRadius);
		if([self isCancelled] == YES) break;
	}
	
	NSLog(@"FSRenderOperation %@ ready to color.\n", self);
	if([self isCancelled] == NO) {
		[colorizer colorUnit: &unit];
		[unit.owner performSelectorOnMainThread: @selector(renderOperationFinished:) withObject: self waitUntilDone: YES];
	}
	else unit.freeResults = YES;
	NSLog(@"FSRenderOperation %@ finished.\n", self);
}


@end
