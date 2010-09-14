//
//  FSVariable.h
//  FractalStream
//
//  Created by Matt Noonan on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSComplexNumber.h"

@interface FSVariable : FSComplexNumber {
	NSString* name;
}

- (id) initWithName: (NSString*) newName;
- (id) initWithName: (NSString*) newName real: (double) x imag: (double) y;
- (void) setName: (NSString*) newName;
- (NSString*) name;

@end
