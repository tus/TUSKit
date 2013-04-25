//
//  tus_ios_client_demoTests.m
//  tus-ios-client-demoTests
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import <TUSKit/TUSKit.h>
#import "tus_ios_client_demoTests.h"

@implementation tus_ios_client_demoTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

//- (void)testExample
//{
//    STFail(@"Unit tests are not implemented yet in tus-ios-client-demoTests");
//}

- (void)test_parseRangeHeader
{
    long long first = 0;
    long long last = 99;
    NSString* rangeHeader = [NSString stringWithFormat:@"Range: bytes=%lld-%lld",
                             first, last];
    TUSResumableUpload* upload = [[TUSResumableUpload alloc] init];
    TUSRange range = [upload rangeFromHeader:rangeHeader];
    STAssertEquals(first, range.first, @"Expected location of %lld %lld",
                   first, range.first);
    STAssertEquals(last, range.last, @"Expected length of %lld %lld",
                   last, range.last);
}

@end
