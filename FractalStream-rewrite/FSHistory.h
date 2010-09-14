/* Maintains a history of views. */

#import <Cocoa/Cocoa.h>
#import "FSDynamics.h"

@interface FSHistory : NSObject {
	NSMutableArray* history;
	IBOutlet FSDynamics* dynamics;
}

- (id) init;

@end
