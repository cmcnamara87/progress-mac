//
//  AppDelegate.h
//  Progress
//
//  Created by Craig McNamara on 21/06/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AFNetworking.h"

static NSString * const BASE_URL_STRING = @"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com/progress/";
static NSString * const BASE_API_URL_STRING = @"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com/progress/api/index.php/";

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMutableArray *projects;
@property (strong, nonatomic) NSMenu *menu;
@property (strong, nonatomic) AFHTTPRequestOperationManager *manager;
@property (strong, nonatomic) NSURLProtectionSpace *loginProtectionSpace;
@property (nonatomic, strong) NSMetadataQuery *metadataSearch;
@property (strong, nonatomic) NSDictionary *activeProject;

- (void)loggedIn:(NSDictionary *)user;
@end
