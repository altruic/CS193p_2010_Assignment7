//
//  UIApplication+NetworkActivity.h
//  CS193P-7
//
//  Created by Ed Sibbald on 1/21/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIApplication (NetworkActivity)
+ (void)showNetworkActivityIndicator;
+ (void)hideNetworkActivityIndicator;
@end
