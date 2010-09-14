/* An FSScene encapsulates the data needed for a particular view of a dynamical system: the current plane and
 parameter values, zoom level, center of the view, a kernel encoding the dynamical system, etc */

#import <Cocoa/Cocoa.h>
#import "FSKernel.h"

@interface FSScene : NSObject {
	double center[2];
	double pixelSize[2];
	BOOL conformal;
	FSKernel* kernel;
	NSArray* parameters;
	NSArray* annotations;
	int activePlane;
	int nParameters;
}

- (double*) center;
- (double*) pixelSize;
- (BOOL) isConformal;
- (FSKernel*) kernel;
- (NSArray*) parameters;
- (NSArray*) annotations;
- (int) plane;
- (void) setKernel: (FSKernel*) k centerX: (double) x Y: (double) y scale: (double) dz;
- (BOOL) canPushParameter;
- (id) initWithScene: (FSScene*) scene pushingParameter: (FSComplexNumber*) Z;

@end
