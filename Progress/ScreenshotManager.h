//
//  ScreenshotManager.h
//  Progress
//
//  Created by Craig McNamara on 24/08/2014.
//  Copyright (c) 2014 dibnt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ScreenshotManager : NSObject

+ (id)sharedManager;

- (void)startWatching;
- (void)stopWatching;
@end
