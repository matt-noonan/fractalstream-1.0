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
 - (double) evaluateFrom: (int) here usingVariables: (double*) var hashSet: (NSMutableDictionary*) hashpile;

@end
