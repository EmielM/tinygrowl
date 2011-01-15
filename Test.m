#import "TinyGrowlClient.h"

#import <Foundation/Foundation.h>

#include <unistd.h>

@interface MyDelegate : NSObject {
	TinyGrowlClient *growl;
	NSTimer *timer;
}
@end

@implementation MyDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	NSLog(@"registering app");
	[growl release];
	growl = [TinyGrowlClient new];
	[growl setDelegate: self];
	[growl setAppName:@"TinyGrowlClientTest"];
	[growl setAllNotifications: [NSArray arrayWithObjects: @"notifications", nil]];
	[growl registerApplication];

	timer = [NSTimer scheduledTimerWithTimeInterval:5.0
											 target:self
										   selector:@selector(tryPost:)
										   userInfo:nil
											repeats:YES];
}

- (void) tryPost:(id)obj
{
	NSLog(@"posting notification..");
	[growl notifyWithType:@"notifications" title:@"title" description:@"description" clickContext:@"someContext"];
}

- (void) tinyGrowlClient:(TinyGrowlClient*)growl didClick:(id)context {
	NSLog(@"didClick");
}

- (void) tinyGrowlClient:(TinyGrowlClient*)growl didTimeOut:(id)context {
	NSLog(@"didTimeOut");
}

- (void) tinyGrowlClient:(TinyGrowlClient*)growl didChangeRunning:(bool)running {
	if (running) NSLog(@"growl started again");
	else NSLog(@"growl quit");
}

@end;

int main() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];

	TinyGrowlClient *growl = [TinyGrowlClient new];

	MyDelegate *d = [MyDelegate new];
	[NSApp setDelegate:[d autorelease]];
	[NSApp run];

	[pool drain];
}
