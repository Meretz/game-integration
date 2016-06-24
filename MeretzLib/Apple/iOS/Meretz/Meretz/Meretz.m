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

/* ---------- implementation */

@implementation MeretzItemDefinition
	@synthesize PublicId;
	@synthesize Name;
	@synthesize Description;

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzItemDefinition: PublicId= '%@', Name= '%@', Description= '%@'",
			self.PublicId, self.Name, self.Description];
	}
@end

@implementation MeretzItem
	@synthesize PublicId;
	@synthesize ItemDefinition;
	@synthesize Price;
	@synthesize Code;
	@synthesize ConsumedTime;

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzItem: PublicId= '%@', ItemDefinition= [%@], Price= '%@', Code= '%@', ConsumedTime= '%@'",
			self.PublicId, self.ItemDefinition, self.Price, self.Code, self.ConsumedTime];
	}
@end

@implementation MeretzResult
	@synthesize Success;
	@synthesize ErrorCode;
	@synthesize ErrorMessage;

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@'",
			self.Success, self.ErrorCode, self.ErrorMessage];
	}
@end

@implementation MeretzVendorUserConnectResult
	@synthesize AccessToken;

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzVendorUserConnectResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@', AccessToken= '%@'",
			self.Success, self.ErrorCode, self.ErrorMessage, self.AccessToken];
	}
@end

@implementation MeretzVendorConsumeResult
	@synthesize Items;

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzVendorConsumeResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@', Items= %@",
			self.Success, self.ErrorCode, self.ErrorMessage, self.Items];
	}
@end

/* $FUTURE
@implementation MeretzVendorUserProfileResult
	@synthesize UsablePoints;
	@synthesize TotalPoints;

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzVendorUserProfileResult: Success= %@, ErrorCode= '%@', ErrorMessage= '%@', UsablePoints= '%@', TotalPoints= '%@'",
			self.Success, self.ErrorCode, self.ErrorMessage, self.UsablePoints, self.TotalPoints];
	}
@end
*/

@implementation Meretz
	@synthesize delegate;
	@synthesize DelegateRespondsToVendorUserConnect;
	@synthesize DelegateRespondsToVendorUserDisconnect;
	@synthesize DelegateRespondsToVendorConsume;
	@synthesize TaskDictionary;
	@synthesize MeretzServerProtocol;
	@synthesize MeretzServerHostName;
	@synthesize MeretzServerPort;
	@synthesize MeretzServerApiPath;
	@synthesize UserAccessToken;

	/* ---------- public methods */

	// call this to initialize Meretz for your organization's application
	- (instancetype)init;
	{
		self= [super init];
		
		if (nil != self)
		{
			if ([self initialize])
			{
				NSLog(@"Meretz: v.%X initialized, using REST API server: %@", MERETZ_VERSION, [self getMeretzServerString]);
			}
			else
			{
				return nil;
			}
		}
		
		return self;
	}

	// set a delegate object
	- (void)setMeretzDelegate:(id<MeretzDelegate>) newDelegate
	{
		if (self.delegate != newDelegate)
		{
			if (nil != newDelegate)
			{
				[self setDelegateRespondsToVendorUserConnect: [newDelegate respondsToSelector:@selector(didVendorUserConnectFinish:)]];
				[self setDelegateRespondsToVendorUserDisconnect: [newDelegate respondsToSelector:@selector(didVendorUserDisconnectFinish:)]];
				[self setDelegateRespondsToVendorConsume: [newDelegate respondsToSelector:@selector(didVendorConsumeFinish:)]];
			}
			else
			{
				[self setDelegateRespondsToVendorUserConnect:FALSE];
				[self setDelegateRespondsToVendorUserDisconnect:FALSE];
				[self setDelegateRespondsToVendorConsume:FALSE];
			}
			
			self.delegate= newDelegate;
		}
		
		return;
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

	- (void) setMeretzPort: (unsigned short) port
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
			NSLog(@"Meretz: attempted to release an invalid task '%X'!", taskId);
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
			NSLog(@"Meretz: No VendorUserConnect task for id '%X'", vendorUserConnectTask);
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
			NSLog(@"Meretz: No VendorUserDisconnect task for id '%X'", vendorUserDisconnectTask);
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
					NSMutableArray *itemArray= [[NSMutableArray alloc] init];
					
					NSDateFormatter *dateFormatter= [[NSDateFormatter alloc] init];
			
					[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
					[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
					
					for (int itemIndex= 0, itemCount= (int)[items count]; itemIndex < itemCount; itemIndex+= 1)
					{
						NSObject *itemObject= [items objectAtIndex:(unsigned)itemIndex];
						NSObject *itemDefinitionObject= [itemObject valueForKey:@"item_definition"];
						NSString *itemDefPublicId= (nil != itemDefinitionObject) ? [itemDefinitionObject valueForKey:@"public_id"] : nil;
						NSString *itemDefName= (nil != itemDefinitionObject) ? [itemDefinitionObject valueForKey:@"name"] : nil;
						NSString *itemDefDescription= (nil != itemDefinitionObject) ? [itemDefinitionObject valueForKey:@"description"] : nil;
						NSString *itemPublicId= [itemObject valueForKey:@"public_id"];
						NSNumber *itemPrice= @([[itemObject valueForKey:@"price"] integerValue]);
						NSString *itemCode= [itemObject valueForKey:@"code"];
						id itemConsumedTimeString= [itemObject valueForKey:@"consumed_time"];
						NSDate *itemConsumedTime= nil;
						
						if (itemConsumedTimeString != [NSNull null])
						{
							itemConsumedTime= [dateFormatter dateFromString:itemConsumedTimeString];
						}
						
						MeretzItemDefinition *itemDefinition= [[MeretzItemDefinition alloc] init];
						MeretzItem *item= [[MeretzItem alloc] init];
						
						[itemDefinition setPublicId:itemDefPublicId];
						[itemDefinition setName:itemDefName];
						[itemDefinition setDescription:itemDefDescription];
						
						[item setPublicId:itemPublicId];
						[item setItemDefinition:itemDefinition];
						[item setPrice:itemPrice];
						[item setCode:itemCode];
						[item setConsumedTime:itemConsumedTime];
						
						[itemArray addObject:item];
					}
					
					[result setSuccess:[NSNumber numberWithBool:success]];
					[result setErrorCode:errorCode];
					[result setErrorMessage:errorMessage];
					[result setItems:itemArray];
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
			NSLog(@"Meretz: No MeretzVendorConsumeResult task for id '%X'", vendorConsumeTask);
		}
		
		return result;
	}

	/* $FUTURE
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
			NSLog(@"Meretz: No VendorUsePoints task for id '%X'", vendorUsePointsTask);
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
			NSLog(@"Meretz: No MeretzVendorUserProfileResult task for id '%X'", vendorUserProfileTask);
		}
		
		return result;
	}
	*/

	/* ---------- private methods */

	- (BOOL) initialize
	{
		BOOL success= FALSE;
		
		self.delegate= nil;
		[self setDelegateRespondsToVendorUserConnect:FALSE];
		[self setDelegateRespondsToVendorUserDisconnect:FALSE];
		[self setDelegateRespondsToVendorConsume:FALSE];
		
		[self setUserAccessToken:@""];
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
		MeretzTaskId taskId= MERETZ_TASK_ID_INVALID;
		NSNumber *taskKey;
		
		// generate a new taskID
		for (taskKey= [NSNumber numberWithUnsignedInt:arc4random()]; TRUE; taskKey= [NSNumber numberWithUnsignedInt:arc4random()])
		{
			NSAssert(nil != taskKey, @"failed to initialize taskKey!");
			if (MERETZ_TASK_ID_INVALID != [taskKey unsignedIntegerValue])
			{
				if (nil == [self.TaskDictionary valueForKey:[taskKey stringValue]])
				{
					break;
				}
			}
		}
		
		// claim ownership of this task
		[newTask setMeretzInstance:self];
		
		// attempt to spin up the task
		if ([newTask beginWork])
		{
			// set status to initial value
			[newTask setTaskStatus: MeretzTaskStatusInProgress];
			// add to the master task list
			self.TaskDictionary[[taskKey stringValue]]= newTask;
			// return the new taskId
			taskId= [taskKey unsignedIntegerValue];
			[newTask setTaskId:taskId];
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

	// calls appropriate delegate method to signal task completion
	-(void) taskDidFinish: (MeretzTaskId) taskId
	{
		MeretzTask *task= [self getTask:taskId];
		
		switch (task.TaskType)
		{
			case MeretzTaskTypeVendorUserConnect:
			{
				if (self.DelegateRespondsToVendorUserConnect)
				{
					MeretzVendorUserConnectResult *result= [self getVendorUserConnectResult:taskId];
					
					if (nil != result)
					{
						[self.delegate didVendorUserConnectFinish:result];
					}
				}
				break;
			}
			case MeretzTaskTypeVendorUserDisconnect:
			{
				if (self.DelegateRespondsToVendorUserDisconnect)
				{
					MeretzResult *result= [self getVendorUserDisconnectResult:taskId];
					
					if (nil != result)
					{
						[self.delegate didVendorUserDisconnectFinish:result];
					}
				}
				break;
			}
			case MeretzTaskTypeVendorConsume:
			{
				if (self.DelegateRespondsToVendorConsume)
				{
					MeretzVendorConsumeResult *result= [self getVendorConsumeResult:taskId];
					
					if (nil != result)
					{
						[self.delegate didVendorConsumeFinish:result];
					}
				}
				break;
			}
			/* $FUTURE
			case MeretzTaskTypeVendorUsePoints:
			case MeretzTaskTypeVendorUserProfile:
			*/
			default:
			{
				NSAssert(FALSE, @"unhandled task type '%ld'!", (long)task.TaskType);
				break;
			}
		}
		
		return;
	}

@end
