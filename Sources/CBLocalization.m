#import "CBLocalization.h"

static NSDictionary<NSString *, NSString *> *CBFrenchStrings(void) {
    return @{
        @"MENU_CREATE_TITLE"      : @"Créer conteneurs Crane",
        @"MENU_CREATE_SUBTITLE"   : @"Création en masse",
        @"MENU_DELETE_TITLE"      : @"Effacer conteneurs Crane",
        @"MENU_DELETE_SUBTITLE"   : @"Conserve toujours le conteneur par défaut",

        @"CREATE_TITLE"           : @"Créer des conteneurs Crane",
        @"CREATE_MESSAGE"         : @"Choisis un préfixe et une quantité entre 1 et %lu. Les conteneurs seront nommés automatiquement, par exemple « %@ %lu », « %@ %lu »…",
        @"CREATE_PLACEHOLDER"     : @"Préfixe",
        @"COUNT_PLACEHOLDER"      : @"Quantité",
        @"CREATE_ACTION"          : @"Créer",

        @"DELETE_TITLE"           : @"Effacer les conteneurs",
        @"DELETE_MESSAGE"         : @"%lu conteneur(s) de « %@ » vont être supprimés définitivement, avec toutes leurs données. Le conteneur par défaut est conservé.\n\nCette action est irréversible.",
        @"DELETE_ACTION"          : @"Tout supprimer",

        @"CANCEL"                 : @"Annuler",
        @"OK"                     : @"OK",

        @"PROGRESS_CREATE"        : @"Création %lu / %lu",
        @"PROGRESS_DELETE"        : @"Suppression %lu / %lu",
        @"PROGRESS_TITLE"         : @"Patiente…",

        @"RESULT_CREATED"         : @"%lu conteneur(s) créé(s).",
        @"RESULT_DELETED"         : @"%lu conteneur(s) supprimé(s).",
        @"RESULT_FAILED"          : @"\n%lu échec(s).",
        @"RESULT_CANCELLED"       : @"\nOpération interrompue.",

        @"ERR_NO_CRANE"           : @"Crane est introuvable. Le tweak nécessite la version complète de Crane : Crane Lite n'expose pas l'API libCrane.",
        @"ERR_UNSUPPORTED"        : @"Crane ne prend pas en charge cette application.",
        @"ERR_NOTHING_TO_DELETE"  : @"Aucun conteneur à supprimer.",
        @"ERR_NO_DEFAULT"         : @"Le conteneur par défaut n'a pas pu être identifié avec certitude. Par sécurité, aucune suppression n'a été effectuée.\n\nUn diagnostic a été écrit dans %@ : envoie-le au développeur.",
        @"ERR_BAD_COUNT"          : @"Indique une quantité entre 1 et %lu.",
        @"ERR_BAD_PREFIX"         : @"Indique un préfixe.",
    };
}

static NSDictionary<NSString *, NSString *> *CBEnglishStrings(void) {
    return @{
        @"MENU_CREATE_TITLE"      : @"Bulk create containers",
        @"MENU_CREATE_SUBTITLE"   : @"Crane",
        @"MENU_DELETE_TITLE"      : @"Bulk delete containers",
        @"MENU_DELETE_SUBTITLE"   : @"Always keeps the default container",

        @"CREATE_TITLE"           : @"Create Crane containers",
        @"CREATE_MESSAGE"         : @"Pick a prefix and an amount between 1 and %lu. Containers are named automatically, for example \"%@ %lu\", \"%@ %lu\"…",
        @"CREATE_PLACEHOLDER"     : @"Prefix",
        @"COUNT_PLACEHOLDER"      : @"Amount",
        @"CREATE_ACTION"          : @"Create",

        @"DELETE_TITLE"           : @"Delete containers",
        @"DELETE_MESSAGE"         : @"%lu container(s) of \"%@\" will be permanently deleted, along with all their data. The default container is kept.\n\nThis cannot be undone.",
        @"DELETE_ACTION"          : @"Delete all",

        @"CANCEL"                 : @"Cancel",
        @"OK"                     : @"OK",

        @"PROGRESS_CREATE"        : @"Creating %lu / %lu",
        @"PROGRESS_DELETE"        : @"Deleting %lu / %lu",
        @"PROGRESS_TITLE"         : @"Please wait…",

        @"RESULT_CREATED"         : @"%lu container(s) created.",
        @"RESULT_DELETED"         : @"%lu container(s) deleted.",
        @"RESULT_FAILED"          : @"\n%lu failure(s).",
        @"RESULT_CANCELLED"       : @"\nOperation interrupted.",

        @"ERR_NO_CRANE"           : @"Crane was not found. This tweak requires the full version of Crane: Crane Lite does not expose the libCrane API.",
        @"ERR_UNSUPPORTED"        : @"Crane does not support this application.",
        @"ERR_NOTHING_TO_DELETE"  : @"No container to delete.",
        @"ERR_NO_DEFAULT"         : @"The default container could not be identified with certainty. Nothing was deleted, as a safety measure.\n\nA diagnostic was written to %@: please send it to the developer.",
        @"ERR_BAD_COUNT"          : @"Enter an amount between 1 and %lu.",
        @"ERR_BAD_PREFIX"         : @"Enter a prefix.",
    };
}

NSString *CBLocalized(NSString *key) {
    static NSDictionary<NSString *, NSString *> *strings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *language = [[NSLocale preferredLanguages] firstObject] ?: @"en";
        strings = [language hasPrefix:@"fr"] ? CBFrenchStrings() : CBEnglishStrings();
    });
    return strings[key] ?: key;
}
