//
//  TUSSession.m
//  Pods
//
//
//

#import "TUSSession.h"
#import "TUSResumableUpload2+Private.h"
#import "TUSUploadStore.h"

@interface TUSSession() <TUSResumableUpload2Delegate>

@property (nonatomic, strong) NSURLSession *session; // Session to use for uploads
@property (nonatomic, strong) NSURL *createUploadURL;
@property (nonatomic, strong) TUSUploadStore *store; // Data store to save upload status in
@property (nonatomic, strong) NSMutableDictionary <NSString *, TUSResumableUpload2 *>* uploads;

#pragma mark TUSResumableUpload2Delegate methods
/**
 Add an NSURLSessionTask that should be associated with an upload for delegate callbacks (e.g. upload progress)
 */
-(void)addTask:(NSURLSessionTask *)task forUpload:(TUSResumableUpload2 *)upload;

/**
 Stop tracking an NSURLSessionTask
 */
-(void)removeTask:(NSURLSessionTask *)task;


@end

@implementation TUSSession

#pragma mark properties
/**
 Setter for allowsCellularAccess that will cancel and resume all outstanding uploads
 */
-(void)setAllowsCellularAccess:(BOOL)allowsCellularAccess
{
    if (_allowsCellularAccess != allowsCellularAccess) {
        // Cancel and resume all the uploads if the cellular access value is changing.
        [self cancelAll];
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
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.allowsCellularAccess = self.allowsCellularAccess;
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
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
        _endpoint = endpoint;
        _uploads = [NSMutableDictionary new];
        _allowsCellularAccess = allowsCellularAccess; // Bypass accessor because we have code that acts "on value changed"
    }
    return self;
}

#pragma mark public methods
- (TUSResumableUpload2 *) createUpload:(NSURL *)fileURL
                               headers:(NSDictionary <NSString *, NSString *> * __nullable)headers
                              metadata:(NSDictionary <NSString *, NSString *> * __nullable)metadata
{
    TUSResumableUpload2 *upload = [[TUSResumableUpload2 alloc]  initWithFile:fileURL delegate:self uploadHeaders:headers metadata:metadata];
    
    self.uploads[upload.id] = upload; // Save the upload by ID for later
    return upload;
}


/**
 Restore an upload, but do not start it.  Uploads must be restored by ID because file URLs can change between launch.
 */
- (TUSResumableUpload2 *) restoreUpload:(NSString *)uploadId{
    TUSResumableUpload2 * restoredUpload = self.uploads[uploadId];
    if (restoredUpload == nil) {
        restoredUpload = [TUSResumableUpload2 loadUploadWithId:uploadId delegate:self];
        if (restoredUpload != nil){
            self.uploads[uploadId] = restoredUpload; // Save the upload if we can find it in the data store
        }
    }
    return restoredUpload;
}

/**
 Restore all uploads from the data store
 */
-(NSArray <TUSResumableUpload2 *> *)restoreAllUploads
{
    // First fetch all the stored background upload identifiers
    NSArray <NSString *> *uploadIds = [self.store allUploadIds];
    
    // Attempt to pull the background upload from the session's in memory store
    for (NSString * uploadId in uploadIds) {
        [self restoreUpload:uploadId]; // Restore the upload
    }
    
    return self.uploads.allValues;
}

-(NSUInteger)cancelAll
{
    NSUInteger cancelled = 0;
    for (TUSResumableUpload2 * upload in self.uploads.allValues) {
        if ([upload cancel]){
            cancelled++;
        }
    }
    [self.session invalidateAndCancel];
    self.session = nil;
    return cancelled;
}

-(NSArray <TUSResumableUpload2 *> *)resumeAll{
    NSMutableArray <TUSResumableUpload2 *> *resumableUploads = [@[] mutableCopy];
    for (TUSResumableUpload2 * upload in self.uploads.allValues) {
        if ([upload resume]){
            [resumableUploads addObject:upload];
        }
    }
    return resumableUploads;
}

#pragma mark delegate methods
-(void)addTask:(NSURLSessionTask *)task forUpload:(TUSResumableUpload2 *)upload{
    @throw @"Not implemented";
}

-(void)removeTask:(NSURLSessionTask *)task{
    @throw @"Not implemented";
}

@end
