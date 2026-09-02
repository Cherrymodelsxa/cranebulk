#import "CBFlowController.h"
#import "CBBulkOperations.h"
#import "CBCraneBridge.h"
#import "CBLocalization.h"
#import "CBUI.h"
#import <UIKit/UIKit.h>

@implementation CBFlowController

#pragma mark - Garde commune

// Retourne NO et affiche l'erreur adequate si l'operation ne peut pas avoir
// lieu sur cette application.
+ (BOOL)validateEnvironmentForApplication:(NSString *)bundleID {
    if (![CBCraneBridge isAvailable]) {
        [CBUI showMessage:CBLocalized(@"ERR_NO_CRANE") title:nil];
        return NO;
    }
    if (![CBCraneBridge isApplicationSupported:bundleID]) {
        [CBUI showMessage:CBLocalized(@"ERR_UNSUPPORTED") title:nil];
        return NO;
    }
    return YES;
}

#pragma mark - Creation

+ (void)startCreateFlowForApplication:(NSString *)bundleID {
    if (![self validateEnvironmentForApplication:bundleID]) return;

    NSString *appName = [CBCraneBridge displayNameForApplication:bundleID];
    NSUInteger nextIndex = [CBBulkOperations nextIndexForPrefix:appName application:bundleID];

    NSString *message = [NSString stringWithFormat:CBLocalized(@"CREATE_MESSAGE"),
                         (unsigned long)CBBulkMaximumCount,
                         appName, (unsigned long)nextIndex,
                         appName, (unsigned long)(nextIndex + 1)];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:CBLocalized(@"CREATE_TITLE")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = CBLocalized(@"CREATE_PLACEHOLDER");
        field.text = appName;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = CBLocalized(@"COUNT_PLACEHOLDER");
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:CBLocalized(@"CANCEL")
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        [CBUI dismissAnimated:YES completion:nil];
    }]];

    // L'alerte retient ses actions, qui retiennent leurs handlers : capturer
    // `alert` fortement ici creerait un cycle et l'alerte ne serait jamais
    // liberee. SpringBoard ne redemarrant pas, la fuite serait permanente.
    __weak UIAlertController *weakAlert = alert;

    [alert addAction:[UIAlertAction actionWithTitle:CBLocalized(@"CREATE_ACTION")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        UIAlertController *strongAlert = weakAlert;
        if (!strongAlert) return;

        NSString *prefix = [strongAlert.textFields[0].text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSInteger count = [strongAlert.textFields[1].text integerValue];

        if (prefix.length == 0) {
            [CBUI showMessage:CBLocalized(@"ERR_BAD_PREFIX") title:nil];
            return;
        }
        if (count < 1 || count > (NSInteger)CBBulkMaximumCount) {
            [CBUI showMessage:[NSString stringWithFormat:CBLocalized(@"ERR_BAD_COUNT"),
                               (unsigned long)CBBulkMaximumCount]
                        title:nil];
            return;
        }
        [self runCreateForApplication:bundleID prefix:prefix count:(NSUInteger)count];
    }]];

    [CBUI presentAlert:alert];
}

+ (void)runCreateForApplication:(NSString *)bundleID
                         prefix:(NSString *)prefix
                          count:(NSUInteger)count {
    __block CBBulkOperation *operation = nil;

    UIAlertController *progress = [CBUI progressAlertWithCancelHandler:^{
        [operation cancel];
    }];
    [CBUI presentAlert:progress];

    operation = [CBBulkOperations createContainersForApplication:bundleID
                                                          prefix:prefix
                                                           count:count
                                                        progress:^(NSUInteger done, NSUInteger total) {
        [CBUI updateProgressAlert:progress
                          message:[NSString stringWithFormat:CBLocalized(@"PROGRESS_CREATE"),
                                   (unsigned long)done, (unsigned long)total]];
    }
                                                      completion:^(CBBulkResult *result) {
        NSString *summary = [NSString stringWithFormat:CBLocalized(@"RESULT_CREATED"),
                             (unsigned long)result.succeeded];
        [self finishWithSummary:summary result:result];
    }];
}

#pragma mark - Suppression

+ (void)startDeleteFlowForApplication:(NSString *)bundleID {
    if (![self validateEnvironmentForApplication:bundleID]) return;

    NSArray<NSString *> *all = [CBCraneBridge containerIdentifiersForApplication:bundleID];
    if (all.count == 0) {
        [CBUI showMessage:CBLocalized(@"ERR_NOTHING_TO_DELETE") title:nil];
        return;
    }

    // Des conteneurs existent mais le defaut n'est pas identifiable : on
    // s'arrete et on produit un diagnostic plutot que de risquer de detruire
    // le conteneur d'origine.
    if (![CBCraneBridge defaultContainerIdentifierForApplication:bundleID]) {
        NSString *path = [CBCraneBridge writeDiagnosticForApplication:bundleID];
        [CBUI showMessage:[NSString stringWithFormat:CBLocalized(@"ERR_NO_DEFAULT"), path]
                    title:nil];
        return;
    }

    NSArray<NSString *> *deletable = [CBCraneBridge deletableContainerIdentifiersForApplication:bundleID];
    if (deletable.count == 0) {
        [CBUI showMessage:CBLocalized(@"ERR_NOTHING_TO_DELETE") title:nil];
        return;
    }

    NSString *appName = [CBCraneBridge displayNameForApplication:bundleID];
    NSString *message = [NSString stringWithFormat:CBLocalized(@"DELETE_MESSAGE"),
                         (unsigned long)deletable.count, appName];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:CBLocalized(@"DELETE_TITLE")
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:CBLocalized(@"CANCEL")
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        [CBUI dismissAnimated:YES completion:nil];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:CBLocalized(@"DELETE_ACTION")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [self runDeleteForApplication:bundleID identifiers:deletable];
    }]];

    [CBUI presentAlert:alert];
}

+ (void)runDeleteForApplication:(NSString *)bundleID
                    identifiers:(NSArray<NSString *> *)identifiers {
    __block CBBulkOperation *operation = nil;

    UIAlertController *progress = [CBUI progressAlertWithCancelHandler:^{
        [operation cancel];
    }];
    [CBUI presentAlert:progress];

    operation = [CBBulkOperations deleteContainersForApplication:bundleID
                                                     identifiers:identifiers
                                                        progress:^(NSUInteger done, NSUInteger total) {
        [CBUI updateProgressAlert:progress
                          message:[NSString stringWithFormat:CBLocalized(@"PROGRESS_DELETE"),
                                   (unsigned long)done, (unsigned long)total]];
    }
                                                      completion:^(CBBulkResult *result) {
        NSString *summary = [NSString stringWithFormat:CBLocalized(@"RESULT_DELETED"),
                             (unsigned long)result.succeeded];
        [self finishWithSummary:summary result:result];
    }];
}

#pragma mark - Fin d'operation

+ (void)finishWithSummary:(NSString *)summary result:(CBBulkResult *)result {
    NSMutableString *text = [summary mutableCopy];
    if (result.failed > 0) {
        [text appendFormat:CBLocalized(@"RESULT_FAILED"), (unsigned long)result.failed];
    }
    if (result.wasCancelled) {
        [text appendString:CBLocalized(@"RESULT_CANCELLED")];
    }

    // L'alerte de progression est encore a l'ecran : la fermer avant de
    // presenter le resume, sinon la seconde presentation est ignoree.
    [CBUI dismissAnimated:NO completion:^{
        [CBUI showMessage:text title:nil];
    }];
}

@end
