



/********** THIS IS THE BAD ONE ***********/



/* FSViewport */


#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <math.h>
#import "FSConfigurationSheet.h"
#import "FSProgramList.h"
#import "FSSession.h"
#import "FSToolStruct.h"
#import "FSViewer.h"

@interface FSKernelData : NSObject
{
	double* in;
	double* out;
	int size;
	int colorScheme;
	float* texture;
	NSLock* lock;
}
- (void) setLock: (NSLock*) newLock;
@end

@interface FSViewport : NSOpenGLView
{
	void (*kernel)(int, double*, int, double*, int, double);
	BOOL configured;
	
	IBOutlet id toolkit;
	IBOutlet FSSession* theSession;
	NSTrackingRectTag coordinateTracker;
	
	IBOutlet FSViewer* theViewer;
	FSViewerData viewerData;
	IBOutlet NSTextField* radBox;
	IBOutlet NSTextField* iterBox;
	IBOutlet NSTextField* aParam;
	IBOutlet NSTextField* bParam;
	IBOutlet NSTextField* cParam;
	IBOutlet NSTextField* maxColors;
	IBOutlet NSButton* useBlackCheck;
	IBOutlet NSTextField* intSteps;
	
	double pa, pb, pc;
	int nsteps;
	
	IBOutlet id owner;
	
	double centerX, centerY, scale;
	double paramX, paramY;
	int maxIterations;
	double maxRadius;
	BOOL dynamical;

	BOOL invertDynamics;
		
		int fixpoints;
		double fixpoint[2][16];
		

	GLuint textureHandle;
	BOOL displayLocked;
	BOOL textureReady;
	NSLock* renderLock;
	NSLock* modificationLock;
	NSLock* textureReadyLock;
	BOOL nodeChanged;
	
	int colorScheme;
}

- (IBAction) reloadView: (id) sender;
- (IBAction) goHome: (id) sender;
- (IBAction) nextColorScheme: (id) sender;
- (IBAction) resetColors: (id) sender;
- (IBAction) invertDynamics: (id) sender;

- (void) relockModificationLock; 
- (void) renderTexture: (id) sender;

- (void) mouseEntered: (NSEvent*) theEvent;
- (void) mouseExited: (NSEvent*) theEvent;
- (void) mouseMoved: (NSEvent*) theEvent;

- (double) currentScale;
- (double) currentCenterX;
- (double) currentCenterY;
- (double) pX;
- (double) pY;

- (void) linkToKernel: (void*) newKernel;
- (IBAction) startKernel: (id) sender;
- (void*) theKernel;
- (void) viewBoxFrom: (NSPoint) start to: (NSPoint) end;
- (void) recenterOn: (NSPoint) newCenter;
- (void) scaleOutFrom: (NSPoint) newCenter by: (double) factor;

- (void) convertEvent: (NSEvent*) theEvent toPoint: (FSPoint*) pt;
- (void) convertLocation: (NSPoint) location toPoint: (FSPoint*) pt;
- (void) convertPoint: (FSPoint) point toLocation:  (NSPoint*) location;

@end
