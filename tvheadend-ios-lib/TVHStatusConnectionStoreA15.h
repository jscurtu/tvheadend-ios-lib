//
//  TVHStatusConnectionStoreA15.h
//  tvheadend-ios-lib
//
//  Created by Luis Fernandes on 18/04/2018.
//  Copyright (c) 2018 Luis Fernandes.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import "TVHStatusConnectionStore.h"

@class TVHServer;

@interface TVHStatusConnectionStoreA15 : NSObject <TVHApiClientDelegate, TVHStatusConnectionStore>
@property (nonatomic, weak) TVHServer *tvhServer;
@property (nonatomic, weak) id <TVHStatusConnectionDelegate> delegate;
- (id)initWithTvhServer:(TVHServer*)tvhServer;
- (void)fetchStatusConnections;

- (NSArray*)connectionsCopy;
- (TVHStatusConnection*)findConnectionStartedAt:(NSDate*)startedAt withPeer:(NSString*)peer;
@end
