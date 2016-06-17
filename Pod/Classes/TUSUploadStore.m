//
//  TUSUploadStore.m
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import "TUSUploadStore.h"
#import "TUSResumableUpload.h"

@interface TUSUploadStore ()
@property (strong, nonatomic) NSMutableDictionary <NSString *, TUSResumableUpload *> * uploads;
@end

@implementation TUSUploadStore

-(id) init
{
    self = [super init];
    if (self) {
        self.uploads = [NSMutableDictionary new];
    }
    return self;
}

-(TUSResumableUpload *) loadUploadWithIdentifier:(NSString *)uploadId delegate:(id<TUSResumableUploadDelegate>)delegate
{
    return self.uploads[uploadId];
}

-(BOOL)saveUpload:(TUSResumableUpload *)upload
{
    self.uploads[upload.uploadId] = upload;
    return YES;
}

-(BOOL)removeUploadWithIdentifier:(NSString *)uploadIdentifier
{
    [self.uploads removeObjectForKey:uploadIdentifier];
    return YES;
}

-(NSArray <NSString *>*)allUploadIdentifiers
{
    return self.uploads.allKeys;
}

-(BOOL)containsUploadWithIdentifier:(NSString *)uploadId
{
    return [self.uploads objectForKey:uploadId] != nil;
}

-(NSString *)generateUploadId
{
    while(1) {
        NSUUID *uuid = [[NSUUID alloc] init];
        if(![self containsUploadWithIdentifier:uuid.UUIDString])
            return uuid.UUIDString;
    }
}
@end
