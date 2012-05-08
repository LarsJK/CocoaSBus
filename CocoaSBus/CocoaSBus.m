//
//  CocoaSBus.m
//  Saia S-Bus Debugger
//
//  Created by Lars-Jørgen Kristiansen on 08.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CocoaSBus.h"

@interface CocoaSBus () {
    GCDAsyncUdpSocket *udpSocket;
    SuccessBlock successBlock;
    FailedBlock failedBlock;
}
@end

@implementation CocoaSBus


- (id) init {
    self = [self init];
    
    if (self != nil)
    {
        // your code here
        udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        NSError *error = nil;
        
        if (![udpSocket bindToPort:0 error:&error])
        {
            NSLog(@"%@", error.localizedDescription);
            return NULL;
        }
        if (![udpSocket beginReceiving:&error])
        {
            NSLog(@"%@", error.localizedDescription);
            return NULL;
        }
        return self;
    }
    return NULL;
}


//CRC code found at http://www.nongnu.org/avr-libc/user-manual/group__util__crc.html
uint16_t crc_xmodem_update (uint16_t crc, uint8_t data) {
    int i;
    
    crc = crc ^ ((uint16_t)data << 8);
    for (i=0; i<8; i++)
    {
        if (crc & 0x8000)
            crc = (crc << 1) ^ 0x1021;
        else
            crc <<= 1;
    }
    
    return crc;
}

//Function to add the standard parameters to the message
- (void)WriteRegistersFrom:(int)address 
                        to:(NSArray*)numbers 
                  onStation:(int)stationNumber 
                    withIP:(NSString*)ipAdress 
                   success:(SuccessBlock)success 
                   failure:(FailedBlock)failure {
    
    //Length is the number of bytes in the whole message including the length itself and the crc
    uint32_t length = htonl(16 + (numbers.count * 4));
    
    #warning This comment might not be correct
    //Version is the verion of S-Bus used. Current verion is 1
    uint8_t version = 1;
        
    #warning Fill in comment about protocol
    //Protocol is ???
    uint8_t protocol = 0;
    
    //Sequence is the messages number in the sequence. An int that is increased for each message
    static uint16_t sequenceTemp = 0;
    
    if (sequenceTemp < UINT16_MAX)
        sequenceTemp++;
    else
        sequenceTemp = 0;
    
    uint16_t sequence = htons(sequenceTemp);
    
    //Attribut can be Request (0x00), Response (0x01) or ACK/NAK (0x03). As a client we always send Requests.
    uint8_t attr = 0x00;
    
    //Station adress is the PCD number
    uint8_t station = (uint8_t)stationNumber;
    
    /*  Command codes:
    *   0x0E - Write Registers
    *
    *
    */
    uint8_t command = 0x0E;
    
    uint8_t count = numbers.count;
    
    uint16_t addr = htons(address);

    unsigned char message[293];
	__block unsigned char *pointer = message;
    
    //Compose header
    memcpy(pointer, &length, sizeof(uint32_t));
	pointer += sizeof(uint32_t);
	memcpy(pointer, &version, sizeof(uint8_t));
	pointer += sizeof(uint8_t);
	memcpy(pointer, &protocol, sizeof(uint8_t));
	pointer += sizeof(uint8_t);
    memcpy(pointer, &sequence, sizeof(uint16_t));
	pointer += sizeof(uint16_t);
	
	// Compose message.
    memcpy(pointer, &attr, sizeof(uint8_t));
	pointer += sizeof(uint8_t);
	memcpy(pointer, &station, sizeof(uint8_t));
	pointer += sizeof(uint8_t);
	memcpy(pointer, &command, sizeof(uint8_t));
	pointer += sizeof(uint8_t);
    memcpy(pointer, &count, sizeof(uint8_t));
	pointer += sizeof(uint8_t);
    memcpy(pointer, &addr, sizeof(uint16_t));
	pointer += sizeof(uint16_t);
    
    
    [numbers enumerateObjectsUsingBlock:^(NSNumber *number, NSUInteger idx, BOOL *stop) {
        uint32_t value = htonl(number.intValue);
        memcpy(pointer, &value, sizeof(uint32_t));
        pointer += sizeof(uint32_t);
    }];
    
    uint16_t crc = 0;
    
    for (int i = 0; i < (pointer - message); i++) {
        crc = crc_xmodem_update(crc, message[i]);
    }
    
    crc = htons(crc);
    
    memcpy(pointer, &crc, sizeof(uint16_t));
	pointer += sizeof(uint16_t);
    
    [udpSocket sendData:[NSData dataWithBytes:message length:(pointer - message)] toHost:ipAdress port:5050 withTimeout:-1 tag:sequenceTemp];
}

#pragma mark - CocoaAsyncSockets Delegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
	// You could add checks here
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
	// You could add checks here
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
	NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (msg)
	{
		NSLog(@"%@", msg);
	}
	else
	{
		NSString *host = nil;
		uint16_t port = 0;
		[GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
        NSLog(@"RECV: Unknown message from: %@:%hu", host, port);
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    
}


@end
