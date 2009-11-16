/*
 *  FSRenderUnit.h
 *  FractalStream
 *
 *  Created by Matthew Noonan on 1/20/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#import "FSViewerData.h"

typedef struct {
	FSViewerData* viewerData;
	double origin[2];
	double offset[2];
	double step[2];
	int dimension[2];
	float location[2];
	int multiplier;
	id owner;
	BOOL parametric;
	BOOL freeResults;
	double* setting;
	int settings;
	double* result;
	BOOL finished;
	int batch;
	NSConditionLock* queueLock;
} FSRenderUnit;
