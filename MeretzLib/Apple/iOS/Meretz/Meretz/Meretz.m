/*
Meretz.m
Thursday May 26, 2016 11:11am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import "Meretz+Internal.h"

/* ---------- constants */

const MeretzTaskId MERETZ_TASK_ID_INVALID = -1;


/* ---------- internal interface */

@interface Meretz()

	- (MeretzTaskId) addTask: (MeretzTask *) newTask;
	- (MeretzTask *) getTask: (MeretzTaskId) taskId;

@end

/* ---------- implementation */

@implementation Meretz

	/* ---------- globals */

	NSString *gVendorAccessToken= nil;
	NSString *gUserAccessToken= nil;

	NSMutableDictionary *gTaskDictionary= nil;

	/* ---------- public methods */

	// call this to initialize Meretz for your organization's application
	- (instancetype)initWithVendorToken: (NSString *) vendorSecretToken
	{
		gVendorAccessToken= vendorSecretToken;
		gUserAccessToken= nil;
		
		gTaskDictionary= nil;
		
		self= [super init];
		
		if (nil != self)
		{
			gTaskDictionary= [NSMutableDictionary dictionary];
			NSLog(@"Meretz v.%X initialized with vendor access token '%@'", MERETZ_VERSION, gVendorAccessToken);
		}
		
		return self;
	}

	// accessors for vendor/user- specific access token
	- (NSString *) getUserAccessToken
	{
		return gUserAccessToken;
	}

	- (void) setUserAccessToken: (NSString *) accessToken
	{
		if (0 == [accessToken length])
		{
			accessToken= @"";
		}
		
		NSLog(@"Meretz user access token is now: %@", accessToken);
		gUserAccessToken= accessToken;
		
		return;
	}

	// query the status of a Meretz asynchronous task
	- (MeretzTaskStatus) getTaskStatus: (MeretzTaskId) taskId
	{
		MeretzTask *task= [self getTask: taskId];
		MeretzTaskStatus status= (nil != task) ? [task getTaskStatus] : MeretzTaskStatusInvalid;
		
		return status;
	}

	// User connection (link a game user to a Meretz user)
	- (MeretzTaskId) vendorUserConnect: (NSString *) userConnectionCode
	{
		NSAssert(0 < [userConnectionCode length], @"VendorUserConnect requires a valid user connection code!");
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		MeretzTask *task= [[MeretzTask alloc] initVendorUserConnect: userConnectionCode];
		
		if (nil != task)
		{
			taskId= [self addTask: task];
		}
		
		return taskId;
	}

	- (MeretzVendorUserConnectResult *) getVendorUserConnectResult: (MeretzTaskId) vendorUserConnectTask
	{
		return nil;
	}

	// User disconnection (for the current user as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserDisconnect
	{
		return MERETZ_TASK_ID_INVALID;
	}

	- (MeretzVendorUserDisconnectResult *) getVendorUserDisconnectResult: (MeretzTaskId) vendorUserDisconnectTask
	{
		return nil;
	}

	// Item consumption over a date range
	- (MeretzTaskId) vendorConsume: (NSDate *) startDate optional: (NSDate *) endDate
	{
		return MERETZ_TASK_ID_INVALID;
	}

	- (MeretzVendorConsumeResult *) getVendorConsumeResult: (MeretzTaskId) vendorConsumeTask
	{
		return nil;
	}

	// Spending points on behalf of the current user (as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUsePoints: (NSInteger) pointQuantity
	{
		return MERETZ_TASK_ID_INVALID;
	}

	- (MeretzVendorUsePointsResult *) getVendorUsePointsResult: (MeretzTaskId) vendorUsePointsTask
	{
		return nil;
	}

	// Retrieving Meretz user information for the current user (as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserProfile
	{
		return MERETZ_TASK_ID_INVALID;
	}

	- (MeretzVendorUserProfileResult *) getVendorUserProfileResult: (MeretzTaskId) vendorUserProfileTask
	{
		return nil;
	}


	/* ---------- private methods */

	- (MeretzTaskId) addTask: (MeretzTask *) newTask
	{
		NSAssert(nil != gTaskDictionary, @"task list uninitialized!");
		NSAssert(nil != newTask, @"cannot add nil task!");
		NSAssert(MeretzTaskStatusInvalid == [newTask getTaskStatus], @"cannot add an already-started task!");
		NSNumber *taskKey= [NSNumber numberWithUnsignedInt:arc4random()];
		NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		MeretzTaskId result= MERETZ_TASK_ID_INVALID;
		
		while (nil != [gTaskDictionary valueForKey:[taskKey stringValue]])
		{
			taskKey= [NSNumber numberWithUnsignedInt:arc4random()];
			NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		}
		
		if ([newTask beginWork])
		{
			[newTask setTaskStatus: MeretzTaskStatusInProgress];
			gTaskDictionary[[taskKey stringValue]]= newTask;
			result= [taskKey unsignedIntegerValue];
		}
		else
		{
			NSLog(@"beginWork() failed for %@", newTask);
		}
		
		return result;
	}

	- (MeretzTask *) getTask: (MeretzTaskId) taskId
	{
		NSAssert(MERETZ_TASK_ID_INVALID != taskId, @"invalid MeretzTask!");
		NSAssert(nil != gTaskDictionary, @"task list uninitialized!");
		NSNumber *taskKey= [NSNumber numberWithUnsignedInt:taskId];
		NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		MeretzTask *result= gTaskDictionary[[taskKey stringValue]];
		NSAssert(nil != result, @"invalid MeretzTaskId!");
		
		return result;
	}

@end
