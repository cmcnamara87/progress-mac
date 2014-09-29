//
//  ScreenshotManager.h
//  Progress
//
//  Created by Craig McNamara on 24/08/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NotificationManager.h"

@interface ScreenshotManager : NSObject

- initWithNotificationManager:(NotificationManager *)notificationManager;

- (void)startWatchingForProject:(NSDictionary *)project;
- (void)stopWatching;
@end
