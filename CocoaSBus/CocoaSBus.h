//
//  CocoaSBus.h
//  Saia S-Bus Debugger
//
//  Created by Lars-Jørgen Kristiansen on 08.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GCDAsyncUdpSocket.h"

typedef void (^SuccessBlock)(id anObject);
typedef void (^FailedBlock)(NSError *error);

@interface CocoaSBus : NSObject <GCDAsyncUdpSocketDelegate> 

- (void)WriteRegistersFrom:(int)address 
                        to:(NSArray*)intValues 
                  onStation:(int)stationNumber 
                    withIP:(NSString*)ipAdress 
                   success:(SuccessBlock)success 
                   failure:(FailedBlock)failure;

@end
