//
//  PhotosTableViewController.h
//  CS193P-5
//
//  Created by Ed Sibbald on 11/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DictPlace;


@interface MostPopularPhotosTVC : UITableViewController
{
	DictPlace *_place;
	NSArray *_photos;
	NSManagedObjectContext *_context;
}

- (id)initWithPlace:(DictPlace *)place manageObjectContext:(NSManagedObjectContext *)context;

@end
