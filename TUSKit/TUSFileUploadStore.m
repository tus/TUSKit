//
//  TUSFileUploadStore.m
//  Pods
//
//  Created by Findyr on 6/17/16.
//
//

#import "TUSFileUploadStore.h"

@interface TUSFileUploadStore()
@property (strong, nonatomic) NSURL *fileURL;
@property (strong, nonatomic) NSMutableDictionary <NSString *, TUSResumableUpload *> * uploads;
@property (strong, nonatomic) NSMutableDictionary <NSString *, NSDictionary *> * serializedUploads;
@end

@implementation TUSFileUploadStore
-(instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self){
        _fileURL = url;
        _uploads = [NSMutableDictionary new];
        _serializedUploads = [NSMutableDictionary dictionaryWithContentsOfURL:url] ?: [NSMutableDictionary new];
    }
    return self;
}

-(TUSResumableUpload *) loadUploadWithIdentifier:(NSString *)uploadId delegate:(id<TUSResumableUploadDelegate>)delegate
{
    TUSResumableUpload * upload = self.uploads[uploadId];
    if (upload){
        return upload;
    }
    NSDictionary * serializedUpload = self.serializedUploads[uploadId];
    if(serializedUpload){
        upload = [[TUSResumableUpload alloc] initWithDictionary:serializedUpload delegate:delegate];
        if (upload){
            self.uploads[uploadId] = upload;
            return upload;
        }
    }
    return nil;
}

-(BOOL)saveUpload:(TUSResumableUpload *)upload
{
    self.uploads[upload.uploadId] = upload;
    NSDictionary *newSerialized = [upload serialize];
    if (![self.serializedUploads[upload.uploadId] isEqualToDictionary:newSerialized]){
        self.serializedUploads[upload.uploadId] = newSerialized;
        [self.serializedUploads writeToURL:self.fileURL atomically:YES];
    }
    return YES;
}

-(BOOL)removeUploadWithIdentifier:(NSString *)uploadIdentifier
{
    [self.uploads removeObjectForKey:uploadIdentifier];
    if (self.serializedUploads[uploadIdentifier]){
        [self.serializedUploads removeObjectForKey:uploadIdentifier];
        [self.serializedUploads writeToURL:self.fileURL atomically:YES];
    }
    return YES;
}

-(NSArray <NSString *>*)allUploadIdentifiers
{
    return self.serializedUploads.allKeys;
}

-(BOOL)containsUploadWithIdentifier:(NSString *)uploadId
{
    return [self.serializedUploads objectForKey:uploadId] != nil;
}

@end
