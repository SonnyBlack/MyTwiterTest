//
//  ViewController.m
//  MyTwitter
//
//  Created by Alex on 04.03.15.
//  Copyright (c) 2015 Oleksii. All rights reserved.
//

#import "ViewController.h"
#import "TableViewController.h"
#import "Chameleon.h"
#import <Social/Social.h>
#import "STTwitter.h"
#import "WebViewVC.h"
#import <Accounts/Accounts.h>

#define CONSUMER_KEY @"7GjBz4QotE08eACaJMPQevCrF"
#define CONSUMER_SECRET @"82ZnuE9IcJskgNzVZnu4nDqYASdl9VkqfYsv6QgoXFHC0X0QtX"

typedef void (^accountChooserBlock_t)(ACAccount *account, NSString *errorMessage); // don't bother with NSError for that

@interface ViewController () <UIActionSheetDelegate>
- (IBAction)goAutorization:(UIButton *)sender;

@property (nonatomic, strong) STTwitterAPI *twitter;
@property (nonatomic, weak) STTwitterAPI *weakTwitter;
@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) accountChooserBlock_t accountChooserBlock;
@property (nonatomic, strong) NSArray *iOSAccounts;
@property (nonatomic, strong) NSArray *statuses;

- (IBAction)goTwitter:(UIButton *)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithGradientStyle:UIGradientStyleTopToBottom withFrame:self.view.frame andColors: @[[UIColor flatWhiteColor], [UIColor flatWhiteColorDark]]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Twitter
- (IBAction)goTwitter:(UIButton *)sender {
    // get timeline
    // maybe need add spinner while perform loading
    if (!_twitter) {
        [self showErrorWithTitle:@"Sorry" message:@"You haven't authorized yet."];
        return;
    }
    
    [_twitter getHomeTimelineSinceID:nil
                               count:20
                        successBlock:^(NSArray *statuses) {
                            self.statuses = statuses;
                            [self performSegueWithIdentifier:@"goTimeLine" sender:nil];
                        
                        } errorBlock:^(NSError *error) {
                            [self showErrorWithTitle:@"Sorry" message:error.localizedDescription];
                        }];
    
}

- (BOOL)checkLoginInSettings {
    [self loginWithiOSAction];
    [self reverseAuthAction];
    if (self.weakTwitter == nil) {
        NSLog(@"Work with cites");
        return true;
    } else {
        NSLog(@"Work without cites");
        return false;
    }
}

- (void)loginWithiOSAction {
    
    //_loginStatusLabel.text = @"Trying to login with iOS...";
    
    __weak typeof(self) weakSelf = self;
    self.accountChooserBlock = ^(ACAccount *account, NSString *errorMessage) {
        account  = [[ACAccount alloc] init];
        NSLog(@"username is %@", account.username);
        NSString *status = nil;
        if(account) {
            status = [NSString stringWithFormat:@"Did select %@", account.username];
            
            [weakSelf loginWithiOSAccount:account];
        } else {
            status = errorMessage;
        }
        
      // weakSelf.errorText = status;
    };
    
    [self chooseAccount];
}

- (void)loginWithiOSAccount:(ACAccount *)account {
    
    self.twitter = [STTwitterAPI twitterAPIOSWithAccount:account];
    
    [_twitter verifyCredentialsWithSuccessBlock:^(NSString *username) {
        
//    _errorText = [NSString stringWithFormat:@"@%@", username];
        
    } errorBlock:^(NSError *error) {
//      _errorText = [error localizedDescription];
    }];
    
}

- (void)loginOnTheWebAction {

    self.twitter = [STTwitterAPI twitterAPIWithOAuthConsumerKey:CONSUMER_KEY
                                                 consumerSecret:CONSUMER_SECRET];
    
    [_twitter postTokenRequest:^(NSURL *url, NSString *oauthToken) {
        NSLog(@"-- url: %@", url);
        NSLog(@"-- oauthToken: %@", oauthToken);
        
        WebViewVC *webViewVC = [self.storyboard instantiateViewControllerWithIdentifier:@"WebViewVC"];
        
        [self presentViewController:webViewVC animated:YES completion:^{
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            [webViewVC.webView loadRequest:request];
        }];
    }
    authenticateInsteadOfAuthorize:NO
                        forceLogin:@(YES)
                        screenName:nil
                     oauthCallback:@"myappp://twitter_access_tokens/"
                        errorBlock:^(NSError *error) {
                            NSLog(@"-- error: %@", error);
                            [self showErrorWithTitle:@"Sorry" message:@"You can't send a tweet right now, make sure your device has an internet connection"];
                        }];
}

- (void)chooseAccount {
    
    ACAccountType *accountType = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    ACAccountStoreRequestAccessCompletionHandler accountStoreRequestCompletionHandler = ^(BOOL granted, NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            if(granted == NO) {
                _accountChooserBlock(nil, @"Acccess not granted.");
                return;
            }
            
            self.iOSAccounts = [_accountStore accountsWithAccountType:accountType];
            
            if([_iOSAccounts count] == 1) {
                ACAccount *account = [_iOSAccounts lastObject];
                _accountChooserBlock(account, nil);
            } else {
                UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Select an account:"
                                                                delegate:self
                                                       cancelButtonTitle:@"Cancel"
                                                  destructiveButtonTitle:nil otherButtonTitles:nil];
                for(ACAccount *account in _iOSAccounts) {
                    [as addButtonWithTitle:[NSString stringWithFormat:@"@%@", account.username]];
                }
                [as showInView:self.view.window];
            }
        }];
    };
    
#if TARGET_OS_IPHONE &&  (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0)
    if (floor(NSFoundationVersionNumber) < NSFoundationVersionNumber_iOS_6_0) {
        [self.accountStore requestAccessToAccountsWithType:accountType
                                     withCompletionHandler:accountStoreRequestCompletionHandler];
    } else {
        [self.accountStore requestAccessToAccountsWithType:accountType
                                                   options:NULL
                                                completion:accountStoreRequestCompletionHandler];
    }
#else
    [self.accountStore requestAccessToAccountsWithType:accountType
                                               options:NULL
                                            completion:accountStoreRequestCompletionHandler];
#endif
    
}

- (void)reverseAuthAction {
    
    STTwitterAPI *twitter = [STTwitterAPI twitterAPIWithOAuthConsumerName:nil consumerKey:CONSUMER_KEY consumerSecret:CONSUMER_SECRET];
    
    __weak typeof(self) weakSelf = self;
    
    [twitter postReverseOAuthTokenRequest:^(NSString *authenticationHeader) {
        
        self.accountChooserBlock = ^(ACAccount *account, NSString *errorMessage) {
            
            if(account == nil) {
//                weakSelf.errorText = errorMessage;
                return;
            }
            
            STTwitterAPI *twitterAPIOS = [STTwitterAPI twitterAPIOSWithAccount:account];
            
            [twitterAPIOS verifyCredentialsWithSuccessBlock:^(NSString *username) {
                
                [twitterAPIOS postReverseAuthAccessTokenWithAuthenticationHeader:authenticationHeader successBlock:^(NSString *oAuthToken, NSString *oAuthTokenSecret, NSString *userID, NSString *screenName) {
                    
//                    weakSelf.loginStatusLabel.text = [NSString stringWithFormat:@"Reverse auth. success for @%@", screenName];
                    
                    NSLog(@"-- REVERSE AUTH OK");
                    NSLog(@"-- you can now access @%@ account (ID: %@) with specified consumer tokens and the following access tokens:", screenName, userID);
                    NSLog(@"-- oAuthToken: %@", oAuthToken);
                    NSLog(@"-- oAuthTokenSecret: %@", oAuthTokenSecret);
                    
                    weakSelf.weakTwitter = [STTwitterAPI twitterAPIWithOAuthConsumerKey:CONSUMER_KEY consumerSecret:CONSUMER_SECRET oauthToken:oAuthToken oauthTokenSecret:oAuthTokenSecret];
                    
                } errorBlock:^(NSError *error) {
//                   weakSelf.errorText = [error localizedDescription];
                }];
                
            } errorBlock:^(NSError *error) {
//               weakSelf.errorText = [error localizedDescription];
            }];
            
        };
        
        [self chooseAccount];
        
    } errorBlock:^(NSError *error) {
//        weakSelf.errorText = [error localizedDescription];
    }];
}

- (void)setOAuthToken:(NSString *)token oauthVerifier:(NSString *)verifier {
    
    // in case the user has just authenticated through WebViewVC
    [self dismissViewControllerAnimated:YES completion:^{
        //
    }];
    
    [_twitter postAccessTokenRequestWithPIN:verifier successBlock:^(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName) {
        NSLog(@"-- screenName: %@", screenName);
        
        //_loginStatusLabel.text = screenName;
        
        /*
         At this point, the user can use the API and you can read his access tokens with:
         
         _twitter.oauthAccessToken;
         _twitter.oauthAccessTokenSecret;
         
         You can store these tokens (in user default, or in keychain) so that the user doesn't need to authenticate again on next launches.
         
         Next time, just instanciate STTwitter with the class method:
         
         +[STTwitterAPI twitterAPIWithOAuthConsumerKey:consumerSecret:oauthToken:oauthTokenSecret:]
         
         Don't forget to call the -[STTwitter verifyCredentialsWithSuccessBlock:errorBlock:] after that.
         */
        
    } errorBlock:^(NSError *error) {
        
       // _loginStatusLabel.text = [error localizedDescription];
        NSLog(@"-- %@", [error localizedDescription]);
    }];
}


- (void)showErrorWithTitle:(NSString *)title message:(NSString *)msg {
    UIAlertView *alertView = [[UIAlertView alloc]
                            initWithTitle:title
                            message:msg
                            delegate:nil
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
    [alertView show];

}

#pragma mark - Autorization

- (IBAction)goAutorization:(UIButton *)sender {
    if ([self checkLoginInSettings]) {
        [self loginOnTheWebAction];
    }
}

#pragma mark - Next Screen

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"goTimeLine"]) {
        
        // Get destination view
        TableViewController *vc = [segue destinationViewController];
        
        // Get button tag number (or do whatever you need to do here, based on your object
        vc.twitter = self.twitter;
        vc.statuses = self.statuses;
    }
}


@end
