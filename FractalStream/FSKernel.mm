//
//  FSKernel.mm
//  FractalStream
//
//  Created by Matthew Noonan on 1/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FSKernel.h"
#include "llvm/Constants.h"
#include "llvm/DerivedTypes.h"
#include "llvm/Instructions.h"
#include "llvm/Function.h"
#include "llvm/CallingConv.h"
#include "llvm/Analysis/Verifier.h"
#include "llvm/Module.h"
#include "llvm/ModuleProvider.h"
#include "llvm/ExecutionEngine/JIT.h"
#include "llvm/ExecutionEngine/GenericValue.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/PassManager.h"
#include "llvm/Assembly/PrintModulePass.h"
#include "llvm/Support/IRBuilder.h"
#include "llvm/Target/TargetData.h"
#include "llvm/Transforms/Scalar.h"
#include <stdlib.h>
#include <iostream>
#include <time.h>

#ifndef WINDOWS
	#import <dlfcn.h>
#endif

using namespace llvm;

extern "C" double frandom(void) { return ((2.0 * rand() / (RAND_MAX + 1.0)) - 1.0); }

void frandom2(double* r) {
	double x, y;
	do {
		x = ((2.0 * rand() / (RAND_MAX + 1.0)) - 1.0);
		y = ((2.0 * rand() / (RAND_MAX + 1.0)) - 1.0);
	} while(x*x + y*y >= 1.0);
	r[0] = x;
	r[1] = y;
}

extern "C" double gaussian(void) {  
	double r[2];
	double w;
	frandom2(r);
	w = r[0] * r[0] + r[1] * r[1];
	return r[0] * sqrt((-2.0 * log(w))/w);
}

void gaussian2(double* R) {
	double r[2];
	double w, z;
	frandom2(r);
	w = r[0] * r[0] + r[1] * r[1];
	z = sqrt((-2.0 * log(w))/w);
	R[0] = r[0] * z;
	R[1] = r[1] * z;
}


@implementation FSKernel

- (id) init {
	self = [super init];
	sprintf(postfixID, "%p", self);
	emitStep = 0;
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (void) reloadDataSources {
	int dataSources, i;
	dataSources = [compiler dataSources];
	if(dataSources) {
		dataSource = (void**) malloc(dataSources * sizeof(void*));
		mergeSource = (void**) malloc(dataSources * sizeof(void*));
		for(i = 0; i < dataSources; i++) {
			dataSource[i] = [dataManager getFunctionPointerForData: [NSString stringWithCString: [compiler nameForDataSource: i] encoding: NSUTF8StringEncoding]];
			mergeSource[i] = [dataManager getFunctionPointerForMerge: [NSString stringWithCString: [compiler nameForDataSource: i] encoding: NSUTF8StringEncoding]];
		}
	}
}

- (void) renewDataSources: (NSNotification*) note {
	[self reloadDataSources];
}

- (BOOL) buildKernelFromCompiler: (FSECompiler*) newComp {
	compiler = newComp;
	[self reloadDataSources];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(renewDataSources:)
												 name: @"FSCustomDataAdded"
											   object: dataManager
	 ];	
	jitter = [FSJitter jitter];
	[self buildLLVMKernel];
	return YES;
}

- (void*) emit: (int) node {
	Value *lhs, *rhs;
	GetElementPtrInst *ptr;
	int nkids, i, c;

	++emitStep;
	
	IRBuilder<> *builder = (IRBuilder<> *) bldr;
	Function *llvmKernel = (Function*) _llvmKernel;
	Value *inputP = (Value*) _inputP, *outputP = (Value*) _outputP;
	AllocaInst *xP = (AllocaInst*) _xP, *jP = (AllocaInst*) _jP, *flagP = (AllocaInst*) _flagP;
	AllocaInst *reportxP = (AllocaInst*) _reportxP; AllocaInst *reportyP = (AllocaInst*) _reportyP;
	AllocaInst *reportedP = (AllocaInst*) _reportedP, *probeP = (AllocaInst*) _probeP;
	Value *big2 = (Value*) _big2, *tiny2 = (Value*) _tiny2;
	Value *maxIt = (Value*) _maxIt, *loop_i = (Value*) _loop_i;
	AllocaInst *dsInP = (AllocaInst*) _dsInP, *dsOutP = (AllocaInst*) _dsOutP, *dsResPl = (AllocaInst*) _dsResPl, *dsResPf = (AllocaInst*) _dsResPf;
	BasicBlock *commenceBlock = (BasicBlock*) _commenceBlock;
	
	#define thisBlock builder -> GetInsertBlock()

	/*** configuration modes ***/
	if((mode == 0) || (mode == 1)) {
		switch(tree[node].type & FSE_Type_Mask) {
			case FSE_Command:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_Block:
						if(tree[node].children) [self emit: tree[node].firstChild];
						nkids = tree[node].children; c = tree[node].firstChild;
						if(nkids > 1) for(i = 0; i < nkids - 1; i++) {
							c = tree[c].nextSibling;
							[self emit: c];
						}
						break;
					case FSE_Dyn:
					case FSE_Par:
						[self emit: tree[node].firstChild];
						break;
					case FSE_Default:
						if(mode == 0) ++defaults;
						if(mode == 1) {
							mode = 2;
							lhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
							mode = 1;
							GetElementPtrInst* outd = GetElementPtrInst::Create(outputP, LLVMi32(defaults++),
								"&out[defaults++]", thisBlock);
							builder -> CreateStore(lhs, outd);
						}
						break;
				}
		}
	}
	
	/*** active modes ***/
	else {
		if(tree[node].value && (tree[node].cachePass == mode)) {  // don't reprocess if we've already done it
			return tree[node].value;
		}
		else if(tree[node].value && (tree[node].cachePass != mode)) tree[node].value = nil;
		if(tree[node].cloneOf) {
			c = node;
			while(tree[c].cloneOf) c = tree[c].cloneOf;
			if((tree[c].cachedAt == 0) || (tree[c].cachePass != mode)) {
				tree[c].cachedAt = 42;
				tree[c].value = [self emit: c];
			}
			tree[c].cachePass = mode;
			return tree[c].value;
		}
		else switch(tree[node].type & FSE_Type_Mask) {
			case FSE_Command:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_Block:
						[self emit: tree[node].firstChild];
						nkids = tree[node].children; c = tree[node].firstChild;
						if(nkids > 1) for(i = 0; i < nkids - 1; i++) {
							c = tree[c].nextSibling; 
							[self emit: c];
						}
						break;
					case FSE_Set:
						/* LHS of FSE_Set is supposed to be a Variable, so we can take its aux[0] to index */
						{
							int v = tree[tree[node].firstChild].auxi[0];
							rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
							ptr = GetElementPtrInst::Create(xP, LLVMi32(v),
								[[NSString stringWithFormat: @"&x[%i]", v] cString], thisBlock);
							builder -> CreateStore(rhs, ptr,
								[[NSString stringWithFormat: @"x[%i]", v] cString]);
						}
						break;
					case FSE_Succeed:
						ptr = GetElementPtrInst::Create(jP, LLVMi32(tree[node].auxi[0]),
							[[NSString stringWithFormat: @"&j[%i]", tree[node].auxi[0]] cString], thisBlock);
						builder -> CreateStore(LLVMi32(0), ptr,
							[[NSString stringWithFormat: @"j[%i]", tree[node].auxi[0]] cString]);
						break;
					case FSE_Fail:
						ptr = GetElementPtrInst::Create(jP, LLVMi32(tree[node].auxi[0]),
							[[NSString stringWithFormat: @"&j[%i]", tree[node].auxi[0]] cString], thisBlock);
						builder -> CreateStore(maxIt, ptr,
							[[NSString stringWithFormat: @"j[%i]", tree[node].auxi[0]] cString]);
						break;
					case FSE_Flag:
						builder -> CreateStore(LLVMi32(tree[node].auxi[0]), flagP);
						break;
					case FSE_Do:
						{
							int jDepth = tree[node].auxi[0];
							BasicBlock* incomingBlock = thisBlock;
							BasicBlock* loopBlock = BasicBlock::Create("FSE_Do", llvmKernel);
							builder -> CreateBr(loopBlock);
							builder -> SetInsertPoint(loopBlock);
							PHINode* j = builder -> CreatePHI(IntegerType::get(32), [[NSString stringWithFormat: @"j%i.", jDepth] cString]);
							j -> addIncoming(LLVMi32(0), incomingBlock);

								[self emit: tree[node].firstChild];		// emit loop body
								Value* nextj = builder -> CreateAdd(j, LLVMi32(1),
									[[NSString stringWithFormat: @"(j%i + 1)", jDepth] cString]);
								Value* jMaxedCond = builder -> CreateICmpEQ(nextj, maxIt);
								Value* endCond = (Value*) [self emit: tree[tree[node].firstChild].nextSibling]; // emit exit condition
								Value* stopCond = builder -> CreateOr(jMaxedCond, endCond);
								BasicBlock* loopEndBlock = BasicBlock::Create("FSE_Do cleanup", llvmKernel);
								builder -> CreateCondBr(stopCond, loopEndBlock, loopBlock);
								j -> addIncoming(nextj, thisBlock);
							
							builder -> SetInsertPoint(loopEndBlock);
							ptr = GetElementPtrInst::Create(jP, LLVMi32(jDepth), [[NSString stringWithFormat: @"j[%i]", jDepth] cString], thisBlock);
							builder -> CreateStore(j, ptr);
						}
						break;
					case FSE_Report:
						lhs = (Value*) [self emit: tree[node].firstChild];
						builder -> CreateStore(lhs, reportxP);
						if(tree[node].children > 1) {
							lhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
							builder -> CreateStore(lhs, reportyP);
						}
						builder -> CreateStore(LLVMi32(1), reportedP);
						break;
					case FSE_If:
						{
							BasicBlock* trueBlock = BasicBlock::Create("true", llvmKernel);
							BasicBlock* falseBlock = BasicBlock::Create("false", llvmKernel);
							BasicBlock* mergeBlock = BasicBlock::Create("merge", llvmKernel);
							Value* ifCond = (Value*) [self emit: tree[node].firstChild];
							builder -> CreateCondBr(ifCond, trueBlock, falseBlock);
							builder -> SetInsertPoint(trueBlock);
								[self emit: tree[tree[node].firstChild].nextSibling];
								builder -> CreateBr(mergeBlock);
							builder -> SetInsertPoint(falseBlock);
								if(tree[node].children > 2) [self emit: tree[tree[tree[node].firstChild].nextSibling].nextSibling];
								builder -> CreateBr(mergeBlock);
							builder -> SetInsertPoint(mergeBlock);
						}
						break;
					case FSE_Else:
						/* this should already get emitted by the associated FSE_If */
						break;
					case FSE_Iterate:
						NSLog(@"**** FSE_Iterate nodes should have been changed to FSE_Do in the tree generator\n");
/*
						fprintf(fp, " FSE_Iterate starts here \n");
						fprintf(fp, "for(j[%i] = 0; j[%i] < maxiter; j[%i]++) {\n",
								tree[node].auxi[0], tree[node].auxi[0], tree[node].auxi[0]);
						// emit code here 
						i = emitSubtreeFrom(tree[node].firstChild, tree, fp);
						j = tree[tree[node].firstChild].nextSibling;
						if(tree[node].children == 3)  { k = emitSubtreeFrom(j, tree, fp); j = tree[j].nextSibling; }
						else k = 0;
						fprintf(fp, "x[%i] = x[%i];\n", k, i);
						// emit test condition here 
						emitSubtreeFrom(j, tree, fp);
						fprintf(fp, "if(");
						emitSubtreeFrom(j, tree, fp);
						fprintf(fp, ") break;\n");
						fprintf(fp, "}\n");
						fprintf(fp, " FSE_Iterate ends here \n");
*/
						break;
					case FSE_Probe:
						{
							Value* prb = builder -> CreateLoad(probeP);
							Value* probeCond = builder -> CreateICmpEQ(prb, LLVMi32(tree[node].auxi[1]));
							BasicBlock* probeBlock = BasicBlock::Create(
								[[NSString stringWithFormat: @"probe%i.", tree[node].auxi[1]] cString], llvmKernel);
							BasicBlock* noprobeBlock = BasicBlock::Create(
								[[NSString stringWithFormat: @"skipprobe%i.", tree[node].auxi[1]] cString], llvmKernel);
							builder -> CreateCondBr(probeCond, probeBlock, noprobeBlock);
							builder -> SetInsertPoint(probeBlock);
							[self emit: tree[node].firstChild];
							Value* reported = builder -> CreateLoad(reportedP);
							Value* reportedCond = builder -> CreateICmpEQ(reported, LLVMi32(0));
							BasicBlock* createReportBlock = BasicBlock::Create(
								[[NSString stringWithFormat: @"default report for probe %i.", tree[node].auxi[1]] cString], llvmKernel);
							BasicBlock* probeReturnBlock = BasicBlock::Create(
								[[NSString stringWithFormat: @"probe%i return", tree[node].auxi[1]] cString], llvmKernel);
							builder -> CreateCondBr(reportedCond, createReportBlock, probeReturnBlock);
							builder -> SetInsertPoint(createReportBlock);
							ptr = GetElementPtrInst::Create(xP, LLVMi32(0), "&x[0]", thisBlock);
							Value* x0 = builder -> CreateLoad(ptr, "x[0]");
							builder -> CreateStore(x0, reportxP);
							ptr = GetElementPtrInst::Create(xP, LLVMi32(1), "&x[1]", thisBlock);
							Value* x1 = builder -> CreateLoad(ptr, "x[1]");
							builder -> CreateStore(x1, reportyP);
							builder -> CreateBr(probeReturnBlock);
							builder -> SetInsertPoint(probeReturnBlock);
							Value* r0 = builder -> CreateLoad(reportxP, "reportX");
							Value* r1 = builder -> CreateLoad(reportyP, "reportY");
							Value* idx = builder -> CreateMul(LLVMi32(3), loop_i, "3i");
							Value* idx1 = builder -> CreateAdd(idx, LLVMi32(0), "3*i + 0");
							Value* idx2 = builder -> CreateAdd(idx, LLVMi32(1), "3*i + 1");
							Value* idx3 = builder -> CreateAdd(idx, LLVMi32(2), "3*i + 2");
							GetElementPtrInst* out1 = GetElementPtrInst::Create(outputP, idx1, "out[(3*i) + 0]", thisBlock);
							builder -> CreateStore(r0, out1);
							GetElementPtrInst* out2 = GetElementPtrInst::Create(outputP, idx2, "out[(3*i) + 1]", thisBlock);
							builder -> CreateStore(r1, out2);
							GetElementPtrInst* out3 = GetElementPtrInst::Create(outputP, idx3, "out[(3*i) + 2]", thisBlock);
							builder -> CreateStore(LLVMd(tree[node].auxf[0]), out3);
							builder -> CreateRetVoid();
							builder -> SetInsertPoint(noprobeBlock);							
						}
						break;
					case FSE_Par:
						if(mode == 2) [self emit: tree[node].firstChild];
						break;
					case FSE_Dyn:
						if(mode == 3) [self emit: tree[node].firstChild];
						break;
					case FSE_Default:
						{
							int L = tree[tree[node].firstChild].auxi[0];
							int R = tree[tree[node].firstChild].auxi[1];
							ptr = GetElementPtrInst::Create(inputP, LLVMi32(R + 5),
								[[NSString stringWithFormat: @"&input[%i]", R + 5] cString], thisBlock);
							rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"input[%i]", R + 5] cString]);
							ptr = GetElementPtrInst::Create(xP, LLVMi32(L),
								[[NSString stringWithFormat: @"&x[%i]", L] cString], thisBlock);
							builder -> CreateStore(rhs, ptr,
								[[NSString stringWithFormat: @"x[%i]", L] cString]);
						}
						break;
					case FSE_Clear:
						NSLog(@"**** use of FSE_Clear should be removed or complexified in tree generator\n");
						{
							int v = tree[node].auxi[1];
							ptr = GetElementPtrInst::Create(xP, LLVMi32(v),
								[[NSString stringWithFormat: @"&x[%i]", v] cString], thisBlock);
							builder -> CreateStore(big2, ptr,
								[[NSString stringWithFormat: @"x[%i]", v] cString]);
							++v;
							ptr = GetElementPtrInst::Create(xP, LLVMi32(v),
								[[NSString stringWithFormat: @"&x[%i]", v] cString], thisBlock);
							builder -> CreateStore(big2, ptr,
								[[NSString stringWithFormat: @"x[%i]", v] cString]);
						}
						break;
					case FSE_Repeat:
						{
							int jDepth = tree[node].auxi[0];
							BasicBlock* incomingBlock = thisBlock;
							BasicBlock* loopBlock = BasicBlock::Create("FSE_Repeat", llvmKernel);
							builder -> CreateBr(loopBlock);
							builder -> SetInsertPoint(loopBlock);
							lhs = (Value*) [self emit: tree[node].firstChild];
							Value* j0 = builder -> CreateFPToUI(lhs, IntegerType::get(32));
							PHINode* j = builder -> CreatePHI(IntegerType::get(32), [[NSString stringWithFormat: @"j%i.", jDepth] cString]);
							j -> addIncoming(j0, incomingBlock);

								[self emit: tree[tree[node].firstChild].nextSibling];		// emit loop body
								Value* nextj = builder -> CreateSub(j, LLVMi32(1),
									[[NSString stringWithFormat: @"(j%i - 1)", jDepth] cString]);
								Value* jZeroCond = builder -> CreateICmpSLE(nextj, LLVMi32(0));
								BasicBlock* loopEndBlock = BasicBlock::Create("FSE_Repeat cleanup", llvmKernel);
								builder -> CreateCondBr(jZeroCond, loopEndBlock, loopBlock);
								j -> addIncoming(nextj, thisBlock);
							
							builder -> SetInsertPoint(loopEndBlock);
							ptr = GetElementPtrInst::Create(jP, LLVMi32(jDepth), [[NSString stringWithFormat: @"&j[%i]", jDepth] cString], thisBlock);
							builder -> CreateStore(j, ptr);
						}
						break;
					case FSE_DataLoop:
						// this construct iterates over a list of data from an external source
						{
							int jDepth = tree[node].auxi[0];
							char name[256];
							Module* mod = (Module*) module;
							ExecutionEngine* EE = (ExecutionEngine*) [[FSJitter jitter] engine];
							
							// Resolve the data source name, get the function pointer and call
							sprintf(name, "%s-%s-%i", tree[node].name, postfixID, emitStep);
							void* dataSourcePtr = [dataManager getFunctionPointerForData: [NSString stringWithUTF8String: tree[node].name]];
							Constant* c = mod -> getOrInsertFunction([[NSString stringWithFormat: @"data source %s", name] cString],
								IntegerType::get(32),
								PointerType::get(Type::DoubleTy, 0),
								PointerType::get(Type::DoubleTy, 0),
								NULL);
							Function* mathf = cast<Function>(c);
							mathf -> setCallingConv(CallingConv::C);
							EE -> addGlobalMapping(mathf, dataSourcePtr);
							void* dataEvalPtr = [dataManager getFunctionPointerForEval: [NSString stringWithUTF8String: tree[node].name]];
							Constant* c0 = mod -> getOrInsertFunction([[NSString stringWithFormat: @"data evaluator %s", name] cString],
																	 IntegerType::get(32),
																	 PointerType::get(Type::DoubleTy, 0),
																	 PointerType::get(IntegerType::get(32), 0),
																	 NULL);
							Function* mathf0 = cast<Function>(c0);
							mathf0 -> setCallingConv(CallingConv::C);
							EE -> addGlobalMapping(mathf0, dataEvalPtr);
							if(dataSourcePtr) { 
								int child = tree[node].firstChild;
								BasicBlock* incomingBlock = thisBlock;
								BasicBlock* loopBlock = BasicBlock::Create("FSE_DataLoop", llvmKernel);
								BasicBlock* loopEndBlock = BasicBlock::Create("FSE_DataLoop cleanup", llvmKernel);
								BasicBlock* skipLoopBlock = BasicBlock::Create("FSE_DataLoop skip", llvmKernel);
								BasicBlock* mergeLoopBlock = BasicBlock::Create("FSE_DataLoop merge", llvmKernel);
						
								rhs = (Value*) [self emit: tree[child].firstChild]; 
								ptr = GetElementPtrInst::Create(dsInP, LLVMi32(0), "&dataSourceIn[0]", thisBlock);
								builder -> CreateStore(rhs, ptr, "dataSourceIn[0]");
								rhs = (Value*) [self emit: tree[tree[child].firstChild].nextSibling];
								child = tree[child].nextSibling;
								ptr = GetElementPtrInst::Create(dsInP, LLVMi32(1), "&dataSourceIn[1]", thisBlock);
								builder -> CreateStore(rhs, ptr, "dataSourceIn[1]");

								std::vector<Value*> args;
								args.push_back(dsInP);
								args.push_back(dsOutP);
								Value* count = builder -> CreateCall(mathf, args.begin(), args.end(), name);
								// at this point, count is set and dsOutP is loaded with data.  skip loop if count is nonpositive.
								Value* jZeroCond = builder -> CreateICmpSLE(count, LLVMi32(0));
								builder -> CreateCondBr(jZeroCond, skipLoopBlock, loopBlock);
								builder -> SetInsertPoint(loopBlock);
								PHINode* j = builder -> CreatePHI(IntegerType::get(32), [[NSString stringWithFormat: @"j%i.", jDepth] cString]);
								j -> addIncoming(LLVMi32(0), incomingBlock);
								
								// load the data for this iteration into the specified variable
								int v = tree[tree[child].firstChild].auxi[0]; 
								int v0 = v;
								Value* idx = builder -> CreateMul(j, LLVMi32(2));
								Value* rhsP = GetElementPtrInst::Create(dsOutP, idx, [[NSString stringWithFormat: @"&dsOutP[2*j[%i]]", jDepth] cString], thisBlock);
								rhs = builder -> CreateLoad(rhsP, [[NSString stringWithFormat: @"dsOutP[2*j[%i]]", jDepth] cString]);
								ptr = GetElementPtrInst::Create(xP, LLVMi32(v), [[NSString stringWithFormat: @"&x[%i]", v] cString], thisBlock);
								builder -> CreateStore(rhs, ptr, [[NSString stringWithFormat: @"x[%i]", v] cString]);
								v = tree[tree[tree[child].firstChild].nextSibling].auxi[0];
								int v1 = v;
								child = tree[child].nextSibling;
								Value* idxp1 = builder -> CreateAdd(idx, LLVMi32(1));
								rhsP = GetElementPtrInst::Create(dsOutP, idxp1, [[NSString stringWithFormat: @"&dsOutP[2*j[%i]+1]", jDepth] cString], thisBlock);
								rhs = builder -> CreateLoad(rhsP, [[NSString stringWithFormat: @"dsOutP[2*j[%i]+1]", jDepth] cString]);
								ptr = GetElementPtrInst::Create(xP, LLVMi32(v), [[NSString stringWithFormat: @"&x[%i]", v] cString], thisBlock);
								builder -> CreateStore(rhs, ptr, [[NSString stringWithFormat: @"x[%i]", v] cString]);
								
								[self emit: child]; // emit loop body
								NSLog(@"here\n");
								ptr = GetElementPtrInst::Create(xP, LLVMi32(v0), [[NSString stringWithFormat: @"&x[%i]", v0] cString], thisBlock);
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"x[%i]", v0] cString]);
								lhs = GetElementPtrInst::Create(dsResPl, idx, [[NSString stringWithFormat: @"dataSourceResLoc[_]"] cString], thisBlock);
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"s"] cString]);
								NSLog(@".\n");
								ptr = GetElementPtrInst::Create(xP, LLVMi32(v1), [[NSString stringWithFormat: @"&x[%i]", v1] cString], thisBlock);
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"x[%i]", v1] cString]);
								lhs = GetElementPtrInst::Create(dsResPl, idxp1, [[NSString stringWithFormat: @"dataSourceResLoc[_+1]"] cString], thisBlock);
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"s"] cString]);
								NSLog(@".\n");
								rhs = builder -> CreateLoad(flagP, [[NSString stringWithFormat: @"flag"] cString]);
								lhs = GetElementPtrInst::Create(dsResPf, idx, [[NSString stringWithFormat: @"dataSourceResFlag[_]"] cString], thisBlock);
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"s"] cString]);
								NSLog(@".\n");
								ptr = GetElementPtrInst::Create(jP, LLVMi32(jDepth+1), [[NSString stringWithFormat: @"j[%i]", jDepth] cString], thisBlock);
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"j[%i]", jDepth] cString]);
								lhs = GetElementPtrInst::Create(dsResPf, idxp1, [[NSString stringWithFormat: @"dataSourceResFlag[_+1]"] cString], thisBlock);
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"s"] cString]);
								NSLog(@".\n");

														  
								Value* nextj = builder -> CreateAdd(j, LLVMi32(1),
									[[NSString stringWithFormat: @"(j[%i] + 1)", jDepth] cString]);
								Value* jCond = builder -> CreateICmpEQ(nextj, count);
								builder -> CreateCondBr(jCond, loopEndBlock, loopBlock);
								j -> addIncoming(nextj, thisBlock);
							
								builder -> SetInsertPoint(loopEndBlock);
//								ptr = GetElementPtrInst::Create(jP, LLVMi32(jDepth), [[NSString stringWithFormat: @"&j[%i]", jDepth] cString], thisBlock);
//								builder -> CreateStore(count, ptr);

								NSLog(@"ok\n");
								std::vector<Value*> args0;
								args0.push_back(dsResPl);
								args0.push_back(dsResPf);
								builder -> CreateCall(mathf0, args0.begin(), args0.end(), name);
								NSLog(@".\n");

								lhs = GetElementPtrInst::Create(xP, LLVMi32(v0), [[NSString stringWithFormat: @"&x[%i]", v0] cString], thisBlock);
								ptr = GetElementPtrInst::Create(dsResPl, LLVMi32(0), [[NSString stringWithFormat: @"&dataSourceResLoc[0]"] cString], thisBlock);
								NSLog(@".\n");
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"dataSourceResLoc[0]"] cString]);
								NSLog(@".\n");
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"s"] cString]);
								NSLog(@".\n");

 
								NSLog(@".\n");
								lhs = GetElementPtrInst::Create(xP, LLVMi32(v1), [[NSString stringWithFormat: @"&x[%i]", v1] cString], thisBlock);
								ptr = GetElementPtrInst::Create(dsResPl, LLVMi32(1), [[NSString stringWithFormat: @"&dataSourceResLoc[1]"] cString], thisBlock);
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"dataSourceResLoc[1]"] cString]);
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"s"] cString]);
								NSLog(@".\n");

								NSLog(@".\n");
								ptr = GetElementPtrInst::Create(dsResPf, LLVMi32(0), [[NSString stringWithFormat: @"&dataSourceResFlag[0]"] cString], thisBlock);
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"dataSourceResFlag[0]"] cString]);
								builder -> CreateStore(rhs, flagP, [[NSString stringWithFormat: @"->flag"] cString]);
								NSLog(@". [jDepth = %i]\n", jDepth);
								lhs = GetElementPtrInst::Create(jP, LLVMi32(jDepth), [[NSString stringWithFormat: @"&j[%i]", jDepth] cString], thisBlock);
								ptr = GetElementPtrInst::Create(dsResPf, LLVMi32(1), [[NSString stringWithFormat: @"&dataSourceResFlag[1]"] cString], thisBlock);
								rhs = builder -> CreateLoad(ptr, [[NSString stringWithFormat: @"dataSourceResFlag[0]"] cString]);
								builder -> CreateStore(rhs, lhs, [[NSString stringWithFormat: @"->j[%i]", jDepth] cString]);
								NSLog(@".\n");
								

								
								
								builder -> CreateBr(mergeLoopBlock);
								
								builder -> SetInsertPoint(skipLoopBlock);
								builder -> CreateBr(mergeLoopBlock);
								
								builder -> SetInsertPoint(mergeLoopBlock);
							}
						}
						break;
					case FSE_Modulo:
						NSLog(@"**** FSE_Modulo needs updating\n");
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
							std::vector<Value*> args;
							args.push_back(lhs);
							args.push_back(rhs);
							Value* reduction = builder -> CreateCall((Function*) _f_fmod, args.begin(), args.end(), "fmod");
							ptr = GetElementPtrInst::Create(xP, LLVMi32(tree[tree[node].firstChild].auxi[0]),
								[[NSString stringWithFormat: @"&x[%i]", tree[tree[node].firstChild].auxi[0]] cString], thisBlock);
							builder -> CreateStore(reduction, ptr);
						}

						break;
				}
				break;
			case FSE_Arith:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_Add:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateAdd(lhs, rhs);
						break;
					case FSE_Sub:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateSub(lhs, rhs);
						break;
					case FSE_Mul:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateMul(lhs, rhs);
						break;
					case FSE_Div:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateFDiv(lhs, rhs);
						break;
					case FSE_Norm:
						break;
					case FSE_Norm2:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateMul(lhs, lhs);
						break;
					case FSE_Conj:
						break;
					case FSE_Neg:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateMul(LLVMd(-1.0), lhs);
						break;
					case FSE_Inv:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateFDiv(LLVMd(1.0), lhs);
						break;
					case FSE_Square:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateMul(lhs, lhs);
						break;
					case FSE_Power:
						NSLog(@"**** FSE_Power needs an update!\n");
/*						lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
						eSF_was_const = 0;
						rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
						out = tree[node].auxi[0];
						if(eSF_was_const) {
							fprintf(fp, " FSE_Power: got a constant\n");
							if(eSF_const_y != 0.0) fprintf(fp, "constant has imaginary part, ignoring\n");
							j = (int) eSF_const_x;
							fprintf(fp, "exponent is %i\n", j);
							k = 0; flag = 0;
							for(i = 0; i < sizeof(int) * 8; i++) if(j & (1 << i)) k = i + 1;
							fprintf(fp, "{\ndouble multiplier;\nmultiplier = x[%i];\n", lhs);
							fprintf(fp, "x[%i] = 1.0;\n", out);
							if(k) {
								for(i = 0; i < k - 1; i++) {
									if(j & (1 << i)) {
										fprintf(fp, "x[%i] *= multiplier;\n", out);
									}
									fprintf(fp, "multiplier *= multiplier;\n");
								}
							}
							fprintf(fp, "}\n");
						}
						else {
							fprintf(fp, "FSE_Power can not deal with variables in the exponent.\n");
						}
*/
						break;
					default:
						break;
				}
				break;
			case FSE_Bool:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_Or:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateOr(lhs, rhs);
						break;
					case FSE_And:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateAnd(lhs, rhs);
						break;
					case FSE_Xor:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateXor(lhs, rhs);
						break;
					case FSE_Nor:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						{
							Value* notThis = builder -> CreateOr(lhs, rhs);
							tree[node].value = (void*) builder -> CreateNot(notThis);
						}
						break;
					case FSE_Nand:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						{
							Value* notThis = builder -> CreateAnd(lhs, rhs);
							tree[node].value = (void*) builder -> CreateNot(notThis);
						}
						break;
					case FSE_Not:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateNot(lhs);
						break;
					default:
						break;
				}
				break;
			case FSE_Comp:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_NotEqual:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						{
							Value* t1 = builder -> CreateSub(lhs, rhs);
							Value* t2 = builder -> CreateMul(t1, t1);
							tree[node].value = (void*) builder -> CreateFCmpOGE(t2, tiny2);
						}
						break;
					case FSE_Equal:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						{
							Value* t1 = builder -> CreateSub(lhs, rhs);
							Value* t2 = builder -> CreateMul(t1, t1);
							tree[node].value = (void*) builder -> CreateFCmpOLT(t2, tiny2);
						}
						break;
					case FSE_LTE:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateFCmpOLE(lhs, rhs);
						break;
					case FSE_GTE:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateFCmpOGE(lhs, rhs);
						break;
					case FSE_LT:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateFCmpOLT(lhs, rhs);
						break;
					case FSE_GT:
						lhs = (Value*) [self emit: tree[node].firstChild];
						rhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
						tree[node].value = (void*) builder -> CreateFCmpOGT(lhs, rhs);
						break;
					case FSE_Escapes:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateFCmpOGT(lhs, big2);
						break;
					case FSE_Vanishes:
						lhs = (Value*) [self emit: tree[node].firstChild];
						tree[node].value = (void*) builder -> CreateFCmpOLT(lhs, tiny2);
						break;
					case FSE_Stops:
						NSLog(@"***** FSE_Stops should have been stripped by now\n");
						break;
					default:
						break;
				}
				break;
			case FSE_Var:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_Complex:
					case FSE_Real:
					case FSE_PosReal:
					case FSE_Truth:
					case FSE_C_Const:
					case FSE_R_Const:
						NSLog(@"deprecated FSE_Var node\n");
						break;
					case FSE_Ident:
						tree[node].value = [self emit: tree[node].firstChild];
						break;
					case FSE_LinkedSubexpression:
						tree[node].value = [self emit: tree[node].auxi[0]];
						break;
					case FSE_Variable:
						ptr = GetElementPtrInst::Create(xP, LLVMi32(tree[node].auxi[0]),
							[[NSString stringWithFormat: @"&x[%i]", tree[node].auxi[0]] cString], thisBlock);
						tree[node].value = (void*) builder -> CreateLoad(ptr,
							[[NSString stringWithFormat: @"x[%i]", tree[node].auxi[0]] cString]);
						break;
					case FSE_Constant:
						tree[node].value = (void*) LLVMd(tree[node].auxf[0]);
						eSF_was_const = 1;
						eSF_const_x = tree[node].auxf[0];
						eSF_const_y = 0.0;
						break;
					default:
						break;
				}
				break;
			case FSE_Func:
				switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
					case FSE_Exp:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_exp, args.begin(), args.end(), "exp");
						}
						break;
					case FSE_Log:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_log, args.begin(), args.end(), "log");
						}
						break;
					case FSE_Sqrt:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_sqrt, args.begin(), args.end(), "sqrt");
						}
						break;
					case FSE_Cosh:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_cosh, args.begin(), args.end(), "cosh");
						}
						break;
					case FSE_Sinh:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_sinh, args.begin(), args.end(), "sinh");
						}
						break;
					case FSE_Tanh:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_tanh, args.begin(), args.end(), "tanh");
						}
						break;
					case FSE_Cos:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_cos, args.begin(), args.end(), "cos");
						}
						break;
					case FSE_Sin:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_sin, args.begin(), args.end(), "sin");
						}
						break;
					case FSE_Tan:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_tan, args.begin(), args.end(), "tan");
						}
						break;
					case FSE_Random:
						{
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_frandom, "uniform-random");
						}
						break;
					case FSE_Gaussian:
						{
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_gaussian, "gaussian-random");
						}
						break;
					case FSE_Arccos:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_acos, args.begin(), args.end(), "acos");
						}
						break;
					case FSE_Arcsin:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_asin, args.begin(), args.end(), "asin");
						}
						break;
					case FSE_Arctan:
						{
							lhs = (Value*) [self emit: tree[node].firstChild];
							std::vector<Value*> args;
							args.push_back(lhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_atan, args.begin(), args.end(), "atan");
						}
						break;
					case FSE_Arg:
						{
							rhs = (Value*) [self emit: tree[node].firstChild];
							lhs = (Value*) [self emit: tree[tree[node].firstChild].nextSibling];
							std::vector<Value*> args;
							args.push_back(lhs);
							args.push_back(rhs);
							tree[node].value = (void*) builder -> CreateCall((Function*) _f_atan2, args.begin(), args.end(), "atan2");
						}
						break;
					case FSE_Im:
						break;
					case FSE_Re:
						break;
					default:
						break;
				}
				break;
		}
		if(((tree[node].type & FSE_Type_Mask) == FSE_Arith) ||
		   ((tree[node].type & FSE_Type_Mask) == FSE_Func) ||
		   ((tree[node].type & FSE_Type_Mask) == FSE_Var)) { tree[node].cachedAt = 42; tree[node].cachePass = mode; }
	}
	tree[node].cachePass = mode;
	return tree[node].value;
	#undef thisBlock
}

- (void) buildLLVMKernel {
	llvm::Module* mod = new llvm::Module("LLVM Kernel");
	module = (void*) mod;

#define thisBlock builder.GetInsertBlock()

	val = (void**) malloc(sizeof(Value*) * [[compiler tree] size]);
	tree = [[compiler tree] nodeAt: 0];
	int node = tree[0].firstChild;
	int savedNode = 0;
	
	// Build the kernel function's interface
	Constant* c = mod -> getOrInsertFunction("kernel",
		Type::VoidTy,							/* (void)			*/
		IntegerType::get(32),					/* int program		*/
		PointerType::get(Type::DoubleTy, 0),	/* double* input	*/
		IntegerType::get(32),					/* int length		*/
		PointerType::get(Type::DoubleTy, 0),	/* double* output	*/
		IntegerType::get(32),					/* int maxIter		*/
		Type::DoubleTy,							/* double maxRadius */
		Type::DoubleTy,							/* double minRadius */
		NULL);
	Function* llvmKernel = cast<Function>(c);
	llvmKernel -> setCallingConv(CallingConv::C);
	Function::arg_iterator args = llvmKernel -> arg_begin();
	Value* program = args++;	program ->	setName("program");
	Value* input = args++;		input ->	setName("input");
	Value* length = args++;		length ->	setName("length");
	Value* output = args++;		output ->	setName("output");
	Value* maxIter = args++;	maxIter ->	setName("maxIter");
	Value* maxRadius = args++;	maxRadius-> setName("maxRadius");
	Value* minRadius = args++;	minRadius->	setName("minRadius");
	
	std::vector<const Type*> nothing(0, Type::DoubleTy);
	std::vector<const Type*> oneDouble(1, Type::DoubleTy);
	std::vector<const Type*> twoDoubles(2, Type::DoubleTy);
	FunctionType* ft = FunctionType::get(Type::DoubleTy, oneDouble, false);
	FunctionType* ft2 = FunctionType::get(Type::DoubleTy, twoDoubles, false);
	FunctionType* ft0 = FunctionType::get(Type::DoubleTy, nothing, false);
	Function* mathf;

	/*** Build extern declarations for math functions ***/
		mathf = Function::Create(ft, Function::ExternalLinkage,   "exp", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_exp = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "log", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_log = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "sqrt", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_sqrt = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "cos", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_cos = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "sin", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_sin = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "tan", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_tan = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "acos", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_acos = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "asin", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_asin = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "atan", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_atan = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "cosh", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_cosh = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "sinh", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_sinh = (void*) mathf;

		mathf = Function::Create(ft, Function::ExternalLinkage,   "tanh", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_tanh = (void*) mathf;

		mathf = Function::Create(ft2, Function::ExternalLinkage,  "atan2", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_atan2 = (void*) mathf;

		mathf = Function::Create(ft2, Function::ExternalLinkage,  "fmod", mod);
		mathf -> setCallingConv(CallingConv::C);				_f_fmod = (void*) mathf;
		
		ExecutionEngine* EE = (ExecutionEngine*) [[FSJitter jitter] engine];

		mathf = cast<Function> (mod -> getOrInsertFunction("frandom", Type::DoubleTy, (Type *)0));
		mathf -> setCallingConv(CallingConv::C);				_f_frandom = (void*) mathf;
		EE -> addGlobalMapping(mathf, (void*) frandom);

		mathf = cast<Function> (mod -> getOrInsertFunction("gaussian", Type::DoubleTy, (Type *)0));
		mathf -> setCallingConv(CallingConv::C);				_f_gaussian = (void*) mathf;
		EE -> addGlobalMapping(mathf, (void*) gaussian);

	/*** end of externs ***/
	
	BasicBlock* block = BasicBlock::Create("entry", llvmKernel);
	IRBuilder<> builder(block);
	bldr = (void*) &builder;
	
	BasicBlock* initModeBlock = BasicBlock::Create("initialization modes", llvmKernel);
	BasicBlock* runModeBlock = BasicBlock::Create("execution modes");

	GetElementPtrInst *x, *j, *tmpP, *tmp2P, *tmp3P;
	Value *tmp, *tmp2, *tmp3;
	AllocaInst* jP = builder.CreateAlloca(Type::Int32Ty, LLVMi32([compiler maximumLoopDepth]), "j[]");	
	AllocaInst* xP = builder.CreateAlloca(Type::DoubleTy, LLVMi32([compiler numberOfVariables]), "x[]");
	AllocaInst* flagP = builder.CreateAlloca(IntegerType::get(32), 0, "&flag");
	AllocaInst* probeP = builder.CreateAlloca(IntegerType::get(32), 0, "&probe");
	AllocaInst* lengthP = builder.CreateAlloca(IntegerType::get(32), 0, "&length");
	AllocaInst* crP = builder.CreateAlloca(Type::DoubleTy, 0, "cr");
	AllocaInst* ciP = builder.CreateAlloca(Type::DoubleTy, 0, "ci");
	AllocaInst* reportedP = builder.CreateAlloca(IntegerType::get(32), 0, "&reported");
	AllocaInst* reportxP = builder.CreateAlloca(Type::DoubleTy, 0, "reportX");
	AllocaInst* reportyP = builder.CreateAlloca(Type::DoubleTy, 0, "reportY");
	AllocaInst* dsInP = builder.CreateAlloca(Type::DoubleTy, LLVMi32(2), "dataSourceIn[]");
	AllocaInst* dsOutP = builder.CreateAlloca(Type::DoubleTy, LLVMi32(512), "dataSourceOut[]");
	AllocaInst* dsResPl = builder.CreateAlloca(Type::DoubleTy, LLVMi32(512), "dataSourceResLoc[]");
	AllocaInst* dsResPf = builder.CreateAlloca(IntegerType::get(32), LLVMi32(512), "dataSourceResFlag[]");
	
	Value* big2 = builder.CreateMul(maxRadius, maxRadius, "huge");
	Value* tiny2 = builder.CreateMul(minRadius, minRadius, "tiny");
	builder.CreateStore(length, lengthP);
	builder.CreateStore(LLVMi32(0), flagP);
	builder.CreateStore(LLVMi32(0), reportedP); 
	builder.CreateStore(LLVMi32(0), probeP);
	Value* cond;
	
	BasicBlock* useProbeBlock = BasicBlock::Create("using a probe", llvmKernel);
	BasicBlock* endUseProbeBlock = BasicBlock::Create("select mode", llvmKernel);
	Value* useProbe = builder.CreateICmpSLT(length, LLVMi32(0));
	builder.CreateCondBr(useProbe, useProbeBlock, endUseProbeBlock);
	builder.SetInsertPoint(useProbeBlock);
		Value* probeNumber = builder.CreateMul(length, LLVMi32(-1));
		builder.CreateStore(probeNumber, probeP);
		builder.CreateStore(LLVMi32(1), lengthP);
		builder.CreateBr(endUseProbeBlock);
	builder.SetInsertPoint(endUseProbeBlock);
	Value* initCond = builder.CreateICmpSLE(program, LLVMi32(0), "initCond");
	builder.CreateCondBr(initCond, initModeBlock, runModeBlock);
			
	bldr = (void*) &builder;
	_llvmKernel = (void*) llvmKernel;
	_inputP = (void*) input; _outputP = (void*) output; _flagP = (void*) flagP;
	_xP = (void*) xP; _jP = (void*) jP;
	_reportxP = (void*) reportxP; _reportyP = (void*) reportyP;
	_reportedP = (void*) reportedP; _probeP = (void*) probeP;
	_maxIt = (void*) maxIter; _big2 = (void*) big2; _tiny2 = (void*) tiny2;
	_dsInP = (void*) dsInP; _dsOutP = (void*) dsOutP;
	_dsResPf = (void*) dsResPf; _dsResPl = (void*) dsResPl;
	
	defaults = 0; pass = 0;
	
	builder.SetInsertPoint(initModeBlock);
		BasicBlock* initBlock = BasicBlock::Create("initialization", llvmKernel);
		BasicBlock* elseBlock = BasicBlock::Create("else");
		cond = builder.CreateICmpEQ(program, LLVMi32(-1), "initializationCond");
		builder.CreateCondBr(cond, initBlock, elseBlock);
		builder.SetInsertPoint(initBlock);

			/* * * * * */
			/* emit the initialization block */
			/* * * * * */
			_loop_i = NULL; _commenceBlock = NULL;
			mode = -1;
			[self emit: node];
			node = tree[node].nextSibling;
			
		builder.CreateRetVoid();
		llvmKernel -> getBasicBlockList().push_back(elseBlock);
		builder.SetInsertPoint(elseBlock);
		BasicBlock* defcntBlock = BasicBlock::Create("defaults count", llvmKernel);
		elseBlock = BasicBlock::Create("else");
		cond = builder.CreateICmpEQ(program, LLVMi32(-2), "defcntCond");
		builder.CreateCondBr(cond, defcntBlock, elseBlock);
		builder.SetInsertPoint(defcntBlock);

			/* * * * * */
			/* emit defaults count */
			/* * * * * */
			mode = 0;
			_loop_i = NULL; _commenceBlock = NULL;
			[self emit: node];
			GetElementPtrInst* defCountPtr = GetElementPtrInst::Create(output, LLVMi32(0), "tmp", defcntBlock);
			builder.CreateStore(LLVMd((double) defaults), defCountPtr);
			
		builder.CreateRetVoid();
		llvmKernel -> getBasicBlockList().push_back(elseBlock);
		builder.SetInsertPoint(elseBlock);
		BasicBlock* defvalBlock = BasicBlock::Create("defaults values", llvmKernel);
		elseBlock = BasicBlock::Create("else");
		cond = builder.CreateICmpEQ(program, LLVMi32(-3), "defvalCond");
		builder.CreateCondBr(cond, defvalBlock, elseBlock);
		builder.SetInsertPoint(defvalBlock);

			/* * * * * */
			/* emit defaults values */
			/* * * * * */
			mode = 1;
			_loop_i = NULL; _commenceBlock = NULL;
			defaults = 0;
			[self emit: node];
			
		builder.CreateRetVoid();
		llvmKernel -> getBasicBlockList().push_back(elseBlock);
		builder.SetInsertPoint(elseBlock);
		builder.CreateRetVoid();
	llvmKernel -> getBasicBlockList().push_back(runModeBlock);
	builder.SetInsertPoint(runModeBlock);
		/* run mode stuff here */
		BasicBlock* parBlock = BasicBlock::Create("parameter space code", llvmKernel);
		BasicBlock* dynBlock = BasicBlock::Create("dynamical space code");
		cond = builder.CreateICmpEQ(program, LLVMi32(1), "programCond");
		builder.CreateCondBr(cond, parBlock, dynBlock);
		builder.SetInsertPoint(parBlock);
		{ // main iteration loop for working in parameter space
			/* Input processing loop */
			BasicBlock* InputLoop = BasicBlock::Create("input loop for parameter space", llvmKernel);
			BasicBlock* commenceBlock = BasicBlock::Create("commence", llvmKernel);
			builder.CreateBr(InputLoop);
			builder.SetInsertPoint(InputLoop);
			PHINode *loop_i = builder.CreatePHI(IntegerType::get(32), "i");
			loop_i -> addIncoming(LLVMi32(0), parBlock);
			{
				GetElementPtrInst* in0 = GetElementPtrInst::Create(input, LLVMi32(0), "&in[0]", InputLoop);
				GetElementPtrInst* in1 = GetElementPtrInst::Create(input, LLVMi32(1), "&in[1]", InputLoop);
				GetElementPtrInst* in2 = GetElementPtrInst::Create(input, LLVMi32(2), "&in[2]", InputLoop);
				Value* c0 = builder.CreateLoad(in0, "in[0]");
				Value* c1 = builder.CreateLoad(in1, "in[1]");
				Value* step = builder.CreateLoad(in2, "in[2]");
				Value* doublei = builder.CreateUIToFP(loop_i, Type::DoubleTy, "(double) i");
				Value* istep = builder.CreateMul(step, doublei, "i * step");
				Value* c00 = builder.CreateAdd(c0, istep, "in[0] + i * in[2]");
				builder.CreateStore(LLVMi32(0), flagP);
				builder.CreateStore(LLVMi32(0), reportedP);
				x = GetElementPtrInst::Create(xP, LLVMi32(0), "&x[0]", thisBlock);
				builder.CreateStore(LLVMd(0.0), x);
				x = GetElementPtrInst::Create(xP, LLVMi32(1), "&x[1]", thisBlock);
				builder.CreateStore(LLVMd(0.0), x);
				x = GetElementPtrInst::Create(xP, LLVMi32(2), "&x[2]", thisBlock);
				builder.CreateStore(c00, x);
				x = GetElementPtrInst::Create(xP, LLVMi32(3), "&x[3]", thisBlock);
				builder.CreateStore(c1, x);
				tmpP = GetElementPtrInst::Create(input, LLVMi32(5), "&in[5]", thisBlock);
				x = GetElementPtrInst::Create(xP, LLVMi32(4), "&x[4]", thisBlock);
				tmp = builder.CreateLoad(tmpP, "in[5]");
				builder.CreateStore(tmp, x);
				tmpP = GetElementPtrInst::Create(input, LLVMi32(6), "&in[6]", thisBlock);
				x = GetElementPtrInst::Create(xP, LLVMi32(5), "&x[5]", thisBlock);
				tmp = builder.CreateLoad(tmpP, "in[6]");
				builder.CreateStore(tmp, x);
				{
					tmpP = GetElementPtrInst::Create(jP, LLVMi32(0), "&j[0]", thisBlock);
					builder.CreateStore(LLVMi32(0), tmpP);
					mode = 2;		/*** Emit parameter space code ***/
					_loop_i = (void*) loop_i; _commenceBlock = (void*) commenceBlock;
					[self emit: node];
				}
				tmpP = GetElementPtrInst::Create(jP, LLVMi32(0), "&j[0]", thisBlock);
				Value* lastJ = builder.CreateLoad(tmpP, "last-j");
				Value* lastJp1 = builder.CreateAdd(lastJ, LLVMi32(1), "last-j + 1");
				Value* shiftedJ = builder.CreateShl(lastJp1, LLVMi32(8), "shifted j");
				Value* flg = builder.CreateLoad(flagP, "flag");
				Value* retStatus = builder.CreateOr(shiftedJ, flg, "int status");
				{
					Value* reported = builder.CreateLoad(reportedP);
					Value* reportedCond = builder.CreateICmpEQ(reported, LLVMi32(0));
					BasicBlock* createReportBlock = BasicBlock::Create("default report", llvmKernel);
					BasicBlock* reportReadyBlock = BasicBlock::Create("report ready", llvmKernel);
					builder.CreateCondBr(reportedCond, createReportBlock, reportReadyBlock);
					builder.SetInsertPoint(createReportBlock);
					GetElementPtrInst *ptr = GetElementPtrInst::Create(xP, LLVMi32(0), "&x[0]", thisBlock);
					Value* x0 = builder.CreateLoad(ptr, "x[0]");
					builder.CreateStore(x0, reportxP);
					ptr = GetElementPtrInst::Create(xP, LLVMi32(1), "&x[1]", thisBlock);
					Value* x1 = builder.CreateLoad(ptr, "x[1]");
					builder.CreateStore(x1, reportyP);
					builder.CreateBr(reportReadyBlock);
					builder.SetInsertPoint(reportReadyBlock);
					Value* r0 = builder.CreateLoad(reportxP, "reportX");
					Value* r1 = builder.CreateLoad(reportyP, "reportY");
					Value* idx = builder.CreateMul(LLVMi32(3), loop_i, "3i");
					Value* idx1 = builder.CreateAdd(idx, LLVMi32(0), "3*i + 0");
					Value* idx2 = builder.CreateAdd(idx, LLVMi32(1), "3*i + 1");
					Value* idx3 = builder.CreateAdd(idx, LLVMi32(2), "3*i + 2");
					GetElementPtrInst* out1 = GetElementPtrInst::Create(output, idx1, "out[(3*i) + 0]", thisBlock);
					builder.CreateStore(r0, out1);
					GetElementPtrInst* out2 = GetElementPtrInst::Create(output, idx2, "out[(3*i) + 1]", thisBlock);
					builder.CreateStore(r1, out2);
					GetElementPtrInst* out3 = GetElementPtrInst::Create(output, idx3, "out[(3*i) + 2]", thisBlock);
					Value* o3 = builder.CreateUIToFP(retStatus, Type::DoubleTy, "status");
					builder.CreateStore(o3, out3);
				}
				// end of main body for i loop	
			}
			builder.CreateBr(commenceBlock);
			builder.SetInsertPoint(commenceBlock);
			Value* next_i = builder.CreateAdd(loop_i, LLVMi32(1), "iplus1");
			Value* iMax = builder.CreateLoad(lengthP, "iMax");
			Value* loop_cond = builder.CreateICmpEQ(next_i, iMax, "input loop condition");
			BasicBlock* currentBlock = builder.GetInsertBlock();  // we've changed which block we are writing to
			BasicBlock* PostBlock = BasicBlock::Create("postblock", llvmKernel);
			builder.CreateCondBr(loop_cond, PostBlock, InputLoop);
			builder.SetInsertPoint(PostBlock);
			loop_i -> addIncoming(next_i, currentBlock);
			builder.CreateRetVoid();
		}
		llvmKernel -> getBasicBlockList().push_back(dynBlock);
		builder.SetInsertPoint(dynBlock);
		{ // main iteration loop for working in dynamical space
			/* Input processing loop */
			BasicBlock* InputLoop = BasicBlock::Create("input loop for dynamical space", llvmKernel);
			BasicBlock* commenceBlock = BasicBlock::Create("commence", llvmKernel);
			builder.CreateBr(InputLoop);
			builder.SetInsertPoint(InputLoop);
			PHINode *loop_i = builder.CreatePHI(IntegerType::get(32), "i");
			loop_i -> addIncoming(LLVMi32(0), dynBlock);
			{
				/* Script code here */
				GetElementPtrInst* in3 = GetElementPtrInst::Create(input, LLVMi32(3), "&in[3]", InputLoop);
				GetElementPtrInst* in4 = GetElementPtrInst::Create(input, LLVMi32(4), "&in[4]", InputLoop);
				Value* c0 = builder.CreateLoad(in3, "in[3]");
				Value* c1 = builder.CreateLoad(in4, "in[4]");
				GetElementPtrInst* in2 = GetElementPtrInst::Create(input, LLVMi32(2), "&in[2]", InputLoop);
				Value* step = builder.CreateLoad(in2, "in[2]");
				Value* doublei = builder.CreateUIToFP(loop_i, Type::DoubleTy, "(double) i");
				Value* istep = builder.CreateMul(step, doublei, "i * step");
				GetElementPtrInst* x0p = GetElementPtrInst::Create(input, LLVMi32(0), "&in[0]", InputLoop);
				Value* x0 = builder.CreateLoad(x0p, "in[0]");
				Value* x00 = builder.CreateAdd(x0, istep, "in[0] + i * in[2]");
				builder.CreateStore(LLVMi32(0), flagP);
				builder.CreateStore(LLVMi32(0), reportedP);
				x = GetElementPtrInst::Create(xP, LLVMi32(0), "&x[0]", thisBlock);
				builder.CreateStore(x00, x);
				x = GetElementPtrInst::Create(xP, LLVMi32(1), "&x[1]", thisBlock);
				tmpP = GetElementPtrInst::Create(input, LLVMi32(1), "&in[1]", InputLoop);
				tmp = builder.CreateLoad(tmpP, "in[1]");
				builder.CreateStore(tmp, x);
				x = GetElementPtrInst::Create(xP, LLVMi32(2), "&x[2]", thisBlock);
				builder.CreateStore(c0, x);
				x = GetElementPtrInst::Create(xP, LLVMi32(3), "&x[3]", thisBlock);
				builder.CreateStore(c1, x);
				tmpP = GetElementPtrInst::Create(input, LLVMi32(5), "&in[5]", thisBlock);
				x = GetElementPtrInst::Create(xP, LLVMi32(4), "&x[4]", thisBlock);
				tmp = builder.CreateLoad(tmpP, "in[5]");
				builder.CreateStore(tmp, x);
				tmpP = GetElementPtrInst::Create(input, LLVMi32(6), "&in[6]", thisBlock);
				x = GetElementPtrInst::Create(xP, LLVMi32(5), "&x[5]", thisBlock);
				tmp = builder.CreateLoad(tmpP, "in[6]");
				builder.CreateStore(tmp, x);
				{
					tmpP = GetElementPtrInst::Create(jP, LLVMi32(0), "&j[0]", thisBlock);
					builder.CreateStore(LLVMi32(0), tmpP);
					mode = 3;		/*** Emit dynamical space code ***/
					_loop_i = (void*) loop_i; _commenceBlock = (void*) commenceBlock;
					[self emit: node];
				}	
				tmpP = GetElementPtrInst::Create(jP, LLVMi32(0), "&j[0]", thisBlock);
				Value* lastJ = builder.CreateLoad(tmpP, "last-j");
				Value* lastJp1 = builder.CreateAdd(lastJ, LLVMi32(1), "last-j + 1");
				Value* shiftedJ = builder.CreateShl(lastJp1, LLVMi32(8), "shifted j");
				Value* flg = builder.CreateLoad(flagP, "flag");
				Value* retStatus = builder.CreateOr(shiftedJ, flg, "int status");
				{
					Value* reported = builder.CreateLoad(reportedP);
					Value* reportedCond = builder.CreateICmpEQ(reported, LLVMi32(0));
					BasicBlock* createReportBlock = BasicBlock::Create("default report", llvmKernel);
					BasicBlock* reportReadyBlock = BasicBlock::Create("report ready", llvmKernel);
					builder.CreateCondBr(reportedCond, createReportBlock, reportReadyBlock);
					builder.SetInsertPoint(createReportBlock);
					GetElementPtrInst *ptr = GetElementPtrInst::Create(xP, LLVMi32(0), "&x[0]", thisBlock);
					Value* x0 = builder.CreateLoad(ptr, "x[0]");
					builder.CreateStore(x0, reportxP);
					ptr = GetElementPtrInst::Create(xP, LLVMi32(1), "&x[1]", thisBlock);
					Value* x1 = builder.CreateLoad(ptr, "x[1]");
					builder.CreateStore(x1, reportyP);
					builder.CreateBr(reportReadyBlock);
					builder.SetInsertPoint(reportReadyBlock);
					Value* r0 = builder.CreateLoad(reportxP, "reportX");
					Value* r1 = builder.CreateLoad(reportyP, "reportY");
					Value* idx = builder.CreateMul(LLVMi32(3), loop_i, "3i");
					Value* idx1 = builder.CreateAdd(idx, LLVMi32(0), "3*i + 0");
					Value* idx2 = builder.CreateAdd(idx, LLVMi32(1), "3*i + 1");
					Value* idx3 = builder.CreateAdd(idx, LLVMi32(2), "3*i + 2");
					GetElementPtrInst* out1 = GetElementPtrInst::Create(output, idx1, "out[(3*i) + 0]", thisBlock);
					builder.CreateStore(r0, out1);
					GetElementPtrInst* out2 = GetElementPtrInst::Create(output, idx2, "out[(3*i) + 1]", thisBlock);
					builder.CreateStore(r1, out2);
					GetElementPtrInst* out3 = GetElementPtrInst::Create(output, idx3, "out[(3*i) + 2]", thisBlock);
					Value* o3 = builder.CreateUIToFP(retStatus, Type::DoubleTy, "status");
					builder.CreateStore(o3, out3);
				}
				// end of main body for i loop	
			}		
			builder.CreateBr(commenceBlock);
			builder.SetInsertPoint(commenceBlock);
			Value* next_i = builder.CreateAdd(loop_i, LLVMi32(1), "iplus1");
			Value* iMax = builder.CreateLoad(lengthP, "iMax");
			Value* loop_cond = builder.CreateICmpEQ(next_i, iMax, "input loop condition");
			BasicBlock* currentBlock = builder.GetInsertBlock();  // we've changed which block we are writing to
			BasicBlock* PostBlock = BasicBlock::Create("postblock", llvmKernel);
			builder.CreateCondBr(loop_cond, PostBlock, InputLoop);
			builder.SetInsertPoint(PostBlock);
			loop_i -> addIncoming(next_i, currentBlock);
			builder.CreateRetVoid();
		}


	if(verifyModule(*mod, PrintMessageAction)) { NSLog(@"module did not verify\n"); llvmKernel -> dump(); return; }
	else NSLog(@"module verified\n");

	ExistingModuleProvider* MP = new ExistingModuleProvider(mod);
	[jitter addModuleProvider: (void*) MP];
	
	PassManager PM;	
	PM.add(new TargetData(*((TargetData*) [jitter targetData])));
	PM.add(createPromoteMemoryToRegisterPass());
	PM.add(createInstructionCombiningPass());
	PM.add(createGVNPREPass());
	PM.add(createGVNPass());
	PM.add(createReassociatePass());

	PM.run(*mod);

//	llvmKernel -> dump();
	
	kernelPtr = (void (*)(int, double*, int, double*, int, double, double)) [jitter getPointerToFunction: (void*) llvmKernel];
}

#undef thisBlock

- (void*) loadKernelFromFile: (NSString*) filename {
#ifndef WINDOWS
	void* dmodule;
	dmodule = dlopen([filename cString], RTLD_NOW);
	NSLog(@"module is %p, filename is %@\n", dmodule, filename);
	if(dmodule == NULL) return NULL;
	kernelPtr = (void(*)(int,double*,int,double*,int,double,double)) dlsym(dmodule, "kernel");
	NSLog(@"kernelPtr is %p\n", (void*) kernelPtr);
	return (void*) kernelPtr;
#else
	return (void*) NULL;
#endif
}

- (void) runKernelWithMode: (int) mde input: (double*) input ofLength: (int) length output: (double*) output maxIter: (int) maxIter maxNorm: (double) maxNorm minNorm: (double) minNorm {
	kernelPtr(mde, input, length, output, maxIter, maxNorm, minNorm);
}

- (void*) kernelPtr { 
	return (void*) kernelPtr;
}

- (void) setDataManager: (FSCustomDataManager*) dm { dataManager = dm; }


@end
