//
//  Photo.h
//  CS193P-5
//
//  Created by Ed Sibbald on 12/5/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DictPhoto : NSObject
{
	NSString *_uniqueId;
	NSString *_title;
	NSString *_desc;
	NSString *_url;

	NSString *_thumbnailUrl;
	NSData *_cachedThumbnailData;
}

@property (copy) NSString *uniqueId;
@property (copy) NSString *title;
@property (copy) NSString *desc;
@property (copy) NSString *thumbnailUrl;
@property (readonly) NSData *cachedThumbnailData;
@property (copy) NSString *url;

// NOT a new designated initializer, just for convenience
- (id)initWithDictionary:(NSDictionary *)dict;

- (void)processThumbnailDataWithBlock:(void (^)(NSData *))processThumbnailData;

+ (void)downloadImageDataFromUrl:(NSString *)url andProcessWithBlock:(void (^)(NSData *))processThumbnailData;

@end
