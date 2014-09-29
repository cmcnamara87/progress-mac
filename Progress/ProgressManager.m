//
//  ProgressManager.m
//  Progress
//
//  Created by Craig McNamara on 29/09/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "ProgressManager.h"

@interface ProgressManager ()
@property (strong, nonatomic) NSTimer *workingTimer;

@property (strong, nonatomic) NSDictionary *activeProject;


@property(strong, nonatomic) ApiManager *apiManager;
@property(strong, nonatomic) ScreenshotManager *screenshotManager;
@end

id refToSelf;

@implementation ProgressManager

- (id)initWithApiManager:(ApiManager *)apiManager
       screenshotManager:(ScreenshotManager *)screenshotManager {
  if (self = [super init]) {
    self.apiManager = apiManager;
    self.screenshotManager = screenshotManager;
    refToSelf = self;
  }
  return self;
}

- (void)addProject:(NSDictionary *)project
{
  NSMutableArray *mPaths = [NSMutableArray array];
  for (NSDictionary *directory in [project objectForKey:@"directories"]) {
    [mPaths addObject:[directory objectForKey:@"path"]];
  }
  NSArray *paths = [mPaths copy];
  
  if([paths count]) {
    [self watchPaths:paths forProject:project];
  }
}

- (void)addDirectories:(NSArray *)paths toProject:(NSDictionary *)project {
  [self watchPaths:paths forProject:project];
}

- (void)watchPaths:(NSArray *)paths forProject:(NSDictionary *)project {
  //  NSOrderedSet *watchSet = [goal watchedFiles];
  
  
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

- (void)madeProgressForProject:(NSDictionary *)project
{
  self.activeProject = project;
  
  [self setUserIsActive];
  [self.screenshotManager startWatchingForProject:project];
  [self.apiManager sendProgressForProject:project];
}

- (void)setUserIsActive
{
  if(self.workingTimer) {
    [self.workingTimer invalidate];
  }
  [self.statusItem setImage:[NSImage imageNamed:@"icon-in-18x18.png"]];
  self.workingTimer = [NSTimer scheduledTimerWithTimeInterval:(15*60) target:self selector:@selector(setUserIsInActive:) userInfo:nil repeats:NO];
}

- (void)setUserIsInActive:(NSTimer*)timer
{
  [self.workingTimer invalidate];
  self.workingTimer = nil;

  [self.statusItem setImage:[NSImage imageNamed:@"icon-18x18.png"]];
  [self.screenshotManager stopWatching];
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
  // Get out the goal that had the file changed event
  NSMutableDictionary *project = (__bridge NSMutableDictionary *)(clientCallBackInfo);
  
  [refToSelf madeProgressForProject:project];
}

@end

