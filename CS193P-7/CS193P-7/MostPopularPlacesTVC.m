//
//  PlacesTableViewController.m
//  CS193P-5
//
//  Created by Ed Sibbald on 11/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MostPopularPlacesTVC.h"

#import "FlickrFetcher.h"
#import "DictPlace.h"
#import "DictPhoto.h"
#import "MostPopularPhotosTVC.h"


@implementation MostPopularPlacesTVC

- (void)dealloc
{
	[_places release];
	[_context release];

	[super dealloc];
}


- (void)processTopPlaces:(NSArray *)topPlaces
{
	NSMutableArray *unsortedPlaces = [NSMutableArray arrayWithCapacity:[topPlaces count]];
	
	for (id obj in topPlaces) {
		if (![obj isKindOfClass:[NSDictionary class]]) {
			NSLog(@"Non-dictionary returned from +topPlaces");
			continue;
		}
		NSDictionary *topPlace = (NSDictionary *)obj;
		DictPlace *place = [[DictPlace alloc] initWithDictionary:topPlace];
		if (place)
			[unsortedPlaces addObject:place];
		[place release];
	}
	
	NSMutableArray *sortDescriptors = [NSMutableArray array];
	[sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
	[sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES]];
	
	[_places release];
	_places = [[unsortedPlaces sortedArrayUsingDescriptors:sortDescriptors] retain];
	[self.tableView reloadData];
}


- (void)reloadPlacesAsync
{
	[_places release];
	_places = nil;
	[self.tableView reloadData];
	
	dispatch_queue_t downloadTopPlacesQueue = dispatch_queue_create("Download Top Places", NULL);
	dispatch_queue_t currQueue = dispatch_get_current_queue();
	dispatch_async(downloadTopPlacesQueue, ^{
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		NSArray *topPlaces = [FlickrFetcher topPlaces];
		//NSLog(@"topPlaces returned: %@", topPlaces);
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		dispatch_async(currQueue, ^{ [self processTopPlaces:topPlaces]; });
	});
	dispatch_release(downloadTopPlacesQueue);
}


- (void)setup
{
	self.title = @"Popular Places";
	self.tabBarItem = [[[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMostViewed tag:0] autorelease];

	[self reloadPlacesAsync];
}


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    if (self = [super initWithStyle:UITableViewStylePlain]) {
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


#pragma mark - View lifecycle

- (void)refreshButtonTapped
{ [self reloadPlacesAsync]; }


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

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
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
	if (section != 0)
		return 0;
    return [_places count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    static NSString *CellWithDetailIdentifier = @"CellWithDetail";

    DictPlace *place = indexPath.section == 0 ? (DictPlace *)[_places objectAtIndex:indexPath.row] : nil;
	BOOL hasDetail = place.desc && [place.desc length] > 0;

    NSString *currentCellIdentifier = hasDetail ? CellWithDetailIdentifier : CellIdentifier;
	UITableViewCellStyle currentCellStyle = hasDetail ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:currentCellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:currentCellStyle reuseIdentifier:currentCellIdentifier] autorelease];
    }
    
    // Configure the cell...
	cell.textLabel.text = place.name;
	cell.detailTextLabel.text = place.desc;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section != 0 || indexPath.row >= [_places count]) {
		NSLog(@"Invalid selected indexPath: %@", indexPath);
		return;
	}
	
	DictPlace *selectedPlace = [_places objectAtIndex:indexPath.row];
	if (!selectedPlace) {
		NSLog(@"Nil place at position: %i", indexPath.row);
		return;
	}
	
	MostPopularPhotosTVC *photosTVC = [[MostPopularPhotosTVC alloc] initWithPlace:selectedPlace
															  manageObjectContext:_context];
	[self.navigationController pushViewController:photosTVC animated:YES];
	[photosTVC release];
}

@end
