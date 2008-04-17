//
//  FSEParseTree.m
//  FSEdit
//
//  Created by Matt Noonan on 5/24/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "FSEParseTree.h"

@implementation FSEParseTree

- (int) size { return nodes; }

- (id) init {
	self = [super init];
	reordered = NO;
	nodes = 256;
	node = (FSEParseNode*) malloc(nodes * sizeof(FSEParseNode));
	nextNode = 0; /* root node is 0 */
	return self;
}

- (void) setTempVar: (int) newTempVar { tempVar = newTempVar; }

- (int) newOrphanOfType: (int) type {
	int i;
	if(nextNode == nodes) {
		nodes += 256;
		node = realloc(node, nodes * sizeof(FSEParseNode));
	}
	node[nextNode].type = type;
	node[nextNode].children = 0;
	node[nextNode].parent = -1;
	node[nextNode].nparents = 0;
	node[nextNode].nextSibling = FSE_Nil;
	node[nextNode].firstChild = FSE_Nil;
	node[nextNode].auxi[0] = 0;
	node[nextNode].auxi[1] = 0;
	node[nextNode].auxf[0] = 0.0;
	node[nextNode].auxf[1] = 42.0;
	node[nextNode].cloneOf = 0;
	node[nextNode].cachedAt = 0;
	node[nextNode].hashed = 0;
	node[nextNode].hash = 42.0;
	node[nextNode].processed = 0;
	nextNode++;
	return nextNode - 1;
}

- (int) setParentOfNode: (int) child to: (int) parent
{
	int i;
	if(node[parent].children > 0) {
		i = node[parent].firstChild;
		while(node[i].nextSibling != FSE_Nil) i = node[i].nextSibling;
		node[i].nextSibling = child;
	}
	else node[parent].firstChild = child;
	node[child].parent = parent;
	node[child].nextSibling = FSE_Nil;
	node[parent].children++;
	return child;
}

- (void) swapBirthOrderAt: (int) spot
{
	int fc, ns;
	fc = node[spot].firstChild;
	ns = node[fc].nextSibling;
	node[spot].firstChild = ns;
	node[fc].nextSibling = node[ns].nextSibling;
	node[ns].nextSibling = fc;
	
}

- (int) cloneSubtreeFrom: (int) here to: (int) there {
	int n, i, child;
	n = [self newNodeOfType: node[here].type at: there];
	if(
	((node[here].type & FSE_Type_Mask) == FSE_Arith) ||
		((node[here].type & FSE_Type_Mask) == FSE_Var) ||
		((node[here].type & FSE_Type_Mask) == FSE_Func)) node[n].cloneOf = here;
	node[n].auxi[0] = node[here].auxi[0];
	node[n].auxi[1] = node[here].auxi[1];
	node[n].auxf[0] = node[here].auxf[0];
	node[n].auxf[1] = node[here].auxf[1];
	if(node[here].children == 0) return n;
	child = node[here].firstChild;
	for(i = 0; i < node[here].children; i++) {
		[self cloneSubtreeFrom: child to: n];
		child = node[child].nextSibling;
	}
	return n;
}


- (int) newNodeOfType: (int) type before: (int) spot {
	int parent, prevSib, i, me;
	me = [self newOrphanOfType: type];
	parent = node[spot].parent;
	if(node[parent].children == 0) {
		node[parent].children = 1;
		node[parent].firstChild = me;
	}
	else if(spot == node[parent].firstChild) {
		++node[parent].children;
		node[me].nextSibling = spot;
		node[parent].firstChild = me;
	}
	else {
		prevSib = node[parent].firstChild;
		for(i = 0; i < node[parent].children; i++) {
			if(node[prevSib].nextSibling == spot) break;
			prevSib = node[prevSib].nextSibling;
		}
		node[prevSib].nextSibling = me;
		node[me].nextSibling = spot;
		++node[parent].children;  /******* TEST ME OUT *******/
	}
	return me;
}

- (void) deleteNodeAt: (int) spot {
	int parent, prevSib, nextSib, i;
	parent = node[spot].parent;
	if(parent == FSE_Nil) return;
	nextSib = node[spot].nextSibling;
	prevSib = node[parent].firstChild;
	if(prevSib == spot) node[parent].firstChild = nextSib;
	else {
		for(i = 0; i < node[parent].children; i++) {
			if(node[prevSib].nextSibling == spot) break;
			prevSib = node[prevSib].nextSibling;
		}
		node[prevSib].nextSibling = nextSib;
	}
	--node[parent].children;
}

- (int) newNodeOfType: (int) type at: (int) spot {
	return [self setParentOfNode: [self newOrphanOfType: type] to: spot];
}

- (FSEParseNode*) nodeAt: (int) index {
	return &(node[index]);
}

/*	Sending the reorder message makes the tree attempt to fix order-of-operation problems.  For example, 
	A * B + C would initially parse to the tree (* A (+ B C)).  reorder replaces trees of this form with
	(+ (* A B) C ).  This will result in the correct order of operations as long as the parser built the
	parse tree without doing any reordering itself.
*/
- (int) weight: (int) type {
	switch (type & FSE_Type_Mask) {
		case FSE_Arith:
			switch (type ^ FSE_Arith) {
				case FSE_Add:		return 101;
				case FSE_Sub:		return 102;		// special value
				case FSE_Mul:		return 103;
				case FSE_Div:		return 104;
				case FSE_Norm:		return  99;
				case FSE_Norm2:		return  99;
				case FSE_Conj:		return 105;
				case FSE_Neg:		return 105;
				case FSE_Inv:		return 105;
				case FSE_Square:	return 106;
				case FSE_Power:		return 106;
				default:			return  99;
			}
		case FSE_Command:
			// resets must be floated down 'manually'
			if(type == (FSE_Command | FSE_Reset)) return 1000;
			break;
		case FSE_Func:
			return 200;
		case FSE_Comp:
			return 51;
		case FSE_Bool:
			return 50;
		default:
			return -1;
	}
	return -1;
}

- (void) reorderFromNode: (int) here {
	int child, parent, w1, w2, child1, child2, brother, sib, grandchild, class, i, childid;

	if(node[here].type == (FSE_Command | FSE_Bumpdown)) {
		--stackPtr;
		/* UNCOMMENTING BREAKS SARAH'S EXCEPTIONAL DIVISOR... WHY??? */
		//[self deleteNodeAt: here];   
		return;
	}

	if(node[here].type == (FSE_Command | FSE_Reset)) {
		int movednode, bro, lhs, rhs, clearnode, t;
		bro = node[loopStack[stackPtr - 1]].firstChild;
		if(node[loopStack[stackPtr - 1]].type == (FSE_Command | FSE_Do)) bro = node[bro].firstChild;
		else if(node[loopStack[stackPtr - 1]].type == (FSE_Command | FSE_Iterate)) {
			NSLog(@"fseiterate\n");
		}		
		movednode = [self newNodeOfType: FSE_Command | FSE_Set before: bro];
		if(node[here].auxf[0] == 1.0) {
			lhs = [self newNodeOfType: FSE_Var | FSE_Variable at: movednode];
			node[lhs].auxi[0] = node[here].auxi[0];
		}
		else {
			lhs = [self newNodeOfType: FSE_Var | FSE_Join at: movednode];
			t = [self newNodeOfType: FSE_Var | FSE_Variable at: lhs];
			node[t].auxi[0] = node[here].auxi[0];
			t = [self newNodeOfType: FSE_Var | FSE_Variable at: lhs];
			node[t].auxi[0] = node[here].auxi[0] + 1;
		}
		rhs = [self cloneSubtreeFrom: node[here].auxi[1] to: movednode];
/*
		rhs = [self newNodeOfType: FSE_Var | FSE_LinkedSubexpression at: movednode];
		node[lhs].auxi[0] = node[here].auxi[0];
		node[rhs].auxi[0] = node[here].auxi[1];
*/

		clearnode = [self newNodeOfType: FSE_Command | FSE_Clear before: loopStack[stackPtr - 1]];
		node[clearnode].auxi[0] = node[here].auxi[1];

		[self deleteNodeAt: here];
		return;
	}
	
	if(node[here].firstChild == FSE_Nil) return;

	if((node[here].type == (FSE_Command | FSE_Do)) || (node[here].type == (FSE_Command | FSE_Iterate))) {
		loopStack[stackPtr++] = here;
	}
	
	child = node[here].firstChild;
	childid = 0;
	while(child != FSE_Nil) { 
		[self reorderFromNode: child];
		++childid;
		child = node[here].firstChild;
		for(i = 0; i < childid; i++) child = node[child].nextSibling;
	}
	
//	if(node[here].children != 2) return;
	class = node[here].type & FSE_Type_Mask;
	if((class != FSE_Var) && (class != FSE_Command) && (here != FSE_RootNode)) {
		parent = node[here].parent;
		brother = -1; sib = node[parent].firstChild;
		while(sib != here) { brother = sib; sib = node[sib].nextSibling; }
		child1 = node[here].firstChild;
		if(node[here].children == 1) { /* special case for unary operators */
			if((node[child1].type & FSE_Type_Mask) == FSE_Var) return;
			grandchild = node[child1].firstChild;
			w1 = [self weight: node[here].type];
			w2 = [self weight: node[child1].type];
			if(w2 < w1) {
				node[grandchild].parent = here;
				node[here].parent = child1;
				node[child1].parent = parent;
				node[child1].nextSibling = node[here].nextSibling;
				node[here].nextSibling = node[grandchild].nextSibling;
				node[grandchild].nextSibling = FSE_Nil;
				node[child1].firstChild = here;
				node[here].firstChild = grandchild;
				if(brother == -1) node[parent].firstChild = child1;
				else node[brother].nextSibling = child1;
				[self reorderFromNode: here];
			}
			return;
		}
		
		child2 = node[child1].nextSibling;
		if((node[child2].type & FSE_Type_Mask) == FSE_Var) return;
		grandchild = node[child2].firstChild;

		w1 = [self weight: node[here].type];
		w2 = [self weight: node[child2].type];
		if((w2 < w1) || ((w1 == 102) && (w2 == 102))) {  // subtraction has priority over itself!
			node[grandchild].parent = here;
			node[here].parent = child2;
			node[child2].parent = parent;
			node[child1].nextSibling = grandchild;
			node[child2].nextSibling = node[here].nextSibling;
			node[here].nextSibling = node[grandchild].nextSibling;
			node[grandchild].nextSibling = FSE_Nil;
			node[child2].firstChild = here;
			if(brother == -1) node[parent].firstChild = child2;
			else node[brother].nextSibling = child2;
			[self reorderFromNode: here];
		}
	}
}


- (void) reorder {
	NSLog(@"\n\n**** reordering ****\n\n");
	if(node[FSE_RootNode].children == 0) return;
	stackPtr = 0;
	[self reorderFromNode: FSE_RootNode];
}

 - (NSString*) realifyFrom: (int) here {
	int i, children, child, child1, child2, replacement, x, y, newNode, nx, ny, u, v, t, n;
	int bits, lastbit;
	NSString* error;
	
	error = nil;
	children = node[here].children;
	if(children == 0) return nil;
	child = node[here].firstChild;
	for(i = 0; i < children; i++) {
		if(error = [self realifyFrom: child]) return error;
		child = node[child].nextSibling;
	}
	
	child1 = node[here].firstChild;
	child2 = node[child1].nextSibling;
	switch(node[here].type & FSE_Type_Mask) {
		case FSE_Arith:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Add:
					if((node[child1].type == (FSE_Var | FSE_Join)) && (node[child2].type == (FSE_Var | FSE_Join))) {
						if(node[child1].children != node[child2].children)
							return [NSString stringWithString: @"cannot add vectors of different dimension"];
						node[here].type = FSE_Var | FSE_Join;
						x = node[child1].firstChild; y = node[child2].firstChild;
						for(i = 0; i < node[child1].children; i++) {
							newNode = [self newNodeOfType: FSE_Arith | FSE_Add at: here];
							nx = node[x].nextSibling; ny = node[y].nextSibling;
							[self cloneSubtreeFrom: x to: newNode];
							[self cloneSubtreeFrom: y to: newNode];
							x = nx; y = ny;
						}
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot add scalars to vectors";
						n = node[child1].firstChild;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Add at: here];
						[self cloneSubtreeFrom: n to: newNode];
						[self cloneSubtreeFrom: child2 to: newNode];
						n = node[n].nextSibling;
						[self cloneSubtreeFrom: n to: here];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child2].type == (FSE_Var | FSE_Join)) {
						if(node[child2].children != 2) return @"cannot add vectors to scalars";
						n = node[child2].firstChild;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Add at: here];
						[self cloneSubtreeFrom: child1 to: newNode];
						[self cloneSubtreeFrom: n to: newNode];
						n = node[n].nextSibling;
						[self cloneSubtreeFrom: n to: here];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					break;
				case FSE_Sub:	
					if((node[child1].type == (FSE_Var | FSE_Join)) && (node[child2].type == (FSE_Var | FSE_Join))) {
						if(node[child1].children != node[child2].children) 
							return [NSString stringWithString: @"cannot subtract vectors of different dimension"];
						node[here].type = FSE_Var | FSE_Join;
						x = node[child1].firstChild; y = node[child2].firstChild;
						for(i = 0; i < node[child1].children; i++) {
							newNode = [self newNodeOfType: FSE_Arith | FSE_Sub at: here];
							nx = node[x].nextSibling; ny = node[y].nextSibling;
							[self cloneSubtreeFrom: x to: newNode];
							[self cloneSubtreeFrom: y to: newNode];
							x = nx; y = ny;
						}
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot subtract scalars from vectors";
						n = node[child1].firstChild;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Sub at: here];
						[self cloneSubtreeFrom: n to: newNode];
						[self cloneSubtreeFrom: child2 to: newNode];
						n = node[n].nextSibling;
						[self cloneSubtreeFrom: n to: here];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child2].type == (FSE_Var | FSE_Join)) {
						if(node[child2].children != 2) return @"cannot subtract vectors from scalars";
						n = node[child2].firstChild;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Sub at: here];
						[self cloneSubtreeFrom: child1 to: newNode];
						[self cloneSubtreeFrom: n to: newNode];
						n = node[n].nextSibling;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Neg at: here];					
						[self cloneSubtreeFrom: n to: newNode];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					break;
				case FSE_Mul:
					if((node[child1].type == (FSE_Var | FSE_Join)) && (node[child2].type == (FSE_Var | FSE_Join))) {
						if((node[child1].children != 2) || (node[child2].children != 2)) 
							return [NSString stringWithString: @"cannot multiply vectors with these dimensions"];
						node[here].type = FSE_Var | FSE_Join;
						x = node[child1].firstChild; y = node[x].nextSibling;
						u = node[child2].firstChild; v = node[u].nextSibling;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Sub at: here];
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: newNode];
								[self cloneSubtreeFrom: x to: t];
								[self cloneSubtreeFrom: u to: t];
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: newNode];
								[self cloneSubtreeFrom: y to: t];
								[self cloneSubtreeFrom: v to: t];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Add at: here];
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: newNode];
								[self cloneSubtreeFrom: x to: t];
								[self cloneSubtreeFrom: v to: t];
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: newNode];
								[self cloneSubtreeFrom: y to: t];
								[self cloneSubtreeFrom: u to: t];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child1].type == (FSE_Var | FSE_Join)) {
						node[here].type = FSE_Var | FSE_Join;
						child = node[child1].firstChild;
						for(i = 0; i < node[child1].children; i++) {
							newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							[self cloneSubtreeFrom: child to: newNode];
							[self cloneSubtreeFrom: child2 to: newNode];
							child = node[child].nextSibling;
						}
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child2].type == (FSE_Var | FSE_Join)) {
						node[here].type = FSE_Var | FSE_Join;
						child = node[child2].firstChild;
						for(i = 0; i < node[child2].children; i++) {
							newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							[self cloneSubtreeFrom: child1 to: newNode];
							[self cloneSubtreeFrom: child to: newNode];
							child = node[child].nextSibling;
						}
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					break;
				case FSE_Div:
					if(node[child2].type == (FSE_Var | FSE_Join)) {
						if(node[child2].children != 2) 
							return [NSString stringWithString: @"cannot divide by vectors"];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
						[self cloneSubtreeFrom: child1 to: newNode];
						n = [self newNodeOfType: FSE_Arith | FSE_Conj at: newNode];
						[self cloneSubtreeFrom: child2 to: n];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: here];
						[self cloneSubtreeFrom: child2 to: newNode];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
						return [self realifyFrom: here];
					}
					else if(node[child1].type == (FSE_Var | FSE_Join)) {
						node[here].type = FSE_Var | FSE_Join;
						child = node[child1].firstChild;
						for(i = 0; i < node[child1].children; i++) {
							newNode = [self newNodeOfType: FSE_Arith | FSE_Div at: here];
							[self cloneSubtreeFrom: child to: newNode];
							[self cloneSubtreeFrom: child2 to: newNode];
							child = node[child].nextSibling;
						}
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					break;
				case FSE_Norm:
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						child = node[child1].firstChild;
						node[here].type = FSE_Func | FSE_Sqrt;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: here];
						[self cloneSubtreeFrom: child1 to: newNode];
						[self deleteNodeAt: child1];
						return [self realifyFrom: here];
					}
					break;
				case FSE_Norm2:
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						child = node[child1].firstChild;
						node[here].type = FSE_Arith | FSE_Add;
						n = here;
						for(i = 0; i < node[child1].children - 1; i++) {
							newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: n];
							[self cloneSubtreeFrom: child to: newNode];
							[self cloneSubtreeFrom: child to: newNode];
							if(i < node[child1].children - 2) 
								n = [self newNodeOfType: FSE_Arith | FSE_Add at: n];
							child = node[child].nextSibling;
						}
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: n];
						[self cloneSubtreeFrom: child to: newNode];
						[self cloneSubtreeFrom: child to: newNode];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Conj:
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2)
							return [NSString stringWithString: @"cannot conjugate vectors of this type"];
						node[here].type = FSE_Var | FSE_Join;
						x = node[child1].firstChild; y = node[x].nextSibling;
						[self cloneSubtreeFrom: x to: here];
						[self cloneSubtreeFrom: y to: [self newNodeOfType: FSE_Arith | FSE_Neg at: here]];
						[self deleteNodeAt: child1];
					}
					else node[here].type = FSE_Var | FSE_Ident;
					break;
				case FSE_Neg:
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						node[here].type = FSE_Var | FSE_Join;
						x = node[child1].firstChild;
						for(i = 0; i < node[child1].children; i++) {
							[self cloneSubtreeFrom: x to: [self newNodeOfType: FSE_Arith | FSE_Neg at: here]];
							x = node[x].nextSibling;
						}
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Inv:
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot invert vectors";
						node[here].type = FSE_Arith | FSE_Mul;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Conj at: here];
						[self cloneSubtreeFrom: child1 to: newNode];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Inv at: here];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: newNode];
						[self cloneSubtreeFrom: child1 to: newNode];
						[self deleteNodeAt: child1];
						return [self realifyFrom: here];
						break;
					}
					break;
				case FSE_Square:
					break;
				case FSE_Power:
					child1 = node[here].firstChild; child2 = node[child1].nextSibling;
					if(node[child2].type == (FSE_Var | FSE_Constant)) {
						if(node[child2].auxf[0] != floor(node[child2].auxf[0])) return @"exponent should be an integer constant";
						n = (int) node[child2].auxf[0];
					}
					else if(node[child2].type == (FSE_Var | FSE_Join)) {
						if(node[child2].children != 2) return @"exponent cannot be a vector of this type";
						if(node[node[node[child2].firstChild].nextSibling].auxf[0] != 0.0) return @"exponent must be real";
						if(node[node[child2].firstChild].auxf[0] != floor(node[node[child2].firstChild].auxf[0])) return @"exponent should be an integer constant";
						n = (int) node[node[child2].firstChild].auxf[0];
					}
					else return @"exponent should be an integer constant";
					if(n < 0) return @"exponent should be positive";
					for(i = lastbit = bits = 0; i < sizeof(int) * 8; i++) if((n >> i) & 1) { lastbit = i + 1; ++bits; }
					if(bits == 0) {
						node[here].type = FSE_Var | FSE_Constant;
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
						node[here].auxf[0] = 1.0;
					}
					else if(lastbit == 1) {
						node[here].type = FSE_Var | FSE_Ident;
						[self deleteNodeAt: child2];
						return [self realifyFrom: here];
					}
					else {
						node[here].type = FSE_Var | FSE_Ident;
						NSLog(@"child1 = %i, child2 = %i, here = %i, lastbit = %i, bits = %i", child1, child2, here, lastbit, bits);
						newNode = [self cloneSubtreeFrom: child1 to: here];
						for(i = 0; i < lastbit - 1; i++) {
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							[self cloneSubtreeFrom: newNode to: t];
							[self cloneSubtreeFrom: newNode to: t];
							newNode = t;
						}
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
						if(bits == 1) {
							for(i = 0; i < lastbit - 1; i++) [self deleteNodeAt: node[here].firstChild];
						}
						else {
							newNode = here;
							child = node[here].firstChild;
							for(i = 0; i < lastbit - 1; i++) {
								if((n >> i) & 1) {
									newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: newNode];
									[self cloneSubtreeFrom: child to: newNode];
								}
								child = node[child].nextSibling;
							}
							[self cloneSubtreeFrom: child to: newNode];
							for(i = 0; i < lastbit; i++) [self deleteNodeAt: node[here].firstChild];
						}
						[self realifyFrom: here];
					}
					break;
			}
			break;
		case FSE_Func:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Exp:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot exponentiate vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Exp at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							[self cloneSubtreeFrom: y to: t];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Exp at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							[self cloneSubtreeFrom: y to: t];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Cosh:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot take cosh of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Cosh at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							[self cloneSubtreeFrom: y to: t];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Sinh at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							[self cloneSubtreeFrom: y to: t];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Sinh:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						int neg;
						if(node[child1].children != 2) return @"cannot take sinh of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Sinh at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							[self cloneSubtreeFrom: y to: t];
						neg = [self newNodeOfType: FSE_Arith | FSE_Neg at: here];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: neg];
							t = [self newNodeOfType: FSE_Func | FSE_Cosh at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							[self cloneSubtreeFrom: y to: t];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Cos:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						int neg;
						if(node[child1].children != 2) return @"cannot take sinh of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cosh at: newNode];
							[self cloneSubtreeFrom: y to: t];
						neg = [self newNodeOfType: FSE_Arith | FSE_Neg at: here];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: neg];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Sinh at: newNode];
							[self cloneSubtreeFrom: y to: t];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Sin:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot take cosh of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cosh at: newNode];
							[self cloneSubtreeFrom: y to: t];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Sinh at: newNode];
							[self cloneSubtreeFrom: y to: t];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Tan:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						int den, q, t2;
						if(node[child1].children != 2) return @"cannot take tangent of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						q = [self newNodeOfType: FSE_Arith | FSE_Div at: here];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: q];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							[self cloneSubtreeFrom: y to: t];
						den = [self newNodeOfType: FSE_Arith | FSE_Add at: q];
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: den];
							t2 = [self newNodeOfType: FSE_Func | FSE_Cos at: t];
							[self cloneSubtreeFrom: x to: t2];
							t2 = [self newNodeOfType: FSE_Func | FSE_Cos at: t];
							[self cloneSubtreeFrom: x to: t2];
							t = [self newNodeOfType: FSE_Arith | FSE_Mul at: den];
							t2 = [self newNodeOfType: FSE_Func | FSE_Sinh at: t];
							[self cloneSubtreeFrom: y to: t2];
							t2 = [self newNodeOfType: FSE_Func | FSE_Sinh at: t];
							[self cloneSubtreeFrom: y to: t2];
						q = [self newNodeOfType: FSE_Arith | FSE_Div at: here];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: q];
							t = [self newNodeOfType: FSE_Func | FSE_Sinh at: newNode];
							[self cloneSubtreeFrom: x to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cosh at: newNode];
							[self cloneSubtreeFrom: y to: t];
						[self cloneSubtreeFrom: den to: q];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Tanh:
					break;
				case FSE_Log:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot take logarithm of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Var | FSE_Constant at: newNode];
							node[t].auxf[0] = 0.5;
							t = [self newNodeOfType: FSE_Func | FSE_Log at: newNode];
							t = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: t];
							[self cloneSubtreeFrom: child1 to: t];
						newNode = [self newNodeOfType: FSE_Func | FSE_Arg at: here];
							[self cloneSubtreeFrom: x to: newNode];
							[self cloneSubtreeFrom: y to: newNode];
						[self deleteNodeAt: child1];
						return [self realifyFrom: here];
					}
					break;
				case FSE_Sqrt:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						int div;
						if(node[child1].children != 2) return @"cannot take square root of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						node[here].type = FSE_Var | FSE_Join;
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Sqrt at: newNode];
							t = [self newNodeOfType: FSE_Arith | FSE_Norm at: t];
							[self cloneSubtreeFrom: child1 to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Cos at: newNode];
							div = [self newNodeOfType: FSE_Arith | FSE_Mul at: t];
							t = [self newNodeOfType: FSE_Var | FSE_Constant at: div];
							node[t].auxf[0] = 0.5;
							t = [self newNodeOfType: FSE_Func | FSE_Arg at: div];
							[self cloneSubtreeFrom: x to: t];
							[self cloneSubtreeFrom: y to: t];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Mul at: here];
							t = [self newNodeOfType: FSE_Func | FSE_Sqrt at: newNode];
							t = [self newNodeOfType: FSE_Arith | FSE_Norm at: t];
							[self cloneSubtreeFrom: child1 to: t];
							t = [self newNodeOfType: FSE_Func | FSE_Sin at: newNode];
							div = [self newNodeOfType: FSE_Arith | FSE_Mul at: t];
							t = [self newNodeOfType: FSE_Var | FSE_Constant at: div];
							node[t].auxf[0] = 0.5;
							t = [self newNodeOfType: FSE_Func | FSE_Arg at: div];
							[self cloneSubtreeFrom: x to: t];
							[self cloneSubtreeFrom: y to: t];
						[self deleteNodeAt: child1];
						return [self realifyFrom: here];
					}
					break;
				case FSE_Arg:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot take argument of vectors";
						x = node[child1].firstChild; y = node[x].nextSibling;
						[self cloneSubtreeFrom: x to: here];
						[self cloneSubtreeFrom: y to: here];
						[self deleteNodeAt: child1];
					}
					break;
				case FSE_Arccos:
				case FSE_Arcsin:
				case FSE_Arctan:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						return @"cannot apply inverse trig functions to a complex variable";
					}
					break;
				case FSE_Re:
					child1 = node[here].firstChild;
					if(node[child1].type != (FSE_Var | FSE_Join)) {
						node[here].type = FSE_Var | FSE_Ident;
						[self realifyFrom: here];
						return;
					}
					if(node[child1].children != 2) return @"Re(z) is not defined on this type of vector";
					node[here].type = FSE_Var | FSE_Ident;
					[self cloneSubtreeFrom: node[child1].firstChild to: here];
					[self deleteNodeAt: child1];
					break;
				case FSE_Im:
					child1 = node[here].firstChild;
					if(node[child1].type != (FSE_Var | FSE_Join)) {
						node[here].type = FSE_Var | FSE_Constant;
						node[here].auxf[0] = 0.0;
						return;
					}
					if(node[child1].children != 2) return @"Im(z) is not defined on this type of vector";
					node[here].type = FSE_Var | FSE_Ident;
					[self cloneSubtreeFrom: node[node[child1].firstChild].nextSibling to: here];
					[self deleteNodeAt: child1];
					break;
			}
			break;
		case FSE_Var:
			if(node[here].type == (FSE_Var | FSE_Ident)) {
				int nchilds;
				n = node[here].firstChild;
				child = node[n].firstChild;
				nchilds = node[n].children;
				node[here].type = node[n].type;
				node[here].auxi[0] = node[n].auxi[0];
				node[here].auxi[1] = node[n].auxi[1];
				node[here].auxf[0] = node[n].auxf[0];
				node[here].auxf[1] = node[n].auxf[1];
				for(i = 0; i < nchilds; i++) {
					[self cloneSubtreeFrom: child to: here];
					child = node[child].nextSibling;
				}
				[self deleteNodeAt: n];
			}
			break;
		case FSE_Comp: 
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Equal:
					child1 = node[here].firstChild; child2 = node[child1].nextSibling;
					node[here].type = FSE_Comp | FSE_Vanishes;
					newNode = [self newNodeOfType: FSE_Arith | FSE_Sub at: here];
					[self cloneSubtreeFrom: child1 to: newNode];
					[self cloneSubtreeFrom: child2 to: newNode];
					[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					return [self realifyFrom: here];
					break;
				case FSE_LT:
				case FSE_LTE:
				case FSE_GT:
				case FSE_GTE:
					child1 = node[here].firstChild; child2 = node[child1].nextSibling;
					if((node[child1].type == (FSE_Var | FSE_Join)) || (node[child2].type == (FSE_Var | FSE_Join))) {
						n = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: here];
						[self cloneSubtreeFrom: child1 to: n];
						newNode = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: here];
						[self cloneSubtreeFrom: child2 to: newNode];
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
						return [self realifyFrom: here];
					}
					break;
				case FSE_NotEqual:
					child1 = node[here].firstChild; child2 = node[child1].nextSibling;
					if(node[child1].children != node[child2].children) return @"cannot compare vectors of different dimension";
					node[here].type = FSE_Comp | FSE_Vanishes;
					newNode = [self newNodeOfType: FSE_Bool | FSE_Not at: here];
					newNode = [self newNodeOfType: FSE_Arith | FSE_Sub at: newNode];
					[self cloneSubtreeFrom: child1 to: newNode];
					[self cloneSubtreeFrom: child2 to: newNode];
					[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					return [self realifyFrom: here];
					break;
				case FSE_Stops:
					child1 = node[here].firstChild;
					if(node[child1].type == (FSE_Var | FSE_Variable)) {
						node[here].type = FSE_Comp | FSE_Equal;
						child2 = [self newNodeOfType: FSE_Var | FSE_Variable at: here];
						node[child2].auxi[0] = node[here].auxi[0];
						node[here].auxi[0] = -1;
					}
					if(node[child1].type == (FSE_Var | FSE_Join)) {
						int nchilds, stops, v;
						nchilds = node[child1].children;
						child = node[child1].firstChild;
						if(nchilds == 1) return error;
						node[here].type = FSE_Comp | FSE_Equal;
						node[here].auxi[0] = -1;
						v = node[here].auxi[1];
						n = [self newNodeOfType: FSE_Var | FSE_Join at: here];
						for(i = 0; i < nchilds; i++) 
							node[[self newNodeOfType: FSE_Var | FSE_Variable at: n]].auxi[0] = v++;
						return [self realifyFrom: here];
					}
					break;
				case FSE_Escapes:
				case FSE_Vanishes:
					child1 = node[here].firstChild;
					n = [self newNodeOfType: FSE_Arith | FSE_Norm2 at: here];
					newNode = [self cloneSubtreeFrom: child1 to: n];
					[self deleteNodeAt: child1];
					return [self realifyFrom: n];
					break;
			}
			break;
		case FSE_Command: 
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Default:
					t = node[here].type;
					child1 = node[here].firstChild; child2 = node[child1].nextSibling;
					if((node[child1].type == (FSE_Var | FSE_Join)) && (node[child2].type == (FSE_Var | FSE_Join))) {
						int c1, c2, nchilds, join;
						node[here].type = FSE_Command | FSE_Block;
						nchilds = node[child1].children;
						if(node[child1].children != node[child2].children) return @"cannot default vectors of differing dimension";
						c1 = node[child1].firstChild;
						c2 = node[child2].firstChild;
						for(i = 0; i < nchilds; i++) {
							join = [self newNodeOfType: FSE_Command | FSE_Default at: here];
							[self cloneSubtreeFrom: c1 to: join];
							[self cloneSubtreeFrom: c2 to: join];
							c1 = node[c1].nextSibling;
							c2 = node[c2].nextSibling;
						}
						[self deleteNodeAt: child1];
						[self deleteNodeAt: child2];
						return [self realifyFrom: here];
					}
					else if(node[child1].type == (FSE_Var | FSE_Join)) {
						int c1, c2, nchilds, join;
						node[here].type = FSE_Command | FSE_Block;
						nchilds = node[child1].children;
						if(node[child1].children != 2) return @"cannot default vector to scalar";
						c1 = node[child1].firstChild;
						join = [self newNodeOfType: FSE_Command | FSE_Default at: here];
						[self cloneSubtreeFrom: c1 to: join];
						[self cloneSubtreeFrom: child2 to: join];
						c1 = node[c1].nextSibling;
						join = [self newNodeOfType: FSE_Command | FSE_Default at: here];
						[self cloneSubtreeFrom: c1 to: join];
						c2 = [self newNodeOfType: FSE_Var | FSE_Constant at: join];
						node[c2].auxf[0] = 0.0;
						[self deleteNodeAt: child1];
						[self deleteNodeAt: child2];
						return [self realifyFrom: here];
					}
					break;
				case FSE_Set:
					t = node[here].type;
					child1 = node[here].firstChild; child2 = node[child1].nextSibling;
					if((node[child1].type == (FSE_Var | FSE_Join)) && (node[child2].type == (FSE_Var | FSE_Join))) {
						int nchilds, tn, c1, c2;
						nchilds = node[child1].children;
						node[here].type = FSE_Command | FSE_Block;
						if(node[child1].children != node[child2].children) return @"cannot set vectors of differing dimension";
						c1 = node[child1].firstChild;
//						if(node[child1].type != (FSE_Var | FSE_Variable)) 
//							return [NSString stringWithFormat: @"cannot set things that are not variables (node %i)", child1];
						c2 = node[child2].firstChild;

						if(t == (FSE_Command | FSE_Set)) { // here is the dumb part:
							tn = node[c1].auxi[0];
							newNode = [self newNodeOfType: FSE_Command | FSE_Set at: here];
							node[[self newNodeOfType: FSE_Var | FSE_Variable at: newNode]].auxi[0] = tempVar;
							[self cloneSubtreeFrom: c2 to: newNode];
							c1 = node[c1].nextSibling;
							c2 = node[c2].nextSibling;
							newNode = [self newNodeOfType: FSE_Command | FSE_Set at: here];
							node[[self newNodeOfType: FSE_Var | FSE_Variable at: newNode]].auxi[0] = node[c1].auxi[0];
							[self cloneSubtreeFrom: c2 to: newNode];
							newNode = [self newNodeOfType: FSE_Command | FSE_Set at: here];
							node[[self newNodeOfType: FSE_Var | FSE_Variable at: newNode]].auxi[0] = tn;
							node[[self newNodeOfType: FSE_Var | FSE_Variable at: newNode]].auxi[0] = tempVar;
						} // end of the dumb part					
/*
						for(i = 0; i < node[child2].children; i++) {
							newNode = [self newNodeOfType: FSE_Command | FSE_Set at: here];
							node[[self newNodeOfType: FSE_Var | FSE_Variable at: newNode]].auxi[0] = n++;
							[self cloneSubtreeFrom: child to: newNode];
							child = node[child].nextSibling;
						}
*/
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child1].type == (FSE_Var | FSE_Join)) {
						if(node[child1].children != 2) return @"cannot assign scalar to vector";
						child = node[child1].firstChild;
						node[here].type = FSE_Command | FSE_Block;
						newNode = [self newNodeOfType: FSE_Command | FSE_Set at: here];
						[self cloneSubtreeFrom: child to: newNode];
						[self cloneSubtreeFrom: child2 to: newNode];
						child = node[child].nextSibling;
						newNode = [self newNodeOfType: FSE_Command | FSE_Set at: here];
						[self cloneSubtreeFrom: child to: newNode];
						[self nodeAt: [self newNodeOfType: FSE_Var | FSE_Constant at: newNode]] -> auxf[0] = 0.0;
						[self deleteNodeAt: child1]; [self deleteNodeAt: child2];
					}
					else if(node[child2].type == (FSE_Var | FSE_Join)) return @"cannot assign vector to scalar";
					break;
			}
			break;
		default:
			break;
	}
	
	return error;
 }
 
 /* find equivalent subtrees and replace with links */
 - optimizeReserving: (int) nvars {
	NSLog(@"- optimizeReserving: (int) nvars is disabled!!!");
/*	double* var;
	int i, here;
	NSMutableDictionary* hashpile;
	
	var = malloc(nvars * sizeof(double));
	for(i = 0; i < nvars; i++) var[i] = 2.0 * ((double) rand() / (double) RAND_MAX) - 1.0;
	
	hashpile = [[NSMutableDictionary alloc] initWithCapacity: 1024];
	[self optimizeFrom: FSE_RootNode usingVariables: (double*) var hashSet: hashpile];
	NSLog(@"hashpile is %@\n", hashpile);
	[hashpile release];
	free(var);*/
 }

- optimizeFrom: (int) here usingVariables: (double*) var hashSet: (NSMutableDictionary*) hashpile {
	int i, children, child, h;
	NSDictionary* hash;
	NSNumber* n;
	
	if(node[here].children != 0) {
		children = node[here].children;
		child = node[here].firstChild;
		for(i = 0; i < children; i++) {
			[self optimizeFrom: child usingVariables: var hashSet: hashpile];
			child = node[child].nextSibling;
		}
	}
	[self evaluateFrom: here usingVariables: var];
	h = here;
	while(node[h].cloneOf) h = node[h].cloneOf;
	if(node[h].hashed) {
		NSNumber* key;
		key = [NSString stringWithFormat: @"%.18e", node[h].hash];
		n = [hashpile valueForKey: [key stringValue]];
		if(n) {
			if([n intValue] != h) node[h].cloneOf = [n intValue];
		}
		else {
			[hashpile setValue: [NSNumber numberWithInt: h] forKey: [key stringValue]];
		}
	}
 	if(node[here].type == (FSE_Command | FSE_Set)) {
		i = node[node[here].firstChild].auxi[0];
		var[i] = 2.0 * ((double) rand() / (double) RAND_MAX) - 1.0;
	}
}
 
 - (double) evaluateFrom: (int) here usingVariables: (double*) var {
	double x, y, r;
	int child1, child2;
	BOOL noluck;
	
	x = y = -42.0;
	r = 17.0;
	noluck = NO;
	if(node[here].cloneOf) return [self evaluateFrom: node[here].cloneOf usingVariables: var];
	if(node[here].hashed) return node[here].hash;
	child1 = node[here].firstChild;
	child2 = node[child1].nextSibling;
 	switch(node[here].type & FSE_Type_Mask) {
		case FSE_Arith:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Add:
					x = [self evaluateFrom: child1 usingVariables: var];
					y = [self evaluateFrom: child2 usingVariables: var];
					r = x + y;
					break;
				case FSE_Sub:
					x = [self evaluateFrom: child1 usingVariables: var];
					y = [self evaluateFrom: child2 usingVariables: var];
					r = x - y;
					break;
				case FSE_Mul:
					x = [self evaluateFrom: child1 usingVariables: var];
					y = [self evaluateFrom: child2 usingVariables: var];
					r = x * y;
					break;
				case FSE_Div:
					x = [self evaluateFrom: child1 usingVariables: var];
					y = [self evaluateFrom: child2 usingVariables: var];
					r = x / y;
					break;
				case FSE_Norm:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = sqrt(x*x);
					break;
				case FSE_Norm2:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = x*x;
					break;
				case FSE_Conj:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = x;
					break;
				case FSE_Neg:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = -x;
					break;
				case FSE_Inv:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = 1.0 / x;
					break;
				case FSE_Square:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = x*x;
					break;
				default:
					noluck = YES;
					break;
			}
			break;
		case FSE_Func:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Exp:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = exp(x);
					break;
				case FSE_Cosh:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = cosh(x);
					break;
				case FSE_Sinh:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = sinh(x);
					break;
				case FSE_Cos:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = cos(x);
					break;
				case FSE_Sin:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = sin(x);
					break;
				case FSE_Tan:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = tan(x);
					break;
				case FSE_Tanh:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = tanh(x);
					break;
				case FSE_Log:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = log(x);
					break;
				case FSE_Sqrt:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = sqrt(x);
					break;
				case FSE_Re:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = x;
					break;
				case FSE_Im:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = x;
					break;
				case FSE_Arcsin:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = asin(x);
					break;
				case FSE_Arccos:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = acos(x);
					break;
				case FSE_Arctan:
					x = [self evaluateFrom: child1 usingVariables: var];
					r = atan(x);
					break;
				default:
					noluck = YES;
					break;
			}
			break;
		case FSE_Var:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Constant:
					r = node[here].auxf[0];
					break;
				case FSE_Variable:
					r = var[node[here].auxi[0]];
					break;
				default:
					noluck = YES;
					break;
			}
			break;
		default:
			noluck = YES;
			break;
	}
	if(noluck) return 2.0 * ((double) rand() / (double) RAND_MAX) - 1.0;
	NSLog(@"node %i is getting hash %f (x = %f, y = %f)\n", here, r, x, y);
	node[here].hashed = 1; node[here].hash = r;
	return r;
}
 
- (void) countParentsFrom: (int) h {
	int here, c, i, nchilds;
	
	here = h;
	while(node[here].cloneOf) here = node[here].cloneOf;
	++node[here].nparents;
	nchilds = node[here].children;
	if(nchilds) {
		c = node[here].firstChild;
		[self countParentsFrom: c];
		if(nchilds > 1) for(i = 0; i < nchilds - 1; i++) {
			c = node[c].nextSibling;
			[self countParentsFrom: c];
		}
	}
}

- (void) linearizeTo: (FSEOpStream*) program {
	
	NSLog(@"linearizing...\n");
	program -> ops = 0;
	program -> allocation_size = 1024;
	program -> savedops = 0;
	program -> saved_allocation_size = 1024;
	program -> registers = 0;
	program -> op = (FSEOp*) malloc(program -> allocation_size * sizeof(FSEOp));
	program -> savedop = (FSEOp*) malloc(program -> saved_allocation_size * sizeof(FSEOp));
	
	[self countParentsFrom: FSE_RootNode];
	node[FSE_RootNode].nparents = 0;

	
	[self linearizeFrom: node[node[FSE_RootNode].firstChild].nextSibling intoOpStream: program];

}

- (void) addOp: (FSEOp*) op toOpStream: (FSEOpStream*) program {
	if(program -> ops == program -> allocation_size) {
		program -> allocation_size += 1024;
		program -> op = realloc(program -> op, program -> allocation_size * sizeof(FSEOp));
	}
	memcpy(&((program -> op)[program -> ops]), op, sizeof(FSEOp));
	program -> ops++;
}

- (void) reduceOpStream: (FSEOpStream*) program toRegisterCount: (int) reg {
	int* range[2];
	int* alias;
	FSEOpStream* rprogram;
	FSEOpStream rpr;
	int i, j;
	
	if(program -> registers == 1) return; // dumb case, probably never happens
	
	rprogram = &rpr;
	rprogram -> ops = 0;
	rprogram -> allocation_size = 1024;
	rprogram -> savedops = 0;
	rprogram -> registers = reg;
	rprogram -> op = (FSEOp*) malloc(rprogram -> allocation_size * sizeof(FSEOp));
	range[0] = (int*) malloc(program -> registers * sizeof(int));
	range[1] = (int*) malloc(program -> registers * sizeof(int));
	alias = (int*) malloc(program -> registers * sizeof(int));

	for(i = 0; i < program -> registers; i++) { range[0][i] = 0; range[1][i] = program -> ops; alias[i] = i; }
	
	// migrate loads outside of loops
	for(i = 0; i < program -> ops; i++) {
		int lastloop = 0;
		FSEOp op;
		if(program -> op[i].type == (FSE_Command | FSE_LoopLabel)) lastloop = i;
		if(program -> op[i].type == (FSE_Var | FSE_Variable)) {
			memcpy(&op, &(program -> op[i]), sizeof(FSEOp));
			for(j = 0; j < i - lastloop; j++) memcpy(&(program -> op[i - j]), &(program -> op[i - j - 1]), sizeof(FSEOp));
			memcpy(&(program -> op[lastloop]), &op, sizeof(FSEOp));
		}
	}

	// find store commands or multiple loads, use to seed the alias table
	for(i = 0; i < program -> ops - 1; i++) {
		if(program -> op[i].type == (FSE_Command | FSE_Store)) {
			for(j = i + 1; j < program -> ops; j++) {
				if((program -> op[j].type == (FSE_Var | FSE_Variable)) && ((int) program -> op[j].aux[0] == (int) program -> op[i].aux[0])) {
					program -> op[j].type = FSE_Command | FSE_Copy;
					program -> op[j].lhs = program -> op[i].lhs;
					alias[program -> op[j].result] = alias[program -> op[i].lhs];
					program -> op[i].type = FSE_Command | FSE_NoOp;
					program -> op[i].lhs = program -> op[i].rhs = program -> op[i].result = -1;
				}
				if((program -> op[j].type == (FSE_Command | FSE_Store)) && ((int) program -> op[j].aux[0] == (int) program -> op[i].aux[0])) break;
			}
		}
		if(program -> op[i].type == (FSE_Var | FSE_Variable)) {
			for(j = i + 1; j < program -> ops; j++) {
				if((program -> op[j].type == (FSE_Var | FSE_Variable)) && ((int) program -> op[j].aux[0] == (int) program -> op[i].aux[0])) {
					program -> op[j].type = FSE_Command | FSE_Copy;
					program -> op[j].lhs = program -> op[i].result;
				}
				if((program -> op[j].type == (FSE_Command | FSE_Store)) && ((int) program -> op[j].aux[0] == (int) program -> op[i].aux[0])) {
					program -> op[j].type = FSE_Command | FSE_Copy;
					program -> op[j].result = program -> op[i].result;
				}
			}
		}
	}

	for(i = 0; i < program -> ops; i++) {
		if(program -> op[i].lhs >= 0) program -> op[i].lhs = alias[program -> op[i].lhs];
		if(program -> op[i].rhs >= 0) program -> op[i].rhs = alias[program -> op[i].rhs];
		if(program -> op[i].result >= 0) program -> op[i].result = alias[program -> op[i].result];
	}
	
	// compute ranges in which each variable is active
	//for(i = 0; i < program -> registers; i++) alias[i] = i;
	for(i = 0; i < program -> ops; i++) {
		if(program -> op[i].lhs >= 0) range[(range[0][program -> op[i].lhs] > 0)? 1 : 0][program -> op[i].lhs] = i;
		if(program -> op[i].rhs >= 0) range[(range[0][program -> op[i].rhs] > 0)? 1 : 0][program -> op[i].rhs] = i;
		if(program -> op[i].result >= 0) range[(range[0][program -> op[i].result] > 0)? 1 : 0][program -> op[i].result] = i;
	}
	
//	for(i = 0; i < program -> registers; i++) NSLog(@"r%i has active range (%i, %i)\n", i, range[0][i], range[1][i]);
	
	for(i = 0; i < program -> registers; i++) {
		for(j = 0; j < program -> registers; j++) {
			if((range[1][i] <= range[0][j]) && (j == alias[j])) {
				alias[j] = alias[i];
				break;
			}
		}
	}
//	for(i = 0; i < program -> registers; i++) NSLog(@"r%i ---> r%i\n", i, alias[i]);

	for(i = 0; i < program -> ops; i++) {
		if(program -> op[i].lhs >= 0) program -> op[i].lhs = alias[program -> op[i].lhs];
		if(program -> op[i].rhs >= 0) program -> op[i].rhs = alias[program -> op[i].rhs];
		if(program -> op[i].result >= 0) program -> op[i].result = alias[program -> op[i].result];
		if((program -> op[i].type == (FSE_Command | FSE_Copy)) && (program -> op[i].lhs == program -> op[i].result)) {
			program -> op[i].lhs = program -> op[i].result = -1;
			program -> op[i].type = FSE_Command | FSE_NoOp;
		}
	}
	

}

- (int) linearizeFrom: (int) h intoOpStream: (FSEOpStream*) program {
	int here, i, nkids, c, rhs;
	FSEOp op;
	here = h;
	
	op.type = FSE_Command | FSE_InvalidOp;
	op.lhs = op.rhs = -1;
	op.result = -1;
	
	while(node[here].cloneOf) here = node[here].cloneOf;
	if(node[here].processed) return node[here].result;

	switch(node[here].type & FSE_Type_Mask) {
		case FSE_Command:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Block:
					nkids = node[here].children;
					c = node[here].firstChild;
					[self linearizeFrom: c intoOpStream: program];
					if(nkids > 1) for(i = 0; i < nkids - 1; i++) {
						c = node[c].nextSibling;
						[self linearizeFrom: c intoOpStream: program];
					}
					op.type = FSE_Command | FSE_NoOp;
					break;
				case FSE_Set:
					op.type = FSE_Command | FSE_Store;
					op.aux[0] = (int) node[node[here].firstChild].auxi[0];
					op.lhs = [self linearizeFrom: node[node[here].firstChild].nextSibling intoOpStream: program];
					op.result = op.rhs;
					break;
				case FSE_Flag:
					op.type = node[here].type;
					break;
				case FSE_Do:
					op.type = FSE_Command | FSE_LoopLabel;
					[self addOp: &op toOpStream: program];
					[self linearizeFrom: node[here].firstChild intoOpStream: program];
					[self linearizeFrom: node[node[here].firstChild].nextSibling intoOpStream: program];
					op.type = FSE_Command | FSE_LoopJump;
					break;
				case FSE_Report:
					op.type = node[here].type;
					op.aux[0] = (int) node[here].auxi[0];
					break;
				case FSE_Bumpdown:
					op.type = FSE_Command | FSE_NoOp;
					break;
				case FSE_If:
				
					break;
				case FSE_Iterate:
				case FSE_Par:
				case FSE_Dyn:
					op.type = FSE_Command | FSE_InvalidOp;
					break;
				case FSE_Default:
					op.type = node[here].type;
					op.aux[0] = (int) node[node[here].firstChild].auxi[0];
					op.result = program -> registers++;
					break;
				case FSE_Clear:
					op.type = node[here].type;
					op.aux[0] = (int) node[node[here].firstChild].auxi[0];
					break;
				case FSE_Repeat:
					op.type = node[here].type;
					op.aux[0] = (double) node[here].auxi[0];
					[self addOp: &op toOpStream: program];
					[self linearizeFrom: node[here].firstChild intoOpStream: program];
					op.type = FSE_Command | FSE_Loop;
					op.aux[0] = 0.0;
					break;
				case FSE_Modulo:
					break;
			}
			break;
		case FSE_Var:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Complex:
				case FSE_Real:
				case FSE_PosReal:
				case FSE_Truth:
				case FSE_C_Const:
				case FSE_R_Const:
				case FSE_Join:
				case FSE_Counter:
					op.type = FSE_Command | FSE_InvalidOp;
					break;
				case FSE_Ident:
					return [self linearizeFrom: node[here].firstChild intoOpStream: program];
					break;
				case FSE_LinkedSubexpression:
					return [self linearizeFrom: node[here].auxi[0] intoOpStream: program];
					break;
				case FSE_Constant:
					op.type = node[here].type;
					op.aux[0] = node[here].auxf[0];
					op.result = program -> registers++;
				case FSE_Variable:
					op.type = node[here].type;
					op.aux[0] = (double) node[here].auxi[0];
					op.result = program -> registers++;
					break;
			}
			break;
		case FSE_Arith:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Add:
				case FSE_Sub:
				case FSE_Mul:
				case FSE_Div:
					op.type = node[here].type;
					op.lhs = [self linearizeFrom: node[here].firstChild intoOpStream: program];
					op.rhs = [self linearizeFrom: node[node[here].firstChild].nextSibling intoOpStream: program];
					op.result = program -> registers++;
					break;
				case FSE_Norm2:
				case FSE_Neg:
				case FSE_Inv:
					op.type = node[here].type;
					op.lhs = [self linearizeFrom: node[here].firstChild intoOpStream: program];
					op.result = program -> registers++;
					break;
				case FSE_Norm:
				case FSE_Conj:
				case FSE_Square:
				case FSE_Power:
					op.type = FSE_Command | FSE_InvalidOp;					
					break;
			}
			break;
		case FSE_Comp:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Equal:
				case FSE_LT:
				case FSE_GT:
				case FSE_LTE:
				case FSE_GTE:
				case FSE_NotEqual:
					op.type = node[here].type;
					op.lhs = [self linearizeFrom: node[here].firstChild intoOpStream: program];
					op.rhs = [self linearizeFrom: node[node[here].firstChild].nextSibling intoOpStream: program];
					break;
				case FSE_Escapes:
				case FSE_Vanishes:
					op.type = node[here].type;
					op.lhs = [self linearizeFrom: node[here].firstChild intoOpStream: program];
					break;
				case FSE_Stops:
					op.type = FSE_Command | FSE_InvalidOp;
					break;
			}
			break;
		case FSE_Bool:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Or:
				case FSE_And:
				case FSE_Not:
					break;
				case FSE_Xor:
				case FSE_Nor:
				case FSE_Nand:
					op.type = FSE_Command | FSE_InvalidOp;
					break;
			}
			break;
		case FSE_Func:
			switch(node[here].type & (-1 ^ FSE_Type_Mask)) {
				case FSE_Exp:
				case FSE_Cosh:
				case FSE_Sinh:
				case FSE_Cos:
				case FSE_Sin:
				case FSE_Tan:
				case FSE_Tanh:
				case FSE_Log:
				case FSE_Sqrt:
				case FSE_Arccos:
				case FSE_Arcsin:
				case FSE_Arctan:
				case FSE_Arg:
					op.type = node[here].type;
					op.lhs = [self linearizeFrom: node[here].firstChild intoOpStream: program];
					op.result = program -> registers++;
					break;
				case FSE_Re:
				case FSE_Im:
					op.type = FSE_Command | FSE_InvalidOp;
					break;
			}
			break;
	}
	[self addOp: &op toOpStream: program];
	if(op.result != -1) node[here].processed = 1;
	node[here].result = op.result;
	return op.result;
}

/* Assign temporary variables to all the nodes and combine subtrees when possible. */
- (NSString*) postprocessReserving: (int) firstTemp {
	int depth;
	BOOL* lock;
	int i, child, child1, child2, k, here, savedHere;
	double r, t;
	
	NSString* error;
	
	return;
	NSLog(@"\n\n**** computing dependency chains ****\n\n");
	
	lock = malloc(nodes * sizeof(BOOL));
	for(i = 0; i < firstTemp; i++) lock[i] = YES;
	
	if(node[FSE_RootNode].children == 0) return;

	here = FSE_RootNode;
	while(node != FSE_Nil) {
	}
}

- (void) log {
	int currentNode;
	int depth, i;
	NSString* log;
	
	log = [[NSString alloc] initWithString: @"Parse tree:\n"];
	depth = 0;
#define Indent for(i = 0; i < depth; i++) log = [log stringByAppendingString: @"  "];

	if(node[FSE_RootNode].children == 0) { 
		log = [log stringByAppendingString: @"{}"];
		return;
	}
	
	currentNode = node[FSE_RootNode].firstChild;
	currentNode = node[currentNode].nextSibling;
	NSLog(@"%@", log);
	[self logFrom: currentNode atDepth: 0];
}
	
- (void) logOpStream: (FSEOpStream*) program {
		NSString* log;
		int i, clonedepth, c;

		log = [NSString stringWithString: @"\n\n"];
		for(i = 0; i < program -> ops; i++) {
			switch(program -> op[i].type & FSE_Type_Mask) {
				case FSE_Command:
					switch(program -> op[i].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Block:
						case FSE_Set:
						case FSE_Iterate:
						case FSE_Par:
						case FSE_Dyn:
						case FSE_Do:
						case FSE_If:
						case FSE_Reset:
						case FSE_Bumpdown:
						case FSE_Modulo:
							log = [log stringByAppendingFormat: @"<<< invalid FSE_Command %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
						case FSE_Repeat:
							log = [log stringByAppendingFormat: @"repeat \'%i\'\n", (int) program -> op[i].aux[0]]; break;
						case FSE_Clear:
							log = [log stringByAppendingFormat: @"clear v%i\n", (int) program -> op[i].aux[0]]; break;
						case FSE_Default:
							log = [log stringByAppendingFormat: @"read v%i -> %i\n", (int) program -> op[i].aux[0], program -> op[i].result]; break;
						case FSE_Report:
							log = [log stringByAppendingFormat: @"log v%i\n", (int) program -> op[i].aux[0]]; break;
						case FSE_Flag:
							log = [log stringByAppendingString: @"flag\n"]; break;
						case FSE_Store:
							log = [log stringByAppendingFormat: @"store v%i, %i\n", (int) program -> op[i].aux[0], program -> op[i].lhs]; break;
						case FSE_NoOp:
							break; log = [log stringByAppendingFormat: @"noop\n"]; break;
						case FSE_InvalidOp:
							log = [log stringByAppendingFormat: @"INVALID\n"]; break;
						case FSE_LoopLabel:
							log = [log stringByAppendingFormat: @"start-loop\n"]; break;
						case FSE_CompLabel:
							log = [log stringByAppendingFormat: @"end-comparison\n"]; break;
						case FSE_CompJump:
							log = [log stringByAppendingFormat: @"jump-fwd\n"]; break;
						case FSE_LoopJump:
							log = [log stringByAppendingFormat: @"jump-back\n"]; break;
						case FSE_Copy:
							log = [log stringByAppendingFormat: @"copy %i -> %i\n", program -> op[i].lhs, program -> op[i].result]; break;
						default:
							log = [log stringByAppendingFormat: @"<<< unknown FSE_Command %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
					}
				break;
			case FSE_Arith:
					switch(program -> op[i].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Add:
							log = [log stringByAppendingFormat: @"add %i, %i -> %i\n",
								program -> op[i].lhs, program -> op[i].rhs, program -> op[i].result]; break;
						case FSE_Sub:
							log = [log stringByAppendingFormat: @"sub %i, %i -> %i\n",
								program -> op[i].lhs, program -> op[i].rhs, program -> op[i].result]; break;
						case FSE_Mul:
							log = [log stringByAppendingFormat: @"mul %i, %i -> %i\n",
								program -> op[i].lhs, program -> op[i].rhs, program -> op[i].result]; break;
						case FSE_Div:
							log = [log stringByAppendingFormat: @"div %i, %i -> %i\n",
								program -> op[i].lhs, program -> op[i].rhs, program -> op[i].result]; break;
						case FSE_Norm2:
							log = [log stringByAppendingFormat: @"norm2 %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Neg:
							log = [log stringByAppendingFormat: @"neg %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Inv:
							log = [log stringByAppendingFormat: @"inv %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Square:
							log = [log stringByAppendingFormat: @"square %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Conj:
						case FSE_Norm:
						case FSE_Power:
							log = [log stringByAppendingFormat: @"<<< invalid FSE_Arith %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
						default:
							log = [log stringByAppendingFormat: @"<<< unknown FSE_Arith %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
					}
				break;
			case FSE_Bool:
					switch(program -> op[i].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Or:
						case FSE_And:
						case FSE_Xor:
						case FSE_Nor:
						case FSE_Nand:
							log = [log stringByAppendingFormat: @"<<< invalid FSE_Bool %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
						case FSE_Not:
							log = [log stringByAppendingFormat: @"not\n"]; break;
						default:
							log = [log stringByAppendingFormat: @"<<< unknown FSE_Bool %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
					}
				break;
			case FSE_Comp:
					switch(program -> op[i].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Equal:
							log = [log stringByAppendingFormat: @"equal %i, %i\n",
								program -> op[i].lhs, program -> op[i].rhs]; break;
						case FSE_LT:
							log = [log stringByAppendingFormat: @"lt %i, %i\n",
								program -> op[i].lhs, program -> op[i].rhs]; break;
						case FSE_GT:
							log = [log stringByAppendingFormat: @"gt %i, %i\n",
								program -> op[i].lhs, program -> op[i].rhs]; break;
						case FSE_LTE:
							log = [log stringByAppendingFormat: @"lte %i, %i\n",
								program -> op[i].lhs, program -> op[i].rhs]; break;
						case FSE_GTE:
							log = [log stringByAppendingFormat: @"gte %i, %i\n",
								program -> op[i].lhs, program -> op[i].rhs]; break;
						case FSE_NotEqual:
							log = [log stringByAppendingFormat: @"not-equal %i, %i\n",
								program -> op[i].lhs, program -> op[i].rhs]; break;
						case FSE_Escapes:
							log = [log stringByAppendingFormat: @"big %i\n",
								program -> op[i].lhs]; break;
						case FSE_Vanishes:
							log = [log stringByAppendingFormat: @"tiny %i\n",
								program -> op[i].lhs]; break;
						case FSE_Stops:
							log = [log stringByAppendingFormat: @"<<< invalid FSE_Comp %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
						default:
							log = [log stringByAppendingFormat: @"<<< unknown FSE_Comp %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
					}
				break;
			case FSE_Var:
					switch(program -> op[i].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Complex:
						case FSE_Real:
						case FSE_PosReal:
						case FSE_Truth:
						case FSE_C_Const:
						case FSE_R_Const:
						case FSE_Ident:
						case FSE_Join:
						case FSE_LinkedSubexpression:
						case FSE_Counter:
							log = [log stringByAppendingFormat: @"<<< invalid FSE_Var %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
						case FSE_Constant:
							log = [log stringByAppendingFormat: @"load \'%f\' -> %i\n", program -> op[i].aux[0], program -> op[i].result]; break;
						case FSE_Variable:
							log = [log stringByAppendingFormat: @"load v%i -> %i\n", (int) program -> op[i].aux[0], program -> op[i].result]; break;
							break;
						default:
							log = [log stringByAppendingFormat: @"<<< unknown FSE_Var %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
					}
				break;
			case FSE_Func:
					switch(program -> op[i].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Exp:
							log = [log stringByAppendingFormat: @"exp %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Cosh:
							log = [log stringByAppendingFormat: @"cosh %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Sinh:
							log = [log stringByAppendingFormat: @"sinh %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Tanh:
							log = [log stringByAppendingFormat: @"tanh %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Cos:
							log = [log stringByAppendingFormat: @"cos %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Sin:
							log = [log stringByAppendingFormat: @"sin %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Tan:
							log = [log stringByAppendingFormat: @"tan %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Log:
							log = [log stringByAppendingFormat: @"log %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Sqrt:
							log = [log stringByAppendingFormat: @"sqrt %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Arccos:
							log = [log stringByAppendingFormat: @"arccos %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Arcsin:
							log = [log stringByAppendingFormat: @"arcsin %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Arctan:
							log = [log stringByAppendingFormat: @"arctan %i -> %i\n",
								program -> op[i].lhs, program -> op[i].result]; break;
						case FSE_Arg:
						case FSE_Re:
						case FSE_Im:
							log = [log stringByAppendingFormat: @"<<< invalid FSE_Func %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
						default:
							log = [log stringByAppendingFormat: @"<<< unknown FSE_Func %i >>>\n", program -> op[i].type & (-1 ^ FSE_Type_Mask)];
							break;
					}
				break;
		}
	}
	NSLog(@"%@\n", log);
}

- (void) logFrom: (int) currentNode atDepth: (int) depth {
		NSString* log;
		int i, clonedepth, c;

		clonedepth = 0;
		c = currentNode;
		while(node[c].cloneOf) { c = node[c].cloneOf; ++clonedepth; }
		if(clonedepth) { [self logFrom: c atDepth: depth]; return; }
		
		log = [[NSString alloc] initWithFormat: @"[%3i]<%i>: ", currentNode, node[currentNode].nparents]; Indent;
		switch(node[currentNode].type & FSE_Type_Mask) {
			case FSE_Command:
					switch(node[currentNode].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Block:
							 log = [log stringByAppendingFormat: @"block"]; break;
						case FSE_Iterate:
							log = [log stringByAppendingFormat: @"iterate"]; break;
						case FSE_Do:
							log = [log stringByAppendingFormat: @"do"]; break;
						case FSE_Set:
							log = [log stringByAppendingFormat: @"set"]; break;
						case FSE_Par:
							log = [log stringByAppendingFormat: @"par"]; break;
						case FSE_Dyn:
							log = [log stringByAppendingFormat: @"dyn"]; break;
						case FSE_Report:
							log = [log stringByAppendingFormat: @"report"]; break;
						case FSE_If:
							log = [log stringByAppendingFormat: @"if"]; break;
						case FSE_Flag:
							log = [log stringByAppendingFormat: @"flag"]; break;
						case FSE_Default:
							log = [log stringByAppendingFormat: @"default"]; break;
						case FSE_Reset:
							log = [log stringByAppendingFormat: @"reset"]; break;
						case FSE_Bumpdown:
							log = [log stringByAppendingFormat: @"bumpdown"]; break;
						case FSE_Clear:
							log = [log stringByAppendingFormat: @"clear:%i", node[currentNode].auxi[0]]; break;
						default:
							log = [log stringByAppendingFormat: @"command"]; break;
					}
					break;
			case FSE_Arith:
					switch(node[currentNode].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Add:
							log = [log stringByAppendingFormat: @"+"]; break;
						case FSE_Sub:
							log = [log stringByAppendingFormat: @"-"]; break;
						case FSE_Mul:
							log = [log stringByAppendingFormat: @"*"]; break;
						case FSE_Div:
							log = [log stringByAppendingFormat: @"/"]; break;
						case FSE_Norm:
							log = [log stringByAppendingFormat: @"norm"]; break;
						case FSE_Norm2:
							log = [log stringByAppendingFormat: @"norm2"]; break;
						case FSE_Conj:
							log = [log stringByAppendingFormat: @"bar"]; break;
						case FSE_Neg:
							log = [log stringByAppendingFormat: @"neg"]; break;
						case FSE_Inv:
							log = [log stringByAppendingFormat: @"inv"]; break;
						case FSE_Square:
							log = [log stringByAppendingFormat: @"sqr"]; break;
						case FSE_Power:
							log = [log stringByAppendingFormat: @"^"]; break;
						default:
							log = [log stringByAppendingFormat: @"unknown-arith"]; break;
					}
				break;
			case FSE_Bool:
					switch(node[currentNode].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Or:
							log = [log stringByAppendingString: @"or"]; break;
						case FSE_And:
							log = [log stringByAppendingString: @"and"]; break;
						case FSE_Xor:
							log = [log stringByAppendingString: @"xor"]; break;
						case FSE_Nor:
							log = [log stringByAppendingString: @"nor"]; break;
						case FSE_Nand:
							log = [log stringByAppendingString: @"nand"]; break;
						case FSE_Not:
							log = [log stringByAppendingString: @"not"]; break;
						default:
							log = [log stringByAppendingString: @"unknown-bool"]; break;
					}
				break;
			case FSE_Comp:
					switch(node[currentNode].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Equal:
							log = [log stringByAppendingString: @"="]; break;
						case FSE_LT:
							log = [log stringByAppendingString: @"<"]; break;
						case FSE_GT:
							log = [log stringByAppendingString: @">"]; break;
						case FSE_LTE:
							log = [log stringByAppendingString: @"<="]; break;
						case FSE_GTE:
							log = [log stringByAppendingString: @">="]; break;
						case FSE_NotEqual:
							log = [log stringByAppendingString: @"=/="]; break;
						case FSE_Escapes:
							log = [log stringByAppendingString: @"escapes"]; break;
						case FSE_Stops:
							log = [log stringByAppendingString: @"stops"]; break;
						case FSE_Vanishes:
							log = [log stringByAppendingString: @"vanishes"]; break;
						default:
							log = [log stringByAppendingString: @"unknown-comp"]; break;
					}
				break;
			case FSE_Var:
					switch(node[currentNode].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Complex:
							log = [log stringByAppendingFormat: @"C:%i", node[currentNode].auxi[0]]; break;
						case FSE_Real:
							log = [log stringByAppendingFormat: @"R:%i", node[currentNode].auxi[0]]; break;
						case FSE_PosReal:
							log = [log stringByAppendingFormat: @"R+:%i", node[currentNode].auxi[0]]; break;
						case FSE_Truth:
							log = [log stringByAppendingFormat: @"Tr:%i", node[currentNode].auxi[0]]; break;
						case FSE_C_Const:
							log = [log stringByAppendingFormat: @"%.3f + %.3f i", (float) node[currentNode].auxf[0], (float) node[currentNode].auxf[1]]; break;
						case FSE_R_Const:
							log = [log stringByAppendingFormat: @"%.3f", (float) node[currentNode].auxf[0]]; break;
						case FSE_Ident:
							log = [log stringByAppendingString: @"id"]; break;
						case FSE_Join:
							log = [log stringByAppendingString: @"vector"]; break;
						case FSE_LinkedSubexpression:
							log = [log stringByAppendingString: @"linked-subexpr"]; break;
						case FSE_Constant:
							log = [log stringByAppendingFormat: @"constant: %.3f", node[currentNode].auxf[0]]; break;
						case FSE_Variable:
							log = [log stringByAppendingFormat: @"variable: %i", node[currentNode].auxi[0]]; break;
						case FSE_Counter:
							log = [log stringByAppendingString: @"counter"]; break;
						default:
							log = [log stringByAppendingString: @"unknown-var"]; break;
					}
				break;
			case FSE_Func:
					switch(node[currentNode].type & (-1 ^ FSE_Type_Mask)) {
						case FSE_Exp:
							log = [log stringByAppendingString: @"exp"]; break;
						case FSE_Cosh:
							log = [log stringByAppendingString: @"cosh"]; break;
						case FSE_Sinh:
							log = [log stringByAppendingString: @"sinh"]; break;
						case FSE_Tanh:
							log = [log stringByAppendingString: @"tanh"]; break;
						case FSE_Cos:
							log = [log stringByAppendingString: @"cos"]; break;
						case FSE_Sin:
							log = [log stringByAppendingString: @"sin"]; break;
						case FSE_Tan:
							log = [log stringByAppendingString: @"tan"]; break;
						case FSE_Log:
							log = [log stringByAppendingString: @"log"]; break;
						case FSE_Sqrt:
							log = [log stringByAppendingString: @"sqrt"]; break;
						case FSE_Re:
							log = [log stringByAppendingString: @"real"]; break;
						case FSE_Im:
							log = [log stringByAppendingString: @"imag"]; break;
						case FSE_Arccos:
							log = [log stringByAppendingString: @"arccos"]; break;
						case FSE_Arcsin:
							log = [log stringByAppendingString: @"arcsin"]; break;
						case FSE_Arctan:
							log = [log stringByAppendingString: @"arctan"]; break;
						case FSE_Arg:
							log = [log stringByAppendingString: @"arg"]; break;
						default:
							log = [log stringByAppendingString: @"unknown-func"]; break;
					}
				break;
		}
//		log = [log stringByAppendingString: @"\n"];
		if(node[currentNode].hashed) NSLog(@"%@    (hash = %f)\n", log, node[currentNode].hash);
		else NSLog(@"%@\n", log);
		if(node[currentNode].children != 0) {
			int child, n;
			n = node[currentNode].children;
			child = node[currentNode].firstChild;
			for(i = 0; i < n; i++) { [self logFrom: child atDepth: depth + 1]; child = node[child].nextSibling; }
		}
		return;
}

@end
