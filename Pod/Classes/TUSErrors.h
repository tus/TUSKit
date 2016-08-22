//
//  TUSErrors.h
//
//  Created by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const TUSErrorDomain;

typedef enum TUSErrorCode : NSInteger {
    TUSFileDataErrorClosed,
    TUSFileDataErrorCannotOpen,
    TUSResumableUploadErrorServer // Server errors will include a "responseCode" key in the user info dictionary
} TUSErrorCode;