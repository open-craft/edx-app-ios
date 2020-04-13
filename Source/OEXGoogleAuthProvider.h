//
//  OEXGoogleAuthProvider.h
//  edXVideoLocker
//
//  Created by Akiva Leffert on 3/24/15.
//  Copyright (c) 2015-2016 edX. All rights reserved.
//

@import Foundation;

#import "OEXEnvironment.h"
#import "OEXExternalAuthProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface OEXGoogleAuthProvider : NSObject <OEXExternalAuthProvider>

@end

@interface OEXSamlAuthProvider : NSObject <OEXExternalAuthProvider>

@property (nonatomic, strong) OEXEnvironment* environment;

@end

NS_ASSUME_NONNULL_END
