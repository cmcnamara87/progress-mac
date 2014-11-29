//
//  LoginWindowController.m
//  
//
//  Created by Craig McNamara on 22/06/2014.
//
//

#import "LoginWindowController.h"
#import "AppDelegate.h"
#import "ApiManager.h"

@interface LoginWindowController ()

@property (copy, nonatomic) void (^completionHandler)(NSURLCredential *credential);
@property (weak, nonatomic) IBOutlet NSTextField *emailTextField;
@property (weak, nonatomic) IBOutlet NSSecureTextField *passwordTextField;

@end

@implementation LoginWindowController

- (id)init
{
  NSLog(@"Debug: Showing login window");
  return [self initWithWindowNibName:@"LoginWindowController" owner:self];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];
  
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)showWindowWithCompletionHandler:(void (^)(NSURLCredential *))completionHandler
{
  [self showWindow:nil];
  self.completionHandler = completionHandler;
}

//- (void)showWindowWithCompletionHandler:(void (^)(NSURLCredential *))completionHandler
//{
//  [self showWindow:nil];
//  self.completionHandler = completionHandler;
//}

- (IBAction)logIn:(id)sender
{
  AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];

  [[ApiManager sharedManager] loginEmail:self.emailTextField.stringValue
                                password:self.passwordTextField.stringValue
                                 success:^(NSDictionary *currentUser) {
//                                   [self storeCredentials];
                                   [self close];
                                   [appDelegate loggedIn:currentUser];
                                 } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   
                                 }];
}

- (NSURLCredential *)storeCredentials
{
  AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
  
  // Delete current credentials
  // TODO: Do you even need to do this?
//  NSDictionary *credentials = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:appDelegate.loginProtectionSpace];
//  NSURLCredential *credential = [credentials.objectEnumerator nextObject];
//  if(credentials) {
//    [[NSURLCredentialStorage sharedCredentialStorage] removeCredential:credential forProtectionSpace:appDelegate.loginProtectionSpace];
//  }

  
//  NSURLCredential *credential;
  NSURLCredential *credential = [NSURLCredential credentialWithUser:self.emailTextField.stringValue password:self.passwordTextField.stringValue persistence:NSURLCredentialPersistencePermanent];
  [[NSURLCredentialStorage sharedCredentialStorage] setCredential:credential forProtectionSpace:appDelegate.loginProtectionSpace];
  return credential;
}

@end
