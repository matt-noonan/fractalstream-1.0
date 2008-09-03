/* FSViewer class, controls the display of dynamical systems.  This version is designed for output in OpenGL views. */

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <math.h>
#import <sys/time.h>
#import "FSViewerData.h"
#import "FSColorWidget.h"

#ifndef GL_TEXTURE_RECTANGLE_EXT
#define GL_TEXTURE_RECTANGLE_EXT            0x84F5
#endif

#define nTasks				2
#define TasksStartedMask	0x03
#define TasksEndedMask		0x0f
#define FSViewer_Infinity   1.23456789e10000

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

typedef struct {
	float* color;
	double* x;
	double* y;
	BOOL active;
	BOOL locked;
	int allocated_entries;
	int used_entries;
} FSViewer_Autocolor_Cache;

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
	NSLock* syncLock;
	NSLock* acLock;
	NSTrackingRectTag coordinateTracker;
	volatile int activeSubtasks;
	int threadCount;
	SEL renderingFinished;
	id renderingFinishedObject;
	
	NSMutableArray* displayList;
	int currentBatch;

	volatile double setting[512];
	int defaults;
	
	IBOutlet NSButton* boxButton;
	IBOutlet NSButton* linesButton;
	IBOutlet NSProgressIndicator* progress;
	IBOutlet FSColorWidget* colorPicker;
	IBOutlet NSButton* denormalButton;
	IBOutlet NSTextField* timerField;
	volatile BOOL autocolorAdded;
	BOOL useFakeZoom;
	
	FSViewer_Autocolor_Cache acCache[64];
	
	BOOL configured;
}

- (id) initWithCoder: (NSCoder*) coder;
- (IBAction) render: (id) sender;
- (void) setViewerData: (FSViewerData*) newData;
- getViewerDataTo: (FSViewerData*) savedData;
- (BOOL) isAwake;
- (void*) theKernel;
- (NSPoint) locationOfPoint: (double*) point;
- (NSImage*) snapshot;
- setRenderCompletedMessage: (SEL) message forObject: (id) obj;
- zoomFrom: (double*) start to: (double*) end scalingFrom: (double) startSize to: (double) endSize;
- (void) drawTexture;
- setDefaultsTo: (double*) def count: (int) n;
- (void) probe: (int) probeNumber atPoint: (double*) p into: (double*) result;

- (void) drawBoxFrom: (NSPoint) start to: (NSPoint) end withColor: (float*) rgb;
- (void) draw: (int) nTraces tracesFrom: (NSPoint*) traceList steps: (int) nSteps;

- (void) drawItem: (FSViewerItem) newItem;
- (void) drawObject: (FSViewerObject*) newObject;
- (void) makeBatch: (int) batch visible: (BOOL) vis;
- (void) changeBatch: (int) batch to: (int) newBatch;
- (void) deleteObjectsInBatch: (int) batch;
- (int) getBatchNumber;

- (void) convertEvent: (NSEvent*) theEvent toPoint: (double*) point;
- (void) convertLocation: (NSPoint) theLocation toPoint: (double*) point;
- (NSPoint) locationOfPoint: (double*) point;
- (void) convertPoint: (double*) point toGL: (double*) gl;

- (FSColorWidget*) colorPicker;
- setColorPicker: (FSColorWidget*) newColorPicker;

- (void) mouseEntered: (NSEvent*) theEvent;
- (void) mouseExited: (NSEvent*) theEvent;
- (void) mouseMoved: (NSEvent*) theEvent;
- (BOOL) acceptsFirstResponder;
@end
