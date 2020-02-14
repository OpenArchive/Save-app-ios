//
//  Constants.h
//  OpenArchive
//
//  Created by Benjamin Erhart on 01.08.18.
//  Copyright © 2018 Open Archive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Constants : NSObject

@property (class, nonatomic, assign, readonly, nonnull) NSString *appGroup NS_REFINED_FOR_SWIFT;

@property (class, nonatomic, assign, readonly, nonnull) NSString *teamId NS_REFINED_FOR_SWIFT;

@property (class, nonatomic, assign, readonly, nonnull) NSString *dropboxKey NS_REFINED_FOR_SWIFT;

@end
