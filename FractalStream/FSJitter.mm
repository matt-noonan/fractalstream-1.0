//
//  FSJitter.m
//  FractalStream
//
//  Created by Matthew Noonan on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSJitter.h"
#include "llvm/Module.h"
#include "llvm/ModuleProvider.h"
#include "llvm/ExecutionEngine/JIT.h"
#include "llvm/ExecutionEngine/GenericValue.h"
using namespace llvm;

@implementation FSJitter

static FSJitter* sharedJitter = nil;

+ (FSJitter*) jitter {
	if(sharedJitter == nil) {
		sharedJitter = [[FSJitter alloc] init];
		[sharedJitter startup];
		[[NSNotificationCenter defaultCenter]
			addObserver: sharedJitter selector: @selector(remover:)
			name: NSApplicationWillTerminateNotification object: NSApp
		];
	}
	return sharedJitter;
}

- (void) remover : (NSNotification*) note {
	if(sharedJitter) {
		[[NSNotificationCenter defaultCenter] removeObserver: sharedJitter];
		[sharedJitter release];
	}
}

- (void) startup {
	/* Build the module provider and execution engine that every document will use */
	llvm::Module* rootModule = new llvm::Module("root module");
	ExistingModuleProvider* MP = new ExistingModuleProvider(rootModule);
	ExecutionEngine* engine = ExecutionEngine::create(MP, false);
	eng = (void*) engine;
}


- (void) addModuleProvider: (void*) modP {
	ExecutionEngine* engine = (ExecutionEngine*) eng;
	synchronizeTo(self) {
		engine -> addModuleProvider((ModuleProvider*) modP);
	}
}

- (void*) removeModuleProvider: (void*) modP {
	ExecutionEngine* engine = (ExecutionEngine*) eng;
	void* r;
	synchronizeTo(self) {
		r = engine -> removeModuleProvider((ModuleProvider*) modP);
	}
	return r;
}

- (void*) getPointerToFunction: (void*) f {
	ExecutionEngine* engine = (ExecutionEngine*) eng;
	void* r;
	synchronizeTo(self) {
		r = engine -> getPointerToFunction((Function*) f);
	}
	return r;
}

- (void*) targetData { 
	ExecutionEngine* engine = (ExecutionEngine*) eng;
	return (void*) engine -> getTargetData();
}

- (void*) engine { return eng; }

@end
