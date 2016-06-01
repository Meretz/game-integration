#ifndef __MERETZ_H__
#define __MERETZ_H__
/*
Meretz.h
Thursday May 26, 2016 11:11am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import <Foundation/Foundation.h>

/* ---------- types */

typedef NSUInteger MeretzTaskId;

/* ---------- constants */

// Meretz version
// [major][minor]
// 0x0000  0x0001
#define MERETZ_VERSION				0x00000001

typedef NS_ENUM(NSInteger, MeretzTaskStatus)
{
	MeretzTaskStatusInvalid = -1, // the queried task is invalid
	MeretzTaskStatusInProgress, // the queried task is in progress
	MeretzTaskStatusComplete // the queried task has completed and results can be gathered
};

extern const MeretzTaskId MERETZ_TASK_ID_INVALID;

/* ---------- interfaces */

// Meretz Item-related constructs

// Meretz ItemDefinition object
@interface MeretzItemDefinition : NSObject
	@property (nonatomic, retain) NSString *publicId;
	@property (nonatomic, retain) NSString *name;
	@property (nonatomic, retain) NSString *description;
@end

// Meretz Item object
@interface MeretzItem : NSObject
	@property (nonatomic, retain) NSString *publicId;
	@property (nonatomic, retain) MeretzItemDefinition *itemDefinition;
	@property (nonatomic, retain) NSNumber *price;
	@property (nonatomic, retain) NSString *code;
	@property (nonatomic, retain) NSDate *consumedTime;
@end

// Meretz API call results

@interface MeretzResult : NSObject
	// will be a BOOL, indicates successful execution of the requested operation
	@property (nonatomic, retain) NSNumber* success;
	// MeretzAPIResult code
	@property (nonatomic, retain) NSString* errorCode;
	// human-readable error details
	@property (nonatomic, retain) NSString* errorMessage;
@end

@interface MeretzVendorUserConnectResult : MeretzResult
	// access-token GUID as a string
	@property (nonatomic, retain) NSString* accessToken;
@end

@interface MeretzVendorConsumeResult : MeretzResult
	// array of MeretzItem objects consumed
	@property (nonatomic, retain) NSArray* items;
@end

@interface MeretzVendorUserProfileResult : MeretzResult
	// # of points user can spend currently, will be an integer
	@property (nonatomic, retain) NSNumber* usablePoints;
	// total # of points the user has, will be an integer >= usablePoints
	@property (nonatomic, retain) NSNumber* totalPoints;
@end

// Meretz API interface

@interface Meretz : NSObject

	// call this to initialize Meretz for your organization's application
	// with your unique vendor access token (as given to you by Meretz)
	// and an optional, previously stored user access token if you have
	// previously connected a game user
	- (instancetype) initWithTokens: (NSString *) vendorSecretToken emptyOrSavedValue: (NSString *) userAccessToken;

	// use these to configure destination server settings as needed (intended for development use only)
	// defaults are: https://www,meretz.com/api , where:
	// protocol= "https"
	// hostName= "www.meretz.com"
	// port= 443 (default for https)
	// apiPath= "/api"

	- (void) setMeretzServerHostName: (NSString *) hostName;
	- (void) setMeretzServerPort: (NSUInteger) port;
	- (void) setMeretzServerProtocol: (NSString *) protocol;
	- (void) setMeretzServerAPIPath: (NSString *) apiPath;

	- (NSString *) getMeretzServerString;

	// accessors for vendor/user- specific access token
	- (NSString *) getUserAccessToken;
	- (void) setUserAccessToken: (NSString *) accessToken;

	// query the status of a Meretz asynchronous task
	- (MeretzTaskStatus) getTaskStatus: (MeretzTaskId) taskId;

	// User connection (link a game user to a Meretz user)
	// userConnectionCode: code string which must be generated by the end
	// user themselves via the Meretz.com website for your registered application
	- (MeretzTaskId) vendorUserConnect: (NSString *) userConnectionCode;
	- (MeretzVendorUserConnectResult *) getVendorUserConnectResult: (MeretzTaskId) vendorUserConnectTask;

	// User disconnection (for the current user as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserDisconnect;
	- (MeretzResult *) getVendorUserDisconnectResult: (MeretzTaskId) vendorUserDisconnectTask;

	// Item consumption over a date range
	// startDate: date to use for start of the search
	// endDate: date to use for the end of the search (if nil, current day is assumed)
	- (MeretzTaskId) vendorConsume: (NSDate *) startDate optional: (NSDate *) endDate;
	- (MeretzVendorConsumeResult *) getVendorConsumeResult: (MeretzTaskId) vendorConsumeTask;

	// Spending points on behalf of the current user (as indicated via the active AccessToken)
	// pointQuantity: number of the current user's points to spend on their behalf
	- (MeretzTaskId) vendorUsePoints: (NSInteger) pointQuantity;
	- (MeretzResult *) getVendorUsePointsResult: (MeretzTaskId) vendorUsePointsTask;

	// Retrieving Meretz user information for the current user (as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserProfile;
	- (MeretzVendorUserProfileResult *) getVendorUserProfileResult: (MeretzTaskId) vendorUserProfileTask;

@end

#endif // __MERETZ_H__
