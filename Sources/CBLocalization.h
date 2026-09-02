// CBLocalization.h — chaines FR / EN embarquees.
//
// Volontairement sans bundle .lproj : le tweak n'installe qu'une dylib, pas de
// ressources, donc les chaines sont compilees dans le binaire.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Chaine localisee pour la cle donnee. Retourne la cle si elle est inconnue.
NSString *CBLocalized(NSString *key);

NS_ASSUME_NONNULL_END
