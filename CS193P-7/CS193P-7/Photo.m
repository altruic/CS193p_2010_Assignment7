//
//  Photo.m
//  CS193P-6
//
//  Created by Ed Sibbald on 1/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Photo.h"
#import "Place.h"

#import "DictPhoto.h"

@interface Photo ()
@property (nonatomic, retain) NSData * thumbnail_data;
@end

@implementation Photo

@dynamic desc;
@dynamic favorite;
@dynamic last_viewed;
@dynamic thumbnail_data; // onyl defined in Photo () category, consumer code should use getOrDownloadThumbnailData
@dynamic thumbnail_url;
@dynamic title;
@dynamic unique_id;
@dynamic url;

@dynamic place;


- (NSData *)getOrDownloadThumbnailData
{
	if (self.thumbnail_data)
		return self.thumbnail_data;

	[DictPhoto downloadImageDataFromUrl:self.thumbnail_url andProcessWithBlock:^(NSData *thumbnailData) {
		self.thumbnail_data = thumbnailData;
		NSError *error = nil;
		[self.managedObjectContext save:&error];
		if (error)
			NSLog(@"Error saving thumbnail data for photo with id %@: %@", self.unique_id, error);
	}];
	return nil;
}


+ (Photo *)photoWithDictPhoto:(DictPhoto *)dictPhoto
					fromPlace:(Place *)place
	   inManagedObjectContext:(NSManagedObjectContext *)context
{
	if (dictPhoto == nil)
		return nil;
	
	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	request.entity = [NSEntityDescription entityForName:@"Photo" inManagedObjectContext:context];
	request.predicate = [NSPredicate predicateWithFormat:@"unique_id = %@", dictPhoto.uniqueId];
	
	NSError *error = nil;
	Photo *photo = [[context executeFetchRequest:request error:&error] lastObject];
	
	if (error) {
		NSLog(@"Error searching for photo with id %@: %@", dictPhoto.uniqueId, error);
		return nil;
	}
	
	if (!photo) {
		photo = [NSEntityDescription insertNewObjectForEntityForName:@"Photo" inManagedObjectContext:context];
		photo.desc = dictPhoto.desc;
		photo.favorite = [NSNumber numberWithBool:NO];
		// don't do any block processing here. if the dict photo doesn't have it yet, we'll get it later when asked.
		if (dictPhoto.cachedThumbnailData)
			photo.thumbnail_data = dictPhoto.cachedThumbnailData;
		photo.thumbnail_url = dictPhoto.thumbnailUrl;
		photo.title = dictPhoto.title;
		photo.unique_id = dictPhoto.uniqueId;
		photo.url = dictPhoto.url;
		
		photo.place = place;
	}
	
	// It's possible the photo in the database doesn't have a thumbnail image because it was added before thumbnail
	// images were cached. In that case, the thumbnail download is reattempted by getOrDownloadThumbnailData.
	
	return photo;
}

@end
