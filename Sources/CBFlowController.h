// CBFlowController.h — enchainement des ecrans pour les deux operations.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CBFlowController : NSObject

/// Demande un prefixe et une quantite, puis cree les conteneurs.
+ (void)startCreateFlowForApplication:(NSString *)bundleID;

/// Demande confirmation, puis supprime tous les conteneurs sauf le defaut.
+ (void)startDeleteFlowForApplication:(NSString *)bundleID;

@end

NS_ASSUME_NONNULL_END
