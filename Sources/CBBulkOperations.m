#import "CBBulkOperations.h"
#import "CBCraneBridge.h"

const NSUInteger CBBulkMaximumCount = 100;

#pragma mark - Jeton d'annulation

@implementation CBBulkOperation
- (void)cancel { _cancelled = YES; }
@end

#pragma mark - Resultat

@interface CBBulkResult ()
@property (nonatomic, readwrite) NSUInteger succeeded;
@property (nonatomic, readwrite) NSUInteger failed;
@property (nonatomic, readwrite, getter=wasCancelled) BOOL cancelled;
@end

@implementation CBBulkResult
@end

#pragma mark - Operations

@implementation CBBulkOperations

+ (NSUInteger)nextIndexForPrefix:(NSString *)prefix application:(NSString *)bundleID {
    if (prefix.length == 0) return 1;

    NSString *pattern = [NSString stringWithFormat:@"^%@\\s+(\\d+)$",
                         [NSRegularExpression escapedPatternForString:prefix]];
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                 options:NSRegularExpressionCaseInsensitive
                                                   error:NULL];
    if (!regex) return 1;

    NSUInteger highest = 0;
    for (NSString *containerID in [CBCraneBridge containerIdentifiersForApplication:bundleID]) {
        NSString *name = [CBCraneBridge displayNameForContainer:containerID application:bundleID];
        if (name.length == 0) continue;

        NSTextCheckingResult *match =
            [regex firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
        if (!match || match.numberOfRanges < 2) continue;

        NSUInteger value = (NSUInteger)[[name substringWithRange:[match rangeAtIndex:1]] integerValue];
        if (value > highest) highest = value;
    }
    return highest + 1;
}

#pragma mark Creation

+ (CBBulkOperation *)createContainersForApplication:(NSString *)bundleID
                                             prefix:(NSString *)prefix
                                              count:(NSUInteger)count
                                           progress:(CBBulkProgressBlock)progress
                                         completion:(CBBulkCompletionBlock)completion {
    CBBulkOperation *operation = [CBBulkOperation new];
    CBBulkResult *result = [CBBulkResult new];

    NSUInteger clamped = MIN(MAX(count, (NSUInteger)1), CBBulkMaximumCount);
    NSUInteger startIndex = [self nextIndexForPrefix:prefix application:bundleID];

    [self runStep:0
            total:clamped
        operation:operation
           result:result
         progress:progress
       completion:completion
          bundleID:bundleID
             work:^BOOL(NSUInteger step) {
        NSString *name = [NSString stringWithFormat:@"%@ %lu",
                          prefix, (unsigned long)(startIndex + step)];
        return [CBCraneBridge createContainerNamed:name application:bundleID] != nil;
    }];

    return operation;
}

#pragma mark Suppression

+ (CBBulkOperation *)deleteContainersForApplication:(NSString *)bundleID
                                        identifiers:(NSArray<NSString *> *)identifiers
                                           progress:(CBBulkProgressBlock)progress
                                         completion:(CBBulkCompletionBlock)completion {
    CBBulkOperation *operation = [CBBulkOperation new];
    CBBulkResult *result = [CBBulkResult new];
    NSArray<NSString *> *targets = [identifiers copy];

    // Si le conteneur actif fait partie des cibles, il faut d'abord revenir au
    // conteneur par defaut : supprimer le conteneur actif sous les pieds de
    // Crane laisserait l'application sans conteneur valide.
    NSString *defaultID = [CBCraneBridge defaultContainerIdentifierForApplication:bundleID];
    NSString *activeID = [CBCraneBridge activeContainerIdentifierForApplication:bundleID];
    if (defaultID && activeID && [targets containsObject:activeID]) {
        [CBCraneBridge setActiveContainer:defaultID application:bundleID];
    }

    [self runStep:0
            total:targets.count
        operation:operation
           result:result
         progress:progress
       completion:completion
          bundleID:bundleID
             work:^BOOL(NSUInteger step) {
        return [CBCraneBridge deleteContainer:targets[step] application:bundleID];
    }];

    return operation;
}

#pragma mark Moteur

// Execute `work` une fois par tour de runloop sur le main thread, en rendant la
// main entre chaque etape pour que SpringBoard reste reactif et que le bouton
// Annuler puisse etre pris en compte.
+ (void)runStep:(NSUInteger)step
          total:(NSUInteger)total
      operation:(CBBulkOperation *)operation
         result:(CBBulkResult *)result
       progress:(CBBulkProgressBlock)progress
     completion:(CBBulkCompletionBlock)completion
       bundleID:(NSString *)bundleID
           work:(BOOL (^)(NSUInteger step))work {

    if (step >= total || operation.isCancelled) {
        result.cancelled = operation.isCancelled;
        // Un seul rechargement, en fin de parcours : le faire a chaque
        // iteration relancerait l'application des dizaines de fois.
        if (result.succeeded > 0) {
            [CBCraneBridge flushAndReloadApplication:bundleID];
        }
        if (completion) completion(result);
        return;
    }

    if (work(step)) {
        result.succeeded++;
    } else {
        result.failed++;
    }

    NSUInteger done = step + 1;
    if (progress) progress(done, total);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self runStep:done
                total:total
            operation:operation
               result:result
             progress:progress
           completion:completion
             bundleID:bundleID
                 work:work];
    });
}

@end
