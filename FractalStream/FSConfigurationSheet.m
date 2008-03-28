#import "FSConfigurationSheet.h"

@implementation FSConfigurationSheet

- (void) awakeFromNib { configured = NO; }

- (IBAction) configureSession:(id)sender
{
	if(configured == NO) {
		[NSApp
			beginSheet:configureSheet
			modalForWindow:parentWindow
			modalDelegate:self
			didEndSelector:NULL
			contextInfo:nil
		];
		parentController = sender;
	}
}

- (IBAction)endConfiguration:(id)sender
{
	configured = YES;
    [configureSheet orderOut:nil];
	[kernelLoader loadKernel:nil];
    [NSApp endSheet:configureSheet];
	if(parentController != nil) [parentController completeConfiguration];

}

@end
