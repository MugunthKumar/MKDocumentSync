//
//  AppDelegate.m
//  MKDocumentSync
//
//  Created by Mugunth Kumar on 6/2/12.
//  Copyright (c) 2012 Steinlogic. All rights reserved.
//

#import "AppDelegate.h"
#import "MKDocumentSync.h"

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    NSString *bundleDocPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Documents"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDirectory = [paths objectAtIndex:0];

    NSArray *files = [[MKDocumentSync sharedInstance] filesInDirectory:bundleDocPath];
    for(NSString *filePath in files) {
        
        NSError *error = nil;
        NSString *relativePath = [filePath stringByReplacingOccurrencesOfString:bundleDocPath withString:@""];
        NSString *destinationPath = [docsDirectory stringByAppendingString:relativePath];
        NSString *directoryPath = [destinationPath stringByDeletingLastPathComponent];
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDir];
        
        if(!(exists && isDir)) {
            
            [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error];
            if(error) DLog(@"%@", error);
            
            error = nil;
        }
        
        [[NSFileManager defaultManager] copyItemAtPath:filePath toPath:destinationPath error:&error];
        if(error) DLog(@"%@", error);
    }
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
