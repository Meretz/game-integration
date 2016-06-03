/*
Meretz.m
Thursday May 26, 2016 11:11am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import "Meretz+Internal.h"

/* ---------- constants */

const MeretzTaskId MERETZ_TASK_ID_INVALID = -1;

// server configuration defaults

const unsigned short kDefaultHTTPPort= 80;
const unsigned short kDefaultHTTPSPort= 443;

#define PROTOCOL_HTTP									@"http"
#define PROTOCOL_HTTPS									@"https"

#define DEFAULT_MERETZ_SERVER_PROTOCOL					PROTOCOL_HTTPS
#define DEFAULT_MERETZ_SERVER_HOST_NAME					@"www.meretz.com"
#define DEFAULT_MERETZ_SERVER_PORT						kDefaultHTTPSPort
#define DEFAULT_MERETZ_SERVER_API_PATH					@"/api"

/* ---------- globals */

Meretz *gMeretzSingleton= nil;

/* ---------- internal interface */

@interface Meretz()

	- (BOOL) initialize;

	// Meretz task management
	- (MeretzTaskId) addTask: (MeretzTask *) newTask;
	- (MeretzTask *) getTask: (MeretzTaskId) taskId;

@end

/* ---------- implementation */

@implementation MeretzResult
@end

@implementation MeretzVendorUserConnectResult
@end

@implementation MeretzVendorConsumeResult
@end

@implementation MeretzVendorUserProfileResult
@end

@implementation Meretz

	/* ---------- globals */



	NSString *gMeretzServerProtocol= nil;
	NSString *gMeretzServerHostName= nil;
	NSNumber *gMeretzServerPort= nil;
	NSString *gMeretzServerApiPath= nil;

	// the unique vendor access token give to you by Meretz
	NSString *gVendorAccessToken= nil;
	// a unique user access token retrieved initially via a vendorUserConnect call,
	// then stored by your app and used for future interactions with the Meretz API
	NSString *gUserAccessToken= nil;

	// the master Meretz task list
	NSMutableDictionary *gTaskDictionary= nil;

	/* ---------- public methods */

	// call this to initialize Meretz for your organization's application
	// with your unique vendor access token (as given to you by Meretz)
	// and an optional, previously stored user access token if you have
	// previously connected a game user
	- (instancetype)initWithTokens: (NSString *) vendorSecretToken emptyOrSavedValue: (NSString *) userAccessToken;
	{
		NSAssert(nil == gMeretzSingleton, @"Meretz API has already been initialized!");
		
		if (0 < [vendorSecretToken length])
		{
			gVendorAccessToken= vendorSecretToken;
			gUserAccessToken= @"";
			
			gTaskDictionary= nil;
			
			self= [super init];
			
			if (nil != self)
			{
				if ([self initialize])
				{
					NSLog(@"Meretz v.%X initialized with vendor access token '%@'", MERETZ_VERSION, gVendorAccessToken);
					if (0 < [userAccessToken length])
					{
						[self setUserAccessToken: userAccessToken];
					}
					
					gMeretzSingleton= self;
					
					NSLog(@"Meretz REST API server: %@", [self getMeretzServerString]);
				}
				else
				{
					return nil;
				}
			}
		}
		else
		{
			NSAssert(FALSE, @"Meretz API use requires a valid vendor access token!");
			return nil;
		}
		
		return self;
	}

	// use these to configure destination server settings as needed (intended for development use only)
	// defaults are: https://www,meretz.com/api , where:
	// protocol= "https"
	// hostName= "www.meretz.com"
	// port= 443 (default for https)
	// apiPath= "/api"
	- (void) setMeretzServerHostName: (NSString *) hostName
	{
		NSAssert(0 < [hostName length], @"invalid Meretz server host name!");
		gMeretzServerHostName= [hostName lowercaseString];
		
		return;
	}

	- (void) setMeretzServerPort: (NSUInteger) port
	{
		gMeretzServerPort= [NSNumber numberWithUnsignedShort:port];
		
		return;
	}

	- (void) setMeretzServerProtocol: (NSString *) protocol
	{
		NSAssert(0 < [protocol length], @"invalid Meretz server protocol string!");
		NSAssert((NSOrderedSame == [protocol caseInsensitiveCompare:PROTOCOL_HTTP]) ||
			(NSOrderedSame == [protocol caseInsensitiveCompare:PROTOCOL_HTTPS]),
			@"Meretz server protocol must be either HTTP or HTTPS!");
		gMeretzServerProtocol= [protocol lowercaseString];
		
		return;
	}

	- (void) setMeretzServerAPIPath: (NSString *) apiPath
	{
		// empty string is allowed
		if (0 == [apiPath length])
		{
			apiPath= @"";
		}
		gMeretzServerApiPath= apiPath;
		
		return;
	}

	- (NSString *) getMeretzServerString
	{
		unsigned short port= [gMeretzServerPort unsignedShortValue];
		NSString *portPart= @"";
		NSString *result;
		
		if ((NSOrderedSame == [gMeretzServerProtocol caseInsensitiveCompare:PROTOCOL_HTTP]) && (kDefaultHTTPPort == port))
		{
			// default port being used for HTTP, no need to be explicit
		}
		else if ((NSOrderedSame == [gMeretzServerProtocol caseInsensitiveCompare:PROTOCOL_HTTPS]) && (kDefaultHTTPSPort == port))
		{
			// default port being used for HTTPS, no need to be explicit
		}
		else
		{
			portPart= [NSString stringWithFormat:@":%d", port];
		}
		
		result= [NSString stringWithFormat:@"%@://%@%@%@", gMeretzServerProtocol, gMeretzServerHostName, portPart, gMeretzServerApiPath];
		
		return result;
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
		
		NSLog(@"Meretz user access token set to: %@", accessToken);
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
	- (MeretzTaskId) vendorUserConnect: (NSString *) userConnectionCode vendorUserToken: (NSString *) vendorUserIdentifier
	{
		NSAssert(0 < [userConnectionCode length], @"VendorUserConnect requires a valid user connection code!");
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		MeretzTask *task= [[MeretzTask alloc] initVendorUserConnect:userConnectionCode vendorUserToken:vendorUserIdentifier];
		
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

	- (MeretzResult *) getVendorUserDisconnectResult: (MeretzTaskId) vendorUserDisconnectTask
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

	- (MeretzResult *) getVendorUsePointsResult: (MeretzTaskId) vendorUsePointsTask
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

	- (BOOL) initialize
	{
		BOOL success= FALSE;
		
		gMeretzServerProtocol= DEFAULT_MERETZ_SERVER_PROTOCOL;
		gMeretzServerHostName= DEFAULT_MERETZ_SERVER_HOST_NAME;
		gMeretzServerPort= [NSNumber numberWithUnsignedShort:DEFAULT_MERETZ_SERVER_PORT];
		gMeretzServerApiPath= DEFAULT_MERETZ_SERVER_API_PATH;
		
		gTaskDictionary= [NSMutableDictionary dictionary];
		
		if (nil != gTaskDictionary)
		{
			success= TRUE;
		}
		
		return success;
	}

	// Meretz task management

	- (MeretzTaskId) addTask: (MeretzTask *) newTask
	{
		NSAssert(nil != gTaskDictionary, @"task list uninitialized!");
		NSAssert(nil != newTask, @"cannot add nil task!");
		NSAssert(MeretzTaskStatusInvalid == [newTask getTaskStatus], @"cannot add an already-started task!");
		NSNumber *taskKey= [NSNumber numberWithUnsignedInt:arc4random()];
		NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		
		// generate a new taskID
		while (nil != [gTaskDictionary valueForKey:[taskKey stringValue]])
		{
			taskKey= [NSNumber numberWithUnsignedInt:arc4random()];
			NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		}
		
		// attempt to spin up the task
		if ([newTask beginWork])
		{
			// set status to initial value
			[newTask setTaskStatus: MeretzTaskStatusInProgress];
			// add to the master task list
			gTaskDictionary[[taskKey stringValue]]= newTask;
			// return the new taskId
			taskId= [taskKey unsignedIntegerValue];
			NSLog(@"new task '%@' (%X) added", newTask, taskId);
		}
		else
		{
			NSLog(@"beginWork() failed for '%@'", newTask);
		}
		
		return taskId;
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
