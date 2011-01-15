/*
 * tinygrowl - http://github.com/EmielM/tinygrowl
 * Copyright (c) 2010, Satoshi Nakagawa, Emiel Mols
 *
 * You can redistribute it and/or modify it under the new BSD license. 
 *
 * A lot of credit goes to Satoshi Nakagawa, the original author
 * of this library: https://github.com/psychs/tinygrowl
 */

#import "TinyGrowlClient.h"

#define GROWL_REGISTER			@"GrowlApplicationRegistrationNotification"
#define GROWL_NOTIFICATION		@"GrowlNotification"
#define GROWL_IS_READY			@"Lend Me Some Sugar; I Am Your Neighbor!"
#define GROWL_CLICKED			@"GrowlClicked!"
#define GROWL_TIMED_OUT			@"GrowlTimedOut!"
#define GROWL_CONTEXT_KEY		@"ClickedContext"

#define GROWL_HELPER_BUNDLE_ID	@"com.Growl.GrowlHelperApp"
	// used to inspect processes to determine whether growl is running

#define CALLBACK_TIME_EPSILON	0.05
#define RUNNING_CACHE_TIME		10.0


@implementation TinyGrowlClient

/* property accessors {{{
@synthesize delegate;
@synthesize appName;
@synthesize allNotifications;
@synthesize defaultNotifications;
@synthesize appIcon;*/

- (void)setDelegate:(id)value { delegate = value; }
- (void)setAppName:(NSString *)value { [value retain]; [appName release]; appName = value; }
- (void)setAllNotifications:(NSArray *)value { [value retain]; [allNotifications release]; allNotifications = value; }
- (void)setDefaultNotifications:(NSArray *)value { [value retain]; [defaultNotifications release]; defaultNotifications = value; }
- (void)setAppIcon:(NSImage *)value { [value retain]; [appIcon release]; appIcon = value; }

- (id)delegate { return delegate; }
- (NSString *)appName { return appName; }
- (NSArray *)allNotifications { return allNotifications; }
- (NSArray *)defaultNotifications { return defaultNotifications; }
- (NSImage *)appIcon { return appIcon; }
// }}}

- (id) init
{
	if (self = [super init]) {
		lastRunningPSN.lowLongOfPSN = kNoProcess;
		lastRunningPSN.highLongOfPSN = kNoProcess;
		lastRunning = true; // assume growl is running
	}
	return self;
}

bool isHelperProcess(ProcessSerialNumber* psnRef) {
	struct ProcessInfoRec info = { .processInfoLength = (UInt32)sizeof(struct ProcessInfoRec) };
	OSStatus err = GetProcessInformation(psnRef, &info);
	if (err != noErr)
		return false;

	NSDictionary *dict = (NSDictionary *)ProcessInformationCopyDictionary(psnRef, kProcessDictionaryIncludeAllInformationMask);
	if (!dict)
		return false;

	CFMakeCollectable(dict);
	bool isHelper = ([[dict objectForKey:(NSString *)kCFBundleIdentifierKey] isEqualToString:GROWL_HELPER_BUNDLE_ID]);

	[dict release];

	return isHelper;
}

- (bool) running
{
	if (isHelperProcess(&lastRunningPSN))
		return true;

	bool running = false;
	struct ProcessSerialNumber psn = {kNoProcess, kNoProcess};
	OSStatus err;
	while (!running && (err = GetNextProcess(&psn)) == noErr)
		running = isHelperProcess(&psn);

	if (running) lastRunningPSN = psn;

	return running;
}

- (void)checkRunning:(bool)force
{
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	if (!force && (now - lastRunningCheck < RUNNING_CACHE_TIME)) return;
	lastRunningCheck = now;

	bool running = [self running];

	if (lastRunning != running) {
		lastRunning = running;
		if ([delegate respondsToSelector:@selector(tinyGrowlClient:didChangeRunning:)])
			[delegate tinyGrowlClient:self didChangeRunning:running];
	}
}

- (void)dealloc
{
	NSDistributedNotificationCenter* dnc = [NSDistributedNotificationCenter defaultCenter];
	[dnc removeObserver:self name:GROWL_IS_READY object:nil];
	[dnc removeObserver:self name:clickedNotificationName object:nil];
	[dnc removeObserver:self name:timedOutNotificationName object:nil];
	[appName release];
	[allNotifications release];
	[defaultNotifications release];
	[appIcon release];
	[clickedNotificationName release];
	[timedOutNotificationName release];
	[super dealloc];
}

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
{
	[self notifyWithType:type title:title description:desc clickContext:nil sticky:NO priority:0 icon:nil];
}

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
		  clickContext:(id)context
{
	[self notifyWithType:type title:title description:desc clickContext:context sticky:NO priority:0 icon:nil];
}

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
		  clickContext:(id)context
				sticky:(BOOL)sticky
{
	[self notifyWithType:type title:title description:desc clickContext:context sticky:sticky priority:0 icon:nil];
}

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
		  clickContext:(id)context
				sticky:(BOOL)sticky
			  priority:(int)priority
				  icon:(NSImage*)icon
{
	NSMutableDictionary* dic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								appName, @"ApplicationName",
								[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]], @"ApplicationPID",
								type, @"NotificationName",
								title, @"NotificationTitle",
								desc, @"NotificationDescription",
								[NSNumber numberWithInt:priority], @"NotificationPriority",
								nil];

	if (icon) {
		[dic setObject:[icon TIFFRepresentation] forKey:@"NotificationIcon"];
	}

	if (sticky) {
		[dic setObject:[NSNumber numberWithInt:1] forKey:@"NotificationSticky"];
	}

	if (context) {
		[dic setObject:context forKey:@"NotificationClickContext"];
	}

	NSDistributedNotificationCenter* dnc = [NSDistributedNotificationCenter defaultCenter];
	[dnc postNotificationName:GROWL_NOTIFICATION object:nil userInfo:dic deliverImmediately:YES];

	[self checkRunning:false];
}

- (void)registerApplication
{
	if (!appName)
		[self setAppName: [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]];

	if (!defaultNotifications)
		[self setDefaultNotifications: allNotifications];

	int pid = [[NSProcessInfo processInfo] processIdentifier];

	[clickedNotificationName release];
	[timedOutNotificationName release];

	clickedNotificationName = [[NSString stringWithFormat:@"%@-%d-%@", appName, pid, GROWL_CLICKED] retain];
	timedOutNotificationName = [[NSString stringWithFormat:@"%@-%d-%@", appName, pid, GROWL_TIMED_OUT] retain];

	NSDistributedNotificationCenter* dnc = [NSDistributedNotificationCenter defaultCenter];
	[dnc addObserver:self selector:@selector(onReady:) name:GROWL_IS_READY object:nil];
	[dnc addObserver:self selector:@selector(onClicked:) name:clickedNotificationName object:nil];
	[dnc addObserver:self selector:@selector(onTimeout:) name:timedOutNotificationName object:nil];

	NSImage* icon = appIcon ?: [NSApp applicationIconImage];

	NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
						 appName, @"ApplicationName",
						 allNotifications, @"AllNotifications",
						 defaultNotifications, @"DefaultNotifications",
						 [icon TIFFRepresentation], @"ApplicationIcon",
						 nil];

	[dnc postNotificationName:GROWL_REGISTER object:nil userInfo:dic deliverImmediately:YES];

	[self checkRunning:true];
}

- (void)onReady:(NSNotification*)note
{
	[self registerApplication];
}

- (void)onClicked:(NSNotification*)note
{
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	if (now - lastCallbackTime < CALLBACK_TIME_EPSILON) return;
	lastCallbackTime = now;

	id context = [[note userInfo] objectForKey:GROWL_CONTEXT_KEY];

	if ([delegate respondsToSelector:@selector(tinyGrowlClient:didClick:)]) {
		[delegate tinyGrowlClient:self didClick:context];
	}
}

- (void)onTimeout:(NSNotification*)note
{
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	if (now - lastCallbackTime < CALLBACK_TIME_EPSILON) return;
	lastCallbackTime = now;

	id context = [[note userInfo] objectForKey:GROWL_CONTEXT_KEY];

	if ([delegate respondsToSelector:@selector(tinyGrowlClient:didTimeOut:)]) {
		[delegate tinyGrowlClient:self didTimeOut:context];
	}
}

@end
