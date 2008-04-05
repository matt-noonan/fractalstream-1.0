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