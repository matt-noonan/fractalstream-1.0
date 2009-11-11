/*
 *  FSTool.h
 *  FractalStream
 *
 *  Created by Matt Noonan on 4/4/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

@protocol FSTool
+ (BOOL) preload: (NSBundle*) theBundle;
+ (void) destroy;
- (void) unfreeze;
- (void) activate;
- (void) deactivate;
- (void) configure;
- (void) setOwnerTo: (id) theOwner;
- (BOOL) is: (int) type;
- (NSString*) name;
- (NSString*) menuName;
- (NSString*) keyEquivalent;
- (void) mouseEntered: (NSEvent*) theEvent;
- (void) mouseExited: (NSEvent*) theEvent;
- (void) mouseMoved: (NSEvent*) theEvent;
- (void) mouseDragged: (NSEvent*) theEvent;
- (void) mouseUp: (NSEvent*) theEvent;
- (void) mouseDown: (NSEvent*) theEvent;
- (void) rightMouseDown: (NSEvent*) theEvent;
- (void) scrollWheel: (NSEvent*) theEvent;
@end

@protocol FSBrowserProtocol
- (IBAction) goForward: (id) sender;
- (IBAction) goBackward: (id) sender;
- (IBAction) refresh: (id) sender;
- (IBAction) goHome: (id) sender;
- (void) changeTo: (NSString*) newName X: (double) x Y: (double) y p1: (double) p1 p2: (double) p2 pixelSize: (double) pixelSize parametric: (BOOL) isPar;
- (void) sendDefaultsToViewer;
- (void) putCurrentDataIn: (FSViewerData*) p;
- (void) refreshAll;
- (void) setVariableNamesTo: (NSArray*) names;
- (void) setVariableValuesToReal: (NSArray*) rp imag: (NSArray*) ip;
- (void) resetDefaults;
- (NSArray*) namedProbes;
@end
