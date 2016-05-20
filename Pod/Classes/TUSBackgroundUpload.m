//
//  TUSResumableUpload.m
//  tus-ios-client-demo
//
//  Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions for background uploading by Findyr.
//  Copyright (c) 2016 Findyr. All rights reserved.

#import "TUSKit.h"
#import "TUSData.h"

#import "TUSBackgroundUpload.h"
#import "TUSFileReader.h"
#imnport "TUSUploadStore.h"

#define HTTP_PATCH @"PATCH"
#define HTTP_POST @"POST"
#define HTTP_HEAD @"HEAD"
#define HTTP_OFFSET @"Upload-Offset"
#define HTTP_UPLOAD_LENGTH  @"Upload-Length"
#define HTTP_TUS @"Tus-Resumable"
#define HTTP_TUS_VERSION @"1.0.0"

#define HTTP_LOCATION @"Location"
#define REQUEST_TIMEOUT 30

typedef NS_ENUM(NSInteger, TUSUploadState) {
    CreatingFile,
    CheckingFile,
    UploadingFile,
    Complete
};

@interface TUSBackgroundUpload ()
@property (strong, nonatomic) NSURL *endpoint; // Endpoint to create a new file
@property (strong, nonatomic) NSURL *url; // Upload URL for file
@property (strong, nonatomic) NSString *fingerprint;
@property (nonatomic) NSUInteger offset;
@property (nonatomic) TUSUploadState state;
@property (strong, nonatomic) void (^progress)(NSInteger bytesWritten, NSInteger bytesTotal);
@property (nonatomic, strong) NSDictionary *uploadHeaders;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) TUSFileReader *fileReader;
@property (readwrite) NSString *id;
@property BOOL idle;
@property BOOL failed;
@end

@implementation TUSBackgroundUpload

- (instancetype)initWithURL:(NSURL *)url
                 sourceFile:(NSURL *)sourceFile
              uploadHeaders:(NSDictionary *)headers
                uploadStore:(TUSUploadStore *)store
{
    //TODO: Add dictionary parameter for upload metadata as well
    self = [super init];
    if (self) {
        [self setEndpoint:url];
        [self setFileReader:[[TUSFileReader alloc] initWithURL:sourceFile]];
        [self setFingerprint:[sourceFile absoluteString]];
        [self setUploadHeaders:headers];
        [self setFileName:[sourceFile lastPathComponent]];
        [self setQueue:[[NSOperationQueue alloc] init]];
        
        NSString *uploadUrl = [[self resumableUploads] valueForKey:[self fingerprint]];
        if (uploadUrl == nil) {
            TUSLog(@"No resumable upload URL for fingerprint %@", [self fingerprint]);
            self.state = CreatingFile;
            return self;
        }
        
        [self setUrl:[NSURL URLWithString:uploadUrl]];
        
        self.state = CheckingFile;
    }
    
    // Should immediately save itself to store
    [self saveToStore:store];
    
    return self;
}

- (BOOL)isComplete
{
    return self.state == Complete;
}

- (NSURLSessionTask *) makeNextCallWithSession:(NSURLSession *)session
{
    // If the process is idle, need to begin at current state
    if (self.idle) {
        switch (self.state) {
            case CreatingFile:
                return [self createFile:session];
            case CheckingFile:
                return [self checkFile:session];
            case UploadingFile:
                return [self uploadFile:session];
            case Complete:
            default:
                return nil;
        }
    }
    return nil;
}

- (NSURLSessionTask *) createFile:(NSURLSession *) session
{
    self.state = CreatingFile;
    
    NSUInteger size = [[self fileReader] length];
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    NSString *plainString = self.fileName;
    NSMutableString *filenameHeader = [[NSMutableString alloc] initWithString:@"filename "];
    NSData *plainData = [plainString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [plainData base64EncodedStringWithOptions:0];
    
    [mutableHeader setObject:[filenameHeader stringByAppendingString:base64String] forKey:@"Upload-Metadata"];
    
    // Add custom headers after the filename, as the upload-metadata may be customized
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    
    // Set the version & length last as they are determined by the uploader
    [mutableHeader setObject:[NSString stringWithFormat:@"%lu", (unsigned long)size] forKey:HTTP_UPLOAD_LENGTH];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self endpoint]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_POST];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    // Create a download task for the empty post (file to be deleted later)
    // TODO: determine if an NSURLSessionDataTask can run while your app is in the background (docs are unclear)
    return [session downloadTaskWithURL:self.url];
}

- (NSURLSessionTask *) checkFile:(NSURLSession *) session
{
    self.state = CheckingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                            timeoutInterval:REQUEST_TIMEOUT];
    
    [request setHTTPMethod:HTTP_HEAD];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    // Create a download task for the empty post (file to be deleted later)
    // TODO: determine if an NSURLSessionDataTask can run while your app is in the background (docs are unclear)
    return [session downloadTaskWithURL:self.url];
}

- (NSURLSessionTask *) uploadFile:(NSURLSession *)session
{
    self.state = UploadingFile;
    
    NSMutableDictionary *mutableHeader = [NSMutableDictionary dictionary];
    [mutableHeader addEntriesFromDictionary:[self uploadHeaders]];
    [mutableHeader setObject:[NSString stringWithFormat:@"%lld", (long long)self.offset] forKey:HTTP_OFFSET];
    [mutableHeader setObject:HTTP_TUS_VERSION forKey:HTTP_TUS];
    [mutableHeader setObject:@"application/offset+octet-stream" forKey:@"Content-Type"];

    
    NSDictionary *headers = [NSDictionary dictionaryWithDictionary:mutableHeader];
    
    TUSLog(@"Resuming upload at %@ for fingerprint %@ from offset %lld",
           [self url], [self fingerprint], (long long)self.offset);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[self url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
    [request setHTTPMethod:HTTP_PATCH];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    // Add the uploadTask (request) to the session
    NSError *error = nil;
    return [session uploadTaskWithRequest:request fromFile:[self.fileReader getFileFromOffset:self.offset error:&error]];
}


#pragma mark - Private Methods
- (NSMutableDictionary*)resumableUploads
{
    //TODO: Remove this and replace with the data store
    static id resumableUploads = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *resumableUploadsPath = [self resumableUploadsFilePath];
        resumableUploads = [NSMutableDictionary dictionaryWithContentsOfURL:resumableUploadsPath];
        if (!resumableUploads) {
            resumableUploads = [[NSMutableDictionary alloc] init];
        }
    });
    
    return resumableUploads;
}

- (NSURL *)resumableUploadsFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *directories = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                               inDomains:NSUserDomainMask];
    NSURL *applicationSupportDirectoryURL = [directories lastObject];
    NSString *applicationSupportDirectoryPath = [applicationSupportDirectoryURL absoluteString];
    
    BOOL isDirectory = NO;
    
    if (![fileManager fileExistsAtPath:applicationSupportDirectoryPath
                           isDirectory:&isDirectory]) {
        NSError *error = nil;
        BOOL success = [fileManager createDirectoryAtURL:applicationSupportDirectoryURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
        if (!success) {
            TUSLog(@"Unable to create %@ directory due to: %@",
                   applicationSupportDirectoryURL,
                   error);
        }
    }
    return [applicationSupportDirectoryURL URLByAppendingPathComponent:@"TUSResumableUploads.plist"];
}

- (long long) length {
    return self.fileReader.length;
}

#pragma mark - URLSession delegate methods

-(void)task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (self.failureBlock) {
        self.failureBlock(error);
    }

    self.idle = YES;
}


-(void)task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    switch([self state]) {
        case UploadingFile:
            if (self.progressBlock) {
                self.progressBlock((NSUInteger)totalBytesSent + self.offset, self.fileReader.length);
            }
            break;
        default:
            break;
    }
}

-(void)dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *headers = [httpResponse allHeaderFields];
    
    switch(self.state) {
        case CheckingFile: {
            if ([httpResponse statusCode] != 200 || [httpResponse statusCode] != 201) {
                TUSLog(@"Server responded to file check with %ld. Restarting upload",
                       (long)httpResponse.statusCode);
                //TODO: Error callback
                //TODO: Deal with gateway timeouts by going back to CheckingFile vs. creating
                self.state = CreatingFile;
                break;
            }
            [self updateStateFromHeaders:headers];
            break;
        }
        case CreatingFile: {
            if ([httpResponse statusCode] != 200 || [httpResponse statusCode] != 201) {
                TUSLog(@"Server responded to create request with %ld status code.",
                       (long)httpResponse.statusCode);
                self.failed = YES;
                //TODO: Handle error callbacks (lock retrying)
                break;
            }
            
            NSString *location = [headers valueForKey:HTTP_LOCATION];
            self.url = [NSURL URLWithString:location];
            
            TUSLog(@"Created resumable upload at %@ for fingerprint %@", [self url], [self fingerprint]);
            
            NSURL *dictionaryFileUrl = [self resumableUploadsFilePath];
            NSMutableDictionary *resumableUploads = [self resumableUploads];
            [resumableUploads setValue:location forKey:[self fingerprint]];
            BOOL success = [resumableUploads writeToURL:dictionaryFileUrl atomically:YES];
            if (!success) {
                TUSLog(@"Unable to save resumableUploads file");
            }
            
            self.state = UploadingFile;
            break;
        }
        case UploadingFile: {
            if ([httpResponse statusCode] != 204) {
                self.failed = YES;
                self.state = CheckingFile;
                //TODO: Handle error callbacks (problem on server)
                TUSLog(@"Server returned unexpected status code to upload - %ld", (long)httpResponse.statusCode);
                break;
            }
            [self updateStateFromHeaders:headers];
            break;
        }
        case Complete: {
            TUSLog(@"Unexpected response from server in complete state for upload at %@ for fingerprint %@", self.url, self.fingerprint);
            break;
        }
        default:
            break;
    }
    
    // Upload is now idle
    self.idle = YES;
    
    completionHandler(NSURLSessionResponseCancel);
}

/**
 Uses the offset from the provided headers to update the state of the upload - used by both check (HEAD) and upload (PATCH) response logic.
 */
-(void)updateStateFromHeaders:(NSDictionary*)headers
{
    NSString *rangeHeader = [headers valueForKey:HTTP_OFFSET];
    if (rangeHeader) {
        long long serverOffset = [rangeHeader longLongValue];
        if (serverOffset >= [self length]) {
            //TODO: Should we verify the file?
            TUSLog(@"Upload complete at %@ for fingerprint %@", [self url], [self fingerprint]);
            NSMutableDictionary *resumableUploads = [self resumableUploads];
            [resumableUploads removeObjectForKey:[self fingerprint]];
            BOOL success = [resumableUploads writeToURL:[self resumableUploadsFilePath]
                                             atomically:YES];
            if (!success) {
                TUSLog(@"Unable to save resumableUploads file");
            }
            if (self.resultBlock) {
                self.resultBlock(self.url);
            }
            self.state = Complete;
            return;
        } else {
            self.offset = (NSUInteger)serverOffset;
            self.state = UploadingFile;
        }
        TUSLog(@"Resumable upload at %@ for %@ from %lld (%@)",
               [self url], [self fingerprint], (long long)self.offset, rangeHeader);
        return;
    }
    else {
        TUSLog(@"Restarting upload at %@ for %@", [self url], [self fingerprint]);
        // We didn't get an offset header, so we need to run the check again
        self.state = CheckingFile;
        return;
    }
}

#pragma mark Persistence functions
+(instancetype)loadUploadWithId:(NSString *)uploadId fromStore:(TUSUploadStore *)store
{
    return [[TUSBackgroundUpload alloc] initWithUploadId:uploadId fromStore:store];
}

-(instancetype)initWithUploadId:(NSString *)uploadId fromStore:(TUSUploadStore *)store
{
    NSDictionary *savedData = [store loadDictionaryForUpload:uploadId];
    
    NSURL *url = [savedData objectForKey:@"uploadUrl"];
    NSURL *sourceFile = [savedData objectForKey:@"sourceFile"];
    NSDictionary *headers = [savedData objectForKey:@"headers"];
    
    self = [super init];
    if (self) {
        [self setEndpoint:url];
        [self setFileReader:[[TUSFileReader alloc] initWithURL:sourceFile]];
        [self setFingerprint:[sourceFile absoluteString]];
        [self setUploadHeaders:headers];
        [self setFileName:[sourceFile lastPathComponent]];
        [self setQueue:[[NSOperationQueue alloc] init]];
        
        NSString *uploadUrl = [[self resumableUploads] valueForKey:[self fingerprint]];
        if (uploadUrl == nil) {
            TUSLog(@"No resumable upload URL for fingerprint %@", [self fingerprint]);
            self.state = CreatingFile;
            return self;
        }
        
        [self setUrl:[NSURL URLWithString:uploadUrl]];
        
        self.state = CheckingFile;
    }

    return self;
}

-(void)saveToStore:(TUSUploadStore *)store
{
    // If the object has not been previously saved
    if (!self.id) {
        NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        NSMutableString *uploadId = [[NSMutableString alloc] initWithCapacity:20];
        
        for (int i=0; i<20; i++) {
            [uploadId appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
        }
        
        self.id = uploadId;
    }
    
    NSDictionary *uploadData = @{@"uploadId": self.id, @"uploadUrl": self.url, @"sourceFile": self.fingerprint, @"headers": self.uploadHeaders};
    
    [store saveDictionaryForUpload:self.id dictionary:uploadData];
}

@end
