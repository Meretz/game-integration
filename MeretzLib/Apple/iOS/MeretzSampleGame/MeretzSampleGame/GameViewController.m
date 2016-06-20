//
//  GameViewController.m
//  MeretzSampleGame
//
//  Created by Stefan Sinclair on 5/31/16.
//  Copyright (c) 2016 E-Squared Labs - All rights reserved.
//

#import "GameViewController.h"

#import "Meretz/include/Meretz.h"

/*

Sample game usage instructions:

1) Work with the Meretz team to get your product(s) setup with a product page on the Meretz.com site

2) Create or acquire a test Meretz.com account for testing

3) Go to your product page on Meretz.com and generate a "user connection code" for your test account (from step 2)
	Paste the resulting connection code into the value for TEST_MERETZ_USER_CONNECTION_CODE below.

3) Purchase an item(s) with your test account (from step 2) via your product page on the Meretz.com site
	(use the URL parameters "force_show=1" and "override_comingsoon=1" as needed)
	e.g.: https://www.meretz.com/rewards/YOUR_PRODUCT_HERE?force_show=1&override_comingsoon=1
	This will ensure you have one or more product items consumed for reporting back in the sample game here below.

3) Generate a "connection code" for your test account (from step 2) and paste it into the value for BLAH
   e.g.: #define TEST_MERETZ_USER_CONNECTION_CODE		@"def123abc456"

4) At the same product page, purchase one or more available items, in order to test the /vendor/consume endpoint
	(https://www.meretz.com/rewards/YOUR_PRODUCT_HERE?force_show=1&override_comingsoon=1)

5) Now build and run this sample game.
	a) click once in the game view to initiate a /vendor/connect for your test account (watch the console for output)
	b) assuming the /vendor/connect succeeds, click again in the game view to 
	initiate a /vendor/consume operation for your test user (watch the console for output)
	NOTE: a real app would want to save off the access-token returned by the VendorConnect operation for future use.
	c) click once more in the game view to initiate a /vendor/disconnect task for your test account (watch the console for output)
	d) that's it for current demo functionality

*/

#define TEST_MERETZ_USER_CONNECTION_CODE		@"de8fcde09bf2"
#define SAMPLE_GAME_USER_IDENTIFIER				@"MeretzSampleGameUser"

typedef NS_ENUM(NSInteger, MeretzSampleGameState)
{
	Initial,
	Connecting,
	Consuming,
	Disconnecting,
	Finished
};

@implementation GameViewController

Meretz *gMeretz= nil;
MeretzSampleGameState gSampleGameState= Initial;
MeretzTaskId gConnectUserTaskId= MERETZ_TASK_ID_INVALID;
MeretzTaskId gVendorConsumeTaskId= MERETZ_TASK_ID_INVALID;
MeretzTaskId gVendorDisconnectTaskId= MERETZ_TASK_ID_INVALID;

static void updateSamepleGameState(void)
{
	switch (gSampleGameState)
	{
		case Initial:
		{
			// initiate a user connection task
			NSString *userConnectionCode= TEST_MERETZ_USER_CONNECTION_CODE;
			NSString *vendorUserIdentifier= SAMPLE_GAME_USER_IDENTIFIER;
			
			gConnectUserTaskId= [gMeretz vendorUserConnect:userConnectionCode vendorUserToken:vendorUserIdentifier];
			if (MERETZ_TASK_ID_INVALID != gConnectUserTaskId)
			{
				gSampleGameState= Connecting;
			}
			else
			{
				NSLog(@"failed to initiate vendorUserConnect!");
				gSampleGameState= Finished;
			}
			break;
		}
		case Connecting:
		{
			if (MERETZ_TASK_ID_INVALID != gConnectUserTaskId)
			{
				MeretzTaskStatus taskStatus= [gMeretz getTaskStatus:gConnectUserTaskId];
				
				if (MeretzTaskStatusComplete == taskStatus)
				{
					MeretzVendorUserConnectResult *userConnectResults= [gMeretz getVendorUserConnectResult:gConnectUserTaskId];
					
					NSLog(@"VendorUserConnect results: %@", userConnectResults);
					
					// set our access token based on what was returned back from /vendor/connect
					[gMeretz setMeretzUserAccessToken:userConnectResults.AccessToken];
					
					// NOTE: a real app would want to save off the access-token returned by the VendorConnect operation for future use,
					// to use (via setMeretzUserAccessToken) each time Meretz is initialized at program startup
					
					// release our /vendor/connect task results
					[gMeretz releaseTask:gConnectUserTaskId];
					gConnectUserTaskId= MERETZ_TASK_ID_INVALID;
					
					// initiate a /vendor/consume task
					NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
					[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
					NSDate *startDate= [dateFormatter dateFromString: @"2016-04-01 00:00:00 GMT"]; // use the current date here
					NSDate *endDate= nil;
					gVendorConsumeTaskId= [gMeretz vendorConsume:startDate optional:endDate];
					
					if (MERETZ_TASK_ID_INVALID != gVendorConsumeTaskId)
					{
						gSampleGameState= Consuming;
					}
					else
					{
						NSLog(@"failed to initiate a /vendor/consume call!");
						gSampleGameState= Finished;
					}

				}
				else
				{
					NSLog(@"VendorUserConnect task still in progress...");
				}
			}
			else
			{
				gSampleGameState= Finished;
			}
			break;
		}
		case Consuming:
		{
			if (MERETZ_TASK_ID_INVALID != gVendorConsumeTaskId)
			{
				MeretzTaskStatus taskStatus= [gMeretz getTaskStatus:gVendorConsumeTaskId];
				
				if (MeretzTaskStatusComplete == taskStatus)
				{
					MeretzVendorConsumeResult *consumeResults= [gMeretz getVendorConsumeResult:gVendorConsumeTaskId];
					
					NSLog(@"VendorConsume results: %@", consumeResults);
					
					// release our /vendor/consume task results
					[gMeretz releaseTask:gVendorConsumeTaskId];
					gVendorConsumeTaskId= MERETZ_TASK_ID_INVALID;
					
					// initiate a /vendor/disconnect
					gVendorDisconnectTaskId= [gMeretz vendorUserDisconnect];
					
					if (MERETZ_TASK_ID_INVALID != gVendorDisconnectTaskId)
					{
						gSampleGameState= Disconnecting;
					}
					else
					{
						NSLog(@"failed to initiate a /vendor/disconnect call!");
						gSampleGameState= Finished;
					}
				}
				else
				{
					NSLog(@"VendorConsume task still in progress...");
				}
			}
			else
			{
				gSampleGameState= Finished;
			}
			break;
		}
		case Disconnecting:
		{
			if (MERETZ_TASK_ID_INVALID != gVendorConsumeTaskId)
			{
				MeretzTaskStatus taskStatus= [gMeretz getTaskStatus:gVendorDisconnectTaskId];
				
				if (MeretzTaskStatusComplete == taskStatus)
				{
					MeretzResult *disconnectResults= [gMeretz getVendorUserDisconnectResult:gVendorDisconnectTaskId];
					
					NSLog(@"VendorDisconnect results: %@", disconnectResults);
					
					// release our /vendor/disconnect task results
					[gMeretz releaseTask:gVendorDisconnectTaskId];
					gVendorDisconnectTaskId= MERETZ_TASK_ID_INVALID;
					
					// finished
					gSampleGameState= Finished;
				}
				else
				{
					NSLog(@"VendorDisconnect task still in progress...");
				}
			}
			else
			{
				gSampleGameState= Finished;
			}
			break;
		}
		case Finished:
		{
			NSLog(@"Meretz sample app has no more tasks to demonstrate");
			break;
		}
		default: break;
	}
	
	return;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// initialize Meretz lib
	NSLog(@"Initializing Meretz");
	gMeretz= [[Meretz alloc] init];
	NSAssert(nil != gMeretz, @"Failed to initialize MeretzLib!");
	
	if (FALSE)
	{
		// point Meretz at a custom dev server
		[gMeretz setMeretzHostName:@"127.0.0.1"];
		[gMeretz setMeretzPort:8000];
		[gMeretz setMeretzProtocol: @"http"];
		[gMeretz setMeretzAPIPath:@""];
		NSLog(@"Meretz server set to: %@", [gMeretz getMeretzServerString]);
	}

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
	
	// Meretz sample code
	updateSamepleGameState();
	
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
}

@end
