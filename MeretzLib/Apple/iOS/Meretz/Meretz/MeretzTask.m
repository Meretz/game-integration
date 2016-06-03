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

#define TASK_INPUT_KEY_VENDOR_CONSUME_START_DATE			@"VENDOR_CONSUME_START_DATE"
#define TASK_INPUT_KEY_VENDOR_CONSUME_END_DATE				@"VENDOR_CONSUME_END_DATE"

#define TASK_INPUT_KEY_VENDOR_USE_POINT_QUANTITY			@"VENDOR_USE_POINTS_QUANTITY"

/* ---------- internal interface */

@interface MeretzTask()

	- (NSString *) getTypeString;

	// endpoint: e.g. "/vendor/connect_user"
	- (NSString *) buildEndpointURL: (NSString *) endpoint;

	- (BOOL) launchSessionTask:(NSString *)url
		customHeaders: (NSDictionary *) headers
		httpMethod: (HTTPMethod) method
		apiData: (NSDictionary *) data
		completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

	- (BOOL) beginWorkVendorUserConnect;
	- (BOOL) beginWorkVendorUserDisconnect;
	- (BOOL) beginWorkVendorConsume;
	- (BOOL) beginWorkVendorUsePoints;
	- (BOOL) beginWorkVendorUserProfile;

@end

/* ---------- implementation */

@implementation MeretzTask


	/* ---------- private members */
	{
		MeretzTaskStatus m_status;
		MeretzTaskType m_type;
		
		NSURLSession *m_NSURLSession;
		NSURLSessionDataTask *m_NSURLSessionDataTask;
		NSMutableDictionary *m_inputs;

		MeretzVendorUserConnectResult *m_vendorUserConnectResult;
		MeretzResult *m_vendorUserDisconnectResult;
		MeretzVendorConsumeResult *m_vendorConsumeResult;
		MeretzResult *m_vendorUsePointsResult;
		MeretzVendorUserProfileResult *m_vendorUserProfileResult;
	}

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
			m_status= MeretzTaskStatusInvalid;
			m_type= MeretzTaskTypeInvalid;
			
			m_NSURLSession= nil;
			m_NSURLSessionDataTask= nil;
			
			m_inputs= [NSMutableDictionary dictionary];
			
			m_vendorUserConnectResult= nil;
			m_vendorUserDisconnectResult= nil;
			m_vendorConsumeResult= nil;
			m_vendorUsePointsResult= nil;
			m_vendorUserProfileResult= nil;
			
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
			m_vendorUserConnectResult= [[MeretzVendorUserConnectResult alloc] init];
			if (nil != m_vendorUserConnectResult)
			{
				m_type= MeretzTaskTypeVendorUserConnect;
				m_inputs[TASK_INPUT_KEY_VENDOR_USER_CONNECTION_CODE]= userConnectionCode;
				m_inputs[TASK_INPUT_KEY_VENDOR_USER_VENDOR_TOKEN]= vendorTokenForUser;
			}
		}
		
		return self;
	}
	- (instancetype)initVendorUserDisconnect
	{
		self= [self init];
		if (nil != self)
		{
			m_vendorUserDisconnectResult= [[MeretzResult alloc] init];
			if (nil != m_vendorUserDisconnectResult)
			{
				m_type= MeretzTaskTypeVendorUserDisconnect;
				// no inputs to task
			}
		}
		
		return self;
	}

	- (instancetype)initVendorConsume: (NSDate *) startDate optional: (NSDate *) endDate
	{
		NSAssert(nil != startDate, @"VendorConsume requires a start date!");
		self= [self init];
		if (nil != self)
		{
			m_vendorConsumeResult= [[MeretzVendorConsumeResult alloc] init];
			if (nil != m_vendorConsumeResult)
			{
				m_type= MeretzTaskTypeVendorConsume;
				m_inputs[TASK_INPUT_KEY_VENDOR_CONSUME_START_DATE]= startDate;
				if (nil != endDate)
				{
					m_inputs[TASK_INPUT_KEY_VENDOR_CONSUME_END_DATE]= endDate;
				}
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
			m_vendorUsePointsResult= [[MeretzResult alloc] init];
			if (nil != m_vendorUsePointsResult)
			{
				m_type= MeretzTaskTypeVendorUsePoints;
				m_inputs[TASK_INPUT_KEY_VENDOR_USE_POINT_QUANTITY]= [NSNumber numberWithInteger:pointQuantity];
			}
		}
		
		return self;
	}

	- (instancetype)initVendorUserProfile
	{
		self= [self init];
		if (nil != self)
		{
			m_vendorUserProfileResult= [[MeretzVendorUserProfileResult alloc] init];
			if (nil != m_vendorUserProfileResult)
			{
				m_type= MeretzTaskTypeVendorUserProfile;
				// no inputs to task
			}
		}
		
		return self;
	}

	- (BOOL) beginWork
	{
		BOOL success;
		
		switch (m_type)
		{
			case MeretzTaskTypeVendorUserConnect: success= [self beginWorkVendorUserConnect]; break;
			case MeretzTaskTypeVendorUserDisconnect: success= [self beginWorkVendorUserDisconnect]; break;
			case MeretzTaskTypeVendorConsume: success= [self beginWorkVendorConsume]; break;
			case MeretzTaskTypeVendorUsePoints: success= [self beginWorkVendorUsePoints]; break;
			case MeretzTaskTypeVendorUserProfile: success= [self beginWorkVendorUserProfile]; break;
			default: NSAssert(FALSE, @"unhandled task type '%d'!", m_type); success= FALSE; break;
		}
		
		return success;
	}

	- (MeretzTaskType) getTaskType
	{
		return m_type;
	}

	- (MeretzTaskStatus) getTaskStatus
	{
		return m_status;
	}

	- (void) setTaskStatus: (MeretzTaskStatus) status
	{
		m_status= status;
		
		return;
	}

	- (MeretzResult *) getResult
	{
		if (nil != m_vendorUserConnectResult) return m_vendorUserConnectResult;
		if (nil != m_vendorUserDisconnectResult) return m_vendorUserDisconnectResult;
		if (nil != m_vendorConsumeResult) return m_vendorConsumeResult;
		if (nil != m_vendorUsePointsResult) return m_vendorUsePointsResult;
		if (nil != m_vendorUserProfileResult) return m_vendorUserProfileResult;
		NSAssert(false, @"MeretzTask not properly initialized!");
		return nil;
	}

	- (MeretzVendorUserConnectResult *) getVendorUserConnectResult
	{
		NSAssert(nil != m_vendorUserConnectResult, @"VendorUserConnectResult task not properly initialized!");
		return m_vendorUserConnectResult;
	}

	- (MeretzResult *) getVendorUserDisconnectResult
	{
		NSAssert(nil != m_vendorUserDisconnectResult, @"VendorUserDisconnect task not properly initialized!");
		return m_vendorUserDisconnectResult;
	}

	- (MeretzVendorConsumeResult *) getVendorConsumeResult
	{
		NSAssert(nil != m_vendorConsumeResult, @"VendorUserConsume task not properly initialized!");
		return m_vendorConsumeResult;
	}

	- (MeretzResult *) getVendorUserPointsResult
	{
		NSAssert(nil != m_vendorUsePointsResult, @"VendorUsePoints task not properly initialized!");
		return m_vendorUsePointsResult;
	}

	- (MeretzVendorUserProfileResult *) getVendorUserProfileResult
	{
		NSAssert(nil != m_vendorUserProfileResult, @"VendorUserProfile task not properly initialized!");
		return m_vendorUserProfileResult;
	}

	/* ---------- private methods */

	- (NSString *) getTypeString
	{
		NSString *result;
		
		switch (m_type)
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
		NSAssert(nil != gMeretzSingleton, @"Meretz has not been initialized!");
		NSString *meretzServerURL= [gMeretzSingleton getMeretzServerString];
		NSString *result= [NSString stringWithFormat:@"%@%@", meretzServerURL, endpoint];
		
		return result;
	}

	- (BOOL) launchSessionTask:(NSString *)url
		customHeaders: (NSDictionary *) headers
		httpMethod: (HTTPMethod) method
		apiData: (NSDictionary *) data
		completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
	{
		NSAssert(nil == m_NSURLSession, @"task already has an active NSURLSession object!");
		NSAssert(nil == m_NSURLSessionDataTask, @"task already has an active NSURLSessionDataTask object!");
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
			
			m_NSURLSession= [NSURLSession sessionWithConfiguration:sessionConfiguration];
			
			if (nil != m_NSURLSession)
			{
				NSMutableURLRequest *request= [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
				
				if (nil != request)
				{
					[request setHTTPMethod:HTTPMethodToString(method)];
					
					if ((nil != data) && (0 < [data count]))
					{
						NSError *jsonSerializationError= nil;
						NSData *requestData= [NSJSONSerialization dataWithJSONObject:data options:0 error:&jsonSerializationError];
						
						if (nil != jsonSerializationError)
						{
							NSLog(@"JSON serialization error: %@", jsonSerializationError);
						}
						
						if (nil != requestData)
						{
							[request setValue:[NSString stringWithFormat:@"%d", [requestData length]] forHTTPHeaderField:HTTP_HEADER_KEY_CONTENT_LENGTH];
							[request setHTTPBody:requestData];
						}
						else
						{
							NSLog(@"failed to JSON serialize request data!");
							request= nil;
						}
					}
					
					if (nil != request)
					{
						NSLog(@"launching request to %@; headers= %@, data= %@", url, headers, data);
						m_NSURLSessionDataTask= [m_NSURLSession dataTaskWithRequest:request completionHandler:completionHandler];
						if (nil != m_NSURLSessionDataTask)
						{
							// start it up
							[ m_NSURLSessionDataTask resume];
							success= TRUE;
						}
						else
						{
							NSLog(@"failed to create NSURLSessionTask for task %@", self);
						}
					}
				}
				else
				{
					NSLog(@"failed to create NSMutableURLRequest!");
				}
			}
			else
			{
				NSLog(@"failed to create NSURLSession for task %@", self);
			}
		}
		else
		{
			NSLog(@"failed to create session configuration object!");
		}
		
		NSLog(@"task %@ launch %@", self, (success ? @"SUCCEEDED" : @"FAILED"));
		
		return success;
	}

	- (BOOL) beginWorkVendorUserConnect
	{
		NSAssert(0 < [[m_inputs objectForKey:TASK_INPUT_KEY_VENDOR_USER_CONNECTION_CODE] length],
			@"VendorUserConnect requires a valid user connection code!");
		NSAssert(0 < [[m_inputs objectForKey:TASK_INPUT_KEY_VENDOR_USER_VENDOR_TOKEN] length],
			@"VendorUserConnect requires a valid user identification token!");
		NSDictionary *headers= @{
			HTTP_HEADER_KVP_ACCEPT_JSON,
			HTTP_HEADER_KVP_CONTENT_TYPE_JSON,
			HTTP_HEADER_KVP_AJAX_REQUEST
		};
		NSString *url= [self buildEndpointURL:MERETZ_API_ENDPOINT_VENDOR_CONNECT_USER];
		BOOL success= [self launchSessionTask: url
			customHeaders: headers
			httpMethod: POST
			apiData: m_inputs
			completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error)
			{
				NSDictionary *jsonDict= (nil != data) ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
				NSLog(@"VendorUserConnect returned NSURLResponse: %@, NSError: %@, JSON: %@",
					response, error, jsonDict);
			}];
		
		return success;
	}

	- (BOOL) beginWorkVendorUserDisconnect
	{
		//###stefan $TODO $IMPLEMENT
		BOOL success= FALSE;
		
		return success;
	}

	- (BOOL) beginWorkVendorConsume
	{
		NSDate *startDate= [m_inputs objectForKey:TASK_INPUT_KEY_VENDOR_CONSUME_START_DATE];
		NSDate *endDate= [m_inputs objectForKey:TASK_INPUT_KEY_VENDOR_CONSUME_END_DATE];
		NSAssert(nil != startDate, @"VendorConsume requires a valid start date!");
		//###stefan $TODO $IMPLEMENT
		BOOL success= FALSE;
		
		return success;
	}

	- (BOOL) beginWorkVendorUsePoints
	{
		NSNumber *pointsNumber= [m_inputs objectForKey:TASK_INPUT_KEY_VENDOR_USE_POINT_QUANTITY];
		NSAssert(nil != pointsNumber, @"VendorUsePoints requires a valid point value!");
		NSUInteger pointValue= [pointsNumber unsignedIntegerValue];
		NSAssert(0 < pointValue, @"VendorUsePoints requires a positive point value!");
		//###stefan $TODO $IMPLEMENT
		BOOL success= FALSE;
		
		return success;
	}

	- (BOOL) beginWorkVendorUserProfile
	{
		//###stefan $TODO $IMPLEMENT
		BOOL success= FALSE;
		
		return success;
	}

@end

/* ---------- functions */

NSString *HTTPMethodToString(
	HTTPMethod method)
{
	NSString *result;
	
	switch (method)
	{
		case GET: result= @"GET"; break;
		case HEAD: result= @"HEAD"; break;
		case POST: result= @"POST"; break;
		case PUT: result= @"PUT"; break;
		case DELETE: result= @"DELETE"; break;
		case TRACE: result= @"TRACE"; break;
		case OPTIONS: result= @"OPTIONS"; break;
		case CONNECT: result= @"CONNECT"; break;
		case PATCH: result= @"PATCH"; break;
		default:
			NSLog(@"unknown HTTP method '%d'!", method);
			result= nil;
			break;
	}
	
	return result;
}

