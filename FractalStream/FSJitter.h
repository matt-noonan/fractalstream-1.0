//
//  FSJitter.h
//  FractalStream
//
//  Created by Matthew Noonan on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSThreading.h"

@interface FSJitter : NSObject {
	void* eng;
}

+ (FSJitter*) jitter;
- (void) remover: (NSNotification*) note;
- (void) startup;
- (void*) getPointerToFunction: (void*) f;
- (void) addModuleProvider: (void*) modP;
- (void*) removeModuleProvider: (void*) modP;
- (void*) engine;
- (void*) targetData;

@end
