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
- (NSUInteger)length;
- (NSURL *)getFileFromOffset:(NSUInteger)offset
                       error:(NSError **)error;

@end
