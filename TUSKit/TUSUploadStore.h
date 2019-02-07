//
//  TUSUploadStore.h
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import <Foundation/Foundation.h>
#import "TUSResumableUpload+Private.h"

/**
 Abstract implementation of a TUSUploadStore.  Must be overridden by a concrete sub-class
 */
@interface TUSUploadStore : NSObject
// IMPLEMENTED METHODS
/**
 Generate a new, unique upload ID for this data store
 */
-(NSString *)generateUploadId;

// UNIMPLEMENTED ABSTRACT METHODS
-(TUSResumableUpload *) loadUploadWithIdentifier:(NSString *)uploadId delegate:(id<TUSResumableUploadDelegate>)delegate;
-(BOOL)saveUpload:(TUSResumableUpload *)upload;
/**
 Remove any uploads with the specified identifier from the data store
 @returns NO if the upload could not be removed, YES if the upload was removed or no upload was found
 */
-(BOOL)removeUploadWithIdentifier:(NSString *)uploadIdentifier;
-(BOOL)containsUploadWithIdentifier:(NSString *)uploadId;
@property (readonly) NSArray <NSString *>* allUploadIdentifiers;

@end
