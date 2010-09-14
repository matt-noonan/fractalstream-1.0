//
//  FSHistory.m
//  FractalStream
//
//  Created by Matt Noonan on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FSHistory.h"


@implementation FSHistory

- (id) init {
	self = [super init];
	history = [[NSMutableArray alloc] init];
	return self;
}

- (void) dealloc {
	[history release];
	[super dealloc];
}

@end
