/* FSViewer class, controls the display of dynamical systems.  This version is designed for output in OpenGL views. */

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <math.h>
#import "FSViewerData.h"
#import <FSColorWidget.h>

typedef struct {
	int type;
		#define FSVO_Point	0
		#define FSVO_Dot	1
		#define FSVO_Line	2
		#define FSVO_Circle	3
		#define FSVO_Box	4
	double point[2][2];
	float color[2][4];
	int batch;
	BOOL visible;
} FSViewerItem;

@interface FSViewerObject : NSObject { FSViewerItem item; }
- (FSViewerItem*) itemPtr;
- (void) setItem: (FSViewerItem) newItem;
@end

@interface FSViewer : NSOpenGLView {

	FSViewerData* view;
	FSViewerData fakeview;
	
	float* texture;
	int textureSize;
	int textureBounds[2];
	GLuint textureHandle;

	BOOL awake;
	BOOL displayLocked;
	BOOL textureReady;
	BOOL glConfigured;
	float finalX, finalY;
	volatile BOOL nodeChanged;
	volatile BOOL readyToRender;
	volatile BOOL rendering;
	volatile BOOL readyToDisplay;
	volatile float* volatile subtexture[4];
	volatile int subtextureSize[4];
	int subtextureOffset[4];
	BOOL changed[4];
	GLuint subtextureHandle[4];
	BOOL subtextureReady[4];
	NSLock* renderLock;
	NSLock* glLock;
	NSLock* finishedLock;
	NSLock* textureReadyLock;
	NSLock* modificationLock[4];
	NSLock* subtextureLock[4];
	NSTrackingRectTag coordinateTracker;
	volatile int activeSubtasks;
	int threadCount;
	
	NSMutableArray* displayList;
	int currentBatch;
	
	IBOutlet NSButton* boxButton;
	IBOutlet NSProgressIndicator* progress;
	IBOutlet FSColorWidget* colorPicker;
	
	BOOL configured;
}

- (id) initWithCoder: (NSCoder*) coder;
- (IBAction) render: (id) sender;
- (void) setViewerData: (FSViewerData*) newData;
- (BOOL) isAwake;
- (void*) theKernel;
- (NSPoint) locationOfPoint: (double*) point;
- (NSImage*) snapshot;

- (void) mouseEntered: (NSEvent*) theEvent;
- (void) mouseExited: (NSEvent*) theEvent;
- (void) mouseMoved: (NSEvent*) theEvent;
- (BOOL) acceptsFirstResponder;
@end
