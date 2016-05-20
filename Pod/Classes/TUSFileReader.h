//
//  TUSFileReader.h
//  Pods
//
//  Created by Findyr on 5/18/16.
//
//

#import <Foundation/Foundation.h>

@interface TUSFileReader : NSObject
- (instancetype)initWithURL:(NSURL *)fileUrl;
- (NSURL *)getFileFromOffset:(NSUInteger)offset
                       error:(NSError **)error;
/**
 Clean up the file reader, deleting associated temporary files.  Returns YES if the reader was successfully cleaned up, NO otherwise.
 */
- (BOOL)close;
@property (readonly) NSUInteger length;
@end
