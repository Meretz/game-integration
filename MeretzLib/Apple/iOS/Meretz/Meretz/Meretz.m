/*
Meretz.m
Thursday May 26, 2016 11:11am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import "Meretz+Internal.h"

/* ---------- constants */

// server configuration defaults

const unsigned short kDefaultHTTPPort= 80;
const unsigned short kDefaultHTTPSPort= 443;

#define PROTOCOL_HTTP									@"http"
#define PROTOCOL_HTTPS									@"https"

#define DEFAULT_MERETZ_SERVER_PROTOCOL					PROTOCOL_HTTPS
#define DEFAULT_MERETZ_SERVER_HOST_NAME					@"www.meretz.com"
#define DEFAULT_MERETZ_SERVER_PORT						kDefaultHTTPSPort
#define DEFAULT_MERETZ_SERVER_API_PATH					@"/api"

/* ---------- private interface */

@interface Meretz()

	/* ---------- private properties */

	@property (nonatomic, retain) NSMutableDictionary *TaskDictionary;
	@property (nonatomic, retain) NSString *MeretzServerProtocol;
	@property (nonatomic, retain) NSString *MeretzServerHostName;
	@property (nonatomic, retain) NSNumber *MeretzServerPort;
	@property (nonatomic, retain) NSString *MeretzServerApiPath;

	// the unique vendor access token give to you by Meretz
	@property (nonatomic, retain) NSString *VendorAccessToken;

	// a unique user access token retrieved initially via a vendorUserConnect call,
	// then stored by your app and used for future interactions with the Meretz API
	@property (nonatomic, retain) NSString *UserAccessToken;

	/* ---------- private methods */

	- (BOOL) initialize;

	// Meretz task management
	- (MeretzTaskId) addTask: (MeretzTask *) newTask;
	- (NSNumber *) getTaskKey: (MeretzTaskId) taskId;
	- (MeretzTask *) getTask: (MeretzTaskId) taskId;

@end

/* ---------- implementation */

@implementation MeretzItemDefinition
	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzItemDefinition: PublicId= '%@', Name= '%@', Description= '%@'",
			self.PublicId, self.Name, self.Description];
	}
@end

@implementation MeretzItem
	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzItem: PublicId= '%@', ItemDefinition= [%@], Price= '%@', Code= '%@', ConsumedTime= '%@'",
			self.PublicId, self.ItemDefinition, self.Price, self.Code, self.ConsumedTime];
	}
@end

@implementation MeretzResult
	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@'",
		self.Success, self.ErrorCode, self.ErrorMessage];
	}
@end

@implementation MeretzVendorUserConnectResult
	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzVendorUserConnectResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@', AccessToken= '%@'",
		self.Success, self.ErrorCode, self.ErrorMessage, self.AccessToken];
	}
@end

@implementation MeretzVendorConsumeResult
	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzVendorConsumeResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@', Items= [%@]",
		self.Success, self.ErrorCode, self.ErrorMessage, self.Items];
	}
@end

@implementation MeretzVendorUserProfileResult
	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzVendorUserProfileResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@', UsablePoints= '%@', TotalPoints= '%@'",
		self.Success, self.ErrorCode, self.ErrorMessage, self.UsablePoints, self.TotalPoints];
	}
@end

@implementation Meretz

	/* ---------- public methods */

	// call this to initialize Meretz for your organization's application
	// with your unique vendor access token (as given to you by Meretz)
	// and an optional, previously stored user access token if you have
	// previously connected a game user
	- (instancetype)initWithTokens: (NSString *) vendorSecretToken emptyOrSavedValue: (NSString *) userAccessToken;
	{
		if (0 < [vendorSecretToken length])
		{
			[self setVendorAccessToken:vendorSecretToken];
			[self setUserAccessToken:@""];
			
			self= [super init];
			
			if (nil != self)
			{
				if ([self initialize])
				{
					NSLog(@"Meretz: v.%X initialized with vendor access token '%@'", MERETZ_VERSION, self.VendorAccessToken);
					if (0 < [userAccessToken length])
					{
						[self setMeretzUserAccessToken:userAccessToken];
					}
					
					NSLog(@"Meretz: REST API server: %@", [self getMeretzServerString]);
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
	- (void) setMeretzHostName: (NSString *) hostName
	{
		NSAssert(0 < [hostName length], @"invalid Meretz server host name!");
		[self setMeretzServerHostName: [hostName lowercaseString]];
		
		return;
	}

	- (void) setMeretzPort: (NSUInteger) port
	{
		[self setMeretzServerPort:[NSNumber numberWithUnsignedShort:port]];
		
		return;
	}

	- (void) setMeretzProtocol: (NSString *) protocol
	{
		NSAssert(0 < [protocol length], @"invalid Meretz server protocol string!");
		NSAssert((NSOrderedSame == [protocol caseInsensitiveCompare:PROTOCOL_HTTP]) ||
			(NSOrderedSame == [protocol caseInsensitiveCompare:PROTOCOL_HTTPS]),
			@"Meretz server protocol must be either HTTP or HTTPS!");
		[self setMeretzServerProtocol:[protocol lowercaseString]];
		
		return;
	}

	- (void) setMeretzAPIPath: (NSString *) apiPath
	{
		// empty string is allowed
		if (0 == [apiPath length])
		{
			apiPath= @"";
		}
		[self setMeretzServerApiPath:apiPath];
		
		return;
	}

	- (NSString *) getMeretzServerString
	{
		unsigned short port= [self.MeretzServerPort unsignedShortValue];
		NSString *portPart= @"";
		NSString *result;
		
		if ((NSOrderedSame == [self.MeretzServerProtocol caseInsensitiveCompare:PROTOCOL_HTTP]) && (kDefaultHTTPPort == port))
		{
			// default port being used for HTTP, no need to be explicit
		}
		else if ((NSOrderedSame == [self.MeretzServerProtocol caseInsensitiveCompare:PROTOCOL_HTTPS]) && (kDefaultHTTPSPort == port))
		{
			// default port being used for HTTPS, no need to be explicit
		}
		else
		{
			portPart= [NSString stringWithFormat:@":%d", port];
		}
		
		result= [NSString stringWithFormat:@"%@://%@%@%@", self.MeretzServerProtocol, self.MeretzServerHostName, portPart, self.MeretzServerApiPath];
		
		return result;
	}

	// accessors for vendor/user- specific access token
	- (NSString *) getMeretzUserAccessToken
	{
		return self.UserAccessToken;
	}

	- (void) setMeretzUserAccessToken: (NSString *) accessToken
	{
		if (0 == [accessToken length])
		{
			accessToken= @"";
		}
		
		NSLog(@"Meretz: user access token set to: %@", accessToken);
		[self setUserAccessToken:accessToken];
		
		return;
	}

	// query the status of a Meretz asynchronous task
	- (MeretzTaskStatus) getTaskStatus: (MeretzTaskId) taskId
	{
		MeretzTask *task= [self getTask: taskId];
		MeretzTaskStatus status= (nil != task) ? task.TaskStatus : MeretzTaskStatusInvalid;
		
		return status;
	}

	// call when finished with a task, to release its resources
	- (void) releaseTask: (MeretzTaskId) taskId
	{
		NSAssert(nil != self.TaskDictionary, @"Meretz not initialized!");
		NSNumber *taskKey= [self getTaskKey:taskId];
		MeretzTask *task= [self getTask:taskId];
		
		if (nil != task)
		{
			NSAssert(self == task.MeretzInstance, @"attempted to release a task which did not belong to this Meretz instance!");
			task.MeretzInstance= nil;
			[self.TaskDictionary removeObjectForKey:taskKey];
		}
		else
		{
			NSLog(@"Meretz: attempted to release an invalid task '%d'!", taskId);
		}
		
		return;
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
		MeretzVendorUserConnectResult *result= nil;
		MeretzTask *task= [self getTask: vendorUserConnectTask];
		
		if (nil != task)
		{
			NSDictionary *taskResults= [task getResult];
			
			if (nil != taskResults)
			{
				BOOL success= (nil != taskResults[TASK_OUTPUT_KEY_SUCCESS]) ? [taskResults[TASK_OUTPUT_KEY_SUCCESS] boolValue] : FALSE;
				NSString *errorCode= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_CODE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_CODE] : @"";
				NSString *errorMessage= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE] : @"";
				NSString *accessToken= (nil != taskResults[TASK_OUTPUT_KEY_VENDOR_CONNECT_USER_ACCESS_TOKEN]) ? taskResults[TASK_OUTPUT_KEY_VENDOR_CONNECT_USER_ACCESS_TOKEN] : @"";
				
				result= [[MeretzVendorUserConnectResult alloc] init];
				
				if (nil != result)
				{
					[result setSuccess:[NSNumber numberWithBool:success]];
					[result setErrorCode:errorCode];
					[result setErrorMessage:errorMessage];
					[result setAccessToken:accessToken];
				}
				else
				{
					NSLog(@"Meretz: failed to alloc MeretzVendorUserConnectResult object!");
				}
			}
			else
			{
				NSLog(@"Meretz: VendorUserConnectResult missing taskResult dictionary!");
			}
		}
		else
		{
			NSLog(@"Meretz: No VendorUserConnect task for id '%d'", vendorUserConnectTask);
		}
		
		return result;
	}

	// User disconnection (for the current user as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserDisconnect
	{
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		MeretzTask *task= [[MeretzTask alloc] initVendorUserDisconnect];
		
		if (nil != task)
		{
			taskId= [self addTask: task];
		}
		
		return taskId;
	}

	- (MeretzResult *) getVendorUserDisconnectResult: (MeretzTaskId) vendorUserDisconnectTask
	{
		MeretzResult *result= nil;
		MeretzTask *task= [self getTask: vendorUserDisconnectTask];
		
		if (nil != task)
		{
			NSDictionary *taskResults= [task getResult];
			
			if (nil != taskResults)
			{
				BOOL success= (nil != taskResults[TASK_OUTPUT_KEY_SUCCESS]) ? [taskResults[TASK_OUTPUT_KEY_SUCCESS] boolValue] : FALSE;
				NSString *errorCode= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_CODE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_CODE] : @"";
				NSString *errorMessage= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE] : @"";
				
				result= [[MeretzResult alloc] init];
				
				if (nil != result)
				{
					[result setSuccess:[NSNumber numberWithBool:success]];
					[result setErrorCode:errorCode];
					[result setErrorMessage:errorMessage];
				}
				else
				{
					NSLog(@"Meretz: failed to alloc MeretzResult object!");
				}
			}
			else
			{
				NSLog(@"Meretz: VendorUserDisconnectResult missing taskResult dictionary!");
			}
		}
		else
		{
			NSLog(@"Meretz: No VendorUserDisconnect task for id '%d'", vendorUserDisconnectTask);
		}
		
		return result;
	}

	// Item consumption over a date range
	- (MeretzTaskId) vendorConsume: (NSDate *) startDate optional: (NSDate *) endDate
	{
		NSAssert(nil != startDate, @"VendorConsume requires a valid startDate!");
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		MeretzTask *task= [[MeretzTask alloc] initVendorConsume:startDate optional:endDate];
		
		if (nil != task)
		{
			taskId= [self addTask: task];
		}
		
		return taskId;
	}

	- (MeretzVendorConsumeResult *) getVendorConsumeResult: (MeretzTaskId) vendorConsumeTask
	{
		MeretzVendorConsumeResult *result= nil;
		MeretzTask *task= [self getTask: vendorConsumeTask];
		
		if (nil != task)
		{
			NSDictionary *taskResults= [task getResult];
			
			if (nil != taskResults)
			{
				BOOL success= (nil != taskResults[TASK_OUTPUT_KEY_SUCCESS]) ? [taskResults[TASK_OUTPUT_KEY_SUCCESS] boolValue] : FALSE;
				NSString *errorCode= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_CODE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_CODE] : @"";
				NSString *errorMessage= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE] : @"";
				NSArray *items= (nil != taskResults[TASK_OUTPUT_KEY_VENDOR_CONSUME_ITEMS] ? taskResults[TASK_OUTPUT_KEY_VENDOR_CONSUME_ITEMS] : @[]);
				
				result= [[MeretzVendorConsumeResult alloc] init];
				
				if (nil != result)
				{
					[result setSuccess:[NSNumber numberWithBool:success]];
					[result setErrorCode:errorCode];
					[result setErrorMessage:errorMessage];
					[result setItems:items];
				}
				else
				{
					NSLog(@"Meretz: failed to alloc MeretzVendorConsumeResult object!");
				}
			}
			else
			{
				NSLog(@"Meretz: MeretzVendorConsumeResult missing taskResult dictionary!");
			}
		}
		else
		{
			NSLog(@"Meretz: No MeretzVendorConsumeResult task for id '%d'", vendorConsumeTask);
		}
		
		return result;
	}

	// Spending points on behalf of the current user (as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUsePoints: (NSInteger) pointQuantity
	{
		NSAssert(0 < pointQuantity, @"VendorUsePoints requires a point quantity > 0!");
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		MeretzTask *task= [[MeretzTask alloc] initVendorUsePoints:pointQuantity];
		
		if (nil != task)
		{
			taskId= [self addTask: task];
		}
		
		return taskId;
	}

	- (MeretzResult *) getVendorUsePointsResult: (MeretzTaskId) vendorUsePointsTask
	{
		MeretzResult *result= nil;
		MeretzTask *task= [self getTask: vendorUsePointsTask];
		
		if (nil != task)
		{
			NSDictionary *taskResults= [task getResult];
			
			if (nil != taskResults)
			{
				BOOL success= (nil != taskResults[TASK_OUTPUT_KEY_SUCCESS]) ? [taskResults[TASK_OUTPUT_KEY_SUCCESS] boolValue] : FALSE;
				NSString *errorCode= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_CODE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_CODE] : @"";
				NSString *errorMessage= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE] : @"";
				
				result= [[MeretzResult alloc] init];
				
				if (nil != result)
				{
					[result setSuccess:[NSNumber numberWithBool:success]];
					[result setErrorCode:errorCode];
					[result setErrorMessage:errorMessage];
				}
				else
				{
					NSLog(@"Meretz: failed to alloc MeretzResult object!");
				}
			}
			else
			{
				NSLog(@"Meretz: VendorUsePointsResult missing taskResult dictionary!");
			}
		}
		else
		{
			NSLog(@"Meretz: No VendorUsePoints task for id '%d'", vendorUsePointsTask);
		}
		
		return result;
	}

	// Retrieving Meretz user information for the current user (as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserProfile
	{
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		MeretzTask *task= [[MeretzTask alloc] initVendorUserProfile];
		
		if (nil != task)
		{
			taskId= [self addTask: task];
		}
		
		return taskId;
	}

	- (MeretzVendorUserProfileResult *) getVendorUserProfileResult: (MeretzTaskId) vendorUserProfileTask
	{
		MeretzVendorUserProfileResult *result= nil;
		MeretzTask *task= [self getTask: vendorUserProfileTask];
		
		if (nil != task)
		{
			NSDictionary *taskResults= [task getResult];
			
			if (nil != taskResults)
			{
				BOOL success= (nil != taskResults[TASK_OUTPUT_KEY_SUCCESS]) ? [taskResults[TASK_OUTPUT_KEY_SUCCESS] boolValue] : FALSE;
				NSString *errorCode= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_CODE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_CODE] : @"";
				NSString *errorMessage= (nil != taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE]) ? taskResults[TASK_OUTPUT_KEY_ERROR_MESSAGE] : @"";
				NSNumber *usablePoints= (nil != taskResults[TASK_OUTPUT_KEY_VENDOR_USER_PROFILE_USABLE_POINTS] ? taskResults[TASK_OUTPUT_KEY_VENDOR_USER_PROFILE_USABLE_POINTS] : [NSNumber numberWithInteger:0]);
				NSNumber *totalPoints= (nil != taskResults[TASK_OUTPUT_KEY_VENDOR_USER_PROFILE_TOTAL_POINTS] ? taskResults[TASK_OUTPUT_KEY_VENDOR_USER_PROFILE_TOTAL_POINTS] : [NSNumber numberWithInteger:0]);
				
				result= [[MeretzVendorUserProfileResult alloc] init];
				
				if (nil != result)
				{
					[result setSuccess:[NSNumber numberWithBool:success]];
					[result setErrorCode:errorCode];
					[result setErrorMessage:errorMessage];
					[result setUsablePoints:usablePoints];
					[result setTotalPoints:totalPoints];
				}
				else
				{
					NSLog(@"Meretz: failed to alloc MeretzVendorUserProfileResult object!");
				}
			}
			else
			{
				NSLog(@"Meretz: MeretzVendorUserProfileResult missing taskResult dictionary!");
			}
		}
		else
		{
			NSLog(@"Meretz: No MeretzVendorUserProfileResult task for id '%d'", vendorUserProfileTask);
		}
		
		return result;
	}


	/* ---------- private methods */

	- (BOOL) initialize
	{
		BOOL success= FALSE;
		
		[self setMeretzServerProtocol:DEFAULT_MERETZ_SERVER_PROTOCOL];
		[self setMeretzServerHostName:DEFAULT_MERETZ_SERVER_HOST_NAME];
		[self setMeretzServerPort:[NSNumber numberWithUnsignedShort:DEFAULT_MERETZ_SERVER_PORT]];
		[self setMeretzServerApiPath:DEFAULT_MERETZ_SERVER_API_PATH];
		
		self.TaskDictionary= [NSMutableDictionary dictionary];
		
		if (nil != self.TaskDictionary)
		{
			success= TRUE;
		}
		
		return success;
	}

	// Meretz task management

	- (MeretzTaskId) addTask: (MeretzTask *) newTask
	{
		NSAssert(nil != self.TaskDictionary, @"task list uninitialized!");
		NSAssert(nil != newTask, @"cannot add nil task!");
		NSAssert(nil == newTask.MeretzInstance, @"attempting to add a task which belongs to an existing Meretz instance!");
		NSAssert(MeretzTaskStatusInvalid == newTask.TaskStatus, @"cannot add an already-started task!");
		NSNumber *taskKey= [NSNumber numberWithUnsignedInt:arc4random()];
		NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		
		// generate a new taskID
		while (nil != [self.TaskDictionary valueForKey:[taskKey stringValue]])
		{
			taskKey= [NSNumber numberWithUnsignedInt:arc4random()];
			NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		}
		
		// claim ownership of this task
		newTask.MeretzInstance= self;
		
		// attempt to spin up the task
		if ([newTask beginWork])
		{
			// set status to initial value
			[newTask setTaskStatus: MeretzTaskStatusInProgress];
			// add to the master task list
			self.TaskDictionary[[taskKey stringValue]]= newTask;
			// return the new taskId
			taskId= [taskKey unsignedIntegerValue];
			NSLog(@"Meretz: new task '%@' (%X) added", newTask, taskId);
		}
		else
		{
			NSLog(@"Meretz: beginWork() failed for '%@'", newTask);
		}
		
		return taskId;
	}

	- (NSNumber *) getTaskKey: (MeretzTaskId) taskId
	{
		NSAssert(MERETZ_TASK_ID_INVALID != taskId, @"invalid taskId!");
		NSNumber *taskKey= [NSNumber numberWithUnsignedInt:taskId];
		NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		
		return taskKey;
	}

	- (MeretzTask *) getTask: (MeretzTaskId) taskId
	{
		NSAssert(nil != self.TaskDictionary, @"task list uninitialized!");
		NSNumber *taskKey= [self getTaskKey:taskId];
		NSAssert(nil != taskKey, @"failed to initialize taskKey!");
		MeretzTask *result= self.TaskDictionary[[taskKey stringValue]];
		NSAssert(nil != result, @"invalid MeretzTaskId!");
		
		return result;
	}

@end
