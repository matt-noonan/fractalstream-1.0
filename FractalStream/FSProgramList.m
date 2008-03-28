/*

	FSProgramList is the data source for the program outline view.  It is freeze dried in
	the Kernels subdirectory.  It contains dictionaries which carry the titles and filenames
	of the compiled kernels.
	
*/

#import "FSProgramList.h"


@implementation FSProgramList

- (id) init
{
	self = [super init];
	programList = [[NSUnarchiver unarchiveObjectWithFile:
		[[NSBundle mainBundle] pathForResource: @"programList" ofType: nil]] retain];
	if(programList == nil) NSLog(@"could not open programList at %@\n",
		[[NSBundle mainBundle] pathForResource: @"programList" ofType: nil]);
	kernelPointer = NULL;
	NSLog(@"programList at: \"%@\"\n", [[NSBundle mainBundle] pathForResource: @"programList" ofType: nil]);
	return self;
}

- (BOOL) outlineView: (NSOutlineView*) outline isItemExpandable: (id) item
{
	return NO;
}

- (int) outlineView: (NSOutlineView*) outline numberOfChildrenOfItem: (id) item
{
	if(item == nil) { return [programList count]; } 
	return 0;
}

- (id) outlineView: (NSOutlineView*) outline child: (int) index ofItem: (id) item
{
	if(item == nil) {
		return [programList objectAtIndex: index];
	}
	return nil;
}

- (id) outlineView: (NSOutlineView*) outline
	objectValueForTableColumn: (NSTableColumn*) tableColumn byItem: (id) item
{
	return [item valueForKey: @"title"];
}

- (IBAction) loadKernel: (id) sender {
	NSString* path;
	
	NSLog(@"loadKernel: %@\n", [
		[listView itemAtRow: [listView selectedRow]]
		valueForKey: @"kernel"
	]);
	
	/*** hack ***/
	path = [NSString stringWithFormat: @"%@/Kernels/%@",
		[[NSBundle mainBundle] resourcePath],
		[[listView itemAtRow: [listView selectedRow]] valueForKey: @"kernel"]
	];
		
	NSLog(@"trying dlopen on \"%@\"\n", path);
	loadedModule = dlopen([path cString], RTLD_NOW);
	if(loadedModule == NULL) { 
		NSLog(@"%s\n", dlerror());
		return;
	}
	kernelPointer = dlsym(loadedModule, "kernel");
	if(kernelPointer == NULL) {
		NSLog(@"could not load kernel\n");
		return;
	}


}

- (BOOL) kernelLoaded {
	return (kernelPointer == NULL)? NO : YES;
}

- (void*) kernel {
	return kernelPointer;
}

- (int) unloadKernel {
	dlclose(loadedModule);
	kernelPointer = NULL;
}

@end
