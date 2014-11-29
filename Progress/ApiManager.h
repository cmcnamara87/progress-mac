//
//  ApiManager.h
//  Progress
//
//  Created by Craig McNamara on 29/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

@interface ApiManager : NSObject

+ (id)sharedManager;


- (void)loginEmail:(NSString*)email
          password:(NSString *)password
           success:(void (^)(NSDictionary *currentUser))success
           failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (void)getCurrentUserSuccess:(void (^)(NSDictionary *user))success
                      failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (void)getOnlineUsersSuccess:(void (^)(NSArray *onlineUsers))success
                      failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (void)logout;

- (void)getProjectsSuccess:(void (^)(NSArray *projects))success
                   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (void)addDirectoryPath:(NSString *)path
               toProject:(NSDictionary *)project
                 success:(void (^)(NSDictionary *project))success
                 failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (void)addProjectName:(NSString *)name
               success:(void (^)(NSDictionary *project))success
               failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

- (void)sendProgressForProject:(NSDictionary *)project;

- (void)uploadScreenshot:(NSMetadataItem *)screenshot
              forProject:(NSDictionary *)project
                    text:(NSString *)text
                 success:(void (^)(NSDictionary *post))success
                 failure:(void (^)(NSError *error))failure;
@end
