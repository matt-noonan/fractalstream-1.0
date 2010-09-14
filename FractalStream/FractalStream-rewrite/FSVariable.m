//
//  FSVariable.m
//  FractalStream
//
//  Created by Matt Noonan on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FSVariable.h"


@implementation FSVariable

- (id) initWithName: (NSString*) newName {
	self = [super init];
	name = (newName == nil)? nil : [NSString stringWithString: newName];
	return self;
}

- (id) initWithName: (NSString*) newName real: (double) x imag: (double) y {
	self = [super initWithReal: x imag: y];
	name = (newName == nil)? nil : [NSString stringWithString: newName];
	return self;
}


- (void) setName: (NSString*) newName {
	[name release];
	name = [[NSString stringWithString: newName] retain];
}

- (NSString*) name { return (name == nil)? @"" : [NSString stringWithString: name]; }

@end
