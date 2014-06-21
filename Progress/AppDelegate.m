//
//  AppDelegate.m
//  Progress
//
//  Created by Craig McNamara on 21/06/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import "AppDelegate.h"

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
  
  [self watchConfigFolder];
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

}


- (void)openWebApp:(id)sender
{
  NSURL *URL = [NSURL URLWithString:@"http://google.com"];
  [[NSWorkspace sharedWorkspace] openURL:URL];
}


#pragma mark - GCD File watching
/* http://www.davidhamrick.com/2011/10/13/Monitoring-Files-With-GCD-Being-Edited-With-A-Text-Editor.html */

- (void)watchConfigFolder
{
  /* Define variables and create a CFArray object containing
   CFString objects containing paths to watch.
   */
  CFStringRef mypath = CFSTR("/Users/cmcnamara87/Desktop");
  CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&mypath, 1, NULL);
  void *callbackInfo = NULL; // could put stream-specific data here.
  FSEventStreamRef stream;
  CFAbsoluteTime latency = 3.0; /* Latency in seconds */
  
  /* Create the stream, passing in a callback */
  stream = FSEventStreamCreate(NULL,
                               &myCallbackFunction,
                               callbackInfo,
                               pathsToWatch,
                               kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
                               latency,
                               kFSEventStreamCreateFlagNone /* Flags explained in reference */
                               );
  FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(),         kCFRunLoopDefaultMode);
  
  FSEventStreamStart(stream);
}

void myCallbackFunction(
                        ConstFSEventStreamRef streamRef,
                        void *clientCallBackInfo,
                        size_t numEvents,
                        void *eventPaths,
                        const FSEventStreamEventFlags eventFlags[],
                        const FSEventStreamEventId eventIds[])
{
  int i;
  char **paths = eventPaths;
  
  // printf("Callback called\n");
  for (i=0; i<numEvents; i++) {
    //        int count;
    /* flags are unsigned long, IDs are uint64_t */
    printf("Change %llu in %s, flags %u\n", eventIds[i], paths[i], (unsigned int)eventFlags[i]);
  }
}


@end
