//
//  FSWorkerManager.h
//  FractalStream
//
//  Created by Matt Noonan on 8/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSKernelData.h"
#import "FSKernel.h"
#import "FSWorker.h"

@interface FSWorkerManager : NSObject {
	NSOperationQueue* queue;
	int batch;
	int logBoxDim;
	NSInteger logBoxSize;
	
	FSKernel* testKernel;
}

@property NSInteger logBoxSize;

- (void) processData: (FSKernelData) data;


@end
