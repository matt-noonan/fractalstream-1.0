#import "FSECompiler.h"
#import <stdlib.h>
#import "FSECompilerSymbols.H"


@implementation FSECompiler

- (id) init {
	self = [super init];
	flags = [[NSMutableArray alloc] init];
	[flags addObject: [NSString stringWithString: @"Default Exit Condition"]];
	probes = [[NSMutableArray alloc] init];
	currentFlagID = 1;
	specialTools = nil;
	source = symbol = title = nil;
	usesC = 0;
	nextvar = 0;
	return self;
}

- (void) awakeFromNib { NSLog(@"FSECompiler %@ woke from nib\n", self); }

#define FSSymbol_NIL		-1
#define FSSymbol_WHITESPACE 0
#define FSSymbol_COMMAND	1
#define FSSymbol_VARIABLE	2
#define FSSymbol_FUNCTION	3
#define FSSymbol_PERIOD		4
#define FSSymbol_PUNCT		5
#define FSSymbol_CHAR		6
#define FSSymbol_OPERATOR	7
#define FSSymbol_PAREN		8
#define FSSymbol_NUMBER		9
#define FSSymbol_CONSTANT	10

- (int) typeOf: (unichar) c
{
	if((c == ' ') || (c == '\n') || (c == '\t') || (c == '\r') || ((c >= 0x0009) && (c <= 0x000d)) ||
		(c == 0x0085) || (c == 0x00a0) || (c == 0x1680) || (c == 0x180e) || ((c >= 0x2000) && (c <= 0x200a)) ||
		(c == 0x2028) || (c == 0x2029) || (c == 0x202f) || (c == 0x205f) || (c == 0x3000)) return FSSymbol_WHITESPACE;
	if((c == '(') || (c == ')') || (c == '[') || (c == ']') || (c == '{') || (c == '}')) return FSSymbol_PAREN;
	if((c == '.') || (c == ',') || (c == ':') || (c == '\"')) return FSSymbol_PUNCT;
	if((c == '+') || (c == '-') || (c == '*') || (c == '/') || (c == '|') || (c == '!')
		|| (c == '&') || (c == '>') || (c == '<') || (c == '=') || (c == '^') 
		|| (c == 0x2020)) return FSSymbol_OPERATOR;
	if((c == '0') || (c == '1') || (c == '2') || (c == '3') || (c == '4') || 
		(c == '5') || (c == '6') || (c == '7') || (c == '8') || (c == '9')) return FSSymbol_NUMBER;
	if((c == 0x03c0)) return FSSymbol_CONSTANT;
	else return FSSymbol_CHAR;
}


- (int) currentSymbolType
{
	unichar c;
	if(index < [source length]) {
		c = [source characterAtIndex: index];
		return [self typeOf: c];
	}
	else return FSSymbol_NIL;
}

- (BOOL) symbolIsAtomic
{
	unichar c;
	if([symbol length] == 0) return NO;
	c = [symbol characterAtIndex: 0];
	return (([self typeOf: c] == FSSymbol_CHAR)
		|| ([self typeOf: c] == FSSymbol_NUMBER)
		|| ([self typeOf: c] == FSSymbol_CONSTANT))? YES : NO;
}

- (BOOL) isCharacter: (unichar) c
{
	NSLog(@"---- DONT USE THIS ----\n");
	if((c == ' ') || (c == '\n') || (c == '\t') || (c == '\r') ||
		(c == '(') || (c == ')') || (c == '[') || (c == ']') || (c == '.') ||
		(c == '+') || (c == '-') || (c == '*') || (c == '/') || (c == '|') || (c == '!')
		|| (c == '&') || (c == '>') || (c == '<') || (c == '=') || (c == '^') 
		|| (c == 0x2020)) return NO;
	return YES;
}

- (void) readNextSymbol
{
	int oldindex, max;
	int type;
	NSRange range;
	BOOL wasNumber;
	
	max = [source length];
	if(index >= max) { symbol = nil; return; }
	while([self currentSymbolType] == FSSymbol_WHITESPACE) { ++index;
		if(index >= max) { symbol = nil; return; }
	}
	oldindex = index; type = [self currentSymbolType];
	if(type == FSSymbol_PAREN) {
		range.location = index; range.length = 1; ++index;
		symbol = [NSString stringWithString: [source substringWithRange: range]];
		lastRange = range;
		return;
	}
	if(type == FSSymbol_PUNCT) {
		range.location = index; range.length = 1; ++index;
		symbol = [NSString stringWithString: [source substringWithRange: range]];
		lastRange = range;
		return;
	}
	if(type == FSSymbol_NUMBER) {
		wasNumber = YES;
		while([self currentSymbolType] == FSSymbol_NUMBER) {
			++index; if(index >= max) break;
		}
	}
	else wasNumber = NO;
	if(index < max) if([source characterAtIndex: index] == '.') {
		++index;
		if([self currentSymbolType] != FSSymbol_NUMBER) --index;
		else type = FSSymbol_NUMBER;
	}
//	if([self currentSymbolType] == FSSymbol_PUNCT) ++index;
//	while(([self currentSymbolType] == type) && ([self currentSymbolType] != FSSymbol_PUNCT)) { ++index; if(index >= max) break; }
	while(([self currentSymbolType] == type)) { ++index; if(index >= max) break; }
	if(index < max) if((type == FSSymbol_NUMBER)
		&& ([source characterAtIndex: index] == 'i')) ++index;
	range.location = oldindex; range.length = index - oldindex;
	if((type == FSSymbol_NUMBER) && (wasNumber == NO)) {
		symbol = [NSString stringWithFormat: @"0%@", [source substringWithRange: range]];
	}
	else symbol = [NSString stringWithString: [source substringWithRange: range]];
	lastRange = range;
}


/* this macro is used several times in -extractArithBelowNode: to create a data node */
#define EVALUATE_YOURSELF \
	if(isEvalNode == NO) { \
		if([lastSymbol isEqualToString: @"#"]) { \
			lhs = [tree newNodeOfType: (FSE_Var | FSE_Counter) at: parent]; \
		} \
		else if(([self typeOf: [lastSymbol characterAtIndex: 0]] == FSSymbol_NUMBER) || (useComplexVars && [lastSymbol isEqualToString: @"i"])) { \
			double x, y; FSEParseNode* num; \
			if(useComplexVars) { \
				int tempn;\
				x = y = 0.0;  \
				if([lastSymbol isEqualToString: @"i"]) y = 1.0; \
				else if([lastSymbol characterAtIndex: [lastSymbol length] - 1] == 'i') { \
					y = [[lastSymbol substringToIndex: [lastSymbol length] - 1] doubleValue]; \
				} \
				else x = [lastSymbol doubleValue]; \
				if(y != 0.0) { \
					lhs = [tree newNodeOfType: (FSE_Var | FSE_Join) at: parent]; \
					[tree nodeAt: [tree newNodeOfType: (FSE_Var | FSE_Constant) at: lhs]] -> auxf[0] = 0.0; \
					[tree nodeAt: [tree newNodeOfType: (FSE_Var | FSE_Constant) at: lhs]] -> auxf[0] = y; \
				} \
				else { \
					lhs = [tree newNodeOfType: (FSE_Var | FSE_Constant) at: parent]; \
					[tree nodeAt: lhs] -> auxf[0] = x; \
				} \
			} \
			else { \
				x = [lastSymbol doubleValue]; \
				lhs = [tree newNodeOfType: (FSE_Var | FSE_Constant) at: parent]; \
				[tree nodeAt: lhs] -> auxf[0] = x; \
			} \
		} \
		else if([self typeOf: [lastSymbol characterAtIndex: 0]] == FSSymbol_CONSTANT) { \
			if([lastSymbol length] > 1) { \
				error = @"bad constant"; \
				lhs = [tree newNodeOfType: (FSE_Var | FSE_Constant) at: parent]; \
				[tree nodeAt: lhs] -> auxf[0] = 0.0; \
			} \
			else { \
				unichar cchar; \
				double x; \
				cchar = [lastSymbol characterAtIndex: 0]; x = 0.0; \
				if(cchar == 0x03c0) x = 3.14159265358979323846; \
				if(x == 0.0) error = @"unknown constant??"; \
				lhs = [tree newNodeOfType: (FSE_Var | FSE_Constant) at: parent]; \
				[tree nodeAt: lhs] -> auxf[0] = x; \
			} \
		} \
		else { \
			/* make a variable evaluation node */ \
			int varIndex; \
			varIndex = [self indexOfVariableWithName: lastSymbol]; \
			if(useComplexVars && (var[varIndex].type == 1)) { \
				lhs = [tree newNodeOfType: (FSE_Var | FSE_Join) at: parent]; \
				[tree nodeAt: [tree newNodeOfType: (FSE_Var | FSE_Variable) at: lhs]] -> auxi[0] = varIndex; \
				[tree nodeAt: [tree newNodeOfType: (FSE_Var | FSE_Variable) at: lhs]] -> auxi[0] = varIndex + 1; \
			} \
			else { \
				lhs = [tree newNodeOfType: (FSE_Var | FSE_Variable) at: parent]; \
				[tree nodeAt: lhs] -> auxi[0] = varIndex; \
			} \
		} \
	} \
	else { \
		/* we started with a subexpression, just link it to the parent */ \
		[tree setParentOfNode: lhs to: parent]; \
	} 

/* attempts to extract an arithmetic expression from the source, returns the root node of the
	generated subtree on success, -1 on failure */
- (int) extractArithBelowNode: (int) parent
{
	int i, oldnode, type, lhs, oldindex, parenindex, vindex, ret, oldparent;
	BOOL isEvalNode;
	NSString* lastSymbol;
	
	[self readNextSymbol];
	
	/* if the symbol is an open paren, iterate */
	isEvalNode = NO;
	if([symbol isEqualToString: @"("] == YES) {
		int depth;
		/* create a new node to sire the subexpression */
		lhs = [tree newOrphanOfType: (FSE_Var | FSE_Ident)];
		[self extractArithBelowNode: lhs];
		parenindex = index; depth = 1;
		while(1) {
			[self readNextSymbol];
			if(symbol == nil) {
				error = [NSString stringWithString: @"error: runaway (, no )"];
				return -1;
			}
			if([symbol isEqualToString: @","]) {
				[tree nodeAt: lhs] -> type = FSE_Var | FSE_Join;
				[self extractArithBelowNode: lhs];
				continue;
			}
			else if([symbol isEqualToString: @"("]) ++depth;
			else if([symbol isEqualToString: @")"]) --depth;
			if(depth == 0) break;
		}
		isEvalNode = YES;
	}
	/* if the symbol is a number or variable, first check that it is not a reserved word.
		then, check the next symbol to see if it a postfix or a binary operator. */
	if(([self symbolIsAtomic] == YES) || (isEvalNode == YES)) {
		for(i = 0; i < reserved_ops; i++) {
			if([symbol isEqualToString: reserved[i].word] == YES) {
				error = [NSString stringWithString: @"error: reserved word"];
				return -1;
			}
		}
		for(i = 0; i < function_ops; i++) { /* is it a function name? */
			if([symbol isEqualToString: function[i].word] == YES) {
				lastSymbol = [NSString stringWithString: symbol];
				oldparent = parent;
//				NSLog(@"found function %@\n", symbol);
				parent = [tree newNodeOfType: (FSE_Func | function[i].code) at: oldparent];
//				if((function[i].code != FSE_Random) && (function[i].code != FSE_Gaussian))
					[self extractArithBelowNode: parent];
				return parent;
			}
		}
		lastSymbol = [NSString stringWithString: symbol];
		oldindex = index; [self readNextSymbol];
		for(i = 0; i < arith_postfix_ops; i++)
			if([symbol isEqualToString: arith_postfix[i].word] == YES) break;
		if(i != arith_postfix_ops) {
			/* found a postfix operator, so make a (postfix_op (eval _)) subtree */
/*			oldnode = node;	oldparent = parent;
			parent = [tree newNodeOfType: (FSE_Arith | arith_postfix[i].code) at: oldparent];
			EVALUATE_YOURSELF;
*/
			error = @"postfix arithmetic operators are disabled in this version of FractalStream.";
			return parent;
		}
		else {
			for(i = 0; i < arith_binary_ops; i++) {
				if([symbol isEqualToString: arith_binary[i].word] == YES) break;
			}
			if(i == arith_binary_ops) {
				/* not followed by a postfix or a binary operator, so just evaluate yourself */
				EVALUATE_YOURSELF;
				index = oldindex;
				return lhs;
			}
			if(i != arith_binary_ops) {
				oldparent = parent;
				parent = [tree newNodeOfType: (FSE_Arith | arith_binary[i].code) at: oldparent];
				EVALUATE_YOURSELF;
				[self extractArithBelowNode: parent];
				return parent;
			}
		}
	}
	else {
		/* we aren't a symbol or a variable, are we a prefix operator? */
		for(i = 0; i < arith_prefix_ops; i++)
			if([symbol isEqualToString: arith_prefix[i].word] == YES) break;
		if(i == arith_prefix_ops) {
			/* not a prefix operator either, must be done */
			return -1;
		}
		lastSymbol = [NSString stringWithString: symbol];
		oldparent = parent;
		parent = [tree newNodeOfType: (FSE_Arith | arith_prefix[i].code) at: oldparent];
		[self extractArithBelowNode: parent];
		return parent;
	}
}

- (int) extractBoolBelowNode: (int) parent
{
	int i, oldparent, expr, oldindex, length, newparent, temp;
	BOOL isEvalNode, wasParen;
	char cName[64];
	NSString* lastSymbol;
	NSString* name;

	wasParen = NO;
	oldindex = index; [self readNextSymbol];
	if([symbol isEqualToString: @"("] == YES) {
		int depth, lhs, savedindex;
		/* create a new node to sire the subexpression */
		lhs = [tree newOrphanOfType: (FSE_Var | FSE_Ident)];
		[self extractBoolBelowNode: lhs];
		depth = 1;
		while(1) {
			[self readNextSymbol];
			if(symbol == nil) {
				error = [NSString stringWithString: @"error: runaway (, no )"];
				return -1;
			}
			if([symbol isEqualToString: @","]) {
				[tree nodeAt: lhs] -> type = FSE_Var | FSE_Join;
				[self extractArithBelowNode: lhs];
				continue;
			}
			else if([symbol isEqualToString: @"("]) ++depth;
			else if([symbol isEqualToString: @")"]) --depth;
			if(depth == 0) break;
		}
		expr = lhs;
		wasParen = YES;
		oldindex = index;
		[self readNextSymbol];
		/* is it followed by a boolean operator? */
		for(i = 0; i < bool_binary_ops; i++) if([symbol isEqualToString: bool_binary[i].word] == YES) break;
		if(i != bool_binary_ops) {
			newparent = [tree newNodeOfType: (FSE_Bool | bool_binary[i].code) at: parent];
			[tree setParentOfNode: lhs to: newparent];
			[self extractBoolBelowNode: newparent];
			return newparent;
		}
	}

	if(wasParen == NO) {
		/* see if we have a logical prefix, if so make a node and iterate */
		for(i = 0; i < bool_prefix_ops; i++) if([symbol isEqualToString: bool_prefix[i].word] == YES) break;
		if(i != bool_prefix_ops) {
			oldparent = parent;
			parent = [tree newNodeOfType: (FSE_Bool | bool_prefix[i].code) at: oldparent];
			[self extractBoolBelowNode: parent];
			return parent;
		}
		/* otherwise, extract an arith. expression, must be put below an ident node temporarily :( */
		index = oldindex;
		expr = [tree newOrphanOfType: (FSE_Var | FSE_Ident)];
		[self extractArithBelowNode: expr];
		oldindex = index;
		[self readNextSymbol];
		/* is it followed by a boolean operator? */
		for(i = 0; i < bool_binary_ops; i++) if([symbol isEqualToString: bool_binary[i].word] == YES) break;
		if(i != bool_binary_ops) {
			newparent = [tree newNodeOfType: (FSE_Bool | bool_binary[i].code) at: parent];
			[tree setParentOfNode: expr to: newparent];
			[self extractBoolBelowNode: newparent];
			return newparent;
		}
	}
	/* is it followed by a binary comparison operator? */
	for(i = 0; i < comp_binary_ops; i++) if([symbol isEqualToString: comp_binary[i].word] == YES) break;
	if(i != comp_binary_ops) {
		int savedindex, compnode;
		compnode = [tree newOrphanOfType: (FSE_Comp | comp_binary[i].code)];
		[tree nodeAt: compnode] -> auxi[0] = -1;
		[tree setParentOfNode: expr to: compnode];
		[self extractArithBelowNode: compnode];
		savedindex = index;
		[self readNextSymbol];
		for(i = 0; i < bool_binary_ops; i++) if([symbol isEqualToString: bool_binary[i].word] == YES) break;
		if(i != bool_binary_ops) {
			newparent = [tree newNodeOfType: (FSE_Bool | bool_binary[i].code) at: parent];
			[tree setParentOfNode: compnode to: newparent];
			[self extractBoolBelowNode: newparent];
		}
		else { index = savedindex; [tree setParentOfNode: compnode to: parent]; parent = compnode; }
		return parent;
	}
	/* is it followed by a unary comparison operator? */
	for(i = 0; i < comp_postfix_ops; i++) if([symbol isEqualToString: comp_postfix[i].word] == YES) break;
	if(i != comp_postfix_ops) {
		int savedindex, compnode;
		compnode = [tree newOrphanOfType: (FSE_Comp | comp_postfix[i].code)];
		[tree nodeAt: compnode] -> auxi[0] = -1;
		[tree setParentOfNode: expr to: compnode];
		if(comp_postfix[i].code == FSE_Stops) {
			int resetnode;
			[tree nodeAt: compnode] -> auxi[1] = [self indexOfVariableWithName:
					[NSString stringWithFormat: @".stops.%i", compnode]];
			[tree nodeAt: compnode] -> auxf[0] = (useComplexVars? 2.0 : 1.0);
			resetnode = [tree newNodeOfType: (FSE_Command | FSE_Reset) at: compnode];
			[tree nodeAt: resetnode] -> auxi[0] = [self indexOfVariableWithName:
					[NSString stringWithFormat: @".stops.%i", compnode]];
			[tree nodeAt: resetnode] -> auxi[1] = expr;
			[tree nodeAt: resetnode] -> auxf[0] = (useComplexVars? 2.0 : 1.0);
		}
		/* is that followed by a boolean operator? */
		savedindex = index;
		[self readNextSymbol];
		for(i = 0; i < bool_binary_ops; i++) if([symbol isEqualToString: bool_binary[i].word] == YES) break;
		if(i != bool_binary_ops) {
			newparent = [tree newNodeOfType: (FSE_Bool | bool_binary[i].code) at: parent];
			[tree setParentOfNode: compnode to: newparent];
			[self extractBoolBelowNode: newparent];
		}
		else { index = savedindex; [tree setParentOfNode: compnode to: parent]; parent = compnode; }
		return parent;
	}
	
	/* none of the above, just link the expression we found */
	[tree setParentOfNode: expr to: parent];
	index = oldindex;
	return expr;
}

- (BOOL) extractCommandBelowNode: (int) parent {
	int node;
	[self readNextSymbol];
	if(symbol == nil) { error = @"script ended unexpectedly"; return NO; }
	else if([symbol isEqualToString: @"."]) { return YES; }
	else if([symbol isEqualToString: @"("]) {
		int pdepth;
		++index; pdepth = 1;
		while(pdepth > 0) {
			if([source characterAtIndex: index] == '(') ++pdepth;
			if([source characterAtIndex: index] == ')') --pdepth;
			++index;
			if(index >= [source length]) { error = @"runaway comment"; return NO; }
		}
		return YES;
	}
	else if([symbol isEqualToString: @"fail"]) {
		node = [tree newNodeOfType: FSE_Command | FSE_Fail at: parent];
		[tree nodeAt: node] -> auxi[0] = loopDepth;
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"fail.\"), got \"%@\" instead.", symbol];
		}
	}
	else if([symbol isEqualToString: @"succeed"]) {
		node = [tree newNodeOfType: FSE_Command | FSE_Succeed at: parent];
		[tree nodeAt: node] -> auxi[0] = loopDepth;
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"succeed.\"), got \"%@\" instead.", symbol];
		}
	}
	else if([symbol isEqualToString: @"reduce"]) {
		node = [tree newNodeOfType: FSE_Command | FSE_Modulo at: parent];
		[self extractArithBelowNode: node];
		[self readNextSymbol];
		if([symbol isEqualToString: @"mod"] == NO) {
			error = [NSString stringWithFormat: @"error: expected \"mod\" clause (\"reduce x mod y.\")"];
		}
		else [self extractArithBelowNode: node];
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"reduce ____ mod ____.\"), got \"%@\" instead.", symbol];
		}
		if(useComplexVars) {
			if(var[[tree nodeAt: [tree nodeAt: [tree nodeAt: node] -> firstChild] -> firstChild] -> auxi[0]].par == YES) {
				error = [NSString stringWithString: @"variables defined with \"default\" are read-only within a script.\n"];
			}
		}
		else {
			if(var[[tree nodeAt: [tree nodeAt: node] -> firstChild] -> auxi[0]].par == YES) {
				error = [NSString stringWithString: @"variables defined with \"default\" are read-only within a script.\n"];
			}
		}
	}		
	else if([symbol isEqualToString: @"set"]) {
		node = [tree newNodeOfType: FSE_Command | FSE_Set at: parent];
		[self extractArithBelowNode: node];
		[self readNextSymbol];
		if([symbol isEqualToString: @"to"] == NO) {
			error = [NSString stringWithFormat: @"error: expected \"to\" clause (\"set x to y.\")"];
		}
		else [self extractArithBelowNode: node];
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"set ____ to ____.\"), got \"%@\" instead.", symbol];
		}
		if(useComplexVars) {
			if(var[[tree nodeAt: [tree nodeAt: [tree nodeAt: node] -> firstChild] -> firstChild] -> auxi[0]].par == YES) {
				error = [NSString stringWithString: @"variables defined with \"default\" are read-only within a script.\n"];
			}
		}
		else {
			if(var[[tree nodeAt: [tree nodeAt: node] -> firstChild] -> auxi[0]].par == YES) {
				error = [NSString stringWithString: @"variables defined with \"default\" are read-only within a script.\n"];
			}
		}
	}
	else if([symbol isEqualToString: @"default"]) {
		int ch, v;
		if(useComplexVars) {
			int join;
			node = [tree newNodeOfType: FSE_Command | FSE_Default at: parent];
			ch = [self extractArithBelowNode: node];
			v = [tree nodeAt: [tree nodeAt: ch] -> firstChild] -> auxi[0];
			var[v].par = YES; var[v+1].par = YES;
			[tree nodeAt: [tree nodeAt: ch] -> firstChild] -> auxi[1] = [self parameterNumberOfVariableAtIndex: v];
			[tree nodeAt: [tree nodeAt: [tree nodeAt: ch] -> firstChild] -> nextSibling] -> auxi[1] =
																[self parameterNumberOfVariableAtIndex: v+1];
		}
		else {
			node = [tree newNodeOfType: FSE_Command | FSE_Default at: parent];
			ch = [self extractArithBelowNode: node];
			v = [tree nodeAt: ch] -> auxi[0];
			var[v].par = YES;
			[tree nodeAt: ch] -> auxi[1] = [self parameterNumberOfVariableAtIndex: v];
		}
//		NSLog(@"made variable %i into parametric variable %i\n", [tree nodeAt: ch] -> auxi[0], [tree nodeAt: ch] -> auxi[1]);
		[self readNextSymbol];
		if([symbol isEqualToString: @"to"] == NO) {
			error = [NSString stringWithFormat: @"error: expected \"to\" clause (\"default x to y.\")"];
		}
		else [self extractArithBelowNode: node];
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"default ____ to ____.\"), got \"%@\" instead.", symbol];
		}
	}
	else if([symbol isEqualToString: @"report"]) { 
		node = [tree newNodeOfType: FSE_Command | FSE_Report at: parent];
		[self extractArithBelowNode: node];
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"report ____.\"), got \"%@\" instead.", symbol];
		}
	}
	else if([symbol isEqualToString: @"["]) {
		NSString* name;
		NSRange range;
		NSEnumerator* flagEnum;
		NSString* testName;
		int savedindex, flagid;
		savedindex = index;
		while([source characterAtIndex: index] != ']') {
			++index;
			if(index >= [source length]) { error = @"runaway flag"; break; }
		}
		range.location = savedindex; range.length = index - savedindex;
		name = [NSString stringWithString: [literalSource substringWithRange: range]];
		[self readNextSymbol];
		node = [tree newNodeOfType: FSE_Command | FSE_Flag at: parent];
		flagid = 0;
		flagEnum = [flags objectEnumerator];
		while(testName = [flagEnum nextObject]) { if([name isEqualToString: testName]) break; ++flagid; }
		[tree nodeAt: node] -> auxi[0] = flagid;
		if(flagid >= currentFlagID) { ++currentFlagID; [flags addObject: name]; }
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"... [____].\"), got \"%@\" instead.", symbol];
		}
	}
	else if([symbol isEqualToString: @"block"] || ([symbol isEqualToString: @":"])) {
		int n;
		BOOL r;
		n = [tree newNodeOfType: FSE_Command | FSE_Block at: parent];
		while(r = [self extractCommandBelowNode: n]) ; // "end" will return NO but no error, so gets converted to YES.
	}
	else if([symbol isEqualToString: @"end"]) {
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"end.\"), got \"%@\" instead.", symbol];
		}
		return NO;
	}
	else if([symbol isEqualToString: @"if"]) {
		node = [tree newNodeOfType: FSE_Command | FSE_If at: parent];
		[self extractBoolBelowNode: node];
		[self readNextSymbol];
		[tree nodeAt: node] -> auxi[0] = -1;
		if([symbol isEqualToString: @"then"] == YES) {
			int n, idx;
			BOOL r;
			n = [tree newNodeOfType: FSE_Command | FSE_Block at: node];
			r = [self extractCommandBelowNode: n];
			if(r == NO) return NO;
			idx = index;
			[self readNextSymbol];
			if([symbol isEqualToString: @"else"]) {
				n = [tree newNodeOfType: FSE_Command | FSE_Block at: node];
				return [self extractCommandBelowNode: n];
			}
			else index = idx;
		}
		else error = [NSString stringWithFormat: @"i do not know this syntax for if (symbol is %@)", symbol];
	}
	else if([symbol isEqualToString: @"load"]) {
		[self readNextSymbol];
		[specialTools addObject: symbol];
		[self readNextSymbol];
		if([symbol isEqualToString: @"."] == NO)
			error = [NSString stringWithFormat: @"expected \"load toolname.\", got %@ instead.", symbol];
	}
	else if([symbol isEqualToString: @"using"]) {
		[self readNextSymbol];
		if([symbol isEqualToString: @"each"]) {
			node = [tree newNodeOfType: FSE_Command | FSE_DataLoop at: parent];
			[tree nodeAt: node] -> auxi[0] = loopDepth;
			dataSourceIndex[dataSourceID] = node;
			[tree nodeAt: node] -> auxi[1] = dataSourceID++;
			[self extractArithBelowNode: node]; // first arg is index variable
			[self readNextSymbol];
			if([symbol isEqualToString: @"in"]) {
				[self readNextSymbol];
				if([symbol getCString: [tree nodeAt: node] -> name maxLength: 64 encoding: NSUTF8StringEncoding]) {
					[self readNextSymbol];
					if([symbol isEqualToString: @"at"]) {
						[self extractArithBelowNode: node];
						[tree swapBirthOrderAt: node];
						++loopDepth;
						[self extractCommandBelowNode: node];
						--loopDepth;
					}
					else error = [NSString stringWithFormat: @"expected \"using each ___ in ___ at ___\", got %@ instead", symbol]; 
				}
				else error = [NSString stringWithFormat: @"bad name for data source (must be no more than 64 bytes in UTF-8 encoding)."];
			}
			else error = [NSString stringWithFormat: @"expected \"using each ___ in ___\", got %@ instead", symbol];
		}
		else error = [NSString stringWithFormat: @"expected \"using each\", got %@ instead", symbol];
	}
	else if([symbol isEqualToString: @"repeat"]) {
		int tnode;
		node = [tree newNodeOfType: FSE_Command | FSE_Repeat at: parent];
		[tree nodeAt: node] -> auxi[0] = loopDepth; 
		tnode = [tree newNodeOfType: FSE_Func | FSE_Re at: node];
		[self extractArithBelowNode: tnode];
		[self readNextSymbol];
		if([symbol isEqualToString: @"times"] == YES) {
			++loopDepth;
			[self extractCommandBelowNode: node];
			--loopDepth;
		}
		else error = [NSString stringWithString: @"expected repeat command to end with \"times\""];
	}
	else if([symbol isEqualToString: @"do"]) { // "do" is equivalent to "iterate:"
		int n;
		BOOL r;
		node = [tree newNodeOfType: FSE_Command | FSE_Do at: parent];
		[tree nodeAt: node] -> auxi[0] = loopDepth;
		n = [tree newNodeOfType: FSE_Command | FSE_Block at: node];
		++loopDepth;
		while(r = [self extractCommandBelowNode: n]) ; // should return NO with error "until"
		--loopDepth;
		if([error isEqualToString: @"until"]) error = nil;
		else {
			error = [NSString stringWithString: @"no matching \"until\" for \"do\""];
			return NO;
		}
		[self extractBoolBelowNode: node];
		if([symbol isEqualToString: @"."] == NO) { 
			error = [NSString stringWithFormat: @"error: expected the sentence to end (\"...until ____.\"), got \"%@\" instead.", symbol];
		}
	}
	else if([symbol isEqualToString: @"until"] == YES) {
		error = [NSString stringWithString: @"until"];
		return NO;
	}
	else if([symbol isEqualToString: @"iterate"] == YES) {
		int setnode, varnode, jnode, v, n;
		node = [tree newNodeOfType: FSE_Command | FSE_Do at: parent];
		[tree nodeAt: node] -> auxi[0] = loopDepth;
		n = [tree newNodeOfType: FSE_Command | FSE_Block at: node];
		setnode = [tree newNodeOfType: FSE_Command | FSE_Set at: n];
		if(useComplexVars) {
			varnode = [tree newNodeOfType: FSE_Var | FSE_Join at: setnode];
			[tree nodeAt: [tree newNodeOfType: FSE_Var | FSE_Variable at: varnode]] -> auxi[0] = 0;
			[tree nodeAt: [tree newNodeOfType: FSE_Var | FSE_Variable at: varnode]] -> auxi[0] = 1;
		}
		else {
			varnode = [tree newNodeOfType: FSE_Var | FSE_Variable at: setnode];
			[tree nodeAt: varnode] -> auxi[0] = 0;
		}
		[self extractArithBelowNode: setnode];
		[self readNextSymbol];
		if([symbol isEqualToString: @"on"] == YES) {
			[tree deleteNodeAt: varnode];
			[self extractArithBelowNode: setnode];
			[tree swapBirthOrderAt: setnode];
			[self readNextSymbol];
			if(useComplexVars) {
				if(var[[tree nodeAt: [tree nodeAt: [tree nodeAt: setnode] -> firstChild] -> firstChild] -> auxi[0]].par == YES) {
					error = [NSString stringWithString: @"variables defined with \"default\" are read-only within a script.\n"];
				}
			}
			else {
				if(var[[tree nodeAt: [tree nodeAt: setnode] -> firstChild] -> auxi[0]].par == YES) {
					error = [NSString stringWithString: @"variables defined with \"default\" are read-only within a script.\n"];
				}
			}
		}
		if([symbol isEqualToString: @"until"] == YES) {
			[self extractBoolBelowNode: node];
			[self readNextSymbol];
			if([symbol isEqualToString: @"."] == NO) {
				error = [NSString stringWithFormat: @"error: expected the sentence to end (\"...until ____.\"), got \"%@\" instead.", symbol];
			}
		}
		else {
			error = [NSString stringWithFormat: @"error: expected \"until\" clause"];
		}
	}
	else if([symbol isEqualToString: @"probe"] == YES) {
		NSString* name;
		NSRange range;
		int savedindex;
		double probetype;
		savedindex = index;
		[self readNextSymbol];
		if		([symbol isEqualToString: @"complex"])	probetype = 0.0;
		else if	([symbol isEqualToString: @"real"])		probetype = 1.0;
		else if	([symbol isEqualToString: @"rational"]) probetype = 2.0;
		else if	([symbol isEqualToString: @"integer"])	probetype = 3.0;
		else										{   probetype = 0.0; index = savedindex; }
		node = [tree newNodeOfType: FSE_Command | FSE_Probe at: parent];
		[self readNextSymbol];
		if([symbol isEqualToString: @"\""] == NO) {
			error = [NSString stringWithFormat: @"error: expected the sentence to read (probe \"[probename]\"), got \"%@\" instead.", symbol];
		}
		savedindex = index;
		while([source characterAtIndex: index] != '\"') {
			++index;
			if(index >= [source length]) { error = @"runaway probe name"; break; }
		}
		range.location = savedindex; range.length = index - savedindex;
		name = [NSString stringWithString: [literalSource substringWithRange: range]];
		[self readNextSymbol];
		[probes addObject: name];
		[tree nodeAt: node] -> auxi[0] = loopDepth;
		[tree nodeAt: node] -> auxi[1] = ++probecount;
		[tree nodeAt: node] -> auxf[0] = probetype;
		[self extractCommandBelowNode: node];
	}
	else if([symbol isEqualToString: @"par"] == YES) {
		node = [tree newNodeOfType: FSE_Command | FSE_Par at: parent];
		[self extractCommandBelowNode: node];
	}
	else if([symbol isEqualToString: @"dyn"] == YES) {
		node = [tree newNodeOfType: FSE_Command | FSE_Dyn at: parent];
		[self extractCommandBelowNode: node];
	}
	else {
		error = [NSString stringWithFormat: @"syntax error, symbol is \"%@\".", symbol];
	}
	
	return error? NO : YES;
}


- (BOOL) usesCustom { return useCustom; }
- (NSString*) customPath { /*NSLog(@"customPath is \"%@\"\n", customPath);*/ return customPath; }

- (NSArray*) specialTools { return [NSArray arrayWithArray: specialTools]; }

- (IBAction) compile: (id) sender
{
	int prefixblock, codeblock, rootblock, t, savednode, tmpnode, savedcounter, savedroot, node;
	NSString *gcc, *ifile;
	char gccC[256], ifileC[256];
	BOOL reported, autopop, custom;
	FSEOpStream opstream;
	
//	NSLog(@"compiler %@ asked to compile by sender %@\n", self, sender);
	error = nil;
	[flags release], flags = nil;
	[probes release], probes = nil;
	flags = [[NSMutableArray alloc] init];
	probes = [[NSMutableArray alloc] init];
	[specialTools release];
	specialTools = [[NSMutableArray alloc] init];
	[flags addObject: [NSString stringWithString: @"Default Exit Condition"]];
	currentFlagID = 1;
	dataSourceID = 0;
	
	usesC = 0;
	int lastIf = -1;
	
	reported = NO;
	autopop = NO;
	custom = NO;
	savedcounter = 0;
	probecount = 0;
	nextvar = 0;
	loopDepth = 0;
	
	tree = [[FSEParseTree alloc] init];
	node = [tree newOrphanOfType: FSE_RootNode];
	rootblock = node;
	orphan = [tree newOrphanOfType: FSE_Nil];  /* orphan node gets used as a temporary root as subtrees get built */
	prefixblock = [tree newNodeOfType: FSE_Command | FSE_Block at: rootblock]; /* this is where prefix code should go */
	codeblock = [tree newNodeOfType: FSE_Command | FSE_Block at: rootblock];
	useComplexVars = YES;
	
	index = 0;
	savednode = -1;
	[self readNextSymbol];
	if([symbol isEqualToString: @"{"]) { 
		while(symbol != nil) {
			[self readNextSymbol];
			if([symbol isEqualToString: @"complex"]) useComplexVars = YES;
			else if([symbol isEqualToString: @"real"]) useComplexVars = NO;
			else if([symbol isEqualToString: @"custom"]) {
				NSRange range;
				int savedindex;
				custom = YES;
				savedindex = index + 1;
				while([source characterAtIndex: index] != '}') {
					++index;
					if(index >= [source length]) { error = @"runaway option list"; break; }
				}
				range.location = savedindex; range.length = index - savedindex;
				customPath = [[NSString stringWithFormat: @"%@/", [literalSource substringWithRange: range]] retain];
				useCustom = YES;
//				NSLog(@"found custom path \"%@\"\n", customPath);
			}
			else break;
		}
		if([symbol isEqualToString: @"}"] == NO) error = [NSString stringWithFormat: @"unknown option \"%@\".", symbol];
	}
	else index = 0;
	
	if(useComplexVars) {
		[self indexOfVariableWithName: @"z"]; [self indexOfVariableWithName: @"c"];
		var[[self indexOfVariableWithName: @"pixel"]].par = YES;
		[self setVariableWithName: @"pixel" toType: 0]; --nextvar;
	}
	else {
		[self indexOfVariableWithName: @"x"]; [self indexOfVariableWithName: @"y"];
		[self indexOfVariableWithName: @"a"]; [self indexOfVariableWithName: @"b"];
		var[[self indexOfVariableWithName: @"pixel"]].par = YES;
	}
	
	
	while([self extractCommandBelowNode: codeblock]) ;
	if([error isEqualToString: @"script ended unexpectedly"]) error = nil;
	if(error) return;
	
	[tree reorder];
//	[tree log];
	
	[tree setTempVar: [self indexOfVariableWithName: @".temp"]];
	error = [tree realifyFrom: FSE_RootNode];
	if(error) {  NSLog(@"ERROR -----> \"%@\", tree is:\n", error); [tree log]; return; }
//	else NSLog(@"realification completed\n");
//	[tree log];
//	[tree postprocessReserving: nextvar];

	[self printVariableStack];

	symbol = nil;
}

- (void) setTitle: (NSString*) newTitle source: (NSString*) newSource andDescription: (NSTextStorage*) newDescription
{
//	if(title != nil) [title release]; title = [newTitle retain];
//	if(source != nil) [source release];
	source = [NSString stringWithString: [newSource lowercaseString]];
	literalSource = [NSString stringWithString: newSource];
//	if(description != nil) [description release]; description = [newDescription retain];
}

- (int) dataSources { return dataSourceID; }
- (char*) nameForDataSource: (int) ds { return [tree nodeAt: dataSourceIndex[ds]] -> name; }

- (void) buildScript: (NSString*) newSource {
	if([[newSource lowercaseString] isEqualToString: source] != YES) {
//		NSLog(@"Compiler is going to build script \"%@\"\n", newSource);
		[self setTitle: @"" source: newSource andDescription: @""];
		[self compile: self];
	}
}

- (NSArray*) flagArray { 
	NSArray* ar;
	ar = [NSArray arrayWithArray: flags];
	return ar;
}

- (NSArray*) probeArray {
	NSArray* ar;
	ar = [NSArray arrayWithArray: probes];
	return ar;
}

- (int) addVariable: (NSString*) name
{
	if(nextvar == FSECOMPILER_VARIABLES) return -1;
	var[nextvar].word = name;
	var[nextvar].code = nextvar;
	var[nextvar].par = NO;
	var[nextvar].type = (useComplexVars == YES)? 1 : 0;
	++nextvar;
	return nextvar;
}

- (void) setVariableWithName: (NSString*) name toType: (int) type { var[[self indexOfVariableWithName: name]].type = type; }

- (NSString*) nameOfVariableAtIndex: (int) idx
{
	if((idx >= nextvar) || (idx < 0)) return nil;
	return [NSString stringWithString: var[idx].word];
}


- (int) indexOfVariableWithName: (NSString*) name
{
	int i, r;
	if(useComplexVars) { if([name isEqualToString: @"c"] == YES) ++usesC; }
	else if([name isEqualToString: @"a"] || [name isEqualToString: @"b"]) ++usesC;
	for(i = 0; i < nextvar; i++) if([var[i].word isEqualToString: name] == YES) return i;
	r = [self addVariable: name] - 1;
	if(useComplexVars) [self addVariable: name];
	return r;
}

- (int) parameterNumberOfVariableAtIndex: (int) idx {
	int i, j;
	j = -1;
	for(i = 0; i <= idx; i++) if(var[i].par == YES) ++j;
	return j;
}

- (void) printVariableStack {
	int i;
	NSLog(@"variable stack:\n");
	for(i = 0; i < nextvar; i++) NSLog(@"        \"%@\" : %i\n", var[i].word, var[i].code);
}

- (int) numberOfVariables { return nextvar; }
- (int) maximumLoopDepth { return 16; }	/* hack, should track the loop depth as we parse */

- (void) setOutputFilename: (NSString*) newFilename { filename = [newFilename retain]; }

- (BOOL) isParametric {
//	NSLog(@"isParametric: useComplexVars is %i, usesC is %i, I eval %i\n", useComplexVars? 1 : 0, usesC, (usesC > (useComplexVars? 1 : 2))? 1 : 0);
	return (usesC > (useComplexVars? 1 : 2))? YES : NO;
}

- (NSArray*) parameters {
	NSMutableArray* p;
	int i;
	p = [[[NSMutableArray alloc] init] autorelease];
	for(i = 5; i < nextvar; i++) if(var[i].par == YES) [p addObject: [self nameOfVariableAtIndex: i]];
	return [NSArray arrayWithArray: p];
}

- (FSEParseTree*) tree { return tree; }

- (NSString*) errorMessage { return (error == nil)? nil : [NSString stringWithString: error]; }
- (NSRange) errorRange { return lastRange; }

@end

