//
//  TUSKit_Tests.m
//  TUSKit-Tests
//
//  Created by afh on 27-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//

#import "TUSResumableUpload.h"

#import "TUSKit_Tests.h"

@implementation TUSKit_Tests

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

- (void)test_rangeFormHeader_first500Bytes
{
    long long first = 0;
    long long last = 499;
    NSString* rangeHeader = [NSString stringWithFormat:@"Range: bytes=%lld-%lld", first, last];
    TUSResumableUpload* upload = [[TUSResumableUpload alloc] init];
    TUSRange range = [upload rangeFromHeader:rangeHeader];
    STAssertEquals(range.first, first, @"First byte of given range differs.");
    STAssertEquals(range.last, last, @"Last byte of given range differs.");
}

- (void)test_rangeFormHeader_second500Bytes
{
    long long first = 500;
    long long last = 999;
    NSString* rangeHeader = [NSString stringWithFormat:@"Range: bytes=%lld-%lld", first, last];
    TUSResumableUpload* upload = [[TUSResumableUpload alloc] init];
    TUSRange range = [upload rangeFromHeader:rangeHeader];
    STAssertEquals(range.first, first, @"First byte of given range differs.");
    STAssertEquals(range.last, last, @"Last byte of given range differs.");
}

- (void)test_rangeFormHeader_invalidFirstBeforeLast
{
    long long first = 200;
    long long last = 100;
    NSString* rangeHeader = [NSString stringWithFormat:@"Range: bytes=%lld-%lld", first, last];
    TUSResumableUpload* upload = [[TUSResumableUpload alloc] init];
    TUSRange range = [upload rangeFromHeader:rangeHeader];
    STAssertEquals(range.first, TUSInvalidRange, @"First byte of given range differs.");
    STAssertEquals(range.last, TUSInvalidRange, @"Last byte of given range differs.");
}

- (void)test_rangeFormHeader_invalidNegative
{
    long long first = -15;
    long long last = -5;
    NSString* rangeHeader = [NSString stringWithFormat:@"Range: bytes=%lld-%lld", first, last];
    TUSResumableUpload* upload = [[TUSResumableUpload alloc] init];
    TUSRange range = [upload rangeFromHeader:rangeHeader];
    STAssertEquals(range.first, TUSInvalidRange, @"First byte of given range differs.");
    STAssertEquals(range.last, TUSInvalidRange, @"Last byte of given range differs.");
}

@end
