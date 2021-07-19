#import "RNEventSource.h"

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>
#import <objc/runtime.h>

#import "EventSource.h"

@implementation EventSource (React)

- (NSNumber *)reactTag
{
  return objc_getAssociatedObject(self, _cmd);
}

- (void)setReactTag:(NSNumber *)reactTag
{
  objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation RNEventSource
{
    NSMutableDictionary<NSNumber *, EventSource *> *_sources;
}

@synthesize eventSource;
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)dealloc
{
  for (EventSource *source in _sources.allValues) {
    [source close];
  }
}

RCT_EXPORT_METHOD(connect:(NSString *)URLString sourceID:(nonnull NSNumber *)sourceID auth:(nonnull NSString *)auth)
{
  NSURL *serverURL = [NSURL URLWithString:URLString];

    EventSource *source = [EventSource eventSourceWithURL:serverURL auth:auth];
  source.reactTag = sourceID;

  [source onOpen: ^(Event *e) {
    [_bridge.eventDispatcher sendDeviceEventWithName:@"eventsourceOpen" body:@{
      @"id": source.reactTag
    }];
  }];

  [source onError: ^(Event *e) {
    [_bridge.eventDispatcher sendDeviceEventWithName:@"eventsourceFailed" body:@{
      @"message":e.error.userInfo[@"NSLocalizedDescription"],
      @"status":RCTNullIfNil(e.error.userInfo[@"status"]),
      @"body":RCTNullIfNil(e.error.userInfo[@"body"]),
      @"id": source.reactTag
    }];
  }];

  [source onMessage: ^(Event *e) {
    [_bridge.eventDispatcher sendDeviceEventWithName:@"eventsourceEvent" body:@{
      @"type": e.event ?: @"message",
      @"data": RCTNullIfNil(e.data),
      @"id": source.reactTag
    }];
  }];

  if (!_sources) {
    _sources = [NSMutableDictionary new];
  }

  _sources[sourceID] = source;
}

RCT_EXPORT_METHOD(close:(nonnull NSNumber *)sourceID)
{
  [_sources[sourceID] close];
  [_sources removeObjectForKey:sourceID];

  RCTLogInfo(@"RNEventSource: Closed %@", sourceID);
}

@end
