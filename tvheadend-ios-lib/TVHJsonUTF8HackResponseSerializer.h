//
//  AFJSONUTF8HackResponseSerializer.h
//  tvheadend-ios-lib
//
//  Created by Luis Fernandes on 21/08/2017.
//  Copyright © 2017 zipleen. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>

@interface TVHJsonUTF8HackResponseSerializer : AFHTTPResponseSerializer <AFURLResponseSerialization>

+ (instancetype)serializer;

@end
