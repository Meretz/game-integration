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
	GET,
	HEAD,
	POST,
	PUT,
	DELETE,
	TRACE,
	OPTIONS,
	CONNECT,
	PATCH,
};

/* ---------- macros */

#define STRINGIFY(x)						(@#x)

/* ---------- globals */

extern Meretz *gMeretzSingleton;

/* ---------- interfaces */

// MeretzTask internals (stored in a dictionary)
@interface MeretzTask : NSObject
	- (instancetype)initVendorUserConnect: (NSString *) userConnectionCode vendorUserToken: (NSString *) vendorTokenForUser;
	- (instancetype)initVendorUserDisconnect;
	- (instancetype)initVendorConsume: (NSDate *) startDate optional: (NSDate *) endDate;
	- (instancetype)initVendorUsePoints: (NSInteger) pointQuantity;
	- (instancetype)initVendorUserProfile;

	- (BOOL) beginWork;

	- (MeretzTaskType) getTaskType;
	- (MeretzTaskStatus) getTaskStatus;
	- (void) setTaskStatus: (MeretzTaskStatus) status;
	- (MeretzResult *) getResult;

	- (MeretzVendorUserConnectResult *) getVendorUserConnectResult;
	- (MeretzResult *) getVendorUserDisconnectResult;
	- (MeretzVendorConsumeResult *) getVendorConsumeResult;
	- (MeretzResult *) getVendorUserPointsResult;
	- (MeretzVendorUserProfileResult *) getVendorUserProfileResult;
@end

/* ---------- functions */

NSString *HTTPMethodToString(HTTPMethod method);

#endif //__MERETZ_INTERNAL_H__
