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
		NSLog(@"encoded names = %@, real = %@, imag = %@, probes = %@\n",
			[browser namedVariables],
			[browser namedVariablesRealParts],
			[browser namedVariablesImagParts],
			[browser namedProbes]
		);
	}
	else if([type isEqualToString: @"full session [20oct]"]) {
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
		NSLog(@"encoded names = %@, real = %@, imag = %@, probes = %@\n",
			[browser namedVariables],
			[browser namedVariablesRealParts],
			[browser namedVariablesImagParts],
			[browser namedProbes]
		);
		[coder encodeObject: [colorizer smoothnessArray]];
	}
	else if([type isEqualToString: @"full session [22oct]"]) {
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
		NSLog(@"encoded names = %@, real = %@, imag = %@, probes = %@\n",
			[browser namedVariables],
			[browser namedVariablesRealParts],
			[browser namedVariablesImagParts],
			[browser namedProbes]
		);
		[coder encodeObject: [colorizer smoothnessArray]];
		[coder encodeObject: [NSNumber numberWithBool: [browser editorDisabled]]];
		[coder encodeObject: tools];
	}
	else NSLog(@"***** unknown type string, FSSave is confused!\n");
}

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	

	tools = [NSNull null];
	disableEditor = NO;
	type = [[coder decodeObject] retain];
	if([type isEqualToString: @"editor"] || [FSSave usesMiniLoads]) {
		editor = [[coder decodeObject] retain];
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
		NSLog(@"tools is %@\n", tools);
	}
	else NSLog(@"***** unknown type string, FSSave is confused!\n");
	
	return self;
}

@end
