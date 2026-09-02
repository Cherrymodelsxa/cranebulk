// CBUI.h — presentation d'alertes depuis SpringBoard.
//
// SpringBoard n'a pas de rootViewController sur lequel presenter librement, et
// s'accrocher a la fenetre courante casse le springboard quand elle change
// d'etat. On utilise donc une UIWindow dediee, creee a la demande et detruite
// des que plus rien n'est affiche.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CBUI : NSObject

/// Presente une alerte dans la fenetre dediee. Si une alerte est deja
/// affichee, elle est fermee d'abord.
+ (void)presentAlert:(UIAlertController *)alert;

/// Ferme ce qui est affiche et libere la fenetre.
+ (void)dismissAnimated:(BOOL)animated completion:(nullable void (^)(void))completion;

/// Alerte de progression sans bouton d'action, hormis Annuler.
+ (UIAlertController *)progressAlertWithCancelHandler:(nullable void (^)(void))cancelHandler;

/// Met a jour le texte d'une alerte de progression deja affichee.
+ (void)updateProgressAlert:(UIAlertController *)alert message:(NSString *)message;

/// Alerte informative simple avec un unique bouton OK.
+ (void)showMessage:(NSString *)message title:(nullable NSString *)title;

@end

NS_ASSUME_NONNULL_END
