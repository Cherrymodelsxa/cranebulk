// CBBulkOperations.h — creation et suppression groupees de conteneurs Crane.
//
// Les appels a l'API Crane sont serialises sur le main thread, une operation
// par tour de runloop. La thread-safety de CraneManager n'est pas documentee,
// et Crane met a jour l'interface de SpringBoard quand les conteneurs
// changent, donc on ne sort pas du main thread. Rendre la main entre chaque
// operation garde l'interface reactive et permet l'annulation.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Nombre maximum de conteneurs traitables en une seule operation.
extern const NSUInteger CBBulkMaximumCount;

/// Jeton d'annulation remis a l'appelant.
@interface CBBulkOperation : NSObject
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
- (void)cancel;
@end

/// Resultat d'une operation groupee.
@interface CBBulkResult : NSObject
@property (nonatomic, readonly) NSUInteger succeeded;
@property (nonatomic, readonly) NSUInteger failed;
@property (nonatomic, readonly, getter=wasCancelled) BOOL cancelled;
@end

typedef void (^CBBulkProgressBlock)(NSUInteger done, NSUInteger total);
typedef void (^CBBulkCompletionBlock)(CBBulkResult *result);

@interface CBBulkOperations : NSObject

/// Premier indice libre pour ce prefixe, en repartant du plus grand suffixe
/// numerique deja utilise. Evite de creer "Firefox 1" quand il existe deja.
+ (NSUInteger)nextIndexForPrefix:(NSString *)prefix application:(NSString *)bundleID;

/// Cree `count` conteneurs nommes "<prefix> <n>".
+ (CBBulkOperation *)createContainersForApplication:(NSString *)bundleID
                                             prefix:(NSString *)prefix
                                              count:(NSUInteger)count
                                           progress:(nullable CBBulkProgressBlock)progress
                                         completion:(nullable CBBulkCompletionBlock)completion;

/// Supprime tous les conteneurs sauf celui par defaut, qui est toujours
/// conserve. Bascule d'abord le conteneur actif sur le defaut si necessaire.
+ (CBBulkOperation *)deleteContainersForApplication:(NSString *)bundleID
                                        identifiers:(NSArray<NSString *> *)identifiers
                                           progress:(nullable CBBulkProgressBlock)progress
                                         completion:(nullable CBBulkCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
