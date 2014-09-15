//
//  NotificationManager.h
//  Progress
//
//  Created by Craig McNamara on 9/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NotificationManager : NSObject <NSUserNotificationCenterDelegate>

+ (id)sharedManager;

- (void)showUser:(NSString *)name isWorkingOn:(NSString *)projectName;
- (void)showTakeScreenshot;
- (void)showLoggedIn;
- (void)showStartAddingProjects;
- (void)showNowTracking:(NSArray *)projects;
- (void)showUploadingScreenshot;
- (void)showScreenshotUploaded;
@end
