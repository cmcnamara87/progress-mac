//
//  ScreenshotManager.m
//  Progress
//
//  Created by Craig McNamara on 24/08/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "ScreenshotManager.h"
#import "ApiManager.h"
#import "AppDelegate.h"

@interface ScreenshotManager ()
@property (nonatomic, strong) NSMetadataQuery *metadataSearch;
@property (nonatomic, strong) NSDate *newestScreenshotCreationDate;
@property (strong, nonatomic) NSTimer *screenshotTimer;
@property (strong, nonatomic) NSDictionary *activeProject;

@property (strong, nonatomic) NotificationManager *notificationManager;
@end

@implementation ScreenshotManager

- initWithNotificationManager:(NotificationManager *)notificationManager
{
  if (self = [super init]) {
    self.notificationManager = notificationManager;
    
    self.metadataSearch = [[NSMetadataQuery alloc] init];
    
    // Register the notifications for batch and completion updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(foundScreenshots:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:_metadataSearch];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(foundScreenshots:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:_metadataSearch];
    
    [self.metadataSearch setPredicate:[NSPredicate predicateWithFormat:@"kMDItemIsScreenCapture = 1"]];
    NSSortDescriptor *sortKeys = [[NSSortDescriptor alloc] initWithKey:(id)kMDItemFSCreationDate
                                                             ascending:YES];
    [self.metadataSearch setSortDescriptors:[NSArray arrayWithObject:sortKeys]];
    [self.metadataSearch stopQuery];
    
  }
  return self;
}

- (void)startWatchingForProject:(NSDictionary *)project
{
  if([self.activeProject objectForKey:@"id"] == [project objectForKey:@"id"]) {
    return;
  }
  
  self.activeProject = project;
  [self startScreenshotNotificationTimer];
  [self.metadataSearch startQuery];
}

- (void)stopWatching
{
  [self.metadataSearch stopQuery];
  [self.screenshotTimer invalidate];
  self.screenshotTimer = nil;
  self.activeProject = nil;
}

- (void)startScreenshotNotificationTimer
{
  [self.screenshotTimer invalidate];
  self.screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:(30*60)
                                                          target:self
                                                        selector:@selector(showTakeScreenshotNotification:)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)showTakeScreenshotNotification:(NSTimer *)timer
{
  [[NotificationManager sharedManager] showTakeScreenshot];
  
  // Lower the timer to 15 mins (if they take a screenshot, we will up it to 30 again)
  [self.screenshotTimer invalidate];
  self.screenshotTimer = [NSTimer scheduledTimerWithTimeInterval:(15*60)
                                                          target:self
                                                        selector:@selector(showTakeScreenshotNotification:)
                                                        userInfo:nil
                                                         repeats:YES];

}


- (void)foundScreenshots:(NSNotification *)sender
{
  NSLog(@"Debug: Finished finding screenshots %lu", (unsigned long)[self.metadataSearch resultCount]);
  // Stop the search while we handle this
  [self.metadataSearch disableUpdates];
  
  if(![self.metadataSearch resultCount]) {
    NSLog(@"Debug: No screenshots found %lu", (unsigned long)[self.metadataSearch resultCount]);
    [self.metadataSearch enableUpdates];
    return;
  }
  
  if ([[sender name] isEqualToString:NSMetadataQueryDidFinishGatheringNotification]) {
    NSMetadataItem *newestScreenshot = [self.metadataSearch resultAtIndex:([self.metadataSearch resultCount] - 1)];
    self.newestScreenshotCreationDate = [newestScreenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
    [self.metadataSearch enableUpdates];
    NSLog(@"Debug: Updating reference screenshot, date %@", self.newestScreenshotCreationDate);
    return;
  }
  
  
  NSUInteger i=0;
  BOOL hasNewScreenshot = false;
  NSMetadataItem *screenshot;
  for (i=0; i < [self.metadataSearch resultCount]; i++) {
    screenshot = [self.metadataSearch resultAtIndex:i];
    NSDate *creationDate = [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
    if (!self.newestScreenshotCreationDate || [creationDate compare:self.newestScreenshotCreationDate] == NSOrderedDescending) {
      
      NSLog(@"Debug: New screenshot found, uploading screenshot path %@, date %@", [screenshot valueForAttribute:(NSString *)kMDItemPath], [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate]);
      
      hasNewScreenshot = true;
      [self uploadScreenshot:screenshot];
      break;
    }
  }
  
  if(!hasNewScreenshot) {
    NSLog(@"Debug: No new screenshot found, last screenshot path %@, date %@", [screenshot valueForAttribute:(NSString *)kMDItemPath], [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate]);
    [self.metadataSearch enableUpdates];
  }
}

- (void)uploadScreenshot:(NSMetadataItem *)screenshot
{
  [self startScreenshotNotificationTimer];
  
  NSString *path = [screenshot valueForAttribute:(NSString *)kMDItemPath];
  NSLog(@"Showing screenshot modal %@", path);

  NSAlert *alert = [NSAlert alertWithMessageText:@"Progress"
                                   defaultButton:@"Upload"
                                 alternateButton:@"Cancel"
                                     otherButton:nil
                       informativeTextWithFormat:@"Upload your screenshot for '%@'?", [self.activeProject objectForKey:@"name"]];
  [alert setIcon:[[NSImage alloc] initWithContentsOfFile:path]];
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  [[input cell] setPlaceholderString:@"What's this about?"];
  [input setStringValue:@""];
  
  [alert setAccessoryView:input];
  
  NSInteger button = [alert runModal];
  
  // Mark this screenshot as done!
  NSDate *creationDate = [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
  self.newestScreenshotCreationDate = creationDate;
  [self.metadataSearch enableUpdates];
  
  if (button == NSAlertDefaultReturn) {
    [[ApiManager sharedManager] uploadScreenshot:screenshot forProject:self.activeProject text:[input stringValue] success:^(NSDictionary *post) {
      // FIXME: move this into the screenshot manager
      [[NotificationManager sharedManager] showScreenshotUploaded];
      // Do something with the result.
      self.newestScreenshotCreationDate = creationDate;
      NSLog(@"Success, Creation date updated: %@", post);
    } failure:^(NSError *error) {
      
    }];
  }
}


@end
