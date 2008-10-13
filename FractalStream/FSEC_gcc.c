/*
 *  FSEC_gcc.c
 *  FractalStream
 *
 *  Created by Matt Noonan on 7/23/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#import "stdio.h"
#import "FSEParseNode.h"

int locked[128];
int nextUnlocked(void) { int i; i = 0; while(locked[i]) ++i; return i; }

double eSF_const_x, eSF_const_y;
int eSF_was_const;
int mode, defaultsCount;

int emitSubtreeFrom(int node, FSEParseNode* tree, FILE* fp) {
		int lhs, rhs, out, i, nkids, c, j, k, flag;
		
		/*** configuration modes ***/
		if((mode == 0) || (mode == 1)) {
			switch(tree[node].type & FSE_Type_Mask) {
				case FSE_Command:
					switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Block:
							fprintf(fp, "/* FSE_Block starts here */\n");
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							nkids = tree[node].children; c = tree[node].firstChild;
							if(nkids > 1) for(i = 0; i < nkids - 1; i++) {
								c = tree[c].nextSibling; emitSubtreeFrom(c, tree, fp);
							}
							fprintf(fp, "/* FSE_Block ends here */\n");
							break;
						case FSE_Dyn:
						case FSE_Par:
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							break;
						case FSE_Default:
							if(mode == 0) ++defaultsCount;
							if(mode == 1) {
								mode = 2;
								lhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								mode = 1;
								fprintf(fp, "out[i++] = x[%i];\n", lhs);
							}
							break;
					}
			}
		}

		/*** active modes ***/
		else {
			if(tree[node].cachedAt && (tree[node].cachePass == mode)) {
				return tree[node].cachedAt;
			}
			else if(tree[node].cloneOf) {
				c = node;
				while(tree[c].cloneOf) c = tree[c].cloneOf;
				if((tree[c].cachedAt == 0) || (tree[c].cachePass != mode)) tree[c].cachedAt = emitSubtreeFrom(c, tree, fp);
				tree[c].cachePass = mode;
				return tree[c].cachedAt;
			}
			else switch(tree[node].type & FSE_Type_Mask) {
			case FSE_Command:
					switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Block:
							fprintf(fp, "/* FSE_Block starts here */\n");
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							nkids = tree[node].children; c = tree[node].firstChild;
							if(nkids > 1) for(i = 0; i < nkids - 1; i++) {
								c = tree[c].nextSibling; emitSubtreeFrom(c, tree, fp);
							}
							fprintf(fp, "/* FSE_Block ends here */\n");
							break;
						case FSE_Set:
							fprintf(fp, "/* FSE_Set starts here [%i] */\n", node);
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							fprintf(fp, "x[%i] = x[%i];\n", lhs, rhs);
							fprintf(fp, "/* FSE_Set ends here */\n");
							break;
						case FSE_Succeed:
							fprintf(fp, "j[%i] = 0;\n", tree[node].auxi[0]);
							break;
						case FSE_Fail:
							fprintf(fp, "j[%i] = maxiter;\n", tree[node].auxi[0]);
							break;
						case FSE_Flag:
							fprintf(fp, "flag = %i;\n", tree[node].auxi[0]);
							break;
						case FSE_Do:
							fprintf(fp, "/* FSE_Do starts here */\n");
							fprintf(fp, "for(j[%i] = 0; j[%i] < maxiter; j[%i]++) {\n",
								tree[node].auxi[0], tree[node].auxi[0], tree[node].auxi[0]);
							/* emit code here */
							i = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							j = tree[tree[node].firstChild].nextSibling;
							/* emit test condition here */
							emitSubtreeFrom(j, tree, fp);
							fprintf(fp, "if(");
							emitSubtreeFrom(j, tree, fp);
							fprintf(fp, ") break;\n");
							fprintf(fp, "}\n");
							fprintf(fp, "/* FSE_Do ends here */\n");
							break;
						case FSE_Report:
							fprintf(fp, "/* FSE_Report starts here */\n");
							i = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "reportX = x[%i]; ", i);
							if(tree[node].children > 1) {
								i = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								fprintf(fp, "reportY = x[%i];\n", i);
							}
							else fprintf(fp, "reportY = 0.0;\n");
							fprintf(fp, "reported = 1;\n");
							fprintf(fp, "/* FSE_Report ends here */\n");
							break;
						case FSE_If:
							fprintf(fp, "/* FSE_If starts here */\n");
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							/* emit test condition here */
							fprintf(fp, "if(");
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, ") {\n");
							/* emit code */
							emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							fprintf(fp, "}\n");
							fprintf(fp, "/* FSE_If ends here */\n");
							break;
						case FSE_Else:
							fprintf(fp, "/* FSE_Else starts here */\n");
							fprintf(fp, "else {");
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "}\n");
							fprintf(fp, "/* FSE_Else ends here */\n");
							break;
						case FSE_Iterate:
							fprintf(fp, "/* FSE_Iterate starts here */\n");
							fprintf(fp, "for(j[%i] = 0; j[%i] < maxiter; j[%i]++) {\n",
								tree[node].auxi[0], tree[node].auxi[0], tree[node].auxi[0]);
							/* emit code here */
							i = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							j = tree[tree[node].firstChild].nextSibling;
							if(tree[node].children == 3)  { k = emitSubtreeFrom(j, tree, fp); j = tree[j].nextSibling; }
							else k = 0;
							fprintf(fp, "x[%i] = x[%i];\n", k, i);
							/* emit test condition here */
							emitSubtreeFrom(j, tree, fp);
							fprintf(fp, "if(");
							emitSubtreeFrom(j, tree, fp);
							fprintf(fp, ") break;\n");
							fprintf(fp, "}\n");
							fprintf(fp, "/* FSE_Iterate ends here */\n");
							break;
						case FSE_Probe:
							fprintf(fp, "/* FSE_Probe starts here */\n");
							fprintf(fp, "if(probe == %i) {\n", tree[node].auxi[1]);
							emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "if(reported) { out[i] = reportX; out[i + 1] = reportY; }\n");
							fprintf(fp, "else { out[i] = x[0]; out[i + 1] = x[1]; }\n");
							fprintf(fp, "out[i + 3] = %f;\n", tree[node].auxf[0]);
							fprintf(fp, "return;\n");
							fprintf(fp, "}\n");
							fprintf(fp, "/* FSE_Probe ends here */\n");
							break;
						case FSE_Par:
							if(mode == 2) {
								fprintf(fp, "/* FSE_Par starts here */\n");
								emitSubtreeFrom(tree[node].firstChild, tree, fp);
								fprintf(fp, "/* FSE_Par ends here */\n");
							}
							break;
						case FSE_Dyn:
							if(mode == 3) {
								fprintf(fp, "/* FSE_Dyn starts here */\n");
								emitSubtreeFrom(tree[node].firstChild, tree, fp);
								fprintf(fp, "/* FSE_Dyn ends here */\n");
							}
							break;
						case FSE_Default:
							lhs = tree[tree[node].firstChild].auxi[0];
							rhs = tree[tree[node].firstChild].auxi[1];
							fprintf(fp, "x[%i] = in[%i]; /* FSE_Default */\n",
								lhs, 5 + rhs);
							break;
						case FSE_Clear:
							fprintf(fp, "x[%i] = maxnorm; x[%i] = maxnorm; /* FSE_Clear */\n", tree[node].auxi[0], tree[node].auxi[0] + 1);
							break;
						case FSE_Repeat:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "for(j[%i] = (int) x[%i]; j[%i]; j[%i]--) {\n", tree[node].auxi[0], lhs, tree[node].auxi[0], tree[node].auxi[0]);
							emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							fprintf(fp, "}\n");
							break;
						case FSE_Modulo:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							fprintf(fp, "x[%i] = fmod(x[%i], x[%i]);\n", lhs, lhs, rhs);
							break;
					}
					break;
			case FSE_Arith:
					switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Add:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							fprintf(fp, "/* node = %i, firstChild = %i, secondChild = %i */\n",
								node, tree[node].firstChild, tree[tree[node].firstChild].nextSibling);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							fprintf(fp, "x[%i] = x[%i] + x[%i];\n", out, lhs, rhs);
							break;
						case FSE_Sub:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							fprintf(fp, "x[%i] = x[%i] - x[%i];\n", out, lhs, rhs);
							break;
						case FSE_Mul:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							fprintf(fp, "x[%i] = x[%i] * x[%i];\n", out, lhs, rhs);
							break;
						case FSE_Div:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							fprintf(fp, "if(x[%i] == 0.0) x[%i] = close;\n", rhs, rhs);
							fprintf(fp, "x[%i] = x[%i] / x[%i];\n", out, lhs, rhs);
							break;
						case FSE_Norm:
							break;
						case FSE_Norm2:
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);							
							fprintf(fp, "x[%i] = x[%i] * x[%i];\n", out, lhs, lhs);
							break;
						case FSE_Conj:
							break;
						case FSE_Neg:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							fprintf(fp, "x[%i] = -x[%i];\n", out, lhs);
							break;
						case FSE_Inv:
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);							
							fprintf(fp, "x[%i] = 1.0 / x[%i];\n", out, lhs);
							break;
						case FSE_Square:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							fprintf(fp, "x[%i] = x[%i] * x[%i];\n", out, lhs, lhs);
							break;
						case FSE_Power:
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							eSF_was_const = 0;
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							out = tree[node].auxi[0];
							/*** hack ***/ out = node;
							if(eSF_was_const) {
								fprintf(fp, "/* FSE_Power: got a constant */\n");
								if(eSF_const_y != 0.0) fprintf(fp, "/* constant has imaginary part, ignoring */\n");
								j = (int) eSF_const_x;
								fprintf(fp, "/* exponent is %i */\n", j);
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
								fprintf(fp, "/* FSE_Power can not deal with variables in the exponent. */\n");
							}
							break;
						default:
							break;
					}
				break;
			case FSE_Bool:
					switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Or:
							if(tree[node].auxi[0] == -1) {
								fprintf(fp, "(");
								emitSubtreeFrom(tree[node].firstChild, tree, fp);
								fprintf(fp, "||");
								emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								fprintf(fp, ")");
								tree[node].auxi[0] = 0;
							}
							else {
								tree[node].auxi[0] = -1;
								emitSubtreeFrom(tree[node].firstChild, tree, fp);
								emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							}
							break;
						case FSE_And:
							if(tree[node].auxi[0] == -1) {
								fprintf(fp, "(");
								emitSubtreeFrom(tree[node].firstChild, tree, fp);
								fprintf(fp, "&&");
								emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								fprintf(fp, ")");
								tree[node].auxi[0] = 0;
							}
							else {
								tree[node].auxi[0] = -1;
								emitSubtreeFrom(tree[node].firstChild, tree, fp);
								emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							}
							break;
						case FSE_Xor:
						case FSE_Nor:
						case FSE_Nand:
						case FSE_Not:
						default:
							break;
					}
				break;
			case FSE_Comp:
					switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_LTE:
						case FSE_GTE:
							break;
						case FSE_NotEqual:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								tree[node].auxi[0] = lhs;
								tree[node].auxi[1] = rhs;
							}
							else {
								lhs = tree[node].auxi[0];
								rhs = tree[node].auxi[1];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(((x[%i]-x[%i])*(x[%i]-x[%i])) > close)",
									lhs, rhs, lhs, rhs);
							}
							break;
							break;
						case FSE_Equal:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								tree[node].auxi[0] = lhs;
								tree[node].auxi[1] = rhs;
							}
							else {
								lhs = tree[node].auxi[0];
								rhs = tree[node].auxi[1];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(((x[%i]-x[%i])*(x[%i]-x[%i])) < close)",
									lhs, rhs, lhs, rhs);
							}
							break;
						case FSE_LT:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								tree[node].auxi[0] = lhs;
								tree[node].auxi[1] = rhs;
							}
							else {
								lhs = tree[node].auxi[0];
								rhs = tree[node].auxi[1];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(x[%i] < x[%i])",
									lhs, rhs);
							}
							break;
						case FSE_GT:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
								tree[node].auxi[0] = lhs;
								tree[node].auxi[1] = rhs;
							}
							else {
								lhs = tree[node].auxi[0];
								rhs = tree[node].auxi[1];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(x[%i] > x[%i])",
									lhs, rhs);
							}
							break;
							break;
						case FSE_Escapes:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								tree[node].auxi[0] = lhs;
							}
							else {
								lhs = tree[node].auxi[0];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(x[%i] > maxnorm)", lhs);
							}
							break;
						case FSE_Stops:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								rhs = tree[node].auxi[1];
								tree[node].auxi[0] = lhs;
							}
							else {
								lhs = tree[node].auxi[0];
								rhs = tree[node].auxi[1];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(((x[%i]-x[%i])*(x[%i]-x[%i])) < close)",
									lhs, rhs, lhs, rhs);
							}
							break;
						case FSE_Vanishes:
							if(tree[node].auxi[0] == -1) {
								lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
								tree[node].auxi[0] = lhs;
							}
							else {
								lhs = tree[node].auxi[0];
								tree[node].auxi[0] = -1;
								fprintf(fp, "(x[%i] < close)", lhs);
							}
							break;
						default:
							break;
					}
				break;
			case FSE_Var:
					switch(tree[node].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Complex:
							out = tree[node].auxi[0];
							break;
						case FSE_Real:
							out = tree[node].auxi[0];
							break;
						case FSE_PosReal:
						case FSE_Truth:
							break;
						case FSE_C_Const:
							/*** hack ***/
							out = node;
							fprintf(fp, "x[%i] = %.20e; y[%i] = %.20e;\n", out, tree[node].auxf[0], out, tree[node].auxf[1]);
							eSF_was_const = 1;
							eSF_const_x = tree[node].auxf[0];
							eSF_const_y = tree[node].auxf[1];
							break;
						case FSE_R_Const:
							/*** hack ***/
							out = node;
							fprintf(fp, "x[%i] = %.20e;\n", out, tree[node].auxf[0]);
							break;
						case FSE_Ident:
							out = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							break;
						case FSE_LinkedSubexpression:
							out = emitSubtreeFrom(tree[node].auxi[0], tree, NULL);
							break;
						case FSE_Variable:
							out = tree[node].auxi[0];
							break;
						case FSE_Constant:
							/*** hack ***/
							out = node;
							fprintf(fp, "x[%i] = %.20e;\n", out, tree[node].auxf[0]);
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
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = exp(x[%i]);\n", out, lhs);
							break;
						case FSE_Cosh:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = cosh(x[%i]);\n", out, lhs);
							break;
						case FSE_Sinh:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = sinh(x[%i]);\n", out, lhs);
							break;
						case FSE_Tanh:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = tanh(x[%i]);\n", out, lhs);
							break;
						case FSE_Cos:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = cos(x[%i]);\n", out, lhs);
							break;
						case FSE_Sin:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = sin(x[%i]);\n", out, lhs);
							break;
						case FSE_Tan:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = tan(x[%i]);\n", out, lhs);
							break;
						case FSE_Arccos:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = acos(x[%i]);\n", out, lhs);
							break;
						case FSE_Arcsin:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = asin(x[%i]);\n", out, lhs);
							break;
						case FSE_Arctan:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = atan(x[%i]);\n", out, lhs);
							break;
						case FSE_Arg:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							rhs = emitSubtreeFrom(tree[tree[node].firstChild].nextSibling, tree, fp);
							fprintf(fp, "x[%i] = atan2(x[%i], x[%i]);\n", out, rhs, lhs);
							break;
						case FSE_Log:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = log(x[%i]);\n", out, lhs);
							break;
						case FSE_Sqrt:
							/*** hack ***/
							out = node;
							lhs = emitSubtreeFrom(tree[node].firstChild, tree, fp);
							fprintf(fp, "x[%i] = sqrt(x[%i]);\n", out, lhs);
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
				((tree[node].type & FSE_Type_Mask) == FSE_Var)) { tree[node].cachedAt = out; tree[node].cachePass = mode; }
		}
		return out;
}

int emit(char* filename, FSEParseNode* tree, int stacksize) {
	int i, root, subtree;
	FILE* fp;
	
	for(i = 0; i < 128; i++) locked[i] = 0;
	locked[0] = locked[1] = 1;

	root = 0;
	subtree = tree[root].firstChild;  /* the first child is the prefix block, the second child is the iteration loop */

	fp = fopen(filename, "w");
	fprintf(fp, "/* emitted by FSEC_gcc.c */\n\n");
	
	fprintf(fp, "/* using tree at address %x */\n", tree);
	
	fprintf(fp, "#include <math.h>\n\n");
	
	fprintf(fp, "void kernel(int mode, double* in, int length, double* out, int maxiter, double maxnorm, double close) {\n");
	fprintf(fp, "int i, j[16], k, n[%i], flag, probe, reported;\n", stacksize);
	fprintf(fp, "double x[%i], step, r, cx, cy, reportX, reportY;\n", stacksize, stacksize);
	fprintf(fp, "flag = 0;\n");
	fprintf(fp, "reported = 0;\n");
	fprintf(fp, "if(mode == -1) /* initialization */{\n");
		emitSubtreeFrom(subtree, tree, fp); /* emit the prefix block */
		subtree = tree[subtree].nextSibling;
	fprintf(fp, "}\n");
	fprintf(fp, "if(mode == -2) /* defaults count */{\n"); mode = 0;
		defaultsCount = 0;
		emitSubtreeFrom(subtree, tree, fp);
		fprintf(fp, "out[0] = %f;\n", (double) defaultsCount);
	fprintf(fp, "}\n");
	fprintf(fp, "if(mode == -3) /* defaults values */{\n"); mode = 1;
		fprintf(fp, "i = 0;\n");
		emitSubtreeFrom(subtree, tree, fp);
	fprintf(fp, "}\n");
	fprintf(fp, "probe = 0; if(length < 0) { probe = -length; length = 1; }\n");
	fprintf(fp, "if(mode == 1) { /* parameter plane */\n"); mode = 2;
	fprintf(fp, "maxnorm *= maxnorm; close *= close;\n step = in[2];\n");
	fprintf(fp, "cx = in[0]; cy = in[1];\n");
	fprintf(fp, "for(i = 0; i < 3 * length; i += 3) {\nj[0] = 0;\n");
	fprintf(fp, "flag = 0; x[0] = 0.0; x[1] = 0.0;\nx[2] = cx; x[3] = cy;\nx[4] = in[5]; x[5] = in[6];\n");
		emitSubtreeFrom(subtree, tree, fp); /* emit the dynamics */	
	fprintf(fp, "if(reported) { out[i] = reportX; out[i + 1] = reportY; }\n");
	fprintf(fp, "else { out[i] = x[0]; out[i + 1] = x[1]; }\n");
	fprintf(fp, "out[i + 2] = (double) ((j[0] << 8) | flag);\n");
	fprintf(fp, "cx += step;\n");
	fprintf(fp, "}\n");
	fprintf(fp, "}\n");
	fprintf(fp, "if(mode == 3) { /* dynamical plane */\n"); mode = 3;
	fprintf(fp, "maxnorm *= maxnorm; close *= close;\n step = in[2];\n");
	fprintf(fp, "cx = in[3]; cy = in[4];\n");
	fprintf(fp, "for(i = 0; i < 3 * length; i += 3) {\nj[0] = 0;\n");
	fprintf(fp, "flag = 0; \nx[0] = in[0]; x[1] = in[1];\nx[2] = cx; x[3] = cy;\nx[4] = in[5]; x[5] = in[6];\n");
		emitSubtreeFrom(subtree, tree, fp); /* emit the dynamics */
	fprintf(fp, "if(reported) { out[i] = reportX; out[i + 1] = reportY; }\n");
	fprintf(fp, "else { out[i] = x[0]; out[i + 1] = x[1]; }\n");
	fprintf(fp, "out[i + 2] = (double) ((j[0] << 8) | flag);\n");
	fprintf(fp, "in[0] += in[2];\n");
	fprintf(fp, "}\n");
	fprintf(fp, "}\n");
	fprintf(fp, "}\n");
	
	fclose(fp);
}

