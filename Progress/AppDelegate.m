//
//  AppDelegate.m
//  Progress
//
//  Created by Craig McNamara on 21/06/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "AppDelegate.h"
#import "AFNetworking.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
  
  NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
  self.statusItem.title = @"";
  self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
  self.statusItem.highlightMode = YES;
  [self.statusItem setImage:[NSImage imageNamed:@"icon.png"]];
  
  [self setupMenu];
  
  [self.window orderOut:self];
  
//  [self watchConfigFolder];
  

  
}

- (void)setupMenu
{
  NSMenu *menu = [[NSMenu alloc] init];
  [menu addItemWithTitle:@"Open Web App" action:@selector(openWebApp:) keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Refresh" action:@selector(openWebApp:) keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Add Project" action:@selector(openWebApp:) keyEquivalent:@""];
//  [menu addItemWithTitle:@"Refresh" action:@selector(getUnreadEntries:) keyEquivalent:@""];
//  if ([[[KMFeedbinCredentialStorage sharedCredentialStorage] credential] hasPassword]) {
//    [menu addItemWithTitle:@"Log Out" action:@selector(logOut:) keyEquivalent:@""];
//  } else {
//    [menu addItemWithTitle:@"Log In" action:@selector(logIn:) keyEquivalent:@""];
//  }
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
  self.statusItem.menu = menu;
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
  [manager GET:@"http://localhost:8888/index.php/me/projects" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
    
    self.projects = responseObject;
    NSLog(@"got json %@", responseObject);
    for(id project in responseObject) {
          NSLog(@"got project %@", project);
      [self watchProject:project];
      // Add menubar for each project
      [menu addItemWithTitle:[project objectForKey:@"name"] action:@selector(openWebApp:) keyEquivalent:@""];
    }
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
  }];

}


- (void)openWebApp:(id)sender
{
  NSURL *URL = [NSURL URLWithString:@"http://google.com"];
  [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (void)watchProject:(NSDictionary *)project {
//  NSOrderedSet *watchSet = [goal watchedFiles];
  
  
  NSMutableArray *mPaths = [NSMutableArray array];
  for (NSDictionary *directory in [project objectForKey:@"directories"]) {
    [mPaths addObject:[directory objectForKey:@"path"]];
  }
  NSArray *paths = [mPaths copy];
  
  CFArrayRef pathArray = (__bridge CFArrayRef)paths;
  
  FSEventStreamRef stream;
  CFAbsoluteTime latency = 3.0; /* Latency in seconds */
  FSEventStreamContext context = {0, (__bridge void*)project, NULL, NULL, NULL};
  /* Create the stream, passing in a callback */
  stream = FSEventStreamCreate(NULL,
                               &projectContentChanged,
                               &context,
                               pathArray,
                               kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
                               latency,
                               kFSEventStreamCreateFlagNone /* Flags explained in reference */
                               );
  FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),         kCFRunLoopDefaultMode);
  
  FSEventStreamStart(stream);
//  NSValue *streamPointer = [NSValue valueWithPointer:stream];
//  [activeWatchers setObject:streamPointer forKey:[goal created]];
}

void projectContentChanged(
                        ConstFSEventStreamRef streamRef,
                        void *clientCallBackInfo,
                        size_t numEvents,
                        void *eventPaths,
                        const FSEventStreamEventFlags eventFlags[],
                        const FSEventStreamEventId eventIds[])
{
  int i;
  char **paths = eventPaths;

  // Check for a bunch of invalid things
  BOOL numInvalidEvents = 0;
  for (i=0; i<numEvents; i++) {
     NSString *eventPath = [NSString stringWithCString:paths[i] encoding:NSUTF8StringEncoding];
    if ([eventPath rangeOfString:@".git"].location != NSNotFound) {
      numInvalidEvents++;
      continue;
    }
    if ([eventPath rangeOfString:@".xcworkspace"].location != NSNotFound) {
      numInvalidEvents++;
      continue;
    }
    if ([eventPath rangeOfString:@".DS_Store"].location != NSNotFound) {
      numInvalidEvents++;
      continue;
    }
    NSLog(@"Change %llu in %s, flags %u\n", eventIds[i], paths[i], (unsigned int)eventFlags[i]);
  }

  if(numInvalidEvents == numEvents) {
    return;
  }
  NSLog(@"-- UPLOADING!");
  
  // Get out the goal that had the file changed event
  NSMutableDictionary *project = (__bridge NSMutableDictionary *)(clientCallBackInfo);
  
  // Add progress to each project
  AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
  NSDictionary *parameters = @{@"foo": @"bar"};
  NSString *url = [NSString stringWithFormat:@"http://localhost:8888/index.php/me/projects/%@/progress", [project objectForKey:@"id"]];
  NSLog(@"url %@", url);
  [manager POST:url parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    NSLog(@"JSON: %@", responseObject);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
  }];

  // Get out the weekly progress object for that goal
//  LHWeeklyProgress *weeklyProgress = [goal progressThisWeek];
  
  // Check how long its been since the last activity
  // I'm doing it in 5 min blocks
//  NSDate *now = [[NSDate alloc] init];
//  NSTimeInterval secondsBetween = [now timeIntervalSinceDate:[weeklyProgress updated]];
//  double minutes = secondsBetween / 60.0;
//  
//  if (minutes < kMinutesThreshold) {
//    [goal willChangeValueForKey:@"percentComplete"];
//    [goal willChangeValueForKey:@"hoursThisWeek"];
//    double minutesCompleted = [weeklyProgress minutesCompletedValue] + minutes;
//    [weeklyProgress setMinutesCompletedValue:minutesCompleted];
//    NSLog(@"Minutes completed: %g", [weeklyProgress minutesCompletedValue]);
//    [goal didChangeValueForKey:@"percentComplete"];
//    [goal didChangeValueForKey:@"hoursThisWeek"];
//  }
//  
//  [weeklyProgress setUpdated:[NSDate date]];
//  NSError *error;
//  [[refToSelf managedObjectContext] save:&error];
//  
//  if (error) {
//    NSLog(@"%@", error);
//  }
  
//  NSLog(@"The Goal is %@ minutesCompleted: %@", [goal valueForKey:@"title"], [weeklyProgress minutesCompleted]);;
  
}

@end
