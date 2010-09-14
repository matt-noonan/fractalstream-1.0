//
//  FSComplexNumber.h
//  FractalStream
//
//  Created by Matt Noonan on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FSComplexNumber : NSObject {
	double z[2];
	BOOL isReal;
}

- (id) initWithReal: (double) x imag: (double) y;
- (BOOL) isReal;
- setReal: (BOOL) r;
- (double) realPart;
- (double) imagPart;
- (void) setReal: (double) r imag: (double) i;
- (NSString*) string;

@end
