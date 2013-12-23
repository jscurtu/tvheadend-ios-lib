//
//  TVHNetworkStore.h
//  tvheadend-ios-lib
//
//  Created by zipleen on 23/12/13.
//  Copyright (c) 2013 zipleen. All rights reserved.
//

#import "TVHApiClient.h"

@class TVHServer;
@class TVHNetwork;

@protocol TVHNetworkDelegate <NSObject>
@optional
- (void)willLoadNetwork;
- (void)didLoadNetwork;
- (void)didErrorNetworkStore:(NSError*)error;
@end

@protocol TVHNetworkStore <TVHApiClientDelegate>
@property (nonatomic, weak) TVHServer *tvhServer;
@property (nonatomic, weak) id <TVHNetworkDelegate> delegate;
- (id)initWithTvhServer:(TVHServer*)tvhServer;
- (void)fetchNetworks;

- (TVHNetwork*)objectAtIndex:(int) row;
- (int)count;
@end
