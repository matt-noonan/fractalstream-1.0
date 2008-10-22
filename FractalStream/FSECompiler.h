/* FSECompiler */

#import <Cocoa/Cocoa.h>
#import "FSEParseTree.h"
#import "FSEC_gcc.h"

/* This class builds a FSEParseTree from the source code.  This parse tree can then be interpreted by
	any back-end systems (see FSEC_gcc.c for a simple example) */

typedef struct {
	NSString* word;
	int code;
	BOOL par;
	int type;
} FSEDict;


@interface FSECompiler : NSObject
{
    NSTextStorage *description;
	NSString *source;
    NSString *title;
	NSString *symbol;
	NSString *filename;
	NSString* literalSource;
	NSString* error;
	NSMutableArray* flags;
	NSMutableArray* probes;
	NSString* customPath;
	NSRange lastRange;
	FSEParseTree *tree;
#define FSECOMPILER_VARIABLES 1024
	FSEDict var[FSECOMPILER_VARIABLES];
	int index, node, nextvar, orphan, currentFlagID;
	int usesC;
	BOOL useComplexVars, useCustom;
}

- (IBAction) compile: (id) sender;

- (int) extractArithBelowNode: (int) node;
- (int) extractBoolBelowNode: (int) node;

- (void) setOutputFilename: (NSString*) newFilename;

- (void) setTitle: (NSString*) newTitle source: (NSString*) newSource andDescription: (NSTextStorage*) newDescription;

- (int) addVariable: (NSString*) name;
- (NSString*) nameOfVariableAtIndex: (int) index;
- (int) indexOfVariableWithName: (NSString*) name;
- (int) parameterNumberOfVariableAtIndex: (int) idx;
- (void) setVariableWithName: (NSString*) name toType: (int) type;
- (NSArray*) flagArray;
- (NSArray*) probeArray;
- (NSString*) errorMessage;
- (NSRange) errorRange;
- (NSArray*) parameters;
- (void) printVariableStack;

- (BOOL) isParametric;
- (BOOL) usesCustom;
- (NSString*) customPath;

@end
