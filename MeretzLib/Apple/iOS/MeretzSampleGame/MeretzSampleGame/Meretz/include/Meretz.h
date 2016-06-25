#ifndef __MERETZ_H__
#define __MERETZ_H__
/*
Meretz.h
Thursday May 26, 2016 11:11am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

Typical usage:

* Vendor registers with Meretz, obtains secret vendor token (one time only, per application if needed)
* Vendor application initializes Meretz API w/ initWithTokens (optionally using a stored user access token)
* Vendor runs asynchronous tasks against the Meretz API using the returned Meretz object
  - tasks created using appropriate Meretz API, returns a taskId
  - vendor code querries task periodically using taskId until it signals as complete
  - once complete, vendor code can retrieve results object using approriate API and the taskId
  - when finished with the task, call releaseTask

Other notes:

* library uses Objective-C ARC

*/

/* ---------- frameworks */

#import <Foundation/Foundation.h>

/* ---------- types */

typedef NSUInteger MeretzTaskId;

/* ---------- constants */

// Meretz version
// [major][minor]
// 0x0000  0x0001
#define MERETZ_VERSION									0x00000001

typedef NS_ENUM(NSInteger, MeretzTaskStatus)
{
	MeretzTaskStatusInvalid = -1, // the queried task is invalid
	MeretzTaskStatusInProgress, // the queried task is in progress
	MeretzTaskStatusComplete // the queried task has completed and results can be gathered
};

#define MERETZ_TASK_ID_INVALID							((unsigned)-1)

/* ---------- interfaces */

// Meretz Item-related constructs

// Meretz ItemDefinition object
@interface MeretzItemDefinition : NSObject
	@property (nonatomic, retain) NSString *PublicId;
	@property (nonatomic, retain) NSString *Name;
	@property (nonatomic, retain) NSString *Description;
@end

// Meretz Item object
@interface MeretzItem : NSObject
	@property (nonatomic, retain) NSString *PublicId;
	@property (nonatomic, retain) MeretzItemDefinition *ItemDefinition;
	@property (nonatomic, retain) NSNumber *Price;
	@property (nonatomic, retain) NSString *Code;
	@property (nonatomic, retain) NSDate *ConsumedTime;
@end

// Meretz API call results

@interface MeretzResult : NSObject
	// will be a BOOL, indicates successful execution of the requested operation
	@property (nonatomic, retain) NSNumber* Success;
	// MeretzAPIResult code
	@property (nonatomic, retain) NSString* ErrorCode;
	// human-readable error details
	@property (nonatomic, retain) NSString* ErrorMessage;
@end

@interface MeretzVendorUserConnectResult : MeretzResult
	// access-token GUID as a string
	@property (nonatomic, retain) NSString* AccessToken;
@end

@interface MeretzVendorConsumeResult : MeretzResult
	// array of MeretzItem objects consumed
	@property (nonatomic, retain) NSArray* Items;
@end

/* $FUTURE
@interface MeretzVendorUserProfileResult : MeretzResult
	// # of points user can spend currently, will be an integer
	@property (nonatomic, retain) NSNumber* UsablePoints;
	// total # of points the user has, will be an integer >= usablePoints
	@property (nonatomic, retain) NSNumber* TotalPoints;
@end
*/

/* ---------- delegate protocol */

@protocol MeretzDelegate<NSObject>
@required
	// called when a user connection with the Meretz back-end completes
	// if successful (result.Success==TRUE), result.AccessToken should be saved and used for all future API calls
	- (void) didVendorUserConnectFinish:(MeretzVendorUserConnectResult *)result;
	// called when a user disconnection from the Meretz back-end completes
	// if successful (result.Success==TRUE), the user is no longer connected with the Meretz backend and
	// any saved access token is now invalid.
	- (void) didVendorUserDisconnectFinish:(MeretzResult *)result;
	// called when a vendorConsumeWithinRange task finishes
	// if successful (result.Success==TRUE), result.Items contains all owned items within specified date range.
	- (void) didVendorConsumeWithinRangeFinish:(MeretzVendorConsumeResult *)result;
	// called when a vendorConsumeGetNew task finishes
	// if successful (result.Success==TRUE), result.Items contains any newly acquired (un-consumed) items.
	-(void) didVendorConsumeGetNewFinish:(MeretzVendorConsumeResult *)result;
	// called when a vendorConsumeAcknowledge task finishes
	// if successful (result.Success==TRUE), result.Items contains the acknowledged (consumed) items.
	-(void) didVendorConsumeAcknowledgeFinish:(MeretzVendorConsumeResult *)result;
@end

// Meretz API interface

@interface Meretz : NSObject

	// call this to initialize Meretz for your organization's application
	- (instancetype) init: (NSString *) savedAccessToken optionalDelegate: (id<MeretzDelegate>) aDelegate;

	// set a delegate object
	- (void)setMeretzDelegate:(id<MeretzDelegate>) newDelegate;

	// use these to configure destination server settings as needed (intended for development use only)
	// defaults are: https://www,meretz.com/api , where:
	// protocol= "https"
	// hostName= "www.meretz.com"
	// port= 443 (default for https)
	// apiPath= "/api"

	- (void) setMeretzHostName: (NSString *) hostName;
	- (void) setMeretzPort: (unsigned short) port;
	- (void) setMeretzProtocol: (NSString *) protocol;
	- (void) setMeretzAPIPath: (NSString *) apiPath;

	- (NSString *) getMeretzServerString;

	// accessors for vendor/user- specific access token
	- (NSString *) getMeretzUserAccessToken;
	- (void) setMeretzUserAccessToken: (NSString *) accessToken;

	#pragma mark high-level API, must be used with delegate

	// User connection (link a game user to a Meretz user)
	// userConnectionCode: code string which must be generated by the end
	//   user themselves via the Meretz.com website for your registered application
	// vendorUserIdentifier: vendor-supplied identification string identifying the user in vendor's namespace
	-(BOOL) startVendorUserConnect: (NSString *) userConnectionCode vendorUserToken: (NSString *) vendorUserIdentifier;

	// User disconnection (for the current user as indicated via the active AccessToken)
	- (BOOL) startVendorUserDisconnect;

	// Retrieve and acknowledge all items recently acquired with Meretz points
	// When used, your delegate responder for didVendorConsumeAcknowledgeFinish is expected to do any work related to the returned MeretzItem list;
	// the delegate responders for didVendorConsumeWithinRangeFinish and didVendorConsumeGetNewFinish can be empty (neither will be called as a result of this method).
	-(BOOL) startVendorConsumeNewItems;

	#pragma mark low-level task management, can be used with / without delegate

	// query the status of a Meretz asynchronous task
	- (MeretzTaskStatus) getTaskStatus: (MeretzTaskId) taskId;

	// call when finished with a task, to release its resources
	- (void) releaseTask: (MeretzTaskId) taskId;

	// User connection (link a game user to a Meretz user)
	// userConnectionCode: code string which must be generated by the end
	//   user themselves via the Meretz.com website for your registered application
	// vendorUserIdentifier: vendor-supplied identification string identifying the user in vendor's namespace
	- (MeretzTaskId) vendorUserConnect: (NSString *) userConnectionCode vendorUserToken: (NSString *) vendorUserIdentifier;
	- (MeretzVendorUserConnectResult *) getVendorUserConnectResult: (MeretzTaskId) vendorUserConnectTask;

	// User disconnection (for the current user as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserDisconnect;
	- (MeretzResult *) getVendorUserDisconnectResult: (MeretzTaskId) vendorUserDisconnectTask;

	// Item consumption over a date range
	// startDate: date to use for start of the search
	// endDate: date to use for the end of the search (if nil, current day is assumed)
	// marks all newly purchased items for the vendor/user/date-range as 'consumed',
	// and returns all vendor/user items within that date range
	- (MeretzTaskId) vendorConsumeWithinRange: (NSDate *) startDate optional: (NSDate *) endDate;
	// Retrieve a list of newly acquired items (read-only)
	- (MeretzTaskId) vendorConsumeGetNew;
	// Acknowledge "consumption" of newly acquired items returned from a vendorConsumeGetNew call
	// input is an array of NSString objects set to the PublicId values of the MeretzItem objects being acknowledged
	- (MeretzTaskId) vendorConsumeAcknowledge: (NSArray *) meretzItemPublicIdArray;
	// Retrieve a list of newly acquired items (acknowledging them at the same time)
	- (MeretzTaskId) vendorConsumeGetNewAndAcknowledge;
	// obtain results from any of the vendorConsumeXYZ methods
	- (MeretzVendorConsumeResult *) getVendorConsumeResult: (MeretzTaskId) vendorConsumeTask;

	/* $FUTURE not currently exposed on the back end
	// Spending points on behalf of the current user (as indicated via the active AccessToken)
	// pointQuantity: number of the current user's points to spend on their behalf
	- (MeretzTaskId) vendorUsePoints: (NSInteger) pointQuantity;
	- (MeretzResult *) getVendorUsePointsResult: (MeretzTaskId) vendorUsePointsTask;

	// Retrieving Meretz user information for the current user (as indicated via the active AccessToken)
	- (MeretzTaskId) vendorUserProfile;
	- (MeretzVendorUserProfileResult *) getVendorUserProfileResult: (MeretzTaskId) vendorUserProfileTask;
	*/

@end

#endif // __MERETZ_H__
