//
//  LoginController.m
//  SpotifyDemo
//
//  Created by Arthur Tonelli on 7/21/16.
//  Copyright © 2016 Arthur Tonelli. All rights reserved.
//

#import "LoginController.h"
#import <Spotify/Spotify.h>

@interface LoginController () <SPTAuthViewDelegate>
    
@property (atomic, readwrite) SPTAuthViewController *authViewController;
@property (atomic, readwrite) BOOL firstLoad;
    
@end

@implementation LoginController

-(void)viewDidLoad {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionUpdateNotification:) name:@"sessionUpdated" object:nil];
    self.statusLabel.text = @"";
    self.firstLoad = YES;
    
}

-(void)sessionUpdateNotification:(NSNotification *)notification {
    
    self.statusLabel.text = @"";
    if(self.navigationController.topViewController == self){
        SPTAuth *auth = [SPTAuth defaultInstance];
        if(auth.session && [auth.session isValid]) {
            [self showPlayer];
        }
    }
    
}

-(void)showPlayer {
    self.firstLoad = NO;
    self.statusLabel.text = @"Logged in.";
    [self performSegueWithIdentifier:@"ShowPlayer" sender:nil];
}

-(void)authenticationViewController:(SPTAuthViewController *)authenticationViewController didFailToLogin:(NSError *)error{
    self.statusLabel.text = @"Login failed.";
    NSLog(@"*** Failed to log in: %@",error);
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)authenticationViewController:(SPTAuthViewController *)authenticationViewController didLoginWithSession:(SPTSession *)session{
    self.statusLabel.text = @"";
    [self dismissViewControllerAnimated:YES completion:^{
        [self showPlayer];
    }];
}

-(void) authenticationViewControllerDidCancelLogin:(SPTAuthViewController *)authenticationViewController{
    self.statusLabel.text = @"Logging in...";
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) openLoginPage {
    
    self.statusLabel.text = @"Logging in...";
    
    self.authViewController = [SPTAuthViewController authenticationViewController];
    self.authViewController.delegate = self;
    self.authViewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    self.authViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    self.definesPresentationContext = YES;
    
    [self presentViewController:self.authViewController animated:NO completion:nil];
    
}

-(void) renewTokenAndShowPlayer {
    self.statusLabel.text = @"Refreshing token...";
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    [auth renewSession:auth.session callback:^(NSError *error, SPTSession *session) {
        auth.session = session;
        
        if(error){
            self.statusLabel.text = @"REfreshing token failed.";
            NSLog(@"*** Error renewing session: %@", error);
            return;
        }
        
        [self showPlayer];
    }];
}

-(void) viewWillAppear:(BOOL)animated {
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    if(auth.session == nil){
        self.statusLabel.text = @"";
        return;
    }
    
    if([auth.session isValid] && self.firstLoad){
        [self showPlayer];
        return;
    }
    
    self.statusLabel.text = @"Token Expired.";
    if(auth.hasTokenRefreshService){
        [self renewTokenAndShowPlayer];
        return;
    }
}

- (IBAction)loginButtonPressed:(id)sender {
    [self openLoginPage];
}

- (IBAction)clearCookiesButtonPressed:(id)sender {
    self.authViewController = [SPTAuthViewController authenticationViewController];
    [self.authViewController clearCookies:nil];
    self.statusLabel.text = @"Cookies cleared.";
}



@end
