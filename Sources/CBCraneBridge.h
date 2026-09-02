// CBCraneBridge.h — couche d'acces sure a l'API Crane.
//
// Aucune liaison statique avec libcrane.dylib : la classe CraneManager est
// resolue au runtime. Si Crane n'est pas installe, le pont se signale
// simplement comme indisponible au lieu d'empecher SpringBoard de charger.

#import <Foundation/Foundation.h>
#import "libCrane.h"

NS_ASSUME_NONNULL_BEGIN

@interface CBCraneBridge : NSObject

/// Crane est installe et son API repond. Re-evalue a chaque appel.
+ (BOOL)isAvailable;

/// Instance partagee de CraneManager, ou nil si Crane est absent.
+ (nullable CraneManager *)manager;

/// L'application accepte-t-elle des conteneurs Crane.
+ (BOOL)isApplicationSupported:(NSString *)bundleID;

/// Nom affichable de l'application (fallback : le bundle identifier).
+ (NSString *)displayNameForApplication:(NSString *)bundleID;

/// Tous les identifiants de conteneurs connus pour cette application.
+ (NSArray<NSString *> *)containerIdentifiersForApplication:(NSString *)bundleID;

/// Identifiant du conteneur par defaut, ou nil s'il n'a pas pu etre determine.
+ (nullable NSString *)defaultContainerIdentifierForApplication:(NSString *)bundleID;

/// Identifiants supprimables : tous sauf le conteneur par defaut.
+ (NSArray<NSString *> *)deletableContainerIdentifiersForApplication:(NSString *)bundleID;

/// Identifiant du conteneur actuellement actif, ou nil.
+ (nullable NSString *)activeContainerIdentifierForApplication:(NSString *)bundleID;

/// Nom affichable d'un conteneur (fallback : son identifiant).
+ (NSString *)displayNameForContainer:(NSString *)containerID application:(NSString *)bundleID;

/// Cree un conteneur. Retourne son identifiant, ou nil en cas d'echec.
+ (nullable NSString *)createContainerNamed:(NSString *)name application:(NSString *)bundleID;

/// Supprime un conteneur. Refuse de supprimer le conteneur par defaut.
+ (BOOL)deleteContainer:(NSString *)containerID application:(NSString *)bundleID;

/// Bascule le conteneur actif (sans passer par la biometrie).
+ (BOOL)setActiveContainer:(nullable NSString *)containerID application:(NSString *)bundleID;

/// Vide le cache de preferences puis relance l'application. A appeler une
/// seule fois en fin d'operation groupee, jamais dans la boucle.
+ (void)flushAndReloadApplication:(NSString *)bundleID;

/// Ecrit un dump de l'etat Crane pour cette application dans
/// /tmp/cranebulk-diagnostic.txt. Sert a verifier la detection du conteneur
/// par defaut sur un appareil reel. Retourne le chemin du fichier.
+ (NSString *)writeDiagnosticForApplication:(NSString *)bundleID;

@end

NS_ASSUME_NONNULL_END
