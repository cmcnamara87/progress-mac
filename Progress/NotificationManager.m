//
//  NotificationManager.m
//  Progress
//
//  Created by Craig McNamara on 9/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "NotificationManager.h"
#import "AppDelegate.h"

@implementation NotificationManager

+ (id)sharedManager {
  static NotificationManager *sharedMyManager = nil;
  @synchronized(self) {
    if (sharedMyManager == nil)
      sharedMyManager = [[self alloc] init];
  }
  return sharedMyManager;
}

- (void)_showNotificationWithTitle:(NSString *)title text:(NSString *)text userInfo:(NSDictionary *)userInfo
{
  //Initalize new notification
  NSUserNotification *notification = [[NSUserNotification alloc] init];
  //Set the title of the notification
  [notification setTitle:title];
  //Set the text of the notification
  [notification setInformativeText:text];
  notification.userInfo = userInfo;
  //Set the time and date on which the nofication will be deliverd (for example 20 secons later than the current date and time)
  [notification setDeliveryDate:[NSDate dateWithTimeInterval:1 sinceDate:[NSDate date]]];
  //Set the sound, this can be either nil for no sound, NSUserNotificationDefaultSoundName for the default sound (tri-tone) and a string of a .caf file that is in the bundle (filname and extension)
  //        [notification setSoundName:NSUserNotificationDefaultSoundName];
  [notification setSoundName:NSUserNotificationDefaultSoundName];
  
  //Get the default notification center
  NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
  center.delegate = self;
  //Scheldule our NSUserNotification
  [center scheduleNotification:notification];
  
}

- (void) userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
  NSString *urlString;
  if(notification.userInfo && [notification.userInfo objectForKey:@"project"]) {
    NSDictionary *project = [notification.userInfo objectForKey:@"project"];
    urlString = [NSString stringWithFormat:@"http://cmcnamara87.github.io/progress/#/users/%@/diary/%@", [project objectForKey:@"userId"],  [project objectForKey:@"id"]];
  } else {
    urlString = @"http://cmcnamara87.github.io/progress/#/me/feed";
  }

  NSURL *URL = [NSURL URLWithString:urlString];
  [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (void)showTakeScreenshot
{
  [self _showNotificationWithTitle:@"You're making progress!" text:@"Share a screenshot to keep track - Press CMD+SHIFT+4" userInfo:nil];
}

- (void)showUser:(NSString *)name isWorkingOn:(NSDictionary *)project
{
  [self _showNotificationWithTitle:[NSString stringWithFormat:@"%@ started working", name] text:[NSString stringWithFormat:@"on %@", [project objectForKey:@"name"]] userInfo:@{@"project": project}];
}

- (void)showLoggedIn
{
  [self _showNotificationWithTitle:@"Log in successful" text:@"Setting up projects" userInfo:nil];
}

- (void)showNowTracking:(NSArray *)projects
{
  [self _showNotificationWithTitle:@"Now watching for any progress" text:[NSString stringWithFormat:@"Watching %lu projects", (unsigned long)[projects count]] userInfo:nil];
}

- (void)showStartAddingProjects
{
  [self _showNotificationWithTitle:@"Get Started!" text:@"Add projects from the Menu bar" userInfo:nil];
}

- (void)showUploadingScreenshot
{
  [self _showNotificationWithTitle:@"Uploading Picture" text:@"Now uploading..." userInfo:nil];
}
- (void)showScreenshotUploaded
{
  [self _showNotificationWithTitle:@"Picture uploaded" text:@"Click to view" userInfo:nil];
}
- (void)showProjectCreated:(NSDictionary *)project
{
  [self _showNotificationWithTitle:@"Project Created" text:@"Click to view" userInfo:@{@"project": project}];
}
@end
