//
//  FSKernel.h
//  FractalStream
//
//  Created by Matt Noonan on 8/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSKernelData.h"
#import "FSVariable.h"

@interface FSKernel : NSObject {
	void* kernelFunction;
	BOOL isActive;
}

- (id) initWithFunction: (void*) f;
- (void) runWithData: (FSKernelData*) data;
- (BOOL) isActive;
- (void) setActive: (BOOL) active;
- (NSArray*) planes;
- (NSArray*) parameters;
- (NSArray*) defaults;
- (NSArray*) probes;
@end
