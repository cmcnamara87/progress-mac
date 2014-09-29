//
//  ApiManager.m
//  Progress
//
//  Created by Craig McNamara on 29/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "ApiManager.h"

static NSString * const BASE_URL_STRING = @"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com/progress/";
static NSString * const BASE_API_URL_STRING = @"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com/progress/api/index.php/";

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
    NSURL *baseUrl = [NSURL URLWithString:BASE_API_URL_STRING];
    self.manager = [[AFHTTPRequestOperationManager manager] initWithBaseURL:baseUrl];
    self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
  }
  return self;
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
  }];
}

@end
