//
//  FSSave.m
//  FractalStream
//
//  Created by Matt Noonan on 2/10/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FSSave.h"


@implementation FSSave

static BOOL miniLoads = YES;

+ (BOOL) usesMiniLoads { return miniLoads; }
+ (void) useMiniLoads: (BOOL) ml { miniLoads = ml; }

- (NSString*) type { return type; }
- (FSSession*) session { return session; }
- (NSArray*) editor { return editor; }
- (NSArray*) minidata { return editor; }
- (FSColorWidget*) colorizer { return colorizer; }
- (NSArray*) variableNames { return names; }
- (NSArray*) variableReal { return real; }
- (NSArray*) variableImag { return imag; }
- (NSArray*) probeNames { return probes; }
- (BOOL) allowEditor { return (disableEditor == YES)? NO : YES; }
- (NSFileWrapper*) customTools { return tools; }
- (BOOL) hasTools { return ([tools isKindOfClass: [NSFileWrapper class]]); }

- (id) init {
	self = [super init];
	tools = [NSNull null];
	disableEditor = NO;
	return self;
}

- (void) setType: (NSString*) newType session: (FSSession*) sess colorizer: (FSColorWidget*) col editor: (FSEController*) edit browser: (FSBrowser*) brow {
	type = [NSString stringWithString: newType];
	session = [sess retain];
	colorizer = [col retain];
	editor = [[edit state] retain];
	browser = [brow retain];
}

- (void) encodeWithCoder: (NSCoder*) coder {
	tools = [browser extraTools];
	if(tools == nil) tools = [NSNull null];
	[coder encodeObject: type forKey: @"type"];
	if([type isEqualToString: @"editor"]) {
		[coder encodeObject: editor forKey: @"editor"];
	}
	else if([type isEqualToString: @"full session [22oct]"]) {
		[coder encodeObject: editor forKey: @"editor"];
		[coder encodeObject: session forKey: @"session"];
		[coder encodeObject: colorizer forKey: @"colorizer"];
		[coder encodeObject: [browser namedVariables] forKey: @"named variables"];
		[coder encodeObject: [browser namedVariablesRealParts] forKey: @"real parts"];
		[coder encodeObject: [browser namedVariablesImagParts] forKey: @"imag parts"];
		[coder encodeObject: [browser namedProbes] forKey: @"namedProbes"];
//		[coder encodeObject: [colorizer smoothnessArray] forKey: @"smoothing"];
		[coder encodeObject: [NSNumber numberWithBool: [browser editorDisabled]] forKey: @"editor disabled?"];
		[coder encodeObject: tools forKey: @"tools"];
	}
	else NSLog(@"***** unknown type string, FSSave is confused!\n");
}

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	

	tools = [NSNull null];
	disableEditor = NO;
	if([coder containsValueForKey: @"type"]) type = [[coder decodeObjectForKey: @"type"] retain];
	else type = [[coder decodeObject] retain];
	if([type isEqualToString: @"editor"] || [FSSave usesMiniLoads]) {
		if([coder containsValueForKey: @"type"]) editor = [[coder decodeObjectForKey: @"editor"] retain];
		else editor = [[coder decodeObject] retain];
		session = nil;
		colorizer = nil;
		browser = nil;
	}
	else if([type isEqualToString: @"full session"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
		NSLog(@"saved with old version");
	}
	else if([type isEqualToString: @"full session [26mar]"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
		names = [[coder decodeObject] retain];
		real = [[coder decodeObject] retain];
		imag = [[coder decodeObject] retain];
		NSLog(@"saved with old version: 26mar");
	}
	else if([type isEqualToString: @"full session [3sep]"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
		names = [[coder decodeObject] retain];
		real = [[coder decodeObject] retain];
		imag = [[coder decodeObject] retain];
		probes = [[coder decodeObject] retain];
		NSLog(@"saved with old version: 3sep");
	}
	else if([type isEqualToString: @"full session [20oct]"]) {
		editor = [[coder decodeObject] retain];
		session = [[coder decodeObject] retain];
		colorizer = [[coder decodeObject] retain];
		names = [[coder decodeObject] retain];
		real = [[coder decodeObject] retain];
		imag = [[coder decodeObject] retain];
		probes = [[coder decodeObject] retain];
		[colorizer readSmoothnessFrom: [coder decodeObject]];
		NSLog(@"saved with old version: 20oct");
	}
	else if([type isEqualToString: @"full session [22oct]"]) {
		if([coder containsValueForKey: @"type"]) {
			editor = [[coder decodeObjectForKey: @"editor"] retain];
			session = [[coder decodeObjectForKey: @"session"] retain];
			colorizer = [[coder decodeObjectForKey: @"colorizer"] retain];
			names = [[coder decodeObjectForKey: @"named variables"] retain];
			real = [[coder decodeObjectForKey: @"real parts"] retain];
			imag = [[coder decodeObjectForKey: @"imag parts"] retain];
			probes = [[coder decodeObjectForKey: @"namedProbes"] retain];
			//[colorizer readSmoothnessFrom: [coder decodeObjectForKey: @"smoothing"]];
			disableEditor = [[coder decodeObjectForKey: @"editor disabled?"] boolValue];
			tools = [[coder decodeObjectForKey: @"tools"] retain];
		}
		else {
			NSLog(@"doing unkeyed loading\n");
			editor = [[coder decodeObject] retain];
			session = [[coder decodeObject] retain];
			colorizer = [[coder decodeObject] retain];
			names = [[coder decodeObject] retain];
			real = [[coder decodeObject] retain];
			imag = [[coder decodeObject] retain];
			probes = [[coder decodeObject] retain];
			[colorizer readSmoothnessFrom: [coder decodeObject]];
			disableEditor = [[coder decodeObject] boolValue];
			tools = [[coder decodeObject] retain];
		}
	}
	else NSLog(@"***** unknown type string, FSSave is confused!\n");
	
	return self;
}

@end
