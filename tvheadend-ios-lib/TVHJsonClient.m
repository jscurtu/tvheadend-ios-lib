//
//  TVHJsonClient.m
//  TVHeadend iPhone Client
//
//  Created by Luis Fernandes on 2/22/13.
//  Copyright 2013 Luis Fernandes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import "TVHServerSettings.h"
#import "TVHJsonClient.h"
#ifdef ENABLE_SSH
#import "SSHWrapper.h"
#endif

#ifndef DEVICE_IS_TVOS
@implementation TVHNetworkActivityIndicatorManager

- (void)networkRequestDidStart:(NSNotification *)notification {
    NSURL *url = [AFNetworkRequestFromNotification(notification) URL];
    if (url) {
        if ( ! [url.path isEqualToString:@"/comet/poll"] ) {
            [self incrementActivityCount];
        }
    }
}

- (void)networkRequestDidFinish:(NSNotification *)notification {
    NSURL *url = [AFNetworkRequestFromNotification(notification) URL];
    if (url) {
        if ( ! [url.path isEqualToString:@"/comet/poll"] ) {
            [self decrementActivityCount];
        }
    }
}

@end
#endif

@implementation TVHJsonClient {
#ifdef ENABLE_SSH
    SSHWrapper *sshPortForwardWrapper;
#endif
}

#pragma mark - Methods

- (void)setUsername:(NSString *)username password:(NSString *)password in:(AFJSONRequestSerializer*)requestSerializer {
    [requestSerializer clearAuthorizationHeader];
    [requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password];
    /*
     // for future reference, MD5 DIGEST. tvheadend uses basic
    NSURLCredential *newCredential;
    newCredential = [NSURLCredential credentialWithUser:username
                                               password:password
                                            persistence:NSURLCredentialPersistenceForSession];
    [self setDefaultCredential:newCredential];
     */
}

#pragma mark - Initialization

- (id)init
{
    [NSException raise:@"Invalid Init" format:@"JsonClient needs ServerSettings to work"];
    return nil;
}

- (id)initWithSettings:(TVHServerSettings *)settings {
    NSParameterAssert(settings);
    
    // setup port forward
    if ( [settings.sshPortForwardHost length] > 0 ) {
        [self setupPortForwardToHost:settings.sshPortForwardHost
                           onSSHPort:[settings.sshPortForwardPort intValue]
                        withUsername:settings.sshPortForwardUsername
                        withPassword:settings.sshPortForwardPassword
                         onLocalPort:[TVHS_SSH_PF_LOCAL_PORT intValue]
                              toHost:settings.sshHostTo
                        onRemotePort:[settings.sshPortTo intValue]
         ];
        _readyToUse = NO;
    } else {
        _readyToUse = YES;
    }
    
    self = [super initWithBaseURL:settings.baseURL];
    if( !self ) {
        return nil;
    }
    
    AFJSONRequestSerializer *jsonRequestSerializer = [AFJSONRequestSerializer serializer];
    if( [settings.username length] > 0 ) {
        [self setUsername:settings.username password:settings.password in:jsonRequestSerializer];
    }
    self.requestSerializer = jsonRequestSerializer;
    
    // @todo: for now, hack this using the "basic" http response serializer instead of the new way of decoding the response
    self.responseSerializer = [AFHTTPResponseSerializer serializer];;
    
#ifndef DEVICE_IS_TVOS
    [[TVHNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
#endif
    
    if ([[AFNetworkReachabilityManager sharedManager] isReachable]) {
        _readyToUse = NO;
    }
    
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        
        if ( status == AFNetworkReachabilityStatusNotReachable ) {
            @synchronized(self) {
                _readyToUse = NO;
            }
        } else {
            @synchronized(self) {
                _readyToUse = YES;
            }
        }
    }];
    
    return self;
}

- (void)dealloc {
    [[self operationQueue] cancelAllOperations];
    [self stopPortForward];
}

#pragma mark AFHTTPClient methods

- (NSURLSessionDataTask*)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    if ( ! [self readyToUse] ) {
        [self dispatchNotReadyError:failure];
        return nil;
    }
    
    return [self GET:path parameters:parameters progress:nil success:success failure:failure];
}


- (NSURLSessionDataTask*)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
         success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
         failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    
    if ( ! [self readyToUse] ) {
        [self dispatchNotReadyError:failure];
        return nil;
    }
    return [super POST:path parameters:parameters progress:nil success:success failure:failure];
}

- (void)dispatchNotReadyError:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    NSLog(@"TVHJsonClient: not ready or not reachable yet, aborting... ");
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:[NSString stringWithFormat:NSLocalizedString(@"Server not reachable or not yet ready to connect.", nil)] };
    NSError *error = [[NSError alloc] initWithDomain:@"Not ready" code:NSURLErrorBadServerResponse userInfo:userInfo];
    dispatch_async(dispatch_get_main_queue(), ^{
        failure(nil, error);
    });
}

#pragma mark JsonHelper

+ (NSDictionary*)convertFromJsonToObjectFixUtf8:(NSData*)responseData error:(__autoreleasing NSError**)error {
    
    NSMutableData *FileData = [NSMutableData dataWithLength:[responseData length]];
    for (int i = 0; i < [responseData length]; ++i)
    {
        char *a = &((char*)[responseData bytes])[i];
        if ( (int)*a > 0 && (int)*a < 0x20 ) {
            ((char*)[FileData mutableBytes])[i] = 0x20;
        } else if ( (int)*a > 0x7F ) {
            ((char*)[FileData mutableBytes])[i] = 0x20;
        } else {
            ((char*)[FileData mutableBytes])[i] = ((char*)[responseData bytes])[i];
        }
    }
    
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:FileData //1
                                                         options:kNilOptions
                                                           error:error];
    
    if( *error ) {
        NSLog(@"[JSON Error (3nd)] output - %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
#ifdef TESTING
        NSLog(@"[JSON Error (3nd)]: %@ ", (*error).description);
#endif
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey:[NSString stringWithFormat:NSLocalizedString(@"Tvheadend returned malformed JSON - check your Tvheadend's Character Set for each mux and choose the correct one!", nil)] };
        *error = [[NSError alloc] initWithDomain:@"Not ready" code:NSURLErrorBadServerResponse userInfo:userInfo];
        return nil;
    }
    
    return json;
}

/**
 this method will try to convert to a string the various different encodings and then strip the control characters.
 thanks to Maury Markowitz @maurymarkowitz for the testing and fixes for this !
 https://github.com/maurymarkowitz/tvheadend-ios-lib/commit/31644825e4e010046dcc34d377748ca3441fe1c5
 */
+ (NSDictionary*)converyByGuessingCharset:(NSData*)responseData error:(__autoreleasing NSError**)error {
    NSError __autoreleasing *errorForThisMethod;
    NSString *convertedString;
    
    // try various encodings to see if any of them produce a working string
    // note that the ordering here is "best guess", there's no real promise it will
    // do the right thing in a wide variety of cases, but it seems that it will produce
    // some sort of readable text in most cases.
    
    NSUInteger encodings[18] = {
        NSUTF8StringEncoding,
        NSISOLatin1StringEncoding,
        NSASCIIStringEncoding,
        NSNEXTSTEPStringEncoding,
        NSJapaneseEUCStringEncoding,
        NSSymbolStringEncoding,
        NSNonLossyASCIIStringEncoding,
        NSShiftJISStringEncoding,
        NSISOLatin2StringEncoding,
        NSUnicodeStringEncoding,
        NSWindowsCP1251StringEncoding,
        NSWindowsCP1252StringEncoding,
        NSWindowsCP1253StringEncoding,
        NSWindowsCP1254StringEncoding,
        NSWindowsCP1250StringEncoding,
        NSISO2022JPStringEncoding,
        NSMacOSRomanStringEncoding
    };
    
    for (int i = 0; i < 20; i++) {
        convertedString = [[NSString alloc] initWithData:responseData encoding:encodings[i]];
        if ( convertedString != nil ) {
            break;
        }
    }
    
    if ( !convertedString ) {
        return [self convertFromJsonToObjectFixUtf8:responseData error:error];
    }

    // now the next problem is that we are also receiving control characters. these are properly
    // escaped, but the JSON parser won't accept them. So here we'll use an NSScanner to remove them
    NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
    NSString *stripped = [[convertedString componentsSeparatedByCharactersInSet:controls] componentsJoinedByString:@""];
    
    // now we try converting the string to data - if we cannot convert back, fallback to the previous method
    NSData *data = [stripped dataUsingEncoding:NSUTF8StringEncoding];
    if ( !data ) {
        return [self convertFromJsonToObjectFixUtf8:responseData error:error];
    }
    
    // and finally, try parsing the data as JSON
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                         options:kNilOptions
                                                           error:&errorForThisMethod];
    
    if( errorForThisMethod ) {
#ifdef TESTING
        NSLog(@"[JSON Error (2st)]: %@", errorForThisMethod.description);
#endif
        return [self convertFromJsonToObjectFixUtf8:responseData error:error];
    }
    
    return json;
}

/**
 Convert the json NSData to JSON
 this has some big issues if the charset is incorrect (which seems to be an usual thing amongst tvheadend users)
 if there is an error, we'll try to call `converyByGuessingCharset` and then convertFromJsonToObjectFixUtf8
 
 @return the converted json data to a NSDictionary
 */
+ (NSDictionary*)convertFromJsonToObject:(NSData*)responseData error:(__autoreleasing NSError**)error {
    NSError __autoreleasing *errorForThisMethod;
    if ( ! responseData ) {
        NSDictionary *errorDetail = @{NSLocalizedDescriptionKey: @"No data received"};
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"No data received"
                                                code:-1
                                            userInfo:errorDetail];
        }
        return nil;
    }
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:responseData
                                                         options:kNilOptions
                                                           error:&errorForThisMethod];
    
    if( errorForThisMethod ) {
        /*NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
         NSString *documentsDirectory = [paths objectAtIndex:0];
         NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"MyFile"];
         [responseData writeToFile:appFile atomically:YES];
         NSLog(@"%@",documentsDirectory);
         */
#ifdef TESTING
        NSLog(@"[JSON Error (1st)]: %@", errorForThisMethod.description);
#endif
        return [self converyByGuessingCharset:responseData error:error];
    }
    
    return json;
}

+ (NSArray*)convertFromJsonToArray:(NSData*)responseData error:(__autoreleasing NSError**)error {
    if ( ! responseData ) {
        NSDictionary *errorDetail = @{NSLocalizedDescriptionKey: @"No data received"};
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"No data received"
                                                code:-1
                                            userInfo:errorDetail];
        }
        return nil;
    }
    NSArray* json = [NSJSONSerialization JSONObjectWithData:responseData
                                                         options:kNilOptions
                                                           error:error];
    
    return json;
}

#pragma mark SSH

- (void)setupPortForwardToHost:(NSString*)hostAddress
                     onSSHPort:(unsigned int)sshHostPort
                  withUsername:(NSString*)username
                  withPassword:(NSString*)password
                   onLocalPort:(unsigned int)localPort
                        toHost:(NSString*)remoteIp
                  onRemotePort:(unsigned int)remotePort  {
#ifdef ENABLE_SSH
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSError *error;
        sshPortForwardWrapper = [[SSHWrapper alloc] init];
        [sshPortForwardWrapper connectToHost:hostAddress port:sshHostPort user:username password:password error:&error];
        if ( !error ) {
            _readyToUse = YES;
            [sshPortForwardWrapper setPortForwardFromPort:localPort toHost:remoteIp onPort:remotePort];
            _readyToUse = NO;
        } else {
            NSLog(@"erro ssh pf: %@", error.localizedDescription);
        }
    });
#endif
}

- (void)stopPortForward {
#ifdef ENABLE_SSH
    if ( ! sshPortForwardWrapper ) {
        return ;
    }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [sshPortForwardWrapper closeConnection];
        sshPortForwardWrapper = nil;
    });
#endif
}
@end
