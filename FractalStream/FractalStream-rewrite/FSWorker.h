//
//  FSWorker.h
//  FractalStream
//
//  Created by Matt Noonan on 8/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSKernelData.h"
#import "FSKernel.h"


@interface FSWorker : NSOperation {
	FSKernelData data;
}

- (id) initWithKernelData: (FSKernelData) newData;
- (FSKernelData*) dataPtr;

@end
