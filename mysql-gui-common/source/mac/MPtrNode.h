//
//  MPtrNode.h
//  MySQLGUICommon
//
//  Copyright (c) 2005 MySQL AB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef int (*MPtrFree)(void*);

@interface MPtrNode : NSObject {
  NSString *_caption;
  void *_pointer;
  MPtrFree _destroyer;
  int _tag;
}

- (void)setCaption:(NSString*)caption;
- (NSString*)caption;
- (void*)pointer;
- (void)setPointer:(void*)ptr;
- (void)setPointer:(void*)ptr destroyer:(MPtrFree)destroyer;
- (int)tag;
- (void)setTag:(int)tag;

@end
