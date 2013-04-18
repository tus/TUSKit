//
//  tus_ios_client_demoTests.m
//  tus-ios-client-demoTests
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//

#import "TUSKit.h"
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
    NSUInteger location = 0;
    NSUInteger length = 99;
    NSString* rangeHeader = [NSString stringWithFormat:@"Range: bytes=%d-%d",
                             location, length];
    TUSResumableUpload* upload = [[TUSResumableUpload alloc] init];
    NSRange range = [upload parseRangeHeader:rangeHeader];
    STAssertEquals(location, range.location, @"Expected location of %d %d",
                   location, range.location);
    STAssertEquals(length, range.length, @"Expected length of %d %d",
                   length, range.length);
}

@end
