//
//  MKDocumentSync.m
//  MKDocumentSync
//
//  Created by Mugunth Kumar on 6/2/12.
//  Copyright 2012 Steinlogic. All rights reserved.
//	File created using Singleton XCode Template by Mugunth Kumar (http://blog.mugunthkumar.com)
//  More information about this template on the post http://mk.sg/89	
//  Permission granted to do anything, commercial/non-commercial with this file apart from removing the line/URL above

#import "MKDocumentSync.h"
#import "MKDocument.h"

@interface MKDocumentSync (/*Private Methods*/)
-(void) pullFromiCloud;
-(void) pushToiCloud;
@property (strong, nonatomic) NSMetadataQuery *query;
@end

@implementation MKDocumentSync
@synthesize query = query_;

#pragma mark -
#pragma mark Singleton Methods

+ (MKDocumentSync*)sharedInstance {

	static MKDocumentSync *_sharedInstance;
	if(!_sharedInstance) {
		static dispatch_once_t oncePredicate;
		dispatch_once(&oncePredicate, ^{
			_sharedInstance = [[super allocWithZone:nil] init];
			});
		}

		return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {	

	return [self sharedInstance];
}


- (id)copyWithZone:(NSZone *)zone {
	return self;	
}

#if (!__has_feature(objc_arc))

- (id)retain {	

	return self;	
}

- (unsigned)retainCount {
	return UINT_MAX;  //denotes an object that cannot be released
}

- (void)release {
	//do nothing
}

- (id)autorelease {

	return self;	
}
#endif

-(void) startSync {
    
    if(NSClassFromString(@"NSUbiquitousKeyValueStore")) { // is iOS 5?

        NSURL *iCloudFirstContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];

        if(iCloudFirstContainer) {  // is iCloud enabled
            
            [self pullFromiCloud];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                //[self pushToiCloud];
            });
            
        } else {
            DLog(@"iCloud Document Sync not enabled");   
        }
    }
    else {
        DLog(@"Not an iOS 5 device");        
    }
}

#pragma mark -
#pragma mark Custom Methods

// Add your custom methods here

- (void)queryDidFinishGathering:(NSNotification *)notification {
    
    NSMetadataQuery *query = [notification object];
    [query disableUpdates];
    [query stopQuery];
    DLog(@"Query ended with %d results", [query resultCount]);
    for(NSMetadataItem *item in query.results) {

        NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
        NSError *error = nil;
        DLog(@"Downloading [%@] from iCloud", url);
        [[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:url error:&error];
        if(error) DLog(@"%@", error);
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSMetadataQueryDidFinishGatheringNotification 
                                                  object:self.query];
    self.query = nil; // we're done with it
}

-(void) pullFromiCloud {
    
    self.query = [[NSMetadataQuery alloc] init];
    [self.query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryUbiquitousDataScope, nil]];

    [self.query setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%K like '*'", NSMetadataItemFSNameKey]]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryDidFinishGathering:) name:NSMetadataQueryDidFinishGatheringNotification object:self.query];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.query startQuery];
    });
}

-(void) pushToiCloud {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDirectory = [paths objectAtIndex:0];    

    NSArray *listOfFiles = [self filesInDirectory:docsDirectory];
    for(NSString *filePath in listOfFiles) {
            
        MKDocument *thisDocument = [[MKDocument alloc] initWithFileURL:[NSURL fileURLWithPath:filePath]];
        NSString *relativePath = [filePath stringByReplacingOccurrencesOfString:docsDirectory withString:@""];
        relativePath = [relativePath stringByReplacingOccurrencesOfString:@"/" withString:@""];
        NSURL *iCloudFirstContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        NSURL *iCloudDestinationURL = [[iCloudFirstContainer URLByAppendingPathComponent:@"Documents"] URLByAppendingPathComponent:relativePath];

        NSError *error = nil;
        [[NSFileManager defaultManager] setUbiquitous:YES 
                                            itemAtURL:thisDocument.fileURL 
                                       destinationURL:iCloudDestinationURL 
                                                error:&error];
        
        if(error) DLog(@"%@", error);
        
        DLog(@"Moving [%@] to iCloud location at [%@]", thisDocument.fileURL, iCloudDestinationURL);
    }
}

-(NSMutableArray*) filesInDirectory: (NSString*) directoryName
{
	NSMutableArray *listOfFiles = [NSMutableArray array];
	
	NSDirectoryEnumerator *sourceDirectoryFilePathEnumerator = [[NSFileManager defaultManager] enumeratorAtPath: directoryName];
	
	NSString *fileName;
	while ((fileName = [sourceDirectoryFilePathEnumerator nextObject])) {
		
		NSDictionary* sourceDirectoryFileAttributes = [sourceDirectoryFilePathEnumerator fileAttributes];		
		NSString* sourceDirectoryFileType = [sourceDirectoryFileAttributes objectForKey:NSFileType];
		
		if ([sourceDirectoryFileType isEqualToString:NSFileTypeRegular] == YES) {
			
            NSString *absPath = [directoryName stringByAppendingPathComponent:fileName];
			[listOfFiles addObject:absPath];
		}
		
		else if([sourceDirectoryFileType isEqualToString:NSFileTypeDirectory] == YES) {			
			
			[listOfFiles addObjectsFromArray:[self filesInDirectory:fileName]];
		}		
	}
	
	return listOfFiles;
}
@end
