//
//  FSRenderOperation.h
//  FractalStream
//
//  Created by Matthew Noonan on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSViewerData.h"
#import "FSRenderUnit.h"
#import "FSColorizer.h"
#import "FSThreading.h"

@interface FSRenderOperation : FSOperation {
	FSRenderUnit unit;
	FSColorizer* colorizer;
}

- (id) initWithUnit: (FSRenderUnit) newUnit colorizer: (FSColorizer*) col;
- (FSRenderUnit*) unit;
- (void) dealloc;

@end
