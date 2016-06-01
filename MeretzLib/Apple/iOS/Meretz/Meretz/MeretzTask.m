/*
MeretzTask.m
Tuesday May 31, 2016 11:49am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import "Meretz+Internal.h"

#import <Foundation/Foundation.h>

/* ---------- constants */

#define TASK_INPUT_USER_CONNECTION_CODE				@"USER_CONNECTION_CODE"

#define TASK_INPUT_VENDOR_CONSUME_START_DATE		@"VENDOR_CONSUME_START_DATE"
#define TASK_INPUT_VENDOR_CONSUME_END_DATE			@"VENDOR_CONSUME_END_DATE"

#define TASK_INPUT_VENDOR_USE_POINT_QUANTITY		@"VENDOR_USE_POINTS_QUANTITY"

/* ---------- internal interface */

@interface MeretzTask()

	- (NSString *) getTypeString;

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

	- (instancetype)initVendorUserConnect: (NSString *) userConnectionCode
	{
		NSAssert(nil != userConnectionCode, @"VendorUserConnect requires a user connection code!");
		self= [self init];
		if (nil != self)
		{
			m_vendorUserConnectResult= [[MeretzVendorUserConnectResult alloc] init];
			if (nil != m_vendorUserConnectResult)
			{
				m_type= MeretzTaskTypeVendorUserConnect;
				m_inputs[TASK_INPUT_USER_CONNECTION_CODE]= userConnectionCode;
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
				m_inputs[TASK_INPUT_VENDOR_CONSUME_START_DATE]= startDate;
				if (nil != endDate)
				{
					m_inputs[TASK_INPUT_VENDOR_CONSUME_END_DATE]= endDate;
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
				m_inputs[TASK_INPUT_VENDOR_USE_POINT_QUANTITY]= [NSNumber numberWithInteger:pointQuantity];
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

	- (BOOL) beginWorkVendorUserConnect
	{
		//###stefan $TODO $IMPLEMENT
		NSString *userConnectionCode= [m_inputs objectForKey:TASK_INPUT_USER_CONNECTION_CODE];
		NSAssert(0 < [userConnectionCode length], @"VendorUserConnect requires a valid user connection code!");
		BOOL success= TRUE;
		
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
		NSDate *startDate= [m_inputs objectForKey:TASK_INPUT_VENDOR_CONSUME_START_DATE];
		NSDate *endDate= [m_inputs objectForKey:TASK_INPUT_VENDOR_CONSUME_END_DATE];
		NSAssert(nil != startDate, @"VendorConsume requires a valid start date!");
		//###stefan $TODO $IMPLEMENT
		BOOL success= FALSE;
		
		return success;
	}

	- (BOOL) beginWorkVendorUsePoints
	{
		NSNumber *pointsNumber= [m_inputs objectForKey:TASK_INPUT_VENDOR_USE_POINT_QUANTITY];
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
