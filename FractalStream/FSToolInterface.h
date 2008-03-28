
@protocol FSToolProtocol

+ (BOOL) preload: (NSBundle*) theBundle;
+ (void) destroy;
- (void) activate;
- (void) deactivate;
- (void) setOwnerTo: (id) owner;
 
@end