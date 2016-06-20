/*
MeretzTask.m
Tuesday May 31, 2016 11:49am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import "Meretz+Internal.h"

#import <Foundation/Foundation.h>

/* ---------- constants */

// HTTP header key, value pairs

#define HTTP_HEADER_KEY_CONTENT_LENGTH						@"Content-Length"
#define HTTP_HEADER_KEY_CONTENT_TYPE						@"Content-Type"

#define HTTP_HEADER_KEY_MERETZ_ACCESS						@"X-Meretz-Access"

#define HTTP_HEADER_VALUE_APPLICATION_JSON					@"application/json"

#define HTTP_HEADER_KVP_ACCEPT_JSON							@"Accept" : HTTP_HEADER_VALUE_APPLICATION_JSON
#define HTTP_HEADER_KVP_CONTENT_TYPE_JSON					HTTP_HEADER_KEY_CONTENT_TYPE : HTTP_HEADER_VALUE_APPLICATION_JSON
#define HTTP_HEADER_KVP_AJAX_REQUEST						@"X-Requested-With" : @"XMLHttpRequest"

// Meretz API endpoints

// /vendor

// POST /vendor/connect_user
// headers: "Content-Type: application/json", "X-Requested-With: XMLHttpRequest"
// data: '{"connection_code":"0123456789AB", "vendor_token":"My Value For User"}'
#define MERETZ_API_ENDPOINT_VENDOR_CONNECT_USER				@"/vendor/connect_user"

// POST /vendor/disconnect_user
// headers: "Content-Type: application/json", "X-Requested-With: XMLHttpRequest", "X-Meretz-Access: ABABABB"
// data: none
#define MERETZ_API_ENDPOINT_VENDOR_DISCONNECT_USER			@"/vendor/disconnect_user"

// POST /vendor/consume
// headers: "Content-Type: application/json", "X-Requested-With: XMLHttpRequest",H "X-Meretz-Access: ABABABB"
// data: '{"start_time":"2011-09-01T13:20:30+03:00"[,"end_time":...][,"read_only":...]}'
#define MERETZ_API_ENDPOINT_VENDOR_CONSUME					@"/vendor/consume"

// POST /vendor/use_points
// headers: "Content-Type: application/json", "X-Requested-With: XMLHttpRequest", "X-Meretz-Access: ABABABB"
// data: '{"meretz_points": 20}'
#define MERETZ_API_ENDPOINT_VENDOR_USE_POINTS				@"/vendor/use_points"

// GET /vendor/user_profile
// headers: "Content-Type: application/json", "X-Requested-With: XMLHttpRequest", "X-Meretz-Access: ABABABB"
#define MERETZ_API_ENDPOINT_VENDOR_USER_PROFILE				@"/vendor/user_profile"

// Meretz task input keys

#define TASK_INPUT_KEY_VENDOR_USER_CONNECTION_CODE			@"connection_code"
#define TASK_INPUT_KEY_VENDOR_USER_VENDOR_TOKEN				@"vendor_token"

#define TASK_INPUT_KEY_VENDOR_CONSUME_START_DATE			@"start_time"
#define TASK_INPUT_KEY_VENDOR_CONSUME_END_DATE				@"end_time"

#define TASK_INPUT_KEY_VENDOR_USE_POINT_QUANTITY			@"meretz_points"

/* ---------- internal interface */

@interface MeretzTask()

	- (NSString *) getTypeString;

	// endpoint: e.g. "/vendor/connect_user"
	- (NSString *) buildEndpointURL: (NSString *) endpoint;

	- (BOOL) launchSessionTask:(NSString *_Nonnull)url
		customHeaders: (NSDictionary *) headers
		httpMethod: (HTTPMethod) method
		apiData: (NSDictionary *) data
		completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

	- (void) taskComplete: (NSData *) data
		httpResponse: (NSURLResponse *) response
		responseError: (NSError *) error;

	- (BOOL) beginWorkVendorUserConnect;
	- (BOOL) beginWorkVendorUserDisconnect;
	- (BOOL) beginWorkVendorConsume;
	- (BOOL) beginWorkVendorUsePoints;
	- (BOOL) beginWorkVendorUserProfile;

	- (NSString *) iso8601DateTimeString: (NSDate *) date;

@end

/* ---------- implementation */

@implementation MeretzTask

	@synthesize MeretzInstance;
	@synthesize TaskStatus;
	@synthesize TaskType;
	@synthesize Session;
	@synthesize SessionDataTask;
	@synthesize TaskInput;
	@synthesize TaskOutput;

	/* ---------- public methods */

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzTask: Type= %@", [self getTypeString]];
	}

	-(instancetype) init
	{
		self= [super init];
		if (nil != self)
		{
			[self setTaskStatus:MeretzTaskStatusInvalid];
			[self setTaskType:MeretzTaskTypeInvalid];
			
			[self setSession:nil];
			[self setSessionDataTask:nil];
			
			[self setTaskInput:[NSMutableDictionary dictionary]];
			[self setTaskOutput:[NSMutableDictionary dictionary]];
			
			return self;
		}
		
		return nil;
	}

	- (instancetype)initVendorUserConnect: (NSString *) userConnectionCode vendorUserToken: (NSString *) vendorTokenForUser
	{
		NSAssert(nil != userConnectionCode, @"VendorUserConnect requires a user connection code!");
		self= [self init];
		if (nil != self)
		{
			[self setTaskType:MeretzTaskTypeVendorUserConnect];
			[self.TaskInput setObject:userConnectionCode forKey:TASK_INPUT_KEY_VENDOR_USER_CONNECTION_CODE];
			[self.TaskInput setObject:vendorTokenForUser forKey:TASK_INPUT_KEY_VENDOR_USER_VENDOR_TOKEN];
		}
		
		return self;
	}

	- (instancetype)initVendorUserDisconnect
	{
		self= [self init];
		if (nil != self)
		{
			[self setTaskType:MeretzTaskTypeVendorUserDisconnect];
			// no inputs to task
		}
		
		return self;
	}

	- (instancetype)initVendorConsume: (NSDate *) startDate optional: (NSDate *) endDate
	{
		NSAssert(nil != startDate, @"VendorConsume requires a start date!");
		self= [self init];
		if (nil != self)
		{
			[self setTaskType:MeretzTaskTypeVendorConsume];
			[self.TaskInput setObject:[self iso8601DateTimeString:startDate] forKey:TASK_INPUT_KEY_VENDOR_CONSUME_START_DATE];
			if (nil != endDate)
			{
				[self.TaskInput setObject:[self iso8601DateTimeString:endDate] forKey:TASK_INPUT_KEY_VENDOR_CONSUME_END_DATE];
			}
		}
		
		return self;
	}

	- (instancetype)initVendorUsePoints: (NSInteger) pointQuantity
	{
		NSAssert(0 < pointQuantity, @"VendorUsePoints requires a positive value for point quantity!");
		self= [self init];
		if (nil != self)
		{
			[self setTaskType:MeretzTaskTypeVendorUsePoints];
			[self.TaskInput setObject:[NSNumber numberWithInteger:pointQuantity] forKey:TASK_INPUT_KEY_VENDOR_USE_POINT_QUANTITY];
		}
		
		return self;
	}

	- (instancetype)initVendorUserProfile
	{
		self= [self init];
		if (nil != self)
		{
			[self setTaskType:MeretzTaskTypeVendorUserProfile];
			// no inputs to task
		}
		
		return self;
	}

	- (BOOL) beginWork
	{
		BOOL success;
		
		switch (self.TaskType)
		{
			case MeretzTaskTypeVendorUserConnect: success= [self beginWorkVendorUserConnect]; break;
			case MeretzTaskTypeVendorUserDisconnect: success= [self beginWorkVendorUserDisconnect]; break;
			case MeretzTaskTypeVendorConsume: success= [self beginWorkVendorConsume]; break;
			case MeretzTaskTypeVendorUsePoints: success= [self beginWorkVendorUsePoints]; break;
			case MeretzTaskTypeVendorUserProfile: success= [self beginWorkVendorUserProfile]; break;
			default: NSAssert(FALSE, @"unhandled task type '%ld'!", (long)self.TaskType); success= FALSE; break;
		}
		
		return success;
	}

	- (NSDictionary *) getResult
	{
		return [self.TaskOutput copy];
	}

	/* ---------- private methods */

	- (NSString *) getTypeString
	{
		NSString *result;
		
		switch (self.TaskType)
		{
			case MeretzTaskTypeInvalid: result= STRINGIFY(MeretzTaskTypeInvalid); break;
			case MeretzTaskTypeVendorUserConnect: result= STRINGIFY(MeretzTaskTypeVendorUserConnect); break;
			case MeretzTaskTypeVendorUserDisconnect: result= STRINGIFY(MeretzTaskTypeVendorUserDisconnect); break;
			case MeretzTaskTypeVendorConsume: result= STRINGIFY(MeretzTaskTypeVendorConsume); break;
			case MeretzTaskTypeVendorUsePoints: result= STRINGIFY(MeretzTaskTypeVendorUsePoints); break;
			case MeretzTaskTypeVendorUserProfile: result= STRINGIFY(MeretzTaskTypeVendorUserProfile); break;
			default: result= STRINGIFY(<unknown>); break;
		}
		
		return result;
	}

	- (NSString *) buildEndpointURL: (NSString *) endpoint
	{
		NSAssert(0 < [endpoint length], @"invalid endpoint!");
		NSAssert(nil != self.MeretzInstance, @"Meretz instance has not been assigned to active task!");
		NSString *meretzServerURL= [self.MeretzInstance getMeretzServerString];
		NSString *result= [NSString stringWithFormat:@"%@%@", meretzServerURL, endpoint];
		
		return result;
	}

	- (BOOL) launchSessionTask:(NSString *_Nonnull)url
		customHeaders: (NSDictionary *) headers
		httpMethod: (HTTPMethod) method
		apiData: (NSDictionary *) data
		completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
	{
		NSAssert(nil == self.Session, @"task already has an active NSURLSession object!");
		NSAssert(nil == self.SessionDataTask, @"task already has an active NSURLSessionDataTask object!");
		NSAssert(0 < [url length], @"valid URL required!");
		NSAssert(nil != completionHandler, @"valid completion handler required!");
		BOOL success= FALSE;
		
		NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
		
		if (nil != sessionConfiguration)
		{
			[sessionConfiguration setAllowsCellularAccess:YES];
			
			if ((nil != headers) && (0 < [headers count]))
			{
				[sessionConfiguration setHTTPAdditionalHeaders:headers];
			}
			
			[self setSession:[NSURLSession sessionWithConfiguration:sessionConfiguration]];
			
			if (nil != self.Session)
			{
				NSURL *nsurl= [NSURL URLWithString:url];
				NSMutableURLRequest *request= [NSMutableURLRequest requestWithURL:nsurl];
				
				if (nil != request)
				{
					[request setHTTPMethod:HTTPMethodToString(method)];
					
					if ((nil != data) && (0 < [data count]))
					{
						NSError *jsonSerializationError= nil;
						NSData *requestData= [NSJSONSerialization dataWithJSONObject:data options:(NSJSONWritingOptions)0 error:&jsonSerializationError];
						
						if (nil != jsonSerializationError)
						{
							NSLog(@"Meretz: JSON serialization error: %@", jsonSerializationError);
						}
						
						if (nil != requestData)
						{
							[request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:HTTP_HEADER_KEY_CONTENT_LENGTH];
							[request setHTTPBody:requestData];
						}
						else
						{
							NSLog(@"Meretz: failed to JSON serialize request data!");
							request= nil;
						}
					}
					
					if (nil != request)
					{
						NSLog(@"Meretz: launching request to %@; headers= %@, data= %@", url, headers, data);
						[self setSessionDataTask:[self.Session dataTaskWithRequest:request completionHandler:completionHandler]];
						if (nil != self.SessionDataTask)
						{
							// start it up
							[self.SessionDataTask resume];
							success= TRUE;
						}
						else
						{
							NSLog(@"Meretz: failed to create NSURLSessionTask for task %@", self);
						}
					}
				}
				else
				{
					NSLog(@"Meretz: failed to create NSMutableURLRequest!");
				}
			}
			else
			{
				NSLog(@"Meretz: failed to create NSURLSession for task %@", self);
			}
		}
		else
		{
			NSLog(@"Meretz: failed to create session configuration object!");
		}
		
		NSLog(@"Meretz: task %@ launch %@", self, (success ? @"SUCCEEDED" : @"FAILED"));
		
		return success;
	}

	- (void) taskComplete: (NSData *) data
		httpResponse: (NSURLResponse *) response
		responseError: (NSError *) error
	{
		NSString *taskTypeString= [self getTypeString];
		
		if (nil == error)
		{
			if ([response isKindOfClass:[NSHTTPURLResponse class]])
			{
				NSInteger statusCode= [(NSHTTPURLResponse *)response statusCode];

				NSLog(@"Meretz: %@ returned HTTP status code: %ld", taskTypeString, (long)statusCode);
				// NOTE: Meretz APIs will try to return result data even for failure status codes
			}
			
			// try to retrieve JSON results
			NSError *jsonDeserializeError= nil;
			NSDictionary *jsonDict= (nil != data) ? [NSJSONSerialization JSONObjectWithData:data options:(NSJSONReadingOptions)0 error:&jsonDeserializeError] : nil;
			
			if (nil != jsonDeserializeError)
			{
				NSLog(@"Meretz: %@ error deserializing JSON response: %@", taskTypeString, jsonDeserializeError);
			}
			else if (nil != jsonDict)
			{
				NSLog(@"Meretz: %@ returned JSON: %@", taskTypeString, jsonDict);
				self.TaskOutput= [jsonDict copy];
			}
			else
			{
				NSLog(@"Meretz: %@ JSON response was empty", taskTypeString);
			}
		}
		else
		{
			NSLog(@"Meretz: %@ experienced an error: %@", taskTypeString, error);
		}
		
		self.TaskStatus= MeretzTaskStatusComplete;
		[self setSession:nil];
		[self setSessionDataTask:nil];
		
		NSLog(@"Meretz: %@ complete", taskTypeString);
		
		return;
	}

	- (BOOL) beginWorkVendorUserConnect
	{
		NSAssert(0 < [[self.TaskInput objectForKey:TASK_INPUT_KEY_VENDOR_USER_CONNECTION_CODE] length],
			@"VendorUserConnect requires a valid user connection code!");
		NSAssert(0 < [[self.TaskInput objectForKey:TASK_INPUT_KEY_VENDOR_USER_VENDOR_TOKEN] length],
			@"VendorUserConnect requires a valid user identification token!");
		NSDictionary *headers= @{
			HTTP_HEADER_KVP_ACCEPT_JSON,
			HTTP_HEADER_KVP_CONTENT_TYPE_JSON,
			HTTP_HEADER_KVP_AJAX_REQUEST
		};
		NSString *url= [self buildEndpointURL:MERETZ_API_ENDPOINT_VENDOR_CONNECT_USER];
		BOOL success= [self launchSessionTask: url
			customHeaders: headers
			httpMethod: HTTPMethodPOST
			apiData: self.TaskInput
			completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error)
			{
				[self taskComplete:data httpResponse:response responseError:error];
			}];
		
		return success;
	}

	- (BOOL) beginWorkVendorUserDisconnect
	{
		NSString *userAccessToken= [self.MeretzInstance getMeretzUserAccessToken];
		BOOL success= FALSE;
		
		if (0 < [userAccessToken length])
		{
			NSDictionary *headers= @{
				HTTP_HEADER_KVP_ACCEPT_JSON,
				HTTP_HEADER_KVP_CONTENT_TYPE_JSON,
				HTTP_HEADER_KVP_AJAX_REQUEST,
				HTTP_HEADER_KEY_MERETZ_ACCESS : userAccessToken
			};
			NSString *url= [self buildEndpointURL:MERETZ_API_ENDPOINT_VENDOR_DISCONNECT_USER];
			
			success= [self launchSessionTask: url
				customHeaders: headers
				httpMethod: HTTPMethodPOST
				apiData: self.TaskInput
				completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error)
				{
					[self taskComplete:data httpResponse:response responseError:error];
				}];
		}
		else
		{
			NSLog(@"Meretz: unable to initiate VendorUserDisconnect - no user access token has been set!");
		}
		
		return success;
	}

	- (BOOL) beginWorkVendorConsume
	{
		NSString *userAccessToken= [self.MeretzInstance getMeretzUserAccessToken];
		BOOL success= FALSE;
		
		if (0 < [userAccessToken length])
		{
			NSDictionary *headers= @{
				HTTP_HEADER_KVP_ACCEPT_JSON,
				HTTP_HEADER_KVP_CONTENT_TYPE_JSON,
				HTTP_HEADER_KVP_AJAX_REQUEST,
				HTTP_HEADER_KEY_MERETZ_ACCESS : userAccessToken
			};
			NSString *url= [self buildEndpointURL:MERETZ_API_ENDPOINT_VENDOR_CONSUME];
			
			success= [self launchSessionTask: url
				customHeaders: headers
				httpMethod: HTTPMethodPOST
				apiData: self.TaskInput
				completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error)
				{
					[self taskComplete:data httpResponse:response responseError:error];
				}];
		}
		else
		{
			NSLog(@"Meretz: unable to initiate VendorConsume - no user access token has been set!");
		}
		
		return success;
	}

	- (BOOL) beginWorkVendorUsePoints
	{
		NSString *userAccessToken= [self.MeretzInstance getMeretzUserAccessToken];
		BOOL success= FALSE;
		
		if (0 < [userAccessToken length])
		{
			NSDictionary *headers= @{
				HTTP_HEADER_KVP_ACCEPT_JSON,
				HTTP_HEADER_KVP_CONTENT_TYPE_JSON,
				HTTP_HEADER_KVP_AJAX_REQUEST,
				HTTP_HEADER_KEY_MERETZ_ACCESS : userAccessToken
			};
			NSString *url= [self buildEndpointURL:MERETZ_API_ENDPOINT_VENDOR_USE_POINTS];
			
			success= [self launchSessionTask: url
				customHeaders: headers
				httpMethod: HTTPMethodPOST
				apiData: self.TaskInput
				completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error)
				{
					[self taskComplete:data httpResponse:response responseError:error];
				}];
		}
		else
		{
			NSLog(@"Meretz: unable to initiate VendorUsePoints - no user access token has been set!");
		}
		
		return success;
	}

	- (BOOL) beginWorkVendorUserProfile
	{
		NSString *userAccessToken= [self.MeretzInstance getMeretzUserAccessToken];
		BOOL success= FALSE;
		
		if (0 < [userAccessToken length])
		{
			NSDictionary *headers= @{
				HTTP_HEADER_KVP_ACCEPT_JSON,
				HTTP_HEADER_KVP_CONTENT_TYPE_JSON,
				HTTP_HEADER_KVP_AJAX_REQUEST,
				HTTP_HEADER_KEY_MERETZ_ACCESS : userAccessToken
			};
			NSString *url= [self buildEndpointURL:MERETZ_API_ENDPOINT_VENDOR_USER_PROFILE];
			
			success= [self launchSessionTask: url
				customHeaders: headers
				httpMethod: HTTPMethodPOST
				apiData: self.TaskInput
				completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error)
				{
					[self taskComplete:data httpResponse:response responseError:error];
				}];
		}
		else
		{
			NSLog(@"Meretz: unable to initiate VendorUserProfile - no user access token has been set!");
		}
		
		return success;
	}

	- (NSString *) iso8601DateTimeString: (NSDate *) date
	{
		NSDateFormatter *dateFormatter= [[NSDateFormatter alloc] init];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
		NSString *iso8601String= [dateFormatter stringFromDate:date];
		
		return iso8601String;
	}

@end

/* ---------- functions */

NSString *HTTPMethodToString(
	HTTPMethod method)
{
	NSString *result;
	
	switch (method)
	{
		case HTTPMethodGET: result= @"GET"; break;
		case HTTPMethodHEAD: result= @"HEAD"; break;
		case HTTPMethodPOST: result= @"POST"; break;
		case HTTPMethodPUT: result= @"PUT"; break;
		case HTTPMethodDELETE: result= @"DELETE"; break;
		case HTTPMethodTRACE: result= @"TRACE"; break;
		case HTTPMethodOPTIONS: result= @"OPTIONS"; break;
		case HTTPMethodCONNECT: result= @"CONNECT"; break;
		case HTTPMethodPATCH: result= @"PATCH"; break;
		default:
			NSLog(@"Meretz: unknown HTTP method '%ld'!", (long)method);
			result= nil;
			break;
	}
	
	return result;
}
