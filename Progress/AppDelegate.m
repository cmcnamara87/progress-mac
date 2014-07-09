//
//  AppDelegate.m
//  Progress
//
//  Created by Craig McNamara on 21/06/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "AppDelegate.h"
#import "LoginWindowController.h"

static NSString * const BASE_URL_STRING = @"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com/progress/";
static NSString * const BASE_API_URL_STRING = @"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com/progress/api/index.php/";


@interface AppDelegate ()
  @property (strong, nonatomic) LoginWindowController *logInWindowController;
  @property (strong, nonatomic) NSDictionary *user;
  @property (strong, nonatomic) NSTimer *workingTimer;
@end

@implementation AppDelegate

id refToSelf; // reference to self for C function

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
  refToSelf = self;
  
//  [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"KMFeedbinRefreshInterval": @120}];
//  NSTimeInterval ti = [[NSUserDefaults standardUserDefaults] doubleForKey:@"KMFeedbinRefreshInterval"];
//  [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(getUnreadEntries:) userInfo:nil repeats:YES];
  
  NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
  self.statusItem.title = @"";
  self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
  self.statusItem.highlightMode = YES;
  [self.statusItem setImage:[NSImage imageNamed:@"icon-18x18.png"]];

  NSURL *baseUrl = [NSURL URLWithString:BASE_API_URL_STRING];
  self.manager = [[AFHTTPRequestOperationManager manager] initWithBaseURL:baseUrl];
  
  // Hide app window
//  [self.window orderOut:self];
  
  [self setupDefaultMenu];
  
  // Setup login protection space
  NSURLCredential *credential;
  NSDictionary *credentials;
  NSURL *url = [NSURL URLWithString:@"http://ec2-54-206-66-123.ap-southeast-2.compute.amazonaws.com"];
  self.loginProtectionSpace = [[NSURLProtectionSpace alloc] initWithHost:url.host
                                                                    port:[url.port integerValue]
                                                                protocol:url.scheme
                                                                   realm:nil
                                                    authenticationMethod:NSURLAuthenticationMethodHTTPDigest];
  
  credentials = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:self.loginProtectionSpace];
  credential = [credentials.objectEnumerator nextObject];
  
  if(credential) {
    NSLog(@"User %@ already connected with password %@", credential.user, credential.password);
    // Log them in
    NSDictionary *parameters = @{@"email": credential.user, @"password": credential.password};
    [self.manager POST:@"users/login" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
      // Login successful, store credentials
      [self loggedIn:responseObject];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      [self logIn:nil];
      NSLog(@"Error: Couldn't log in with %@, shw login, %@", credentials, error);
    }];
  } else {
    [self logIn:nil];
    NSLog(@"Not logged in, show login");
  }
  
  
  
//  [self watchConfigFolder];
}


- (void)setupLoggedInMenu
{
  if(!_menu) {
    self.menu = [[NSMenu alloc] init];
    self.statusItem.menu = self.menu;
  } else {
    [self.menu removeAllItems];
  }
  [self.menu addItemWithTitle:@"Open Web App" action:@selector(openWebApp:) keyEquivalent:@""];
  [self.menu addItem:[NSMenuItem separatorItem]];
  [self.menu addItemWithTitle:@"Add Project" action:@selector(createNewProject:) keyEquivalent:@""];
  [self.menu addItem:[NSMenuItem separatorItem]];
  [self.menu addItem:[NSMenuItem separatorItem]];
  [self.menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];
}

- (void)setupDefaultMenu
{
  if(!_menu) {
    self.menu = [[NSMenu alloc] init];
    self.statusItem.menu = self.menu;
  } else {
    [self.menu removeAllItems];
  }
  [self.menu addItemWithTitle:@"Open Web App" action:@selector(openWebApp:) keyEquivalent:@""];
  [self.menu addItemWithTitle:@"Log In" action:@selector(logIn:) keyEquivalent:@""];
  [self.menu addItem:[NSMenuItem separatorItem]];
  [self.menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];
}

- (void)loggedIn:(NSDictionary *)user
{
  self.user = user;
  [self setupLoggedInMenu];
  [self setupProjects];
}

- (void)quit:(id)sender
{
  // log out
  [self.manager POST:@"users/logout" parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
    // Logout
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: Couldn't log out %@", error);
  }];
  
  // Destroy credentails
  NSDictionary *credentials = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:self.loginProtectionSpace];
  NSURLCredential *credential = [credentials.objectEnumerator nextObject];
  [[NSURLCredentialStorage sharedCredentialStorage] removeCredential:credential forProtectionSpace:self.loginProtectionSpace];
  
  // Quit app
  [[NSApplication sharedApplication] terminate:nil];
}


- (void)logIn:(id)sender
{
  NSLog(@"Show login");
  if (!_logInWindowController) {
    NSLog(@"making contrlller");
    _logInWindowController = [[LoginWindowController alloc] init];
  }
  [self.logInWindowController showWindow:nil];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
//  [self.logInWindowController showWindowWithCompletionHandler:^(NSURLCredential *credential){
//    [[KMFeedbinCredentialStorage sharedCredentialStorage] setCredential:credential];
//    [self getUnreadEntries:self];
//    [self setupMenu];
//  }];
//  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (void)setupProjects
{
  self.projects = [NSMutableArray array];
  [self.manager GET:@"me/projects" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
    
    for(id project in responseObject) {
      [self setupProject:project];
    }
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
  }];
}


- (void)setupProject:(NSDictionary *)project
{
  [self.projects addObject:project];
  [self watchProject:project];
  [self createMenuItemForProject:project];
}

- (void)watchProject:(NSDictionary *)project
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

- (NSMenuItem *)createMenuItemForProject:(NSDictionary *)project
{
  NSMenuItem *projectMenuItem = [self.menu insertItemWithTitle:[project objectForKey:@"name"] action:@selector(showOpenProject:) keyEquivalent:@"" atIndex:4];
  [projectMenuItem setTarget:self];
  [projectMenuItem setRepresentedObject:project];
  return projectMenuItem;
}

- (void)showOpenProject:(id)sender
{
  NSDictionary *project = [sender representedObject];
  NSAlert *alert = [NSAlert alertWithMessageText:[project objectForKey:@"name"]
                                   defaultButton:@"View Project"
                                 alternateButton:@"Cancel"
                                     otherButton:nil
                       informativeTextWithFormat:@"Add more folders to watch, or view the project"];
  [alert addButtonWithTitle:@"Add folders"];
  
  NSInteger button = [alert runModal];
  
  if (button == NSAlertThirdButtonReturn) {
    [self addDirectoriesToProject:project];
  } else if (button == NSAlertDefaultReturn) {
    [self openWebApp:nil];
  }
}

- (void)showAddDirectoriesToProject:(id)sender
{
  NSDictionary *project = [sender representedObject];
  [self addDirectoriesToProject:project];
}

- (void)addDirectoriesToProject:(NSDictionary *)project
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setAllowsMultipleSelection:YES];
  [panel setCanChooseDirectories:YES];
  [panel setCanChooseFiles:NO];
//  NSInteger clicked = [panel runModal];
  
  [panel beginWithCompletionHandler:^(NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {
      // Get out all the paths
      NSMutableArray *paths = [NSMutableArray array];
      
      for (NSURL *url in [panel URLs] ) {
        [paths addObject:[url path]];
        
        NSDictionary *parameters = @{@"path": [url path]};
        NSString *url = [NSString stringWithFormat:@"me/projects/%@/directories", [project objectForKey:@"id"]];
        NSLog(@"Posting to %@", url);
        [self.manager POST:url parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
          NSLog(@"JSON: %@", responseObject);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
          NSLog(@"Error: %@", error);
        }];
      }
      
      // Start watching those paths
      [self watchPaths:[paths copy] forProject:project];
    }
  }];

}

- (void)createNewProject:(id)sender
{
  NSAlert *alert = [NSAlert alertWithMessageText:@"Create a new project"
                                   defaultButton:@"OK"
                                 alternateButton:@"Cancel"
                                     otherButton:nil
                       informativeTextWithFormat:@"What's your projects name?"];
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  [input setStringValue:@""];
  [alert setAccessoryView:input];
  
  NSInteger button = [alert runModal];
  if (button == NSAlertDefaultReturn) {
    [input validateEditing];
    
    NSDictionary *parameters = @{@"name": [input stringValue]};

    [self.manager POST:@"me/projects" parameters:parameters success:^(AFHTTPRequestOperation *operation, id project) {
      NSLog(@"JSON: %@", project);
      [self setupProject:project];
      [self addDirectoriesToProject:project];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      NSLog(@"Error: %@", error);
    }];
    
//    return [input stringValue];
  } else if (button == NSAlertAlternateReturn) {
//    return nil;
  } else {
//    NSAssert1(NO, @"Invalid input dialog button %d", button);
//    return nil;
  }
}
- (void)openWebApp:(id)sender
{

  NSString *urlString = [NSString stringWithFormat:@"%@#/user/%@/projects", BASE_URL_STRING, [self.user objectForKey:@"id"]];
  NSURL *URL = [NSURL URLWithString:urlString];
  
  [[NSWorkspace sharedWorkspace] openURL:URL];
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
  NSDictionary *parameters = @{@"foo": @"bar"};
  NSString *url = [NSString stringWithFormat:@"me/projects/%@/progress", [project objectForKey:@"id"]];
  NSLog(@"url %@", url);
  [[refToSelf manager] POST:url parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    NSLog(@"JSON: %@", responseObject);
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
  }];
  
  [[refToSelf statusItem] setImage:[NSImage imageNamed:@"icon-in-18x18.png"]];

  // Invalid existing timer
  if([refToSelf workingTimer]) {
    [[refToSelf workingTimer] invalidate];
    [refToSelf setWorkingTimer:nil];
  }
  [refToSelf setWorkingTimer:[NSTimer scheduledTimerWithTimeInterval:(15*60) target:refToSelf selector:@selector(disableWorkingIcon:) userInfo:nil repeats:NO]];
  
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

- (void)disableWorkingIcon:(NSTimer*)timer
{
  NSLog(@"disable working timer????");
  self.workingTimer = nil;
   [self.statusItem setImage:[NSImage imageNamed:@"icon-18x18.png"]];
}

@end
