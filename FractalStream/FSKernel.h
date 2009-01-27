//
//  FSKernel.h
//  FractalStream
//
//  Created by Matthew Noonan on 1/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FSECompiler.h"

#define LLVMi32(x) ConstantInt::get(IntegerType::get(32), (x), true)
#define LLVMu32(x) ConstantInt::get(IntegerType::get(32), (x), false)
#define LLVMd(x) ConstantFP::get(Type::DoubleTy, (x))

@interface FSKernel : NSObject {
	BOOL kernelLoaded;
	BOOL useJIT;
	int mode, pass, defaults;
	FSECompiler* compiler;
	FSEParseNode* tree;
	void** val;
	void (*kernelPtr)(int, double*, int, double*, int, double, double);
	void* module;
	void* jit;
	void* bldr;
	void (*llvmPtr)(int, double*, int, double*, int, double, double);
	
	void* _llvmKernel;					// (Function*) llvmKernel
	void *_inputP, *_outputP;	// (Value*) _inputP etc
	void *_xP, *_jP, *_flagP;							// (AllocaInst*) xP etc
	void *_reportxP, *_reportyP, *_reportedP, *_probeP;	// (AllocaInst*) reportxP etc
	void *_big2, *_tiny2;	// (Value*) big2 etc
	void *_maxIt, *_loop_i; // (Value*) maxIt etc
	void *_commenceBlock;	// (BasicBlock*) commenceBlock
	void *_f_exp, *_f_log, *_f_sqrt, *_f_cos, *_f_sin, *_f_tan;			// (Function*) f_exp etc
	void *_f_cosh, *_f_sinh, *_f_tanh, *_f_acos, *_f_asin, *_f_atan;	// (Function*) f_cosh etc
	void *_f_atan2, *_f_fmod;	// (Function*) f_atan2 etc
	int eSF_was_const;
	double eSF_const_x;
	double eSF_const_y;
	
}

- (void) test;
- (BOOL) buildKernelFromCompiler: (FSECompiler*) newComp;
- (void) buildLLVMKernel;
- (void*) loadKernelFromFile: (NSString*) filename;
- (void*) kernelPtr;
- (void) runKernelWithMode: (int) mde input: (double*) input ofLength: (int) length output: (double*) output maxIter: (int) maxIter maxNorm: (double) maxNorm minNorm: (double) minNorm;
- (void*) emit: (int) node;

@end
