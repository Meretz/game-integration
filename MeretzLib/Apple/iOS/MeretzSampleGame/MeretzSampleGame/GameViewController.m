//
//  GameViewController.m
//  MeretzSampleGame
//
//  Created by Stefan Sinclair on 5/31/16.
//  Copyright (c) 2016 E-Squared Labs - All rights reserved.
//

#import "GameViewController.h"

/*

Sample game usage instructions:

1) Work with the Meretz team to get your product(s) setup with a product page on the Meretz.com site.

2) Create or acquire a test Meretz.com account for testing.

3) Purchase an item(s) with your test account (from step 2) via your product page on the Meretz.com site:
	(use the URL parameters "force_show=1" and "override_comingsoon=1" as needed)
	e.g.: https://www.meretz.com/rewards/YOUR_PRODUCT_HERE?force_show=1&override_comingsoon=1
	This will ensure you have one or more product items consumed for reporting back in the sample game here below.

4) While still on your product page on the Meretz.com site, generate a "user connection code" for your test account (from step 2).

5) Now build and run this sample game.
	a) Click in the "Connection Code" text field to enter your connection code from step 4 (watch the console for output).
	   NOTE: assuming connection is successful, a VendorConnect operation will be initiated for your test account (watch the console for output).
 	   NOTE: the sample game will also save the Meretz access-key for your user if the VendorConnect operation was successful.
	   Any saved Meretz access-key will be used automatically on future program runs. Your application should follow a similar pattern.
	b) Click the "Consume Items" button to manually check for new items purchased with Meretz points (watch the console for output).
	d) Click the "Disconnect" button to initiate a VendorDisconnect task for your test account (watch the console for output).
		NOTE: assuming this completes successfully, your user's account is now no longer linked with the Meretz back-end,
		ie. the stored access-key is now invalid.
	e) That's it for current demo functionality :)
*/

#define MERETZ_USER_ACCESS_TOKEN_NSUSERDEFAULTS_KEY			@"MeretzUserAccessToken"
#define SAMPLE_GAME_USER_IDENTIFIER							@"MeretzSampleGameUser"

// toggle this value to test delegate responders vs. manual low-level task management
static BOOL USE_MERETZ_DELEGATE= TRUE;

typedef NS_ENUM(NSInteger, MeretzSampleGameState)
{
	Initial,
	Connecting,
	Consuming,
	Disconnecting,
	Idle
};

/* ---------- internal interface */

@interface GameViewController()

	@property (nonatomic, retain) Meretz *MeretzAPI;
	@property (nonatomic, assign) MeretzSampleGameState SampleGameState;
	@property (nonatomic, assign) MeretzTaskId VendorConnectUserTaskId;
	@property (nonatomic, assign) MeretzTaskId VendorConsumeTaskId;
	@property (nonatomic, assign) MeretzTaskId VendorDisconnectUserTaskId;

	@property (nonatomic, retain) UITextField *ConnectionCodeTextField;
	@property (nonatomic, retain) UIButton *ConsumeButton;
	@property (nonatomic, retain) UIButton *DisconnectButton;
	@property (nonatomic, retain) NSString *ConnectionCode;

	-(void) initializeMeretzDemo;
	-(void) initializeMeretzDemoUI;
	-(void) updateMeretzDemoUI;
	-(BOOL) userIsConnectedWithMeretz;
	-(void) sampleGameTick: (id) sender;
	-(NSString *) getSavedMeretzAccessToken;
	-(void) saveMeretzAccessToken: (NSString *)accessToken;
	-(void) beginVendorUserConnect;
	-(void) beginVendorUserConsume;
	-(void) beginVendorUserDisconnect;

	// MeretzDelegate methods
	// called when a user connection with the Meretz back-end completes
	// if successful (result.Success==TRUE), result.AccessToken should be saved and used for all future API calls
	- (void) didVendorUserConnectFinish:(MeretzVendorUserConnectResult *)result;
	// called when a user disconnection from the Meretz back-end completes
	// if successful (result.Success==TRUE), the user is no longer connected with the Meretz backend and
	// any saved access token is now invalid.
	- (void) didVendorUserDisconnectFinish:(MeretzResult *)result;
	// called when the user has purchased new items for your game using Meretz points
	// if successful (result.Success==TRUE), result.Items contains any newly acquired items.
	- (void) didVendorConsumeFinish:(MeretzVendorConsumeResult *)result;

@end

@implementation GameViewController

	@synthesize MeretzAPI;
	@synthesize SampleGameState;
	@synthesize VendorConnectUserTaskId;
	@synthesize VendorConsumeTaskId;
	@synthesize VendorDisconnectUserTaskId;
	@synthesize ConnectionCodeTextField;
	@synthesize ConnectionCode;

	-(void) initializeMeretzDemo
	{
		// initialize Meretz lib
		NSLog(@"Initializing Meretz");
		self.MeretzAPI= [[Meretz alloc] init];
		NSAssert(nil != self.MeretzAPI, @"Failed to initialize MeretzLib!");
		self.SampleGameState= Initial;
		self.VendorConnectUserTaskId= MERETZ_TASK_ID_INVALID;
		self.VendorConsumeTaskId= MERETZ_TASK_ID_INVALID;
		self.VendorDisconnectUserTaskId= MERETZ_TASK_ID_INVALID;
		
		self.ConnectionCodeTextField= nil;
		self.ConnectionCode= @"";
		
		// if we have previously saved a Meretz Access Token, use it
		// your game will want to use a similar pattern
		NSString *savedAccessToken= [self getSavedMeretzAccessToken];
		if ((nil != savedAccessToken) && (0 < [savedAccessToken length]))
		{
			NSLog(@"Retrieved saved Meretz access token: %@", savedAccessToken);
			[MeretzAPI setMeretzUserAccessToken:savedAccessToken];
		}
		
		if (FALSE)
		{
			// point Meretz at a custom dev server
			[MeretzAPI setMeretzHostName:@"127.0.0.1"];
			[MeretzAPI setMeretzPort:8000];
			[MeretzAPI setMeretzProtocol: @"http"];
			[MeretzAPI setMeretzAPIPath:@""];
			NSLog(@"Meretz server set to: %@", [MeretzAPI getMeretzServerString]);
		}
		
		if (USE_MERETZ_DELEGATE)
		{
			[MeretzAPI setMeretzDelegate:self];
		}
		
		[self initializeMeretzDemoUI];
		
		// run a basic update loop, to allow us to check async operations in Meretz-land
		float intervalSeconds= 0.25f;
		[NSTimer scheduledTimerWithTimeInterval:intervalSeconds target:self selector:@selector(sampleGameTick:) userInfo:nil repeats:YES];
		
		return;
	}

	-(void) initializeMeretzDemoUI
	{
		float width= self.view.frame.size.width, height= 30.0f;
		
		self.ConnectionCodeTextField= [[UITextField  alloc] initWithFrame: CGRectMake(0, 0, width, height)];
		self.ConnectionCodeTextField.borderStyle= UITextBorderStyleRoundedRect;
		self.ConnectionCodeTextField.contentVerticalAlignment= UIControlContentVerticalAlignmentCenter;
		[self.ConnectionCodeTextField setFont:[UIFont boldSystemFontOfSize:12]];
		self.ConnectionCodeTextField.placeholder= @"Connection Code";
		
		[self.view addSubview:self.ConnectionCodeTextField];
		self.ConnectionCodeTextField.delegate= self;
		
		[self becomeFirstResponder];
		
		width= 0.5f * self.view.frame.size.width;
		
		self.ConsumeButton= [UIButton buttonWithType:UIButtonTypeRoundedRect];
		self.DisconnectButton= [UIButton buttonWithType:UIButtonTypeRoundedRect];
		
		[self.ConsumeButton setTitle:@"Consume Items" forState:UIControlStateNormal];
		[self.DisconnectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
		
		[self.ConsumeButton addTarget:self action:@selector(beginVendorUserConsume) forControlEvents:UIControlEventTouchDown];
		[self.DisconnectButton addTarget:self action:@selector(beginVendorUserDisconnect) forControlEvents:UIControlEventTouchDown];
		
		[self.ConsumeButton setFrame:CGRectMake(0, 1 * height, width, height)];
		[self.DisconnectButton setFrame:CGRectMake(0, 2 * height, width, height)];
		
		[self.view addSubview:self.ConsumeButton];
		[self.view addSubview:self.DisconnectButton];
		
		[self updateMeretzDemoUI];
		
		return;
	}

	-(void) updateMeretzDemoUI
	{
		if ([self userIsConnectedWithMeretz])
		{
			if (nil != self.ConnectionCodeTextField)
			{
				if (self.ConnectionCodeTextField.enabled)
				{
					[self.ConnectionCodeTextField setEnabled:FALSE];
					self.ConnectionCodeTextField.text= @"User Linked with Meretz";
				}
			}
			
			if (nil != self.ConsumeButton)
			{
				if (!self.ConsumeButton.enabled)
				{
					[self.ConsumeButton setEnabled:TRUE];
				}
			}
			
			if (nil != self.DisconnectButton)
			{
				if (!self.DisconnectButton.enabled)
				{
					[self.DisconnectButton setEnabled:TRUE];
				}
			}
		}
		else
		{
			if (nil != self.ConnectionCodeTextField)
			{
				if (!self.ConnectionCodeTextField.enabled)
				{
					[self.ConnectionCodeTextField setEnabled:TRUE];
					self.ConnectionCodeTextField.text= @"";
					self.ConnectionCodeTextField.placeholder= @"Connection Code";
				}
			}
			
			if (nil != self.ConsumeButton)
			{
				if (self.ConsumeButton.enabled)
				{
					[self.ConsumeButton setEnabled:FALSE];
				}
			}
			
			if (nil != self.DisconnectButton)
			{
				if (self.DisconnectButton.enabled)
				{
					[self.DisconnectButton setEnabled:FALSE];
				}
			}
		}
	}

	-(BOOL) userIsConnectedWithMeretz
	{
		return ((nil != MeretzAPI) && (0 < [[MeretzAPI getMeretzUserAccessToken] length]));
	}

	-(void) sampleGameTick: (id) sender
	{
		if (nil != self.ConnectionCodeTextField)
		{
			if ([self userIsConnectedWithMeretz])
			{
				[self.ConnectionCodeTextField setText:@"Connected to Meretz"];
			}
		}
		
		switch (self.SampleGameState)
		{
			case Initial:
			{
				// initialize Meretz sample UI
				if ([self userIsConnectedWithMeretz])
				{
					// check for newly consumed items automatically at startup
					[self beginVendorUserConsume];
				}
				self.SampleGameState= Idle;
				break;
			}
			case Connecting:
			{
				if (MERETZ_TASK_ID_INVALID != self.VendorConnectUserTaskId)
				{
					MeretzTaskStatus taskStatus= [MeretzAPI getTaskStatus:self.VendorConnectUserTaskId];
					
					if (MeretzTaskStatusComplete == taskStatus)
					{
						MeretzVendorUserConnectResult *userConnectResults= [MeretzAPI getVendorUserConnectResult:self.VendorConnectUserTaskId];
						
						[self didVendorUserConnectFinish:userConnectResults];
					}
					else
					{
						NSLog(@"VendorUserConnect task still in progress...");
					}
				}
				else if (!USE_MERETZ_DELEGATE)
				{
					NSLog(@"Lost our VendorUserConnect task?");
					self.SampleGameState= Idle;
				}
				break;
			}
			case Consuming:
			{
				if (MERETZ_TASK_ID_INVALID != self.VendorConsumeTaskId)
				{
					MeretzTaskStatus taskStatus= [MeretzAPI getTaskStatus:self.VendorConsumeTaskId];
					
					if (MeretzTaskStatusComplete == taskStatus)
					{
						MeretzVendorConsumeResult *consumeResults= [MeretzAPI getVendorConsumeResult:self.VendorConsumeTaskId];
						
						[self didVendorConsumeFinish:consumeResults];
					}
					else
					{
						NSLog(@"VendorConsume task still in progress...");
					}
				}
				else if (!USE_MERETZ_DELEGATE)
				{
					NSLog(@"Lost our VendorUserConsume task?");
					self.SampleGameState= Idle;
				}
				break;
			}
			case Disconnecting:
			{
				if (MERETZ_TASK_ID_INVALID != self.VendorDisconnectUserTaskId)
				{
					MeretzTaskStatus taskStatus= [MeretzAPI getTaskStatus:self.VendorDisconnectUserTaskId];
					
					if (MeretzTaskStatusComplete == taskStatus)
					{
						MeretzResult *disconnectResults= [MeretzAPI getVendorUserDisconnectResult:self.VendorDisconnectUserTaskId];
						
						[self didVendorUserDisconnectFinish:disconnectResults];
					}
					else
					{
						NSLog(@"VendorDisconnect task still in progress...");
					}
				}
				else if (!USE_MERETZ_DELEGATE)
				{
					NSLog(@"Lost our VendorUserDisconnect task?");
					self.SampleGameState= Idle;
				}
				break;
			}
			case Idle:
			default:
			{
				break;
			}
		}
		
		return;
	}

	-(NSString *) getSavedMeretzAccessToken
	{
		NSString *savedAccessToken= [[NSUserDefaults standardUserDefaults] stringForKey:MERETZ_USER_ACCESS_TOKEN_NSUSERDEFAULTS_KEY];
	
		return savedAccessToken;
	}

	-(void) saveMeretzAccessToken: (NSString *)accessToken
	{
		[[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:MERETZ_USER_ACCESS_TOKEN_NSUSERDEFAULTS_KEY];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		return;
	}

	-(void) beginVendorUserConnect
	{
		// initiate a user connection task
		NSString *userConnectionCode= self.ConnectionCodeTextField.text;
		NSString *vendorUserIdentifier= SAMPLE_GAME_USER_IDENTIFIER;
		MeretzTaskId result= [MeretzAPI vendorUserConnect:userConnectionCode vendorUserToken:vendorUserIdentifier];
		
		if (MERETZ_TASK_ID_INVALID != result)
		{
			NSLog(@"initiating vendorUserConnect with connection code '%@'", userConnectionCode);
			self.SampleGameState= Connecting;
		}
		else
		{
			NSLog(@"failed to initiate vendorUserConnect!");
			self.SampleGameState= Idle;
		}
		
		self.ConnectionCodeTextField.text= @"";
		
		// if we're acting as a Meretz delegate, there is no need to save the task handle
		if (!USE_MERETZ_DELEGATE)
		{
			self.VendorConnectUserTaskId= result;
		}
		
		return;
	}

	-(void) beginVendorUserConsume
	{
		if ([self userIsConnectedWithMeretz])
		{
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
			NSDate *startDate= [dateFormatter dateFromString: @"2016-04-01 00:00:00 GMT"]; // using a date sufficiently in the past to catch recent purchases
			NSDate *endDate= nil;
			MeretzTaskId result= [MeretzAPI vendorConsume:startDate optional:endDate];
			
			if (MERETZ_TASK_ID_INVALID != result)
			{
				self.SampleGameState= Consuming;
			}
			else
			{
				NSLog(@"failed to initiate a /vendor/consume call!");
				self.SampleGameState= Idle;
			}
			
			// if we're acting as a Meretz delegate, there is no need to save the task handle
			if (!USE_MERETZ_DELEGATE)
			{
				self.VendorConsumeTaskId= result;
			}
		}
		else
		{
			NSLog(@"User is not connected with Meretz, /vendor/consume call not initiated (it would fail)");
			self.SampleGameState= Idle;
		}
		
		return;
	}

	-(void) beginVendorUserDisconnect
	{
		if ([self userIsConnectedWithMeretz])
		{
			MeretzTaskId result= [MeretzAPI vendorUserDisconnect];
			
			if (MERETZ_TASK_ID_INVALID != result)
			{
				self.SampleGameState= Disconnecting;
			}
			else
			{
				NSLog(@"failed to initiate a /vendor/disconnect call!");
				self.SampleGameState= Idle;
			}
			
			// if we're acting as a Meretz delegate, there is no need to save the task handle
			if (!USE_MERETZ_DELEGATE)
			{
				self.VendorDisconnectUserTaskId= result;
			}
		}
		else
		{
			NSLog(@"User is not connected with Meretz, /vendor/disconnect call not initiated (it would fail)");
			self.SampleGameState= Idle;
		}
		
		return;
	}

	// called when a user connection with the Meretz back-end completes
	// if successful (result.Success==TRUE), result.AccessToken should be saved and used for all future API calls
	- (void) didVendorUserConnectFinish:(MeretzVendorUserConnectResult *)result
	{
		NSLog(@"VendorUserConnect results: %@", result);
		
		if (TRUE == [result.Success boolValue])
		{
			// set our access token based on what was returned back from /vendor/connect
			[MeretzAPI setMeretzUserAccessToken:result.AccessToken];
			
			// save this access token for future program runs
			[self saveMeretzAccessToken:result.AccessToken];
		}
		else
		{
			self.ConnectionCodeTextField.text= @"";
			self.ConnectionCodeTextField.placeholder= @"Connection Code";
		}
		
		if (MERETZ_TASK_ID_INVALID != self.VendorConnectUserTaskId)
		{
			// release our /vendor/connect task results
			[MeretzAPI releaseTask:self.VendorConnectUserTaskId];
			self.VendorConnectUserTaskId= MERETZ_TASK_ID_INVALID;
		}
		
		[self updateMeretzDemoUI];
		
		self.SampleGameState= Idle;
		
		// check for newly consumed items automatically when newly connected with Meretz
		if ([self userIsConnectedWithMeretz])
		{
			[self beginVendorUserConsume];
		}
		
		return;
	}

	// called when a user disconnection from the Meretz back-end completes
	// if successful (result.Success==TRUE), the user is no longer connected with the Meretz backend and
	// any saved access token is now invalid.
	- (void) didVendorUserDisconnectFinish:(MeretzResult *)result
	{
		NSLog(@"VendorDisconnect results: %@", result);
		
		if (TRUE == [result.Success boolValue])
		{
			// clear any saved access token value
			[self saveMeretzAccessToken:@""];
			[MeretzAPI setMeretzUserAccessToken:@""];
		}
		
		if (MERETZ_TASK_ID_INVALID != self.VendorDisconnectUserTaskId)
		{
			// release our /vendor/disconnect task results
			[MeretzAPI releaseTask:self.VendorDisconnectUserTaskId];
			self.VendorDisconnectUserTaskId= MERETZ_TASK_ID_INVALID;
		}
		
		[self updateMeretzDemoUI];
		
		// finished
		self.SampleGameState= Idle;
		
		return;
	}

	// called when the user has purchased new items for your game using Meretz points
	// if successful (result.Success==TRUE), result.Items contains any newly acquired items.
	- (void) didVendorConsumeFinish:(MeretzVendorConsumeResult *)result
	{
		NSLog(@"VendorConsume results: %@", result);
		
		if (MERETZ_TASK_ID_INVALID != self.VendorConsumeTaskId)
		{
			// release our /vendor/consume task results
			[MeretzAPI releaseTask:self.VendorConsumeTaskId];
			self.VendorConsumeTaskId= MERETZ_TASK_ID_INVALID;
		}
		
		self.SampleGameState= Idle;
		
		return;
	}

#pragma mark : UITextField delegates

	-(void)textFieldDidBeginEditing:(UITextField *)textField
	{
		self.ConnectionCodeTextField.placeholder= @"";
		
		return;
	}

	-(void)textFieldDidEndEditing:(UITextField *)textField
	{
		if (![self userIsConnectedWithMeretz])
		{
			[self beginVendorUserConnect];
		}
		else
		{
			NSLog(@"Already connected with Meretz, disconnect first to initiate a new user connection.");
		}
		
		return;
	}

	-(BOOL) textFieldShouldReturn:(UITextField *)textField
	{
		[self.ConnectionCodeTextField resignFirstResponder];
		
		return YES;
	}

#pragma mark : SampleGameApp template code

	- (void)viewDidLoad
	{
		[super viewDidLoad];
		
		// create a new scene
		SCNScene *scene = [SCNScene sceneNamed:@"art.scnassets/ship.scn"];

		// create and add a camera to the scene
		SCNNode *cameraNode = [SCNNode node];
		cameraNode.camera = [SCNCamera camera];
		[scene.rootNode addChildNode:cameraNode];
		
		// place the camera
		cameraNode.position = SCNVector3Make(0, 0, 15);
		
		// create and add a light to the scene
		SCNNode *lightNode = [SCNNode node];
		lightNode.light = [SCNLight light];
		lightNode.light.type = SCNLightTypeOmni;
		lightNode.position = SCNVector3Make(0, 10, 10);
		[scene.rootNode addChildNode:lightNode];
		
		// create and add an ambient light to the scene
		SCNNode *ambientLightNode = [SCNNode node];
		ambientLightNode.light = [SCNLight light];
		ambientLightNode.light.type = SCNLightTypeAmbient;
		ambientLightNode.light.color = [UIColor darkGrayColor];
		[scene.rootNode addChildNode:ambientLightNode];
		
		// retrieve the ship node
		SCNNode *ship = [scene.rootNode childNodeWithName:@"ship" recursively:YES];
		
		// animate the 3d object
		[ship runAction:[SCNAction repeatActionForever:[SCNAction rotateByX:0 y:2 z:0 duration:1]]];
		
		// retrieve the SCNView
		SCNView *scnView = (SCNView *)self.view;
		
		// set the scene to the view
		scnView.scene = scene;
		
		// allows the user to manipulate the camera
		scnView.allowsCameraControl = YES;
			
		// show statistics such as fps and timing information
		scnView.showsStatistics = YES;

		// configure the view
		scnView.backgroundColor = [UIColor blackColor];
		
		// add a tap gesture recognizer
		UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
		NSMutableArray *gestureRecognizers = [NSMutableArray array];
		[gestureRecognizers addObject:tapGesture];
		[gestureRecognizers addObjectsFromArray:scnView.gestureRecognizers];
		scnView.gestureRecognizers = gestureRecognizers;
		
		// $MERETZ
		[self initializeMeretzDemo];
		
		return;
	}

	- (void) handleTap:(UIGestureRecognizer*)gestureRecognize
	{
		// retrieve the SCNView
		SCNView *scnView = (SCNView *)self.view;
		
		// check what nodes are tapped
		CGPoint p = [gestureRecognize locationInView:scnView];
		NSArray *hitResults = [scnView hitTest:p options:nil];
		
		// check that we clicked on at least one object
		if([hitResults count] > 0){
			// retrieved the first clicked object
			SCNHitTestResult *result = [hitResults objectAtIndex:0];
			
			// get its material
			SCNMaterial *material = result.node.geometry.firstMaterial;
			
			// highlight it
			[SCNTransaction begin];
			[SCNTransaction setAnimationDuration:0.5];
			
			// on completion - unhighlight
			[SCNTransaction setCompletionBlock:^{
				[SCNTransaction begin];
				[SCNTransaction setAnimationDuration:0.5];
				
				material.emission.contents = [UIColor blackColor];
				
				[SCNTransaction commit];
			}];
			
			material.emission.contents = [UIColor redColor];
			
			[SCNTransaction commit];
		}
		
		return;
	}

	- (BOOL)shouldAutorotate
	{
		return YES;
	}

	- (BOOL)prefersStatusBarHidden {
		return YES;
	}

	- (UIInterfaceOrientationMask)supportedInterfaceOrientations
	{
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
			return UIInterfaceOrientationMaskAllButUpsideDown;
		} else {
			return UIInterfaceOrientationMaskAll;
		}
	}

	- (void)didReceiveMemoryWarning
	{
		[super didReceiveMemoryWarning];
		// Release any cached data, images, etc that aren't in use.
		
		return;
	}

@end
