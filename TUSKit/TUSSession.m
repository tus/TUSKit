//
//  TUSSession.m
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import "TUSKit.h"
#import "TUSSession.h"
#import "TUSResumableUpload+Private.h"

@interface TUSSession() <TUSResumableUploadDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session; // Session to use for uploads
@property (nonatomic, strong) NSURL *createUploadURL;
@property (nonatomic, strong) TUSUploadStore *store; // Data store to save upload status in
@property (nonatomic, strong) NSMutableDictionary <NSString *, TUSResumableUpload *>* uploads;
@property (nonatomic, strong) NSMutableDictionary <NSURLSessionTask *, TUSResumableUpload *>* tasks;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration; // Session config to use for uploads

#pragma mark TUSResumableUploadDelegate method declarations
/**
 Add an NSURLSessionTask that should be associated with an upload for delegate callbacks (e.g. upload progress)
 */
-(void)addTask:(NSURLSessionTask *)task forUpload:(TUSResumableUpload *)upload;

/**
 Stop tracking an NSURLSessionTask
 */
-(void)removeTask:(NSURLSessionTask *)task;

/**
 Stop tracking a TUSResumableUpload
 */
-(void)removeUpload:(TUSResumableUpload * _Nonnull)upload;

@end

@implementation TUSSession


#pragma mark properties
/**
 Setter for allowsCellularAccess that will cancel and resume all outstanding uploads
 */
-(void)setAllowsCellularAccess:(BOOL)allowsCellularAccess
{
    if (_allowsCellularAccess != allowsCellularAccess) {
        // Stop and resume all the uploads if the cellular access value is changing.
        [self stopAll];
        _allowsCellularAccess = allowsCellularAccess;
        [self resumeAll];
    }
}

/**
 Lazy instantiating getter for session
 */
-(NSURLSession *) session{
    // Lazily instantiate a session
    if (_session == nil){
        NSURLSessionConfiguration *sessionConfiguration;
        if (_sessionConfiguration == nil) {
            sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfiguration.allowsCellularAccess = self.allowsCellularAccess;
            sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
            sessionConfiguration.URLCache = nil;
        } else {
            sessionConfiguration = _sessionConfiguration;
        }
        
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _session;
}


#pragma mark initializers
- (id)initWithEndpoint:(NSURL *)endpoint
             dataStore:(TUSUploadStore *)store
  allowsCellularAccess:(BOOL)allowsCellularAccess
{
    self = [super init];
    
    if (self) {
        _store = store; // TODO: Load uploads from store
        _createUploadURL = endpoint;
        _uploads = [NSMutableDictionary new];
        _tasks = [NSMutableDictionary new];
        _allowsCellularAccess = allowsCellularAccess; // Bypass accessor because we have code that acts "on value changed"
    }
    return self;
}

- (id)initWithEndpoint:(NSURL *)endpoint
             dataStore:(TUSUploadStore *)store
  sessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration
{
    self = [super init];
    
    if (self) {
        _store = store; // TODO: Load uploads from store
        _createUploadURL = endpoint;
        _uploads = [NSMutableDictionary new];
        _tasks = [NSMutableDictionary new];
        _allowsCellularAccess = YES; //default
        _sessionConfiguration = sessionConfiguration;
    }
    return self;
}

#pragma mark public methods
- (TUSResumableUpload *) createUploadFromFile:(NSURL *)fileURL
                                        retry:(int)retryCount
                                      headers:(NSDictionary <NSString *, NSString *> * __nullable)headers
                                     metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata
{
    TUSResumableUpload *upload = [[TUSResumableUpload alloc]  initWithUploadId:[self.store generateUploadId]
                                                                          file:fileURL
                                                                         retry:retryCount
                                                                      delegate:self
                                                                 uploadHeaders:headers?:@{}
                                                                      metadata:metadata];
    
    if (upload){
        self.uploads[upload.uploadId] = upload; // Save the upload by ID for later
    }
    
    return upload;
}

- (TUSResumableUpload * _Nullable) createUploadFromFile:(NSURL * _Nonnull)fileURL
                                                  retry:(int)retryCount
                                                headers:(NSDictionary <NSString *, NSString *> * __nullable)headers
                                               metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata
                                              uploadUrl:(NSURL * _Nonnull)uploadUrl
{
    TUSResumableUpload *upload = [[TUSResumableUpload alloc] initWithUploadId:[self.store generateUploadId]
                                                                         file:fileURL
                                                                        retry:retryCount
                                                                     delegate:self
                                                                uploadHeaders:headers?:@{}
                                                                     metadata:metadata
                                                                    uploadUrl:uploadUrl];

    if (upload){
        self.uploads[upload.uploadId] = upload; // Save the upload by ID for later
    }

    return upload;
}

/**
 Restore an upload, but do not start it.  Uploads must be restored by ID because file URLs can change between launch.
 */
- (TUSResumableUpload *) restoreUpload:(NSString *)uploadId{
    TUSResumableUpload * restoredUpload = self.uploads[uploadId];
    if (restoredUpload == nil) {
        restoredUpload = [self.store loadUploadWithIdentifier:uploadId delegate:self];
        if (restoredUpload != nil){
            self.uploads[uploadId] = restoredUpload; // Save the upload if we can find it in the data store
        }
    }
    return restoredUpload;
}

/**
 Restore all uploads from the data store
 */
-(NSArray <TUSResumableUpload *> *)restoreAllUploads
{
    // First fetch all the stored background upload identifiers
    NSArray <NSString *> *uploadIds = [self.store allUploadIdentifiers];
    
    // Attempt to pull the background upload from the session's in memory store
    for (NSString * uploadId in uploadIds) {
        [self restoreUpload:uploadId]; // Restore the upload
    }
    
    return self.uploads.allValues;
}

-(NSUInteger)cancelAll
{
    NSUInteger cancelled = 0;
    for (TUSResumableUpload * upload in self.uploads.allValues) {
        if ([upload cancel]){
            cancelled++;
        }
    }
    [self.session invalidateAndCancel];
    self.session = nil;
    return cancelled;
}

-(NSUInteger)stopAll
{
    NSUInteger stopped = 0;
    for (TUSResumableUpload * upload in self.uploads.allValues) {
        if ([upload stop]){
            stopped++;
        }
    }
    [self.session invalidateAndCancel];
    self.session = nil;
    return stopped;
}

-(NSArray <TUSResumableUpload *> *)resumeAll{
    NSMutableArray <TUSResumableUpload *> *resumableUploads = [@[] mutableCopy];
    for (TUSResumableUpload * upload in self.uploads.allValues) {
        if ([upload resume]){
            [resumableUploads addObject:upload];
        }
    }
    return resumableUploads;
}

#pragma mark delegate methods
-(void)addTask:(NSURLSessionTask *)task forUpload:(TUSResumableUpload *)upload{
    self.tasks[task] = upload;
}

-(void)removeTask:(NSURLSessionTask *)task{
    [self.tasks removeObjectForKey:task];
}

-(void)saveUpload:(TUSResumableUpload * _Nonnull)upload{
    self.uploads[upload.uploadId] = upload;
    [self.store saveUpload:upload];
}

-(void)removeUpload:(TUSResumableUpload * _Nonnull)upload{
    // We rely on the TUSBackgroundTasks to remove themselves.
    [self.uploads removeObjectForKey:upload.uploadId];
    [self.tasks removeObjectsForKeys:[self.tasks allKeysForObject:upload]];
    [self.store removeUploadWithIdentifier:upload.uploadId];
}

#pragma mark NSURLSessionDataDelegate methods
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    // Unfortunately we need to use this delegate method to report progress back to the task for it to report it to its callback methods
    [self.tasks[task] task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
}

@end
