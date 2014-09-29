//
//  AppDelegate.m
//  Progress
//
//  Created by Craig McNamara on 21/06/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "AppDelegate.h"
#import "LoginWindowController.h"
#import "ScreenshotManager.h"
#import "NotificationManager.h"
#import "ProgressManager.h"
#import "NSBundle+LoginItem.h"
#import "ApiManager.h"

@interface AppDelegate ()
@property (strong, nonatomic) LoginWindowController *logInWindowController;
@property (strong, nonatomic) NSDictionary *user;
@property (strong, nonatomic) NSTimer *workingTimer;
@property (strong, nonatomic) NSArray *online;
@property (strong, nonatomic) NSTimer *onlineTimer;


@property(strong, nonatomic) ApiManager *apiManager;
@property(strong, nonatomic) NotificationManager *notificationManager;
@property(strong, nonatomic) ScreenshotManager *screenshotManager;
@property(strong, nonatomic) ProgressManager *progressManager;
@end

@implementation AppDelegate


id refToSelf; // reference to self for C function

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  if(![[NSBundle mainBundle] isLoginItem]) {
    [[NSBundle mainBundle] addToLoginItems];
  }
  NSLog(@"main bundle path %@", [[NSBundle mainBundle] bundlePath]);
  //  [self addToLoginItems];
  
  //  [self showTakeScreenshotNotification:nil];
  // Insert code here to initialize your application
  refToSelf = self;
  
  //  [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"KMFeedbinRefreshInterval": @120}];
  //  NSTimeInterval ti = [[NSUserDefaults standardUserDefaults] doubleForKey:@"KMFeedbinRefreshInterval"];
  //  [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(getUnreadEntries:) userInfo:nil repeats:YES];
  
  NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
  
  self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
  self.statusItem.title = @"";
  self.statusItem.highlightMode = YES;
  [self.statusItem setImage:[NSImage imageNamed:@"icon-18x18.png"]];
  
  self.apiManager = [ApiManager sharedManager];
  self.notificationManager = [NotificationManager sharedManager];
  
  self.screenshotManager = [[ScreenshotManager alloc] initWithNotificationManager:self.notificationManager];
  self.progressManager = [[ProgressManager alloc] initWithApiManager:self.apiManager screenshotManager:self.screenshotManager];
  [self.progressManager setStatusItem:self.statusItem];
  
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
    NSLog(@"Debug: User %@ already connected with password %@", credential.user, credential.password);
    // Log them in
    
    [self.apiManager loginEmail:credential.user password:credential.password success:^(NSDictionary *currentUser) {
      [self loggedIn:currentUser];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
      [self logIn:nil];
    }];
  } else {
    NSLog(@"Debug: Not logged in, show login");
    [self logIn:nil];
  }
}

- (void)loginEmail:(NSString *)email password:(NSString *)password {
  
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
  [self.menu addItemWithTitle:@"Online (0)" action:nil keyEquivalent:@""];
  [self.menu addItem:[NSMenuItem separatorItem]];
  [self.menu addItemWithTitle:@"Add Project" action:@selector(createNewProject:) keyEquivalent:@""];
  [self.menu addItem:[NSMenuItem separatorItem]];
  //  [self.menu addItemWithTitle:@"FARTS" action:nil keyEquivalent:@""];
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
  NSLog(@"User has logged in");
  [[NotificationManager sharedManager] showLoggedIn];
  self.user = user;
  [self setupLoggedInMenu];
  [self setupProjects];
  
  self.online = [NSMutableArray array];
  // Add online menu item
  [self checkOnline];
  
  self.onlineTimer = [NSTimer scheduledTimerWithTimeInterval:(15*60) target:self selector:@selector(checkOnlineTimer:) userInfo:nil repeats:YES];
}

- (void)checkOnlineTimer:(NSTimer*)timer
{
  [self checkOnline];
}

- (void)checkOnline
{
  NSLog(@"Checking for online users");
  // Get users online
  
  [self.apiManager getOnlineUsersSuccess:^(NSArray *onlineUsers) {
    [self.menu removeItemAtIndex:1];
    [self.menu insertItemWithTitle:[NSString stringWithFormat:@"Online (%lu)", (unsigned long)[onlineUsers count]] action:nil keyEquivalent:@"" atIndex:1];
    
    for(id onliner in onlineUsers) {
      if([[onliner objectForKey:@"id"] intValue] == [[self.user objectForKey:@"id"] intValue]) {
        NSLog(@"You are online");
        continue;
      }
      BOOL exists = NO;
      for(id existingOnliner in self.online) {
        if([[existingOnliner objectForKey:@"id"] intValue] == [[onliner objectForKey:@"id"] intValue]) {
          exists = YES;
        }
      }
      if(exists == NO) {
        NSLog(@"user is online %@", [onliner objectForKey:@"name"]);
        [[NotificationManager sharedManager] showUser:[onliner objectForKey:@"name"] isWorkingOn:[onliner objectForKey:@"activeProject"]];
      }
    }
    
    self.online = onlineUsers;
  } failure:nil];
}
- (void)quit:(id)sender
{
  // log out
  [self.apiManager logout];
  
  // Destroy credentails
  NSDictionary *credentials = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:self.loginProtectionSpace];
  NSURLCredential *credential = [credentials.objectEnumerator nextObject];
  [[NSURLCredentialStorage sharedCredentialStorage] removeCredential:credential forProtectionSpace:self.loginProtectionSpace];
  
  // Quit app
  [[NSApplication sharedApplication] terminate:nil];
}


- (void)logIn:(id)sender
{
  if (!_logInWindowController) {
    _logInWindowController = [[LoginWindowController alloc] init];
  }
  [self.logInWindowController showWindow:nil];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (void)setupProjects
{
  self.projects = [NSMutableArray array];
  
  [self.apiManager getProjectsSuccess:^(NSArray *projects) {
    if([projects count] == 0) {
      // No projects
      [[NotificationManager sharedManager] showStartAddingProjects];
    }
    for(id project in projects) {
      [self setupProject:project];
    }
  } failure:nil];
}


- (void)setupProject:(NSDictionary *)project
{
  [self.projects addObject:project];
  [self.progressManager addProject:project];
  [self createMenuItemForProject:project];
}


- (NSMenuItem *)createMenuItemForProject:(NSDictionary *)project
{
  NSMenuItem *projectMenuItem = [self.menu insertItemWithTitle:[project objectForKey:@"name"] action:@selector(showOpenProject:) keyEquivalent:@"" atIndex:5];
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
    [self addDirectoriesToProject:project isNew:NO];
  } else if (button == NSAlertDefaultReturn) {
    [self openWebApp:nil];
  }
}

- (void)showAddDirectoriesToProject:(id)sender
{
  NSDictionary *project = [sender representedObject];
  [self addDirectoriesToProject:project isNew:NO];
}

- (void)addDirectoriesToProject:(NSDictionary *)project isNew:(BOOL)isNew
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setAllowsMultipleSelection:YES];
  [panel setCanCreateDirectories:YES];
  [panel setCanChooseDirectories:YES];
  [panel setCanChooseFiles:NO];
  //  NSInteger clicked = [panel runModal];
  
  [panel beginWithCompletionHandler:^(NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {
      // Get out all the paths
      NSMutableArray *paths = [NSMutableArray array];
      
      for (NSURL *url in [panel URLs] ) {
        [paths addObject:[url path]];
        
        [self.apiManager addDirectoryPath:[url path] toProject:project success:^(NSDictionary *project) {
          if(isNew) {
            // Open the website
            NSString *urlString = [NSString stringWithFormat:@"http://cmcnamara87.github.io/progress/#/users/%@/diary/%@", [project objectForKey:@"userId"],  [project objectForKey:@"id"]];
            NSURL *URL = [NSURL URLWithString:urlString];
            [[NSWorkspace sharedWorkspace] openURL:URL];
          }
        } failure:nil];
      }
      
      // Start watching those paths
      [self.progressManager addDirectories:[paths copy] toProject:project];
    }
  }];
  
}

- (void)createNewProject:(id)sender
{
  NSAlert *alert = [NSAlert alertWithMessageText:@"Create a new project"
                                   defaultButton:@"Create"
                                 alternateButton:@"Cancel"
                                     otherButton:nil
                       informativeTextWithFormat:@"What's your projects name?"];
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  [input setStringValue:@""];
  [alert setAccessoryView:input];
  
  NSInteger button = [alert runModal];
  if (button != NSAlertDefaultReturn) {
    return;
  }
  
  [input validateEditing];
  
  // Fixes: 'capturing self strongly in this block is likely to lead to a retain cycle'
  __weak typeof(self) weakSelf = self;
  
  [self.apiManager addProjectName:[input stringValue] success:^(NSDictionary *project) {
    [[NotificationManager sharedManager] showProjectCreated:project];
    
    [weakSelf setupProject:project];
    
    NSAlert *alert = [NSAlert alertWithMessageText:@"Add folders to watch"
                                     defaultButton:@"Add folders"
                                   alternateButton:@"Do it later"
                                       otherButton:nil
                         informativeTextWithFormat:@"We will track whenever you save in thse folders and record your progress."];
    
    NSInteger button = [alert runModal];
    if (button != NSAlertDefaultReturn) {
      return;
    }
    
    [weakSelf addDirectoriesToProject:project isNew:YES];
    
  } failure:nil];
}


- (void)openWebApp:(id)sender
{
  NSString *urlString = @"http://cmcnamara87.github.io/progress";
  if(self.user) {
    // Overwrite with user url if they are logged in
    urlString = @"http://cmcnamara87.github.io/progress/#/me/feed";
  }
  NSURL *URL = [NSURL URLWithString:urlString];
  [[NSWorkspace sharedWorkspace] openURL:URL];
}

@end
