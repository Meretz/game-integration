#ifndef __MERETZ_INTERNAL_H__
#define __MERETZ_INTERNAL_H__
/*
Meretz_Internal.h
Thursday May 26, 2016 11:11am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import <Foundation/Foundation.h>

#import "Meretz.h"

/* ---------- constants */

typedef NS_ENUM(NSInteger, MeretzTaskType)
{
	MeretzTaskTypeInvalid = -1,
	MeretzTaskTypeVendorUserConnect,
	MeretzTaskTypeVendorUserDisconnect,
	MeretzTaskTypeVendorConsume,
	MeretzTaskTypeVendorUsePoints,
	MeretzTaskTypeVendorUserProfile,
};

typedef NS_ENUM(NSInteger, HTTPMethod)
{
	HTTPMethodGET,
	HTTPMethodHEAD,
	HTTPMethodPOST,
	HTTPMethodPUT,
	HTTPMethodDELETE,
	HTTPMethodTRACE,
	HTTPMethodOPTIONS,
	HTTPMethodCONNECT,
	HTTPMethodPATCH,
};

typedef NS_ENUM(NSInteger, HTTPStatus)
{
	// 1xx Informational
    HTTPStatusContinue= 100,
    HTTPStatusSwitchingProtocols= 101,
    HTTPStatusProcessing= 102,
    HTTPStatusCheckpoint= 103,
    
    // 2xx Success
    HTTPStatusOK= 200,
    HTTPStatusCreated= 201,
    HTTPStatusAccepted = 202,
    HTTPStatusNonAuthoritativeInformation= 203,
    HTTPStatusNoContent= 204,
    HTTPStatusResetContent= 205,
    HTTPStatusPartialContent= 206,
    HTTPStatusMultiStatus= 207,
    HTTPStatusAlreadyReported= 208,
    HTTPStatusIMUsed= 226,
    
    // 3xx Redirection
    HTTPStatusMultipleChoices= 300,
    HTTPStatusMovedPermanently= 301,
    HTTPStatusFound= 302,
    HTTPStatusSeeOther= 303,
    HTTPStatusNotModified= 304,
    HTTPStatusUseProxy= 305,
    HTTPStatusSwitchProxy= 306,
    HTTPStatusTemporaryRedirect= 307,
    HTTPStatusPermanentRedirect= 308,
    
    // 4xx Client Error
    HTTPStatusBadRequest= 400,
    HTTPStatusUnauthorized= 401,
    HTTPStatusPaymentRequired= 402,
    HTTPStatusForbidden= 403,
    HTTPStatusNotFound= 404,
    HTTPStatusMethodNotAllowed= 405,
    HTTPStatusNotAcceptable= 406,
    HTTPStatusProxyAuthenticationRequired= 407,
    HTTPStatusRequestTimeout= 408,
    HTTPStatusConflict= 409,
    HTTPStatusGone= 410,
    HTTPStatusLengthRequired= 411,
    HTTPStatusPreconditionFailed= 412,
    HTTPStatusPayloadTooLarge= 413,
    HTTPStatusRequestURITooLong= 414,
    HTTPStatusUnsupportedMediaType= 415,
    HTTPStatusRequestRangeNotSatisfiable= 416,
    HTTPStatusExpectationFailed= 417,
    HTTPStatusImaTeapot= 418, // yes, this is a thing.
    HTTPStatusAuthenticationTimeout= 419,
    HTTPStatusMisdirectedRequest= 421,
    HTTPStatusUnprocessableEntity= 422,
    HTTPStatusLocked= 423,
    HTTPStatusFailedDependency= 424,
    HTTPStatusUpgradeRequired= 426,
    HTTPStatusPreconditionRequired= 428,
    HTTPStatusTooManyRequests= 429,
    HTTPStatusRequestHeaderFieldsTooLarge= 431,
    HTTPStatusUnavailableForLegalReasons= 451,
    
    // 5xx Server Error
    HTTPStatusInternalServerError= 500,
    HTTPStatusNotImplemented= 501,
    HTTPStatusBadGateway= 502,
    HTTPStatusServiceUnavailable= 503,
    HTTPStatusGatewayTimeout= 504,
    HTTPStatusHTTPVersionNotSupported= 505,
    HTTPStatusVariantAlsoNegotiates= 506,
    HTTPStatusInsufficientStorage= 507,
    HTTPStatusLoopDetected= 508,
    HTTPStatusNotExtended= 510,
    HTTPStatusNetworkAuthenticationRequired= 511
};

// Meretz task output keys

#define TASK_OUTPUT_KEY_SUCCESS									@"success"
#define TASK_OUTPUT_KEY_ERROR_CODE								@"error_code"
#define TASK_OUTPUT_KEY_ERROR_MESSAGE							@"error_message"

// /vendor/connect_user
#define TASK_OUTPUT_KEY_VENDOR_CONNECT_USER_ACCESS_TOKEN		@"access_token"

// /vendor/consume
#define TASK_OUTPUT_KEY_VENDOR_CONSUME_ITEMS					@"items"

// /vendor/user_profile
#define TASK_OUTPUT_KEY_VENDOR_USER_PROFILE_USABLE_POINTS		@"usable_meretz_points"
#define TASK_OUTPUT_KEY_VENDOR_USER_PROFILE_TOTAL_POINTS		@"total_meretz_points"

/* ---------- macros */

#define STRINGIFY(x)						(@#x)

/* ---------- interfaces */

// MeretzTask internals (stored in a dictionary)
@interface MeretzTask : NSObject

	@property Meretz *MeretzInstance;
	@property MeretzTaskStatus TaskStatus;
	@property MeretzTaskType TaskType;
		
	@property NSURLSession *Session;
	@property NSURLSessionDataTask *SessionDataTask;
	@property NSMutableDictionary *TaskInput;
	@property NSMutableDictionary *TaskOutput;

	- (instancetype)initVendorUserConnect: (NSString *) userConnectionCode vendorUserToken: (NSString *) vendorTokenForUser;
	- (instancetype)initVendorUserDisconnect;
	- (instancetype)initVendorConsume: (NSDate *) startDate optional: (NSDate *) endDate;
	- (instancetype)initVendorUsePoints: (NSInteger) pointQuantity;
	- (instancetype)initVendorUserProfile;

	- (BOOL) beginWork;

	- (NSDictionary *) getResult;
@end

/* ---------- functions */

NSString *HTTPMethodToString(HTTPMethod method);

#endif //__MERETZ_INTERNAL_H__
