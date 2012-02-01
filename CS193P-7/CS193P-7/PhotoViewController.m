//
//  PhotoViewController.m
//  CS193P-5
//
//  Created by Ed Sibbald on 11/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "PhotoViewController.h"

#import "UIApplication+NetworkActivity.h"

#import "FlickrFetcher.h"
#import "Place.h"
#import "Photo.h"


@interface PhotoViewController ()
@property (readonly) NSString *favoritePhotoFilePath;
@property (readonly) UIScrollView *scrollView;
@property (readonly) UIImageView *imageView;
@end


@implementation PhotoViewController

@synthesize photo = _photo;

- (NSString *)favoritePhotoFilePath
{
	NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [docsPath stringByAppendingPathComponent:_photo.unique_id];
}


- (UIScrollView *)scrollView
{
	UIView *view = self.view;
	return [view isKindOfClass:[UIScrollView class]] ? (UIScrollView *)view : nil;
}


- (UIImageView *)imageView
{
	NSArray *subviews = self.scrollView.subviews;
	return subviews.count > 0 ? [subviews objectAtIndex:0] : nil;
}


- (id)initWithPhoto:(Photo *)aPhoto
{
	self = [super init];
	if (self) {
		_photo = [aPhoto retain];
		self.title = !_photo ? @"No photo" : [_photo.title length] == 0 ? @"No title" : _photo.title;
		
		if (_photo) {
			_photo.last_viewed = [NSDate date];
			NSError *error = nil;
			if (![_photo.managedObjectContext save:&error])
				NSLog(@"Error updating last viewed time: %@", error);
		}
	}
	return self;
}

- (void)dealloc
{
	[_imageData release];
	[_photo release];
	[super dealloc];
}

#pragma mark - View lifecycle

- (BOOL)loadImageDataWithBlock:(void (^)(NSData *))loadImageData
{
	if (_imageData) {
		loadImageData(_imageData);
		return YES;
	}
	
	dispatch_queue_t loadImageDataQueue = dispatch_queue_create("Load Image Data", NULL);

	// don't access CoreData object from another thread!
	BOOL isFavorite = [self.photo.favorite boolValue];
	NSString *photoUrl = self.photo.url;
	dispatch_queue_t currQueue = dispatch_get_current_queue();

	dispatch_async(loadImageDataQueue, ^{
		if (isFavorite) {
			_imageData = [[NSData alloc] initWithContentsOfFile:self.favoritePhotoFilePath];
			if (_imageData)
				NSLog(@"Failed to load favorited image data from file: %@", self.favoritePhotoFilePath);
		}
		
		if (!_imageData) {
			[UIApplication showNetworkActivityIndicator];
			_imageData = [[FlickrFetcher imageDataForPhotoWithURLString:photoUrl] retain];
			[UIApplication hideNetworkActivityIndicator];
		}

		dispatch_async(currQueue, ^{ loadImageData(_imageData); }); // run this back on the original thread
	});

	dispatch_release(loadImageDataQueue);

	return NO;
}


- (void)updateZoomScalesAndResetZoom:(BOOL)reset
{
	if (![self.view isKindOfClass:[UIScrollView class]])
		return;
	
	UIScrollView *scrollView = self.scrollView;
	
	CGSize scrollViewSize = scrollView.bounds.size;
	double scrollAspect = scrollViewSize.width / scrollViewSize.height;
	CGSize imageViewSize = self.imageView.bounds.size;
	double imageAspect = imageViewSize.width / imageViewSize.height;
	
	scrollView.minimumZoomScale = imageAspect > scrollAspect
		? scrollViewSize.width / imageViewSize.width
		: scrollViewSize.height / imageViewSize.height;
	scrollView.maximumZoomScale = 2.0;
	
	if (reset) {
		scrollView.zoomScale = imageAspect > scrollAspect
			? scrollViewSize.height / imageViewSize.height
			: scrollViewSize.width / imageViewSize.width;
	}
}


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
	// how would i just pass a selector in here?
	BOOL imageLoaded = [self loadImageDataWithBlock:^(NSData *imageData) { 
		UIImage *image = [[UIImage alloc] initWithData:imageData];
		UIView *imageView = [[UIImageView alloc] initWithImage:image];
		[image release];
		
		UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
		scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		scrollView.delegate = self;
		scrollView.minimumZoomScale = 0.1;
		scrollView.maximumZoomScale = 2.0;
		scrollView.backgroundColor = [UIColor blackColor];
		[scrollView addSubview:imageView];
		scrollView.contentSize = imageView.bounds.size;
		[imageView release];
		
		self.view = scrollView;
		[scrollView release];
		
		[self updateZoomScalesAndResetZoom:YES];
	}];
	if (imageLoaded)
		return;

	// load up our spinner
	UIActivityIndicatorView *activityIndicatorView =
		[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	activityIndicatorView.backgroundColor = [UIColor blackColor];
	activityIndicatorView.frame = [[UIScreen mainScreen] applicationFrame];
	activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.view = activityIndicatorView;
	[activityIndicatorView startAnimating];
	[activityIndicatorView release];
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{ return self.imageView; }


- (void)updateFavoriteButton
{
	UIBarButtonItem *favButton = nil;
	if ([_photo.favorite boolValue])
		favButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
																  target:self
																  action:@selector(removeButtonTapped)];
	else
		favButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
																  target:self
																  action:@selector(addButtonTapped)];
	self.navigationItem.rightBarButtonItem = favButton;
	[favButton release];
}


- (void)addButtonTapped
{
	_photo.favorite = [NSNumber numberWithBool:YES];
	_photo.place.favorite = [NSNumber numberWithBool:YES];
	NSError *error = nil;
	if (![_photo.managedObjectContext save:&error]) {
		NSLog(@"Error setting favorite flag for photo with id %@: %@", _photo.unique_id, error);
		return;
	}
	
	NSString *filePath = self.favoritePhotoFilePath;
	dispatch_queue_t savePhotoFileQueue = dispatch_queue_create("Save Photo File", NULL);
	dispatch_async(savePhotoFileQueue, ^{ [_imageData writeToFile:filePath atomically:YES]; });
	dispatch_release(savePhotoFileQueue);
	
	[self updateFavoriteButton];
}


- (void)removeButtonTapped
{
	_photo.favorite = [NSNumber numberWithBool:NO];
	// unset flag on place if need be
	BOOL otherFavPhotoExists = NO;
	for (Photo *photo in _photo.place.photos) {
		if ([photo.favorite boolValue]) {
			otherFavPhotoExists = YES;
			break;
		}
	}
	_photo.place.favorite = [NSNumber numberWithBool:otherFavPhotoExists];
	
	NSError *error = nil;
	if (![_photo.managedObjectContext save:&error]) {
		NSLog(@"Error unsetting favorite flag for photo with id %@: %@", _photo.unique_id, error);
		return;
	}

	dispatch_queue_t deletePhotoFileQueue = dispatch_queue_create("Delete Photo File", NULL);
	dispatch_async(deletePhotoFileQueue, ^{
		NSError *error = nil;
		[[NSFileManager defaultManager] removeItemAtPath:self.favoritePhotoFilePath error:&error];
		if (error)
			NSLog(@"Error deleting locally cached data for photo with id %@", _photo.unique_id);
	});
	dispatch_release(deletePhotoFileQueue);
	
	[self updateFavoriteButton];
}


- (void)viewDidLoad
{
	[super viewDidLoad];
	[self updateFavoriteButton];
}


- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self updateZoomScalesAndResetZoom:YES];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{ return YES; }


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[self updateZoomScalesAndResetZoom:NO];
}

@end
