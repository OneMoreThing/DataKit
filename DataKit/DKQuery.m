//
//  DKQuery.m
//  DataKit
//
//  Created by Erik Aigner on 23.02.12.
//  Copyright (c) 2012 chocomoko.com. All rights reserved.
//

#import "DKQuery.h"

#import "DKQuery-Private.h"
#import "DKRequest.h"
#import "DKEntity.h"
#import "DKEntity-Private.h"
#import "DKManager.h"
#import "DKMapReduce.h"

@interface DKQueryConditionProxy : NSProxy

+ (id)proxyForQuery:(DKQuery *)query conditionArray:(NSMutableArray *)array;

@end

@implementation DKQuery
DKSynthesize(entityName)
DKSynthesize(limit)
DKSynthesize(skip)
DKSynthesize(mapReduce)
DKSynthesize(cachePolicy)
DKSynthesize(queryMap)
DKSynthesize(sort)
DKSynthesize(ors)
DKSynthesize(ands)
DKSynthesize(referenceIncludes)
DKSynthesize(fieldInclExcl)

+ (DKQuery *)queryWithEntityName:(NSString *)entityName {
  return [[self alloc] initWithEntityName:entityName];
}

- (id)initWithEntityName:(NSString *)entityName {
  self = [super init];
  if (self) {
    self.entityName = entityName;
    self.queryMap = [NSMutableDictionary new];
    self.sort = [NSMutableDictionary new];
    self.ors = [NSMutableArray new];
    self.ands = [NSMutableArray new];
    self.referenceIncludes = [NSMutableArray new];
    self.fieldInclExcl = [NSMutableDictionary new];
    self.cachePolicy = DKCachePolicyIgnoreCache;
  }
  return self;
}

- (void)reset {
  [self.queryMap removeAllObjects];
  [self.sort removeAllObjects];
  [self.ors removeAllObjects];
  [self.ands removeAllObjects];
  [self.referenceIncludes removeAllObjects];
  [self.fieldInclExcl removeAllObjects];
}

- (DKQuery *)or {
  return [DKQueryConditionProxy proxyForQuery:self conditionArray:self.ors];
}

- (DKQuery *)and {
  return [DKQueryConditionProxy proxyForQuery:self conditionArray:self.ands];
}

- (void)orderAscendingByKey:(NSString *)key {
  [self.sort setObject:[NSNumber numberWithInteger:1] forKey:key];
}

- (void)orderDescendingByKey:(NSString *)key {
  [self.sort setObject:[NSNumber numberWithInteger:-1] forKey:key];
}

- (void)orderAscendingByCreationDate {
  [self orderAscendingByKey:@"_id"];
}

- (void)orderDescendingByCreationDate {
  [self orderDescendingByKey:@"_id"];
}

- (void)orderAscendingByUpdateDate {
  [self orderDescendingByKey:@"_updated"];
}

- (void)orderDescendingByUpdateDate {
  [self orderDescendingByKey:@"_updated"];
}

- (void)orderAscendingBySequenceNumber {
  [self orderAscendingByKey:@"_seq"];
}

- (void)orderDescendingBySequenceNumber {
  [self orderDescendingByKey:@"_seq"];
}

- (void)whereKey:(NSString *)key equalTo:(id)object {
  [self.queryMap setObject:object forKey:key];
}

- (void)whereKey:(NSString *)key lessThan:(id)object {
  [[self queryDictForKey:key] setObject:object forKey:@"$lt"];
}

- (void)whereKey:(NSString *)key lessThanOrEqualTo:(id)object {
  [[self queryDictForKey:key] setObject:object forKey:@"$lte"];
}

- (void)whereKey:(NSString *)key greaterThan:(id)object {
  [[self queryDictForKey:key] setObject:object forKey:@"$gt"];
}

- (void)whereKey:(NSString *)key greaterThanOrEqualTo:(id)object {
  [[self queryDictForKey:key] setObject:object forKey:@"$gte"];
}

- (void)whereKey:(NSString *)key notEqualTo:(id)object {
  [[self queryDictForKey:key] setObject:object forKey:@"$ne"];
}

- (void)whereKey:(NSString *)key containedIn:(NSArray *)array {
  [[self queryDictForKey:key] setObject:array forKey:@"$in"];
}

- (void)whereKey:(NSString *)key notContainedIn:(NSArray *)array {
  [[self queryDictForKey:key] setObject:array forKey:@"$nin"];
}

- (void)whereKey:(NSString *)key containsAllIn:(NSArray *)array {
  [[self queryDictForKey:key] setObject:array forKey:@"$all"];
}

- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex {
  [self whereKey:key matchesRegex:regex options:0];
}

- (void)whereKey:(NSString *)key matchesRegex:(NSString *)regex options:(DKRegexOption)options {
  NSMutableString *optionString = [NSMutableString new];
  if ((options & DKRegexOptionCaseInsensitive) == DKRegexOptionCaseInsensitive) {
    [optionString appendString:@"i"];
  }
  else if ((options & DKRegexOptionMultiline) == DKRegexOptionMultiline) {
    [optionString appendString:@"m"];
  }
  else if ((options & DKRegexOptionDotall) == DKRegexOptionDotall) {
    [optionString appendString:@"s"];
  }
  NSMutableDictionary *queryDict = [self queryDictForKey:key];
  [queryDict setObject:regex forKey:@"$regex"];
  if (optionString.length > 0) {
    [queryDict setObject:optionString forKey:@"$options"];
  }
}

- (void)whereKey:(NSString *)key containsString:(NSString *)string caseInsensitive:(BOOL)caseInsensitive {
  NSString *safeString = [self makeRegexSafeString:string];
  DKRegexOption opts = DKRegexOptionMultiline;
  if (caseInsensitive) {
    opts |= DKRegexOptionCaseInsensitive;
  }
  [self whereKey:key matchesRegex:safeString options:opts];
}

- (void)whereKey:(NSString *)key hasPrefix:(NSString *)prefix {
  NSString *safeString = [self makeRegexSafeString:prefix];
  NSString *regex = [NSString stringWithFormat:@"^%@", safeString];
  [self whereKey:key matchesRegex:regex];
}

- (void)whereKey:(NSString *)key hasSuffix:(NSString *)suffix {
  NSString *safeString = [self makeRegexSafeString:suffix];
  NSString *regex = [NSString stringWithFormat:@"%@$", safeString];
  [self whereKey:key matchesRegex:regex];
}

- (void)whereKeyExists:(NSString *)key {
  [[self queryDictForKey:key] setObject:[NSNumber numberWithBool:YES] forKey:@"$exists"];
}

- (void)whereKeyDoesNotExist:(NSString *)key {
  [[self queryDictForKey:key] setObject:[NSNumber numberWithBool:NO] forKey:@"$exists"];
}

- (void)whereEntityIdMatches:(NSString *)entityId {
  [self whereKey:@"_id" equalTo:entityId];
}

- (void)whereSequenceNumberMatches:(NSUInteger)sequenceNum {
  [self whereKey:@"_seq" equalTo:[NSNumber numberWithUnsignedInteger:sequenceNum]];
}

-(void) whereKey:(NSString *)key nearPoint:(NSArray*)point withinDistance:(NSNumber*)distance {
   [[self queryDictForKey:key] setObject:point forKey:@"$near"];
   //[[self queryDictForKey:key] setObject:@"true" forKey:@"spherical"];
   [[self queryDictForKey:key] setObject:distance forKey:@"$maxDistance"];
}

- (void)includeReferenceAtKey:(NSString *)key {
  if (![self.referenceIncludes containsObject:key]) {
    [self.referenceIncludes addObject:key];
  }
}

- (void)excludeKeys:(NSArray *)keys {
  [self.fieldInclExcl removeAllObjects];
  for (NSString *key in keys) {
    [self.fieldInclExcl setObject:[NSNumber numberWithInt:0] forKey:key];
  }
}

- (void)includeKeys:(NSArray *)keys {
  [self.fieldInclExcl removeAllObjects];
  for (NSString *key in keys) {
    [self.fieldInclExcl setObject:[NSNumber numberWithInt:1] forKey:key];
  }
}

- (id)find:(NSError **)error one:(BOOL)findOne count:(NSUInteger *)countOut {  
  // Create request dict
  NSMutableDictionary *requestDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      self.entityName, @"entity", nil];
  if (self.queryMap.count > 0) {
    [requestDict setObject:self.queryMap forKey:@"q"];
  }
  if (self.ors.count > 0) {
    [requestDict setObject:self.ors forKey:@"or"];
  }
  if (self.ands.count > 0) {
    [requestDict setObject:self.ands forKey:@"and"];
  }
  if (self.referenceIncludes.count > 0) {
    [requestDict setObject:self.referenceIncludes forKey:@"refIncl"];
  }
  if (self.fieldInclExcl.count > 0) {
    [requestDict setObject:self.fieldInclExcl forKey:@"fieldInEx"];
  }
  if (self.sort.count > 0) {
    [requestDict setObject:self.sort forKey:@"sort"];
  }
  if (self.limit > 0) {
    [requestDict setObject:[NSNumber numberWithUnsignedInteger:self.limit] forKey:@"limit"];
  }
  if (self.mapReduce != nil) {
    NSMutableDictionary *mr = [NSMutableDictionary new];
    
    if (self.mapReduce.mapFunction.length > 0) {
      [mr setObject:self.mapReduce.mapFunction forKey:@"map"];
    }
    if (self.mapReduce.reduceFunction.length > 0) {
      [mr setObject:self.mapReduce.reduceFunction forKey:@"reduce"];
    }
    if (self.mapReduce.finalizeFunction.length > 0) {
      [mr setObject:self.mapReduce.finalizeFunction forKey:@"finalize"];
    }
    if (self.mapReduce.context.count > 0) {
      [mr setObject:self.mapReduce.context forKey:@"context"];
    }
    
    [requestDict setObject:mr forKey:@"mr"];
  }
  if (self.skip > 0) {
    [requestDict setObject:[NSNumber numberWithUnsignedInteger:self.skip] forKey:@"skip"];
  }
  if (findOne) {
    [requestDict setObject:[NSNumber numberWithBool:YES] forKey:@"findOne"];
  }
  if (countOut != NULL) {
    [requestDict setObject:[NSNumber numberWithBool:YES] forKey:@"count"];
  }
  
  
  // Send request synchronously
  DKRequest *request = [DKRequest request];
  request.cachePolicy = self.cachePolicy;
  
  NSError *requestError = nil;
  id results = [request sendRequestWithObject:requestDict method:@"query" error:&requestError];
  if (requestError != nil) {
    if (error != nil) {
      *error = requestError;
    }
    return nil;
  }
  
  // Map reduce is uses, process result and return
  if (self.mapReduce != nil) {
    return self.mapReduce.resultProcessor(results);
  }
  
  // Query returned results
  else if ([results isKindOfClass:[NSArray class]]) {
    NSMutableArray *entities = [NSMutableArray new];
    for (NSDictionary *objDict in results) {
      if ([objDict isKindOfClass:[NSDictionary class]]) {
        DKEntity *entity = [[DKEntity alloc] initWithName:self.entityName];
        entity.resultMap = objDict;
        
        [entities addObject:entity];
      }
    }
    
    return [NSArray arrayWithArray:entities];
  }
  
  // Query returned object count
  else if ([results isKindOfClass:[NSNumber class]]) {
    if (countOut != NULL) {
      *countOut = [(NSNumber *)results unsignedIntegerValue];
    }
  }
  else {
#ifdef CONFIGURATION_Debug
    NSLog(@"warning: query did not return object list: %@", results);
#endif
  }
  return nil;
}

- (NSArray *)findAll {
  return [self findAll:NULL];
}

- (NSArray *)findAll:(NSError **)error {
  if (self.mapReduce != nil) {
    [NSException raise:NSInternalInconsistencyException format:@"cannot use find-all with map reduce set"];
    return nil;
  }
  return [self find:error one:NO count:NULL];
}

- (void)findAllInBackgroundWithBlock:(void (^)(NSArray *results, NSError *error))block {
  dispatch_queue_t q = dispatch_get_current_queue();
  dispatch_async([DKManager queue], ^{
    NSError *error = nil;
    NSArray *entities = [self findAll:&error];
    if (block != NULL) {
      dispatch_async(q, ^{
        block(entities, error); 
      });
    }
  });
}

- (DKEntity *)findOne {
  return [self findOne:NULL];
}

- (DKEntity *)findOne:(NSError **)error {
  if (self.mapReduce != nil) {
    [NSException raise:NSInternalInconsistencyException format:@"cannot use find-one with map reduce set"];
    return nil;
  }
  return [[self find:error one:YES count:NULL] lastObject];
}

- (void)findOneInBackgroundWithBlock:(void (^)(DKEntity *entity, NSError *error))block {
  dispatch_queue_t q = dispatch_get_current_queue();
  dispatch_async([DKManager queue], ^{
    NSError *error = nil;
    DKEntity *entity = [self findOne:&error];
    if (block != NULL) {
      dispatch_async(q, ^{
        block(entity, error); 
      });
    }
  });
}

- (id)performMapReduce:(DKMapReduce *)mapReduce {
  return [self performMapReduce:mapReduce error:NULL];
}

- (id)performMapReduce:(DKMapReduce *)mapReduce error:(NSError **)error {
  self.mapReduce = mapReduce;
  id result = [self find:error one:NO count:NULL];
  self.mapReduce = nil;
  
  return result;
}

- (void)performMapReduce:(DKMapReduce *)mapReduce inBackgroundWithBlock:(void (^)(id result, NSError *error))block {
  dispatch_queue_t q = dispatch_get_current_queue();
  dispatch_async([DKManager queue], ^{
    NSError *error = nil;
    id result = [self performMapReduce:mapReduce error:&error];
    if (block != NULL) {
      dispatch_async(q, ^{
        block(result, error); 
      });
    }
  });
}

- (NSInteger)countAll {
  return [self countAll:NULL];
}

- (NSInteger)countAll:(NSError **)error {
  NSUInteger count = 0;
  [self find:error one:NO count:&count];
  return count;
}

- (void)countAllInBackgroundWithBlock:(void (^)(NSUInteger count, NSError *error))block {
  dispatch_queue_t q = dispatch_get_current_queue();
  dispatch_async([DKManager queue], ^{
    NSError *error = nil;
    NSUInteger count = [self countAll:&error];
    if (block != NULL) {
      dispatch_async(q, ^{
        block(count, error); 
      });
    }
  });
}

@end

@implementation DKQueryConditionProxy {
@private
  DKQuery         *query_;
  NSMutableArray  *conditions_;
}

+ (id)proxyForQuery:(DKQuery *)query conditionArray:(NSMutableArray *)array {
  DKQueryConditionProxy *proxy = [self alloc];
  proxy->query_ = query;
  proxy->conditions_ = array;
  return proxy;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
  NSMutableDictionary *queryMap = query_.queryMap;
  query_.queryMap = [NSMutableDictionary new];

  [invocation invokeWithTarget:query_];

  if (query_.queryMap.count > 0) {
    [conditions_ addObject:query_.queryMap];
  }
  query_.queryMap = queryMap;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
  return [query_ methodSignatureForSelector:sel];
}

@end

@implementation DKQuery (Private)

- (NSMutableDictionary*)queryDictForKey:(NSString *)key {
  NSMutableDictionary *dict = [self.queryMap objectForKey:key];
  if (dict == nil) {
    dict = [NSMutableDictionary new];
    [self.queryMap setObject:dict forKey:key];
  }
  
  return dict;
}

- (NSString *)makeRegexSafeString:(NSString *)string {
  // There are 11 special regex characters we need to escape!
  // 1: the opening square bracket [
  // 2: the backslash \
  // 3: the caret ^
  // 4: the dollar sign $
  // 5: the period or dot .
  // 6: the vertical bar or pipe symbol |
  // 7: the question mark ?
  // 8: the asterisk or star *
  // 9: the plus sign +
  // 10: the opening round bracket (
  // 11: and the closing round bracket )  
  CFStringRef strIn = (__bridge CFStringRef)string;
  CFMutableStringRef accu = CFStringCreateMutable(NULL, string.length * 2);
  
  for (NSUInteger loc=0; loc<string.length; loc++) {
    unichar c =  CFStringGetCharacterAtIndex(strIn, loc);
    BOOL escape = NO;
    switch (c) {
      case '[':
      case '\\':
      case '^':
      case '$':
      case '.':
      case '|':
      case '?':
      case '*':
      case '+':
      case '(':
      case ')': escape = YES; break;
    }
    if (escape) {
      CFStringAppend(accu, CFSTR("\\"));
    }
    CFStringRef s = CFStringCreateWithCharacters(NULL, &c, 1);
    CFStringAppend(accu, s);
    CFRelease(s);
  };
  
  return CFBridgingRelease(accu);
}

@end
