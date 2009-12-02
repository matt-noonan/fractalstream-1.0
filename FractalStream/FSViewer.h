/* FSViewer class, controls the display of dynamical systems.   */

#import <Cocoa/Cocoa.h>
/*#import <OpenGL/gl.h>*/
#import <math.h>
#import <sys/time.h>
#import "FSViewerData.h"
#import "FSColorWidget.h"
#import "FSRenderOperation.h"
#import "FSColorizer.h"
#import "FSThreading.h"
#import "FSFullscreenWindow.h"

#ifndef GL_TEXTURE_RECTANGLE_EXT
#define GL_TEXTURE_RECTANGLE_EXT            0x84F5
#endif

#define nTasks				1
#define TasksStartedMask	0x01
#define TasksEndedMask		0x03



@interface FSViewerObject : NSObject { FSViewerItem item; @public int plane; }
- (FSViewerItem*) itemPtr;
- (void) setItem: (FSViewerItem) newItem;
@end

@interface FSViewer : NSView {

	FSViewerData* view;
	FSViewerData fakeview;
	
	BOOL awake;
	BOOL displayLocked;
	float finalX, finalY;
	volatile BOOL nodeChanged;
	volatile BOOL readyToRender;
	volatile BOOL rendering;
	BOOL readyToDisplay;
	NSTrackingRectTag coordinateTracker;
	SEL renderingFinished;
	id renderingFinishedObject;
	int renderBatch;
	
	NSMutableArray* displayList;
	int currentBatch;
	int undrawnBlocks;
	
	double setting[512];
	int defaults;
	
	IBOutlet NSButton* boxButton;
	IBOutlet NSButton* linesButton;
	IBOutlet NSProgressIndicator* progress;
	IBOutlet FSColorWidget* colorPicker;
	IBOutlet NSButton* denormalButton;
	IBOutlet NSTextField* timerField;
	IBOutlet NSTextView* viewDescription;
	IBOutlet NSWindow* controllingWindow;
	IBOutlet id document;
	IBOutlet NSButton* insetButton;
	
	FSColorizer* viewerColorizer;
	BOOL useFakeZoom;
	FSOperationQueue* workQueue;
	NSString* drawing;
	
	NSImage* background;
	NSBitmapImageRep** tile;
	NSImage* inset;
	BOOL showInset;
	double insetMarker[2];
	
	unsigned char** tileData;
	int tilesPerRow;
	int totalTiles;
	FSViewer_Autocolor_Cache acCache[64];
	int renderQueueEntries;
	FSFullscreenWindow* fswindow;
	
	BOOL configured;
	IBOutlet NSImageView* tView;
	NSConditionLock* queueLock;
	
	BOOL proposingView;
	double proposedZoomMultiple;
	double proposedCenter[2], proposedTranslation[2];
	double initialTouchLocation[2];
	BOOL followingTouches;
}

- (IBAction) tTest: (id) sender;
- (IBAction) toggleInset: (id) sender; 

- (id) initWithCoder: (NSCoder*) coder;
- (IBAction) render: (id) sender;
- (IBAction) startFullScreen: (id) sender;
- (IBAction) endFullScreen: (id) sender;
- (void) setViewerData: (FSViewerData*) newData;
- (void) getViewerDataTo: (FSViewerData*) savedData;
- (BOOL) isAwake;
- (void*) theKernel;
- (NSPoint) locationOfPoint: (double*) point;
- (NSImage*) snapshot;
- (void) setRenderCompletedMessage: (SEL) message forObject: (id) obj;
- (void) zoomFrom: (double*) start to: (double*) end scalingFrom: (double) startSize to: (double) endSize;
- (void) drawTexture;
- (void) setDefaultsTo: (double*) def count: (int) n;
- (void) runAt: (double*) p into: (double*) result probe: (int) pr;
- (void) runAt: (double*) p into: (double*) result probe: (int) pr steps: (int) ns;
- (void) runAt: (double*) p withParameter: (double*) q into: (double*) result probe: (int) pr steps: (int) ns;
- (void) renderOperationFinished: (id) op;
- (void) lockAllAutocolor;

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
- (void) setColorPicker: (FSColorWidget*) newColorPicker;

- (void) mouseEntered: (NSEvent*) theEvent;
- (void) mouseExited: (NSEvent*) theEvent;
- (void) mouseMoved: (NSEvent*) theEvent;
- (BOOL) acceptsFirstResponder;

- (void) registerForNotifications: (id) owningDocument;
- (id) document;

@end
