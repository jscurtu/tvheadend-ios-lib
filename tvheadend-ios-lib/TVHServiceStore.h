//
//  TVHServiceStore.h
//  TvhClient
//
//  Created by Luis Fernandes on 08/12/13.
//  Copyright (c) 2013 Luis Fernandes.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import "TVHApiClient.h"

@class TVHServer;
@class TVHMux;

@protocol TVHServiceStore <TVHApiClientDelegate>
@property (nonatomic, weak) TVHServer *tvhServer;
@property (strong, nonatomic) NSString *identifier;
- (void)fetchServices;
- (NSArray*)servicesForMux:(TVHMux*)mux;
@end
