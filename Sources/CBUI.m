#import "CBUI.h"
#import "CBLocalization.h"

static UIWindow *gCBWindow = nil;

@implementation CBUI

#pragma mark - Fenetre dediee

+ (UIWindow *)window {
    if (gCBWindow) return gCBWindow;

    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *targetScene = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]
                && scene.activationState == UISceneActivationStateForegroundActive) {
                targetScene = (UIWindowScene *)scene;
                break;
            }
        }
        if (targetScene) window = [[UIWindow alloc] initWithWindowScene:targetScene];
    }
    if (!window) window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    window.rootViewController = [UIViewController new];
    window.backgroundColor = [UIColor clearColor];
    // Au dessus des alertes systeme, sinon l'alerte est presentee sous
    // l'interface de SpringBoard et reste invisible.
    window.windowLevel = UIWindowLevelAlert + 100;

    gCBWindow = window;
    return window;
}

+ (void)teardownWindow {
    gCBWindow.hidden = YES;
    gCBWindow.rootViewController = nil;
    gCBWindow = nil;
}

#pragma mark - Presentation

+ (void)presentAlert:(UIAlertController *)alert {
    if (!alert) return;

    // Presenter est systematiquement differe d'un tour de runloop : quand cet
    // appel vient du handler d'un bouton d'alerte, UIKit est encore en train
    // de fermer l'alerte precedente et la nouvelle presentation serait ignoree.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self window];
        UIViewController *root = window.rootViewController;

        void (^present)(void) = ^{
            window.hidden = NO;
            [window makeKeyAndVisible];
            [root presentViewController:alert animated:YES completion:nil];
        };

        if (root.presentedViewController) {
            [root dismissViewControllerAnimated:NO completion:present];
        } else {
            present();
        }
    });
}

+ (void)dismissAnimated:(BOOL)animated completion:(void (^)(void))completion {
    UIViewController *root = gCBWindow.rootViewController;
    if (!root.presentedViewController) {
        [self teardownWindow];
        if (completion) completion();
        return;
    }
    [root dismissViewControllerAnimated:animated completion:^{
        [self teardownWindow];
        if (completion) completion();
    }];
}

#pragma mark - Alertes prefabriquees

+ (UIAlertController *)progressAlertWithCancelHandler:(void (^)(void))cancelHandler {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:CBLocalized(@"PROGRESS_TITLE")
                                            message:@"\n"
                                     preferredStyle:UIAlertControllerStyleAlert];
    if (cancelHandler) {
        [alert addAction:[UIAlertAction actionWithTitle:CBLocalized(@"CANCEL")
                                                  style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction *action) {
            cancelHandler();
        }]];
    }
    return alert;
}

+ (void)updateProgressAlert:(UIAlertController *)alert message:(NSString *)message {
    // setMessage: sur une alerte affichee est pris en compte, l'alerte se
    // remet en page toute seule.
    alert.message = message;
}

+ (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:(title ?: @"CraneBulk")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:CBLocalized(@"OK")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [CBUI dismissAnimated:YES completion:nil];
    }]];
    [self presentAlert:alert];
}

@end
