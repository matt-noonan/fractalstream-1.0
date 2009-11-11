/****************************************************************************

	FSSession instances are used for storing the history of views which 
	the user has made (which program, which regions viewed, notes).
	
****************************************************************************/

#import <Cocoa/Cocoa.h>
#import "FSViewerData.h"

#define Session_Nodes 128

//int GlobalNodeCount = 0;

@interface FSSessionNode : NSObject <NSCoding> {

	@public
		double upperLeft[2];
		double lowerRight[2];
		double scale;
		double center[2];
		int program;
		FSViewerData data;
		NSString* title;
		NSString* notes;
		int children;
		FSSessionNode* nextSibling;
		FSSessionNode* previousSibling;
		FSSessionNode* parent;
		FSSessionNode* firstChild;
		FSSessionNode* favoredChild;
		NSMutableDictionary* extra;
		int nodeNumber;
}


- (double) scale;
- (double) centerX;
- (double) centerY;

- (id) setViewportX: (double) x Y: (double) y scale: (double) c;
- (id) setTitle: (NSString*) newTitle;
- (FSViewerData) data;
- (FSViewerData*) dataPtr;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;
- (NSMutableDictionary*) extra;

@end



@interface FSSession : NSObject <NSCoding> {
	
	@protected
		IBOutlet NSOutlineView* historyView;
		IBOutlet id owner;
		FSSessionNode* root;
		FSSessionNode* currentNode;
		
		NSImage* cachedView;
		NSImage* workingView;
	
	@public
		NSData* sessionNotes;
		NSString* sessionTitle;
		NSString* sessionProgram;
		NSFileWrapper* sessionKernel;
		NSArray* flagNames;
		BOOL kernelIsCached;
}

- (FSSessionNode*) getRootNode;
- (FSSessionNode*) getCurrentNode;
- (FSSessionNode*) currentNode;

- (void) getSessionFrom: (FSSession*) session;

- (void) setFlags: (NSArray*) flagArray;
- (void) setTitle: (NSString*) title;
- (void) setNotes: (NSData*) notes;
- (void) setProgram: (NSString*) program;
- (void) readKernelFrom: (NSString*) path;
- (void) setKernelIsCached: (BOOL) isCached;
- (NSString*) title;
- (NSString*) program;
- (NSData*) notes;
- (NSFileWrapper*) kernelWrapper;

- (NSArray*) flagNames;

- (IBAction) goToRoot: (id) sender;
- (IBAction) selectCurrentParent: (id) sender;
- (IBAction) cloneCurrentNode: (id) sender;
- (IBAction) deleteCurrentNode: (id) sender;
- (IBAction) deleteCurrentChildren: (id) sender;
- (IBAction) goBackward: (id) sender;
- (IBAction) goForward: (id) sender;

- (FSSessionNode*) addChildNode: (FSSessionNode*) child andMakeCurrent: (BOOL) makeCurrent;
- (FSSessionNode*) addChildNodeWithLocation: (double*) box andProgram: (int) program;
- (FSSessionNode*) addChildNodeWithScale: (double) scale X: (double) x Y: (double) y flags: (int) flag;
- (FSSessionNode*) addChildWithData: (FSViewerData) theData andMakeCurrent: (BOOL) makeCurrent;
- (FSSessionNode*) root;

- (BOOL) kernelIsCached;

// required methods for NSOutlineView
- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (FSSessionNode*) item;
- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (FSSessionNode*) item;
- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (FSSessionNode*) item;
- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) tableColumn
	byItem: (FSSessionNode*) item;

- (void) encodeWithCoder: (NSCoder*) coder;
- (id) initWithCoder: (NSCoder*) coder;

- (void) changeTo: (FSSessionNode*) node;

@end
