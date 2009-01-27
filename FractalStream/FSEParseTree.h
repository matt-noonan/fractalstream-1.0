//
//  FSEParseTree.h
//  FSEdit
//
//  Created by Matt Noonan on 5/24/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <math.h>
#import "FSEParseNode.h"
#import <stdlib.h>

@interface FSEParseTree : NSObject {

	int nodes, nextNode;
	FSEParseNode* node;
	BOOL reordered;
	int stackPtr;
	int loopStack[256];
	int tempVar;
}

- (void) deleteNodeAt: (int) spot;
- (int) newNodeOfType: (int) type at: (int) spot;
- (int) newOrphanOfType: (int) type;
- (int) setParentOfNode: (int) child to: (int) parent;
- (void) swapBirthOrderAt: (int) spot;
- (FSEParseNode*) nodeAt: (int) index;
- (void) reorder;
- (NSString*) postprocessReserving: (int) firstTemp;
- (void) log;
- (int) size;
- (void) setTempVar: (int) newTempVar;
- (void) countParentsFrom: (int) h;
- (void) logOpStream: (FSEOpStream*) program;
- (void) logFrom: (int) currentNode atDepth: (int) depth;
 - (NSString*) realifyFrom: (int) here;
- (void) reorderFromNode: (int) here;
- (int) weight: (int) type;
 - (double) evaluateFrom: (int) here usingVariables: (double*) var;
- (void) linearizeTo: (FSEOpStream*) program;
- (void) addOp: (FSEOp*) op toOpStream: (FSEOpStream*) program;
- (int) linearizeFrom: (int) h intoOpStream: (FSEOpStream*) program;
- (void) reduceOpStream: (FSEOpStream*) program toRegisterCount: (int) reg;
- (void) insertOp: (FSEOp*) op intoProgram: (FSEOpStream*) program atLocation: (int) loc;
- (FSEParseNode*) nodeAt: (int) index;


@end
