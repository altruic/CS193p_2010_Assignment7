//
//  PhotosTableViewController.m
//  CS193P-5
//
//  Created by Ed Sibbald on 11/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MostPopularPhotosTVC.h"

#import "UIApplication+NetworkActivity.h"
#import "FlickrFetcher.h"
#import "DictPlace.h"
#import "DictPhoto.h"
#import "Photo.h"
#import "Place.h"
#import "PhotoViewController.h"


@implementation MostPopularPhotosTVC

- (void)processPhotosAtPhotos:(NSArray *)photosAtPlace
{
	NSMutableArray *photos = [NSMutableArray arrayWithCapacity:[photosAtPlace count]];
	for (id obj in photosAtPlace) {
		if (![obj isKindOfClass:[NSDictionary class]]) {
			NSLog(@"Non-dictionary returned from +photosAtPlace");
			continue;
		}
		NSDictionary *photoDict = (NSDictionary *)obj;
		DictPhoto *photo = [[DictPhoto alloc] initWithDictionary:photoDict];
		if (photo)
			[photos addObject:photo];
		[photo release];
	}
	
	[_photos release];
	_photos = [[NSArray arrayWithArray:photos] retain];
	[self.tableView reloadData];
}


- (void)reloadPhotosAsync
{
	if (!_place)
		return;

	[_photos release];
	_photos = nil;
	[self.tableView reloadData];
	
	dispatch_queue_t downloadPhotosAtPlaceQueue = dispatch_queue_create("Download Photos At Place", NULL);
	dispatch_queue_t currQueue = dispatch_get_current_queue();
	dispatch_async(downloadPhotosAtPlaceQueue, ^{
		[UIApplication showNetworkActivityIndicator];
		NSArray *photosAtPlace = [FlickrFetcher photosAtPlace:_place.uniqueId];
		//NSLog(@"photosAtPlace returned: %@", photosAtPlace);
		[UIApplication hideNetworkActivityIndicator];
		dispatch_async(currQueue, ^{ [self processPhotosAtPhotos:photosAtPlace]; });
	});
	dispatch_release(downloadPhotosAtPlaceQueue);
}


- (void)setup
{
	self.title = _place.name;
	self.tabBarItem = [[[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemRecents tag:0] autorelease];

	[self reloadPhotosAsync];
}


// fixme: I forgot which method is called when loaded from a nib, but we have to make sure -setup is called then as well
// fixme: does that also mess with our (new) designated initializer here?
- (id)initWithPlace:(DictPlace *)place manageObjectContext:(NSManagedObjectContext *)context
{
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		_place = [place retain];
		_context = [context retain];
		[self setup];
    }
    return self;
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


- (void)dealloc
{
	[_place release];
	[_photos release];
	[_context release];

	[super dealloc];
}


#pragma mark - View lifecycle

- (void)refreshButtonTapped
{ [self reloadPhotosAsync]; }


- (void)viewDidLoad
{
    [super viewDidLoad];
	
	UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
																				   target:self
																				   action:@selector(refreshButtonTapped)];
	self.navigationItem.rightBarButtonItem = refreshButton;
	[refreshButton release];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{ return YES; }


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{ return 1; }


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{ return [_photos count]; }


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section > 0 || indexPath.row >= [_photos count]) {
		NSLog(@"Invalid index path: %@", indexPath);
		return nil;
	}
	
	id possPhoto = [_photos objectAtIndex:indexPath.row];
	DictPhoto *photo = [possPhoto isKindOfClass:[DictPhoto class]] ? (DictPhoto *)possPhoto : nil;
	if (!photo) {
		NSLog(@"Non-nil photo expected at index: %i", indexPath.row);
		return nil;
	}

	BOOL requiresSubTitle = [photo.title length] > 0 && [photo.desc length] > 0;
	NSString *cellId = requiresSubTitle ? @"CellWithSubtitle" : @"Cell";
	UITableViewCellStyle cellStyle = requiresSubTitle ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:cellId] autorelease];
    }
    
    cell.textLabel.text = [photo.title length] > 0 ? photo.title
		: [photo.desc length] > 0 ? photo.desc
		: @"Unknown";
	if (requiresSubTitle)
		cell.detailTextLabel.text = photo.desc;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	if (photo.cachedThumbnailData)
		cell.imageView.image = [UIImage imageWithData:photo.cachedThumbnailData];
	else {
		cell.imageView.image = nil;
		[photo processThumbnailDataWithBlock:^(NSData *thumbnailData) {
			[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:NO];
		}];
	}
	
    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section > 0 || indexPath.row >= [_photos count]) {
		NSLog(@"Invalid index path: %@", indexPath);
		return;
	}

	id possPhoto = [_photos objectAtIndex:indexPath.row];
	if (![possPhoto isKindOfClass:[DictPhoto class]]) {
		NSLog(@"Non-DictPhoto (%@) at specified index path: %@", possPhoto, indexPath);
		return;
	}
	DictPhoto *dictPhoto = (DictPhoto *)possPhoto;

	Place *place = [Place placeFromDictPlace:_place inManagedObjectContext:_context];
	Photo *photo = [Photo photoWithDictPhoto:dictPhoto fromPlace:place inManagedObjectContext:_context];
	if (!photo) {
		NSLog(@"Could not create photo with id %@ in CoreData", dictPhoto.uniqueId);
		return;
	}
	
	NSError *error = nil;
	if ([_context hasChanges] && ![_context save:&error]) {
		NSLog(@"Error saving changes to managed object context: %@", error);
		return;
	}

    PhotoViewController *photoVC = [[PhotoViewController alloc] initWithPhoto:photo];
	[self.navigationController pushViewController:photoVC animated:YES];
	[photoVC release];
}


@end
