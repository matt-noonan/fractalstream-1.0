//
//  FSRenderOperation.h
//  FractalStream
//
//  Created by Matthew Noonan on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSViewerData.h"

typedef struct {
	FSViewerData* viewerData;
	double origin[2];
	double offset[2];
	double step[2];
	int dimension[2];
	id owner;
	BOOL freeResults;
	double* setting;
	int settings;
	double* result;
} FSRenderUnit;

@interface FSRenderOperation : NSOperation {
	FSRenderUnit unit;
}

- (id) init;
- (void) dealloc;

@end
