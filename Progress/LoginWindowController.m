//
//  LoginWindowController.m
//  
//
//  Created by Craig McNamara on 22/06/2014.
//
//

#import "LoginWindowController.h"
#import "AppDelegate.h"

@interface LoginWindowController ()

@property (copy, nonatomic) void (^completionHandler)(NSURLCredential *credential);
@property (weak, nonatomic) IBOutlet NSTextField *emailTextField;
@property (weak, nonatomic) IBOutlet NSSecureTextField *passwordTextField;

@end

@implementation LoginWindowController

- (id)init
{
  NSLog(@"initing");
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

  NSDictionary *parameters = @{@"email": self.emailTextField.stringValue, @"password": self.passwordTextField.stringValue};
  [appDelegate.manager POST:@"users/login" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
    
    // Login successful, store credentials
    [self storeCredentials];
    [self close];
    [appDelegate loggedIn:responseObject];
    
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
  }];
}

- (NSURLCredential *)storeCredentials
{
  AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
  NSURLCredential *credential;
  credential = [NSURLCredential credentialWithUser:self.emailTextField.stringValue password:self.passwordTextField.stringValue persistence:NSURLCredentialPersistencePermanent];
  [[NSURLCredentialStorage sharedCredentialStorage] setCredential:credential forProtectionSpace:appDelegate.loginProtectionSpace];
  return credential;
}

@end
