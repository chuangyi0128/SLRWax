//
//  AOPAspect.h
//  AOPAspect
//
//  Created by Andras Koczka on 1/21/12.
//  Copyright (c) 2012 Andras Koczka
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>

typedef void (^ldaspect_block_t)(NSInvocation *invocation);

@interface LDAOPAspect : NSObject

// Intercept methods return an identifier that can be used for deregistration with the removeInterceptorWithIdentifier method
// Only instance methods can be intercepted
- (NSString *)interceptClass:(Class)aClass beforeSelector:(SEL)selector usingBlock:(ldaspect_block_t)block;
- (NSString *)interceptClass:(Class)aClass afterSelector:(SEL)selector usingBlock:(ldaspect_block_t)block;
- (NSString *)interceptClass:(Class)aClass insteadSelector:(SEL)selector usingBlock:(ldaspect_block_t)block;

// Removes an interceptor block
- (void)removeAnInterceptorWithIdentifier:(NSString *)identifier;

// Use this method to get the AOPAspect instance. Don't use alloc/init.
+ (LDAOPAspect *)instance;

@end
