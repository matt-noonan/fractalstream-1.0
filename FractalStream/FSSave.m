//
//  FSSave.m
//  FractalStream
//
//  Created by Matt Noonan on 2/10/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FSSave.h"


@implementation FSSave

- (NSString*) type { return type; }
- (FSSession*) session { return session; }
- (NSArray*) editor { return editor; }
- (FSColorWidget*) colorizer { return colorizer; }
- (NSArray*) variableNames { return names; }
- (NSArray*) variableReal { return real; }
- (NSArray*) variableImag { return imag; }
- (NSArray*) probeNames { return probes; }



- (void) setType: (NSString*) newType session: (FSSession*) sess colorizer: (FSColorWidget*) col editor: (FSEController*) edit browser: (FSBrowser*) brow {
	type = [NSString stringWithString: newType];
	session = [sess retain];
	colorizer = [col retain];
	editor = [[edit state] retain];
	browser = [brow retain];
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: type];
	if([type isEqualToString: @"editor"]) {
		NSLog(@"encoding editor\n");
		[coder encodeObject: editor];
	}
	else if([type isEqualToString: @"full session"]) {
		NSLog(@"encoding full session\n");
		[coder encodeObject: editor];
		[coder encodeObject: session];
		NSLog(@"encoding colorizer\n");
		[coder encodeObject: colorizer];
	}
	else if([type isEqualToString: @"full session [26mar]"]) {
		NSLog(@"encoding full session\n");
		[coder encodeObject: editor];
		[coder encodeObject: session];
		NSLog(@"encoding colorizer\n");
		[coder encodeObject: colorizer];
		NSLog(@"encoding defaults\n");
		[coder encodeObject: [browser namedVariables]];
		[coder encodeObject: [browser namedVariablesRealParts]];
		[coder encodeObject: [browser namedVariablesImagParts]];
	}
	else if([type isEqualToString: @"full session [3sep]"]) {
		NSLog(@"encoding full session\n");
		[coder encodeObject: editor];
		[coder encodeObject: session];
		NSLog(@"encoding colorizer\n");
		[coder encodeObject: colorizer];
		NSLog(@"encoding defaults\n");
		[coder encodeObject: [browser namedVariables]];
		[coder encodeObject: [browser namedVariablesRealParts]];
		[coder encodeObject: [browser namedVariablesImagParts]];
		[coder encodeObject: [browser namedProbes]];
	}
	else NSLog(@"***** unknown type string, FSSave is confused!\n");
}

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	NSLog(@"FSSave got initWithCoder\n");
	type = [[coder decodeObject] retain];
	NSLog(@"type is \"%@\"\n", type);
	if([type isEqualToString: @"editor"]) {
		editor = [[coder decodeObject] retain];
		session = nil;
		colorizer = nil;
		browser = nil;
	}
	else if([type isEqualToString: @"full session"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
	}
	else if([type isEqualToString: @"full session [26mar]"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
		names = [[coder decodeObject] retain];
		real = [[coder decodeObject] retain];
		imag = [[coder decodeObject] retain];
	}
	else if([type isEqualToString: @"full session [3sep]"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
		names = [[coder decodeObject] retain];
		real = [[coder decodeObject] retain];
		imag = [[coder decodeObject] retain];
		probes = [[coder decodeObject] retain];
	}
	else NSLog(@"***** unknown type string, FSSave is confused!\n");
	
	return self;
}

@end
