//
//  UIApplication+NetworkActivity.m
//  CS193P-7
//
//  Created by Ed Sibbald on 1/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "UIApplication+NetworkActivity.h"


static int activityCount = 0;

@implementation UIApplication (NetworkActivity)

+ (void)showNetworkActivityIndicator
{
	UIApplication *application = [UIApplication sharedApplication];
	if ([application isStatusBarHidden]) return;
	@synchronized (application) {
		if (activityCount == 0)
			[application setNetworkActivityIndicatorVisible:YES];
		++activityCount;
	}
}


+ (void)hideNetworkActivityIndicator
{
	UIApplication *application = [UIApplication sharedApplication];
	if ([application isStatusBarHidden]) return;
	@synchronized (application) {
		--activityCount;
		if (activityCount <= 0) {
			[application setNetworkActivityIndicatorVisible:NO];
			activityCount = 0;
		}
	}
}

@end
