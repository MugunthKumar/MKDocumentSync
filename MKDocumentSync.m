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

@interface MKDocumentSync (/*Private Methods*/)
-(void) pullFromiCloud;
-(void) pushToiCloud;
-(NSString*) documentsDirectory;
@property (strong, nonatomic) NSMetadataQuery *metadataQuery;
@end

@implementation MKDocumentSync
@synthesize metadataQuery = metadataQuery;

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
                [self pushToiCloud];
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
    
    for(NSMetadataItem *item in self.metadataQuery.results) {

        NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
        NSError *error = nil;
        DLog(@"Downloading [%@] from iCloud", url);
        
        NSNumber *isIniCloud = nil;
        if ([url getResourceValue:&isIniCloud forKey:NSURLIsUbiquitousItemKey error:nil]) {

            // If the item is in iCloud, see if it is downloaded.
            if ([isIniCloud boolValue]) {
                NSNumber*  isDownloaded = nil;
                error = nil;
                // If the item is in iCloud, see if it is downloaded.
                if ([url getResourceValue:&isDownloaded forKey:NSURLUbiquitousItemIsDownloadedKey error:&error]) {
                    
                    if(error) DLog(@"Cannot check iCloud sync status of file [%@]", error);
                    if (![isDownloaded boolValue]) {
                    
                        error = nil;
                        [[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:url error:&error];
                        if(error) DLog(@"Cannot start downloading from iCloud [%@]", error);
                    }
                }
                
                error = nil;
                NSNumber*  isConflicted = nil;
                if ([url getResourceValue:&isConflicted forKey:NSURLUbiquitousItemHasUnresolvedConflictsKey error:&error]) {
                    
                    if ([isConflicted boolValue]) {
                        
                        DLog(@"%@ is in conflict. Removing from iCloud", url);
                        NSString *fileName = [url lastPathComponent];
                        NSString *documentsDirectoryPath = [[self documentsDirectory] stringByAppendingPathComponent:fileName];
                        [[NSFileManager defaultManager] moveItemAtURL:url toURL:[NSURL fileURLWithPath:documentsDirectoryPath] 
                                                                error:&error];
                        if(error) DLog(@"Moving conflicted file failed: [%@]", error);

                        error = nil;
                        [[NSFileManager defaultManager] evictUbiquitousItemAtURL:url error:&error];
                        if(error) DLog(@"Evicting conflicted file failed: [%@]", error);
                    }
                }
            }
        }
    }
    
    [self.metadataQuery disableUpdates];
    [self.metadataQuery stopQuery];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSMetadataQueryDidFinishGatheringNotification 
                                                  object:self.metadataQuery];
    self.metadataQuery = nil; // we're done with it
}

-(void) pullFromiCloud {
    
    self.metadataQuery = [[NSMetadataQuery alloc] init];
    self.metadataQuery.searchScopes = [NSArray arrayWithObject:NSMetadataQueryUbiquitousDocumentsScope];
    self.metadataQuery.predicate = [NSPredicate predicateWithFormat:@"%K LIKE '*'", NSMetadataItemFSNameKey];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryDidFinishGathering:) 
                                                 name:NSMetadataQueryDidFinishGatheringNotification 
                                               object:self.metadataQuery];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryDidFinishGathering:) 
                                                 name:NSMetadataQueryDidUpdateNotification 
                                               object:self.metadataQuery];
    
    [self.metadataQuery startQuery];
}

-(void) pushToiCloud {

    NSString *docsDirectory = [self documentsDirectory];
    NSArray *listOfFiles = [self filesInDirectory:docsDirectory];
    for(NSString *filePath in listOfFiles) {
            
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        NSString *relativePath = [filePath stringByReplacingOccurrencesOfString:docsDirectory withString:@""];
        relativePath = [relativePath substringFromIndex:1];
        
        NSURL *iCloudFirstContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        NSURL *iCloudDestinationURL = [[iCloudFirstContainer URLByAppendingPathComponent:@"Documents"] URLByAppendingPathComponent:relativePath];

        NSURL *directoryURL = [iCloudDestinationURL URLByDeletingLastPathComponent];
        
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error];        
        if(error) DLog(@"Unable to create iCloud local directory [%@]", error);
        
        error = nil;
        [[NSFileManager defaultManager] setUbiquitous:YES 
                                            itemAtURL:fileURL
                                       destinationURL:iCloudDestinationURL 
                                                error:&error];
        
        if(error) DLog(@"%@", error);
        
        DLog(@"Moving [%@] to iCloud location at [%@]", fileURL, iCloudDestinationURL);
    }
}

-(NSString*) documentsDirectory {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDirectory = [paths objectAtIndex:0];    
    
    return docsDirectory;
}

-(NSString*) iCloudLocalDocumentDirectory {
    
    NSURL *iCloudFirstContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
    NSURL *iCloudDocsURL = [iCloudFirstContainer URLByAppendingPathComponent:@"Documents"];    
    return [iCloudDocsURL path];
}

-(NSMutableArray*) filesIniCloudDirectory {
    
    return [self filesInDirectory:[self iCloudLocalDocumentDirectory]];
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
