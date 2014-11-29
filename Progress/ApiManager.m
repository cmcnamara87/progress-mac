//
//  ApiManager.m
//  Progress
//
//  Created by Craig McNamara on 29/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "ApiManager.h"
#import "NotificationManager.h"
#import "AppDelegate.h"


@interface ApiManager ()
@property (strong, nonatomic) AFHTTPRequestOperationManager *manager;
@property (strong, nonatomic) NSDictionary *currentUser;

// Rate limit progress
@property (strong, nonatomic) NSTimer *progressRateLimitTimer;
@property(nonatomic) BOOL isProgressRateLimited;
@end

@implementation ApiManager

+ (id)sharedManager {
  static ApiManager *sharedMyManager = nil;
  @synchronized(self) {
    if (sharedMyManager == nil)
      sharedMyManager = [[self alloc] init];
  }
  return sharedMyManager;
}

- (id)init {
  if (self = [super init]) {
    NSURL *baseUrl = [NSURL URLWithString:kApiUrl];
    self.manager = [[AFHTTPRequestOperationManager manager] initWithBaseURL:baseUrl];
    self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(HTTPOperationDidFinish:) name:AFNetworkingOperationDidFinishNotification object:nil];

  }
  return self;
}

- (void)HTTPOperationDidFinish:(NSNotification *)notification {
  AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
  
  if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
    return;
  }
  
  if ([operation.response statusCode] == 401) {
    // enqueue a new request operation here
    AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
    [appDelegate logIn:nil];
  }
}

- (void)loginEmail:(NSString*)email
          password:(NSString *)password
           success:(void (^)(NSDictionary *currentUser))success
           failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
  NSDictionary *parameters = @{@"email": email, @"password": password};
  [self.manager POST:@"users/login" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    self.currentUser = responseObject;
    success(responseObject);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't log in with %@", email);
    NSLog(@"Error: %@", error);
    if(failure) {
      failure(operation, error);
    }
  }];
}

- (void)getOnlineUsersSuccess:(void (^)(NSArray *onlineUsers))success
                      failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
  [self.manager GET:@"me/following/online" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
    success(responseObject);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't get online users");
    NSLog(@"Error: %@", error);
    if(failure) {
      failure(operation, error);
    }
  }];
}

- (void)getCurrentUserSuccess:(void (^)(NSDictionary *user))success
                      failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
  [self.manager GET:@"me/user" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
    success(responseObject);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't get current user %@", error);
    if(failure) {
      failure(operation, error);
    }
  }];
}

- (void)logout
{
  [self.manager POST:@"users/logout"
          parameters:nil
             success:nil
             failure:^(AFHTTPRequestOperation *operation, NSError *error) {
               NSLog(@"Error: Couldn't log out %@", error);
             }];
}

- (void)getProjectsSuccess:(void (^)(NSArray *projects))success
                   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
  [self.manager GET:@"me/projects" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
    success(responseObject);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't get projects %@", error);
    if(failure) {
      failure(operation, error);
    }
  }];
}


- (void)addDirectoryPath:(NSString *)path
               toProject:(NSDictionary *)project
                 success:(void (^)(NSDictionary *project))success
                 failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
  NSDictionary *parameters = @{@"path": path};
  NSString *url = [NSString stringWithFormat:@"me/projects/%@/directories", [project objectForKey:@"id"]];
  
  [self.manager POST:url parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    success(project);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't add directory %@ to project Id %@, %@", path, [project objectForKey:@"id"], error);
    if(failure) {
      failure(operation, error);
    }
  }];
}

- (void)addProjectName:(NSString *)name
               success:(void (^)(NSDictionary *project))success
               failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
  NSDictionary *parameters = @{@"name": name};
  [self.manager POST:@"me/projects" parameters:parameters success:^(AFHTTPRequestOperation *operation, id project) {
    success(project);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't create project, %@", error);
    if(failure) {
      failure(operation, error);
    }
  }];
}

- (void)sendProgressForProject:(NSDictionary *)project
{
  if(self.isProgressRateLimited) {
    NSLog(@"Debug: Gobbling progress.");
    if(!self.progressRateLimitTimer) {
      self.progressRateLimitTimer = [NSTimer scheduledTimerWithTimeInterval:(2*60)
                                                                     target:self
                                                                   selector:@selector(sendProgressNowTimer:)
                                                                   userInfo:@{@"project": project}
                                                                    repeats:NO];
    }
    return;
  }
  
  [self sendProgressNowForProject:project];
  self.isProgressRateLimited = YES;
}

- (void)sendProgressNowTimer:(NSTimer *)progressTimer
{
  NSDictionary *project = [[progressTimer userInfo] objectForKey:@"project"];
  [self sendProgressNowForProject:project];
  
  [self.progressRateLimitTimer invalidate];
  self.progressRateLimitTimer = nil;
  self.isProgressRateLimited = NO;
}

- (void)sendProgressNowForProject:(NSDictionary *)project
{
  NSString *url = [NSString stringWithFormat:@"me/projects/%@/progress", [project objectForKey:@"id"]];
  [self.manager POST:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
    NSLog(@"Debug: Added progress for project id %@", [project objectForKey:@"id"]);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't send progress for project, %@ %@", project, error);
    // SHow the login window
//    [appDelegate logIn:nil];
  }];
}




- (void)uploadScreenshot:(NSMetadataItem *)screenshot
              forProject:(NSDictionary *)project
                    text:(NSString *)text
                 success:(void (^)(NSDictionary *post))success
                 failure:(void (^)(NSError *error))failure;
{
  NSString *fileName = [screenshot valueForAttribute:(NSString *)kMDItemFSName];
  NSString *path = [screenshot valueForAttribute:(NSString *)kMDItemPath];
//  NSDate *creationDate = [screenshot valueForAttribute:(NSString *)kMDItemContentCreationDate];
  
  [[NotificationManager sharedManager] showUploadingScreenshot];
  
  //  NSString* apiUrl = @"http://example.com/upload";
  
  // Prepare a temporary file to store the multipart request prior to sending it to the server due to an alleged
  // bug in NSURLSessionTask.
  NSString* tmpFilename = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
  NSURL* tmpFileUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tmpFilename]];
  
  
  NSString *url = [NSString stringWithFormat:@"%@me/projects/%@/screenshots", kApiUrl, [project objectForKey:@"id"]];
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
                                                                                                
                                                                                                if(error) {
                                                                                                                                                                                          NSLog(@"Error: %@", error);
                                                                                                  if(failure) {
                                                                                                    
                                                                                                  failure(error);                                                                                                  }

                                                                                                  return;
                                                                                                }
                                                                                                
                                                                                                success(responseObject);
                                                                                                
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
