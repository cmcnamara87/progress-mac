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
@end

@implementation ScreenshotManager


+ (id)sharedManager {
  static ScreenshotManager *sharedMyManager = nil;
  @synchronized(self) {
    if (sharedMyManager == nil)
      sharedMyManager = [[self alloc] init];
  }
  return sharedMyManager;
}


- (void)startWatching
{
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
  NSLog(@"Found screensht!");
    // Stop the search while we handle this
  [self.metadataSearch disableUpdates];
  
  
  if ([[sender name] isEqualToString:NSMetadataQueryDidFinishGatheringNotification]) {
    NSMetadataItem *newestScreenshot = [self.metadataSearch resultAtIndex:([self.metadataSearch resultCount] - 1)];
    self.newestScreenshotCreationDate = [newestScreenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
    [self.metadataSearch enableUpdates];
    return;
  }
  

  NSUInteger i=0;
  for (i=0; i < [self.metadataSearch resultCount]; i++) {
    NSMetadataItem *screenshot = [self.metadataSearch resultAtIndex:i];
    NSDate *creationDate = [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
    if ([creationDate compare:self.newestScreenshotCreationDate] == NSOrderedDescending) {
      [self uploadScreenshot:screenshot];
      self.newestScreenshotCreationDate = creationDate;
    }
  }
  /*
   NSMetadataItem *newestScreenshot = [self.metadataSearch resultAtIndex:([self.metadataSearch resultCount] - 1)];
   //    NSString *path = [newestScreenshot valueForAttribute:(NSString *)kMDItemPath];
   //
   NSDate *creationDate = [newestScreenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];  NSLog(@"finished gathereing! %@", creationDate);
   */
  

  
  // Popup alert

  
  [self.metadataSearch enableUpdates];
}

- (void)uploadScreenshot:(NSMetadataItem *)screenshot
{
  NSString *path = [screenshot valueForAttribute:(NSString *)kMDItemPath];
  NSString *fileName = [screenshot valueForAttribute:(NSString *)kMDItemFSName];
  
  AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
  NSAlert *alert = [NSAlert alertWithMessageText:@"Progress"
                                   defaultButton:@"Upload"
                                 alternateButton:@"Cancel"
                                     otherButton:nil
                       informativeTextWithFormat:@"Upload your screenshot for '%@'?", [appDelegate.activeProject objectForKey:@"name"]];
  [alert setIcon:[[NSImage alloc] initWithContentsOfFile:path]];
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  [[input cell] setPlaceholderString:@"What's this about?"];
  [input setStringValue:@""];
  
  [alert setAccessoryView:input];
  
  NSInteger button = [alert runModal];
  
  if (button == NSAlertDefaultReturn) {
    [self uploadFilePath:path fileName:fileName forProject:appDelegate.activeProject text:[input stringValue]];
  }
}

- (void)uploadFilePath:(NSString *)path fileName:(NSString *)fileName forProject:(NSDictionary *)project text:(NSString *)text
{
  
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
                                                                                                
                                                                                                // Do something with the result.
                                                                                                if (error) {
                                                                                                  NSLog(@"Error: %@", error);
                                                                                                } else {
                                                                                                  NSLog(@"Success: %@", responseObject);
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
