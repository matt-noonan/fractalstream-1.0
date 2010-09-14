//
//  FSComplexNumber.m
//  FractalStream
//
//  Created by Matt Noonan on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FSComplexNumber.h"


@implementation FSComplexNumber

- (id) init {
	self = [super init];
	z[0] = z[1] = 0.0; isReal = NO;
	return self;
}

- (id) initWithReal: (double) x imag: (double) y {
	self = [super init];
	z[0] = x; z[1] = y; isReal = NO;
	return self;
}


- (BOOL) isReal { return isReal; }
- setReal: (BOOL) r { isReal = r; }
- (double) realPart { return z[0]; }
- (double) imagPart { return isReal? 0.0 : z[1]; }
- (void) setReal: (double) r imag: (double) i { z[0] = r; z[1] = i; }
- (NSString*) string { 
	return isReal? 
		[NSString stringWithFormat: @"%0.4f", z[0]] : [NSString stringWithFormat: @"%0.4f + %0.4fi", z[0], z[1]];
}

@end
