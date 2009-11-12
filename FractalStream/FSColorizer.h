//
//  FSColorizer.h
//  FractalStream
//
//  Created by Matt Noonan on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSViewerData.h"
#import "FSRenderUnit.h"
#import "FSColor.h"
#import "FSColorWidget.h"
#import "FSThreading.h"
#import "FSColorLibraryController.h"


@interface FSColorizer : NSObject {
	int acMax;
	FSViewer_Autocolor_Cache* acCache;
	FSColorWidget* colorPicker;
	NSMutableArray* colorArray;
	int currentBatch;
}

- (id) init;
- (void) dealloc;

- (void) colorUnit: (FSRenderUnit*) unit;
- (void) setColorWidget: (FSColorWidget*) picker autocolorCache: (FSViewer_Autocolor_Cache*) acc;
- (void) setColorArray: (NSArray*) colors;
- (void) setCurrentBatch: (int) cb;

@end
