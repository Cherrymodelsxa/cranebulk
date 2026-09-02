// Tweak.x — injection des entrees CraneBulk dans le menu long-press des icones.
//
// SpringBoard construit le menu d'une icone via le delegue UIContextMenuInteraction
// implemente par SBIconView. La configuration renvoyee porte un bloc
// "actionProvider" appele au moment ou le menu s'affiche. On enveloppe ce bloc
// pour ajouter notre section sans toucher aux entrees existantes, dont le
// sous-menu Conteneur de Crane.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "Sources/CBCraneBridge.h"
#import "Sources/CBFlowController.h"
#import "Sources/CBLocalization.h"

#pragma mark - Interfaces privees SpringBoard

@interface SBApplication : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@end

@interface SBIcon : NSObject
- (NSString *)applicationBundleID;
@end

@interface SBApplicationIcon : SBIcon
- (SBApplication *)application;
@end

@interface SBIconView : UIView
- (SBIcon *)icon;
@end

#pragma mark - Utilitaires

static const void *kCBActionProviderKey = &kCBActionProviderKey;

static NSString *CBBundleIdentifierForIcon(SBIcon *icon) {
    if (!icon) return nil;
    if ([icon respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [icon applicationBundleID];
        if (bundleID.length) return bundleID;
    }
    if ([icon respondsToSelector:@selector(application)]) {
        SBApplication *app = [(SBApplicationIcon *)icon application];
        if ([app respondsToSelector:@selector(bundleIdentifier)] && app.bundleIdentifier.length) {
            return app.bundleIdentifier;
        }
    }
    return nil;
}

// Lit le bloc actionProvider de la configuration. KVC d'abord, acces direct a
// l'ivar en secours si Apple renomme la propriete.
static id CBGetActionProvider(UIContextMenuConfiguration *configuration) {
    @try {
        return [configuration valueForKey:@"actionProvider"];
    } @catch (NSException *exception) {
        Ivar ivar = class_getInstanceVariable([configuration class], "_actionProvider");
        return ivar ? object_getIvar(configuration, ivar) : nil;
    }
}

// Remplace le bloc actionProvider. Le bloc est copie sur le tas et rattache a
// la configuration en objet associe : object_setIvar ne retient rien, sans
// cette reference forte le bloc serait libere avant son appel.
static BOOL CBSetActionProvider(UIContextMenuConfiguration *configuration, id provider) {
    id copied = [provider copy];
    objc_setAssociatedObject(configuration, kCBActionProviderKey, copied,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        [configuration setValue:copied forKey:@"actionProvider"];
        return YES;
    } @catch (NSException *exception) {
        Ivar ivar = class_getInstanceVariable([configuration class], "_actionProvider");
        if (!ivar) return NO;
        object_setIvar(configuration, ivar, copied);
        return YES;
    }
}

#pragma mark - Construction du menu

static UIMenu *CBMenuByAppendingSection(UIMenu *original, NSString *bundleID) {
    // Le menu se ferme avec une animation ; presenter l'alerte pendant cette
    // fermeture la ferait disparaitre avec lui.
    void (^runAfterMenuDismissal)(void (^)(void)) = ^(void (^work)(void)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), work);
    };

    UIAction *create =
        [UIAction actionWithTitle:CBLocalized(@"MENU_CREATE_TITLE")
                            image:[UIImage systemImageNamed:@"plus.square.on.square"]
                       identifier:@"com.blaxk.cranebulk.create"
                          handler:^(__kindof UIAction *action) {
            runAfterMenuDismissal(^{
                [CBFlowController startCreateFlowForApplication:bundleID];
            });
        }];

    UIAction *purge =
        [UIAction actionWithTitle:CBLocalized(@"MENU_DELETE_TITLE")
                            image:[UIImage systemImageNamed:@"trash"]
                       identifier:@"com.blaxk.cranebulk.delete"
                          handler:^(__kindof UIAction *action) {
            runAfterMenuDismissal(^{
                [CBFlowController startDeleteFlowForApplication:bundleID];
            });
        }];
    purge.attributes = UIMenuElementAttributesDestructive;

    if (@available(iOS 15.0, *)) {
        create.subtitle = CBLocalized(@"MENU_CREATE_SUBTITLE");
        purge.subtitle = CBLocalized(@"MENU_DELETE_SUBTITLE");
    }

    // Section inline : les deux entrees apparaissent dans un groupe separe par
    // un filet, sans sous-menu a deplier.
    UIMenu *section = [UIMenu menuWithTitle:@""
                                      image:nil
                                 identifier:@"com.blaxk.cranebulk.section"
                                    options:UIMenuOptionsDisplayInline
                                   children:@[create, purge]];

    if (!original) return [UIMenu menuWithTitle:@"" children:@[section]];
    return [original menuByReplacingChildren:
            [original.children arrayByAddingObject:section]];
}

#pragma mark - Hook

%hook SBIconView

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location {
    UIContextMenuConfiguration *configuration = %orig;
    if (!configuration) return configuration;

    NSString *bundleID = CBBundleIdentifierForIcon([self icon]);
    if (bundleID.length == 0) return configuration;

    // Rien n'est ajoute aux icones que Crane ne gere pas : dossiers, widgets,
    // ou applications exclues.
    if (![CBCraneBridge isAvailable] || ![CBCraneBridge isApplicationSupported:bundleID]) {
        return configuration;
    }

    id originalProvider = CBGetActionProvider(configuration);

    UIContextMenuActionProvider wrapped = ^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIMenu *base = nil;
        if (originalProvider) {
            base = ((UIContextMenuActionProvider)originalProvider)(suggested);
        }
        return CBMenuByAppendingSection(base, bundleID);
    };

    CBSetActionProvider(configuration, wrapped);
    return configuration;
}

%end

#pragma mark - Chargement

%ctor {
    %init;

    // Diagnostic uniquement, et volontairement differe : SBIconView vient de
    // SpringBoardHome.framework, qui n'est pas garanti charge au moment ou les
    // constructeurs des tweaks s'executent. Verifier ici et renoncer au %init
    // desactiverait le tweak a tort sur un systeme parfaitement compatible.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        Class iconViewClass = objc_getClass("SBIconView");
        SEL selector = @selector(contextMenuInteraction:configurationForMenuAtLocation:);
        if (!iconViewClass || !class_getInstanceMethod(iconViewClass, selector)) {
            NSLog(@"[CraneBulk] SBIconView n'expose pas %@ sur cette version d'iOS : "
                  @"les entrees de menu n'apparaitront pas.",
                  NSStringFromSelector(selector));
        }
    });
}
