//
//  FSDynamics.h
//  FractalStream
//
//  Created by Matt Noonan on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSWorker.h"
#import "FSKernelData.h"

@interface FSDynamics : NSObject {
	NSImage* dynamicsImage;
	unsigned char* rgb;
	int width, height;
	int batch, completedWorkers;
	NSBitmapImageRep* lastBitmap;
}

- (void) processResults: (FSWorker*) worker;
- (NSImage*) image;
- (void) setWidth: (int) w height: (int) h;
- (NSBitmapImageRep*) getBitmapWithWidth: (int) w height: (int) h;
- (NSBitmapImageRep*) bitmap;
- (int) getBatchIdentifier;

@end
