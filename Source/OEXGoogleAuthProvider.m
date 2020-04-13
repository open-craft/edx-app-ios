//
//  OEXGoogleAuthProvider.m
//  edXVideoLocker
//
//  Created by Akiva Leffert on 3/24/15.
//  Copyright (c) 2015 edX. All rights reserved.
//

#import "OEXGoogleAuthProvider.h"

#import "edX-Swift.h"

#import "OEXExternalAuthProviderButton.h"
#import "OEXGoogleSocial.h"
#import "OEXRegisteringUserDetails.h"

@implementation OEXGoogleAuthProvider

- (UIColor*)googleBlue {
    return [UIColor colorWithRed:66.0/255.0 green:133.0/255.0 blue:244.0/255.0 alpha:1];
}

- (NSString*)displayName {
    return [Strings google];
}

- (NSString*)backendName {
    return @"google-oauth2";
}

- (OEXExternalAuthProviderButton*)freshAuthButton {
    OEXExternalAuthProviderButton* button = [[OEXExternalAuthProviderButton alloc] initWithFrame:CGRectZero];
    button.provider = self;
    [button setImage:[UIImage imageNamed:@"icon_google_white"] forState:UIControlStateNormal];
    [button useBackgroundImageOfColor:[self googleBlue]];
    return button;
}

- (void)authorizeServiceFromController:(UIViewController *)controller requestingUserDetails:(BOOL)loadUserDetails withCompletion:(void (^)(NSString *, OEXRegisteringUserDetails *, NSError *))completion {
    [[OEXGoogleSocial sharedInstance] loginFromController:controller withCompletion:^(NSString* token, NSError* error){
        [[OEXGoogleSocial sharedInstance] clearHandler];
        if(error) {
            completion(token, nil, error);
        }
        else {
            if(loadUserDetails) {
                [[OEXGoogleSocial sharedInstance] requestUserProfileInfoWithCompletion:^(GIDProfileData* userInfo) {
                    OEXRegisteringUserDetails* profile = [[OEXRegisteringUserDetails alloc] init];
                    profile.email = userInfo.email;
                    profile.name = userInfo.name;
                    completion(token, profile, error);
                }];
            }
            else {
                completion(token, nil, error);
            }
        }
    }];
}

@end

@implementation OEXSamlAuthProvider

- (UIColor*)buttonColor {
    // FIXME JV make configurable
    return [UIColor colorWithRed:66.0/255.0 green:133.0/255.0 blue:244.0/255.0 alpha:1];
}

- (NSString*)displayName {
    // FIXME JV make configurable
    return @"Cloudera";
}

- (NSString*)backendName {
    // FIXME JV make configurable
    return @"tpa-saml";
}

- (OEXExternalAuthProviderButton*)freshAuthButton {
    OEXExternalAuthProviderButton* button = [[OEXExternalAuthProviderButton alloc] initWithFrame:CGRectZero];
    button.provider = self;
    // FIXME: make configurable
    //[button setImage:[UIImage imageNamed:@"icon_google_white"] forState:UIControlStateNormal];
    [button useBackgroundImageOfColor:[self buttonColor]];
    return button;
}

- (void)authorizeServiceFromController:(UIViewController *)controller requestingUserDetails:(BOOL)loadUserDetails withCompletion:(void (^)(NSString *, OEXRegisteringUserDetails *, NSError *))completion {

  NSLog(@"SamlAuthProvider authorizeServiceFromController");

  [self setupGlobalEnvironment];
  [self.environment.router showTpaAuthViewFromController:controller];
}

#pragma mark Environment

- (void)setupGlobalEnvironment {
    self.environment = [[OEXEnvironment alloc] init];
    [self.environment setupEnvironment];
}

@end
