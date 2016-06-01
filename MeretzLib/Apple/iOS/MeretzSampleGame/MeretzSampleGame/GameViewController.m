//
//  GameViewController.m
//  MeretzSampleGame
//
//  Created by Stefan Sinclair on 5/31/16.
//  Copyright (c) 2016 Meretz. All rights reserved.
//

#import "GameViewController.h"

#import "Meretz/include/Meretz.h"

#define MERETZ_SAMPLE_VENDOR_ACCESS_TOKEN		@"Meretz-Sample"

@implementation GameViewController

Meretz *gMeretz= nil;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// initialize Meretz lib
	NSString *storedUserAccessToken= nil;
	NSLog(@"Initializing Meretz w/ vendor access token %@", MERETZ_SAMPLE_VENDOR_ACCESS_TOKEN);
	gMeretz= [[Meretz alloc] initWithTokens:MERETZ_SAMPLE_VENDOR_ACCESS_TOKEN emptyOrSavedValue:storedUserAccessToken];
	NSAssert(nil != gMeretz, @"Failed to initialize MeretzLib!");
	
	if (TRUE)
	{
		// point Meretz at a custom dev server
		[gMeretz setMeretzServerHostName:@"127.0.0.1"];
		[gMeretz setMeretzServerPort:8080];
		[gMeretz setMeretzServerProtocol: @"http"];
		[gMeretz setMeretzServerAPIPath:@""];
		NSLog(@"Meretz server set to: %@", [gMeretz getMeretzServerString]);
	}
	
	if (TRUE)
	{
		// initiate a user connection task
		NSString *userConnectionCode= @"ABC123";
		
		MeretzTaskId connectUserTaskId= [gMeretz vendorUserConnect:userConnectionCode];
		if (MERETZ_TASK_ID_INVALID != connectUserTaskId)
		{
			NSLog(@"connectUserTask started: %X", connectUserTaskId);
		}
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
