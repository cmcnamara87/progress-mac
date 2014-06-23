//
//  AppDelegate.h
//  Progress
//
//  Created by Craig McNamara on 21/06/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AFNetworking.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMutableArray *projects;
@property (strong, nonatomic) NSMenu *menu;
@property (strong, nonatomic) AFHTTPRequestOperationManager *manager;

- (void)loggedIn:(NSDictionary *)user;
@end
