/*
 * tinygrowl - http://github.com/EmielM/tinygrowl
 * Copyright (c) 2010, Satoshi Nakagawa, Emiel Mols
 *
 * You can redistribute it and/or modify it under the new BSD license. 
 */

#import <Cocoa/Cocoa.h>

@interface TinyGrowlClient : NSObject
{
	id delegate;
	NSString* appName;
	NSArray* allNotifications;
	NSArray* defaultNotifications;
	NSImage* appIcon;

	NSString* clickedNotificationName;
	NSString* timedOutNotificationName;
	NSTimeInterval lastCallbackTime;

	bool lastRunning;
	ProcessSerialNumber lastRunningPSN;
	NSTimeInterval lastRunningCheck;
}

- (void)setDelegate:(id)value;
- (void)setAppName:(NSString *)value;
- (void)setAllNotifications:(NSArray *)value;
- (void)setDefaultNotifications:(NSArray *)value;
- (void)setAppIcon:(NSImage *)value;

- (id)delegate;
- (NSString *)appName;
- (NSArray *)allNotifications;
- (NSArray *)defaultNotifications;
- (NSImage *)appIcon;

- (bool)running;

- (void)registerApplication;

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc;

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
		  clickContext:(id)context;

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
		  clickContext:(id)context
				sticky:(BOOL)sticky;

- (void)notifyWithType:(NSString*)type
				 title:(NSString*)title
		   description:(NSString*)desc
		  clickContext:(id)context
				sticky:(BOOL)sticky
			  priority:(int)priority
				  icon:(NSImage*)icon;

@end


@interface NSObject (TinyGrowlClientDelegate)
- (void)tinyGrowlClient:(TinyGrowlClient*)sender didClick:(id)context;
- (void)tinyGrowlClient:(TinyGrowlClient*)sender didTimeOut:(id)context;
- (void)tinyGrowlClient:(TinyGrowlClient*)sender didChangeRunning:(bool)running;
@end
