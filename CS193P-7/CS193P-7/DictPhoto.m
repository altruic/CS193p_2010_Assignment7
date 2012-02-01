//
//  Photo.m
//  CS193P-5
//
//  Created by Ed Sibbald on 12/5/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "DictPhoto.h"

#import "UIApplication+NetworkActivity.h"
#import "FlickrFetcher.h"

@implementation DictPhoto

@synthesize uniqueId = _uniqueId;
@synthesize title = _title;
@synthesize desc = _description;
@synthesize thumbnailUrl = _thumbnailUrl;
@synthesize cachedThumbnailData = _cachedThumbnailData;
@synthesize url = _url;

- (id)initWithDictionary:(NSDictionary *)dict
{
	self = [self init];
	if (!self)
		return self;

	id possId = [dict objectForKey:@"id"];
	NSString *photoId = [possId isKindOfClass:[NSString class]] ? (NSString *)possId : nil;
	if (!photoId) {
		NSLog(@"Non-nil string expected at key \"id\"");
		[self release];
		return nil;
	}
	self.uniqueId = photoId;

	id possTitle = [dict objectForKey:@"title"];
	NSString *title = [possTitle isKindOfClass:[NSString class]] ? (NSString *)possTitle : nil;
	if (!title) {
		NSLog(@"Non-nil string expected at key \"title\"");
		[self release];
		return nil;
	}
	self.title = title;
	
	id possDescriptionDict = [dict objectForKey:@"description"];
	NSDictionary *descriptionDict = [possDescriptionDict isKindOfClass:[NSDictionary class]]
		? (NSDictionary *)possDescriptionDict : nil;
	if (!descriptionDict) {
		NSLog(@"Non-nil dictionary expected at key \"description\"");
		[self release];
		return nil;
	}
	id possDescription = [descriptionDict objectForKey:@"_content"];
	NSString *description = [possDescription isKindOfClass:[NSString class]] ? (NSString *)possDescription : nil;
	if (!description) {
		NSLog(@"Non-nil string expected at key \"description/\"_content\"\"");
		[self release];
		return nil;
	}
	self.desc = description;
	
	self.thumbnailUrl = [FlickrFetcher urlStringForPhotoWithFlickrInfo:dict format:FlickrFetcherPhotoFormatSquare];
	self.url = [FlickrFetcher urlStringForPhotoWithFlickrInfo:dict format:FlickrFetcherPhotoFormatLarge];
	
	return self;
}


- (void)dealloc
{
	self.uniqueId = nil;
	self.title = nil;
	self.desc = nil;
	self.thumbnailUrl = nil;
	self.url = nil;
	[_cachedThumbnailData release];
	[super dealloc];
}


- (void)processThumbnailDataWithBlock:(void (^)(NSData *))processThumbnailData
{
	if (_cachedThumbnailData)
		processThumbnailData(_cachedThumbnailData);
	[DictPhoto downloadImageDataFromUrl:self.thumbnailUrl andProcessWithBlock:^(NSData *thumbnailData) {
		_cachedThumbnailData = [thumbnailData retain];
		processThumbnailData(thumbnailData);
	}];
}


+ (void)downloadImageDataFromUrl:(NSString *)url andProcessWithBlock:(void (^)(NSData *))processImageData
{
	dispatch_queue_t downloadImageDataQueue = dispatch_queue_create("image data downloader", NULL);
	dispatch_queue_t currQueue = dispatch_get_current_queue();
	dispatch_async(downloadImageDataQueue, ^{
		[UIApplication showNetworkActivityIndicator];
		NSData *imageData = [FlickrFetcher imageDataForPhotoWithURLString:url];
		[UIApplication hideNetworkActivityIndicator];
		dispatch_async(currQueue, ^{ processImageData(imageData); });
	});
	dispatch_release(downloadImageDataQueue);
}

@end
