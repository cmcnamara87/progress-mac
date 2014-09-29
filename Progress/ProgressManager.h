//
//  ProgressManager.h
//  Progress
//
//  Created by Craig McNamara on 29/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ApiManager.h"
#import "ScreenshotManager.h"

@interface ProgressManager : NSObject

- (id)initWithApiManager:(ApiManager *)apiManager
       screenshotManager:(ScreenshotManager *)screenshotManager;
- (void)addProject:(NSDictionary *)project;
- (void)addDirectories:(NSArray *)path toProject:(NSDictionary *)project;

@property(strong, nonatomic) NSStatusItem *statusItem;

@end
