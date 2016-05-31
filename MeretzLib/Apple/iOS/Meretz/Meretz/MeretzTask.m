/*
MeretzTask.m
Tuesday May 31, 2016 11:49am Stefan S.
Copyright (c) 2016 by E-Squared Labs - All rights reserved

*/

/* ---------- frameworks */

#import "Meretz+Internal.h"

#import <Foundation/Foundation.h>

/* ---------- internal interface */

@interface MeretzTask()

	- (BOOL) beginWorkVendorUserConnect;

@end

/* ---------- implementation */

@implementation MeretzTask


	/* ---------- private members */
	{
		MeretzTaskStatus m_status;
		MeretzTaskType m_type;

		MeretzVendorUserConnectResult *m_vendorUserConnectResult;
		MeretzVendorUserDisconnectResult *m_vendorUserDisconnectResult;
		MeretzVendorConsumeResult *m_vendorConsumeResult;
		MeretzVendorUsePointsResult *m_vendorUsePointsResult;
		MeretzVendorUserProfileResult *m_vendorUserProfileResult;
	}

	/* ---------- public methods */

	- (NSString *)description
	{
		return [NSString stringWithFormat: @"MeretzTask: Type= %d", m_type];
	}

	-(instancetype) init
	{
		self= [super init];
		if (nil != self)
		{
			m_status= MeretzTaskStatusInvalid;
			m_type= MeretzTaskTypeInvalid;
			
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
		self= [self init];
		if (nil != self)
		{
			m_vendorUserConnectResult= [[MeretzVendorUserConnectResult alloc] init];
			if (nil != m_vendorUserConnectResult)
			{
				m_type= MeretzTaskTypeVendorUserConnect;
			}
		}
		
		return self;
	}
	- (instancetype)initVendorUserDisconnect
	{
		self= [self init];
		if (nil != self)
		{
			m_vendorUserDisconnectResult= [[MeretzVendorUserDisconnectResult alloc] init];
			if (nil != m_vendorUserDisconnectResult)
			{
				m_type= MeretzTaskTypeVendorUserDisconnect;
			}
		}
		
		return self;
	}

	- (instancetype)initVendorConsume: (NSDate *) startDate optional: (NSDate *) endDate
	{
		self= [self init];
		if (nil != self)
		{
			m_vendorConsumeResult= [[MeretzVendorConsumeResult alloc] init];
			if (nil != m_vendorConsumeResult)
			{
				m_type= MeretzTaskTypeVendorConsume;
			}
		}
		
		return self;
	}

	- (instancetype)initVendorUsePoints: (NSInteger) pointQuantity
	{
		self= [self init];
		if (nil != self)
		{
			m_vendorUsePointsResult= [[MeretzVendorUsePointsResult alloc] init];
			if (nil != m_vendorUsePointsResult)
			{
				m_type= MeretzTaskTypeVendorUsePoints;
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
			}
		}
		
		return self;
	}

	- (BOOL) beginWork
	{
		//###stefan $TODO $IMPLEMENT
		return FALSE;
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

	- (MeretzVendorUserDisconnectResult *) getVendorUserDisconnectResult
	{
		NSAssert(nil != m_vendorUserDisconnectResult, @"VendorUserDisconnect task not properly initialized!");
		return m_vendorUserDisconnectResult;
	}

	- (MeretzVendorConsumeResult *) getVendorConsumeResult
	{
		NSAssert(nil != m_vendorConsumeResult, @"VendorUserConsume task not properly initialized!");
		return m_vendorConsumeResult;
	}

	- (MeretzVendorUsePointsResult *) getVendorUserPointsResult
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

	- (BOOL) beginWorkVendorUserConnect
	{
		//###stefan $TODO $IMPLEMENT
		return FALSE;
	}

@end
