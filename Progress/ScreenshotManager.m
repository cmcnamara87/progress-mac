//
//  ScreenshotManager.m
//  Progress
//
//  Created by Craig McNamara on 24/08/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "ScreenshotManager.h"
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
  }
  return self;
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
  
  [self.screenshotTimer invalidate];
  self.screenshotTimer = nil;
}



- (void)startWatchingForProject:(NSDictionary *)project
{
  self.activeProject = project;
  [self startScreenshotNotificationTimer];
  
  if(self.metadataSearch) {
    return;
  }
  
  
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
  [self.metadataSearch startQuery];
}

- (void)stopWatching
{
  [self.metadataSearch disableUpdates];
  self.metadataSearch = nil;
}

- (void)foundScreenshots:(NSNotification *)sender
{
  NSLog(@"Finished finding screenshots %lu", (unsigned long)[self.metadataSearch resultCount]);
  // Stop the search while we handle this
  [self.metadataSearch disableUpdates];
  
  if(![self.metadataSearch resultCount]) {
    NSLog(@"No screenshots found %lu", (unsigned long)[self.metadataSearch resultCount]);
    [self.metadataSearch enableUpdates];
    return;
  }
  
  if ([[sender name] isEqualToString:NSMetadataQueryDidFinishGatheringNotification]) {
    NSMetadataItem *newestScreenshot = [self.metadataSearch resultAtIndex:([self.metadataSearch resultCount] - 1)];
    self.newestScreenshotCreationDate = [newestScreenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
    [self.metadataSearch enableUpdates];
    NSLog(@"Updating reference screenshot, date %@", self.newestScreenshotCreationDate);
    return;
  }
  
  
  NSUInteger i=0;
  BOOL hasNewScreenshot = false;
  NSMetadataItem *screenshot;
  for (i=0; i < [self.metadataSearch resultCount]; i++) {
    screenshot = [self.metadataSearch resultAtIndex:i];
    NSDate *creationDate = [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
    if (!self.newestScreenshotCreationDate || [creationDate compare:self.newestScreenshotCreationDate] == NSOrderedDescending) {
      
      NSLog(@"New screenshot found, uploading screenshot path %@, date %@", [screenshot valueForAttribute:(NSString *)kMDItemPath], [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate]);
      
      hasNewScreenshot = true;
      [self uploadScreenshot:screenshot];
      break;
    }
  }
  
  if(!hasNewScreenshot) {
    NSLog(@"No new screenshot found, last screenshot path %@, date %@", [screenshot valueForAttribute:(NSString *)kMDItemPath], [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate]);
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
    [self uploadScreenshot:screenshot forProject:self.activeProject text:[input stringValue]];
  }
}

- (void)uploadScreenshot:(NSMetadataItem *)screenshot forProject:(NSDictionary *)project text:(NSString *)text
{
  NSString *fileName = [screenshot valueForAttribute:(NSString *)kMDItemFSName];
  NSString *path = [screenshot valueForAttribute:(NSString *)kMDItemPath];
  NSDate *creationDate = [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
  
  [[NotificationManager sharedManager] showUploadingScreenshot];
  
  //  NSString* apiUrl = @"http://example.com/upload";
  
  // Prepare a temporary file to store the multipart request prior to sending it to the server due to an alleged
  // bug in NSURLSessionTask.
  NSString* tmpFilename = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
  NSURL* tmpFileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tmpFilename]];
  
  
  NSString *url = [NSString stringWithFormat:@"%@me/projects/%@/screenshots", BASE_API_URL_STRING, [project objectForKey:@"id"]];
  NSLog(@"Sending screenshot to %@", url);
  NSMutableURLRequest *multipartRequest = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST"
                                                                                                     URLString:url
                                                                                                    parameters:@{@"text": text}
                                                                                     constructingBodyWithBlock:^(id<AFMultipartFormData> formData)
                                           {
                                             [formData appendPartWithFileURL:[NSURL fileURLWithPath:path] name:@"file" fileName:fileName mimeType:@"image/jpeg" error:nil];
                                           } error:nil];
  
  
  // Dump multipart request into the temporary file.
  [[AFHTTPRequestSerializer serializer] requestWithMultipartFormRequest:multipartRequest
                                            writingStreamContentsToFile:tmpFileUrl
                                                      completionHandler:^(NSError *error) {
                                                        // Once the multipart form is serialized into a temporary file, we can initialize
                                                        // the actual HTTP request using session manager.
                                                        
                                                        // Create default session manager.
                                                        AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
                                                        
                                                        // Show progress.
                                                        NSProgress *progress = nil;
                                                        // Here note that we are submitting the initial multipart request. We are, however,
                                                        // forcing the body stream to be read from the temporary file.
                                                        NSURLSessionUploadTask *uploadTask = [manager uploadTaskWithRequest:multipartRequest
                                                                                                                   fromFile:tmpFileUrl
                                                                                                                   progress:&progress
                                                                                                          completionHandler:^(NSURLResponse *response, id responseObject, NSError *error)
                                                                                              {
                                                                                                // Cleanup: remove temporary file.
                                                                                                [[NSFileManager defaultManager] removeItemAtURL:tmpFileUrl error:nil];
                                                                                                
                                                                                                [[NotificationManager sharedManager] showScreenshotUploaded];
                                                                                                // Do something with the result.
                                                                                                if (error) {
                                                                                                  NSLog(@"Error: %@", error);
                                                                                                } else {
                                                                                                  self.newestScreenshotCreationDate = creationDate;
                                                                                                  NSLog(@"Success, Creation date updated: %@", responseObject);
                                                                                                }
                                                                                              }];
                                                        
                                                        // Add the observer monitoring the upload progress.
                                                        //                                                        [progress addObserver:self
                                                        //                                                                   forKeyPath:@"fractionCompleted"
                                                        //                                                                      options:NSKeyValueObservingOptionNew
                                                        //                                                                      context:NULL];
                                                        
                                                        
                                                        // Start the file upload.
                                                        [uploadTask resume];
                                                      }];
  
  //  @"me/projects/%@/progress", [project objectForKey:@"id"]];
  
  
  //  requestWithMultipartFormRequest:writingStreamContentsToFile:completionHandler:
  
  // Hopefully this fixes it
  //  [request setValue:0 forHTTPHeaderField:@"Content-Length"];
  
  //  AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  //  NSProgress *progress = nil;
  //
  //  NSURLSessionUploadTask *uploadTask = [manager uploadTaskWithStreamedRequest:request progress:&progress completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
  //    if (error) {
  //      NSLog(@"Error: %@", error);
  //    } else {
  //      [self openWebApp:nil];
  //    }
  //  }];
  //  [uploadTask resume];
}


@end
