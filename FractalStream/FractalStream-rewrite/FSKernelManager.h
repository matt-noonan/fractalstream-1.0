//
//  FSKernelManager.h
//  FractalStream
//
//  Created by Matt Noonan on 8/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSKernel.h"

@interface FSKernelManager : NSObject {
	NSMutableArray* kernelArray;
}

- (int) createKernelForFunction: (void*) kernelPtr;
- deprecateKernel: (int) kernel;
- (void*) kernel: (int) kernel;

@end
