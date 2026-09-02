#import "CBCraneBridge.h"
#import <dlfcn.h>

// Chemins possibles de libcrane.dylib selon le type de jailbreak.
static NSString *const kCBCraneLibraryPaths[] = {
    @"/var/jb/usr/lib/libcrane.dylib",   // rootless (Dopamine, Fugu15 Max)
    @"/usr/lib/libcrane.dylib",          // rootful
};

@implementation CBCraneBridge

#pragma mark - Resolution de l'API

+ (Class)craneManagerClass {
    Class cls = NSClassFromString(@"CraneManager");
    if (cls) return cls;

    // Crane n'a pas encore ete charge dans ce processus : tentative de dlopen.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (NSUInteger i = 0; i < sizeof(kCBCraneLibraryPaths) / sizeof(NSString *); i++) {
            NSString *path = kCBCraneLibraryPaths[i];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                dlopen(path.fileSystemRepresentation, RTLD_LAZY);
                if (NSClassFromString(@"CraneManager")) break;
            }
        }
    });
    return NSClassFromString(@"CraneManager");
}

+ (CraneManager *)manager {
    Class cls = [self craneManagerClass];
    if (!cls || ![cls respondsToSelector:@selector(sharedManager)]) return nil;
    return (CraneManager *)[cls sharedManager];
}

+ (BOOL)isAvailable {
    CraneManager *mgr = [self manager];
    // createNewContainerWithName:forApplicationWithIdentifier: est le minimum
    // vital. Crane Lite n'expose pas libCrane, ce test le detecte.
    return mgr != nil
        && [mgr respondsToSelector:@selector(createNewContainerWithName:forApplicationWithIdentifier:)]
        && [mgr respondsToSelector:@selector(containerIdentifiersOfApplicationWithIdentifier:)];
}

#pragma mark - Applications

+ (BOOL)isApplicationSupported:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (!mgr || bundleID.length == 0) return NO;
    if (![mgr respondsToSelector:@selector(isApplicationSupportedByCrane:)]) return YES;
    return [mgr isApplicationSupportedByCrane:bundleID];
}

+ (NSString *)displayNameForApplication:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (mgr && [mgr respondsToSelector:@selector(displayNameForApplicationWithIdentifier:)]) {
        NSString *name = [mgr displayNameForApplicationWithIdentifier:bundleID];
        if (name.length) return name;
    }
    return bundleID ?: @"";
}

#pragma mark - Conteneurs

+ (NSArray<NSString *> *)containerIdentifiersForApplication:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (!mgr || bundleID.length == 0) return @[];
    NSArray *raw = [mgr containerIdentifiersOfApplicationWithIdentifier:bundleID];
    if (![raw isKindOfClass:NSArray.class]) return @[];

    NSMutableArray<NSString *> *clean = [NSMutableArray array];
    for (id entry in raw) {
        if ([entry isKindOfClass:NSString.class] && [(NSString *)entry length]) {
            [clean addObject:entry];
        }
    }
    return clean;
}

+ (NSString *)activeContainerIdentifierForApplication:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (!mgr || ![mgr respondsToSelector:@selector(activeContainerIdentifierForApplicationWithIdentifier:)]) {
        return nil;
    }
    id active = [mgr activeContainerIdentifierForApplicationWithIdentifier:bundleID];
    return [active isKindOfClass:NSString.class] ? active : nil;
}

+ (NSString *)displayNameForContainer:(NSString *)containerID application:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    SEL sel = @selector(displayNameForContainerWithIdentifier:ofApplicationWithIdentifier:shouldUseShortVersion:);
    if (mgr && [mgr respondsToSelector:sel]) {
        NSString *name = [mgr displayNameForContainerWithIdentifier:containerID
                                        ofApplicationWithIdentifier:bundleID
                                              shouldUseShortVersion:YES];
        if (name.length) return name;
    }
    return containerID ?: @"";
}

#pragma mark - Detection du conteneur par defaut
//
// Crane n'expose pas directement "quel est le conteneur par defaut". Trois
// strategies independantes sont tentees, de la plus fiable a la plus faible.
// Si aucune n'aboutit, la methode retourne nil et l'appelant doit considerer
// qu'aucune suppression n'est sure.

+ (NSString *)defaultContainerIdentifierForApplication:(NSString *)bundleID {
    NSArray<NSString *> *all = [self containerIdentifiersForApplication:bundleID];
    if (all.count == 0) return nil;
    NSSet<NSString *> *known = [NSSet setWithArray:all];

    // Strategie 1 : les reglages de l'application referencent l'identifiant du
    // conteneur par defaut sous une cle contenant "default".
    NSString *fromSettings = [self defaultIdentifierFromSettings:bundleID known:known];
    if (fromSettings) return fromSettings;

    // Strategie 2 : comparaison des libelles. Crane sait produire le libelle du
    // conteneur par defaut, le conteneur dont le libelle correspond est lui.
    NSString *fromDisplayName = [self defaultIdentifierFromDisplayNames:bundleID candidates:all];
    if (fromDisplayName) return fromDisplayName;

    // Strategie 3 : identifiant litteral, forme historique.
    for (NSString *containerID in all) {
        if ([containerID caseInsensitiveCompare:@"Default"] == NSOrderedSame) {
            return containerID;
        }
    }

    return nil;
}

+ (NSString *)defaultIdentifierFromSettings:(NSString *)bundleID known:(NSSet<NSString *> *)known {
    CraneManager *mgr = [self manager];
    if (!mgr || ![mgr respondsToSelector:@selector(applicationSettingsForApplicationWithIdentifier:)]) {
        return nil;
    }
    id settings = [mgr applicationSettingsForApplicationWithIdentifier:bundleID];
    if (![settings isKindOfClass:NSDictionary.class]) return nil;

    for (id key in (NSDictionary *)settings) {
        if (![key isKindOfClass:NSString.class]) continue;
        if ([(NSString *)key rangeOfString:@"default" options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }
        id value = ((NSDictionary *)settings)[key];
        // La valeur n'est retenue que si elle designe un conteneur existant.
        if ([value isKindOfClass:NSString.class] && [known containsObject:value]) {
            return value;
        }
    }
    return nil;
}

+ (NSString *)defaultIdentifierFromDisplayNames:(NSString *)bundleID candidates:(NSArray<NSString *> *)candidates {
    CraneManager *mgr = [self manager];
    SEL nameSel = @selector(displayNameForContainerWithName:isDefaultContainer:shouldUseShortVersion:);
    SEL idSel = @selector(displayNameForContainerWithIdentifier:ofApplicationWithIdentifier:shouldUseShortVersion:);
    if (!mgr || ![mgr respondsToSelector:nameSel] || ![mgr respondsToSelector:idSel]) return nil;

    NSString *defaultLabel = [mgr displayNameForContainerWithName:@""
                                              isDefaultContainer:YES
                                           shouldUseShortVersion:YES];
    if (defaultLabel.length == 0) return nil;

    for (NSString *containerID in candidates) {
        NSString *label = [mgr displayNameForContainerWithIdentifier:containerID
                                         ofApplicationWithIdentifier:bundleID
                                               shouldUseShortVersion:YES];
        if (label.length && [label isEqualToString:defaultLabel]) {
            return containerID;
        }
    }
    return nil;
}

+ (NSArray<NSString *> *)deletableContainerIdentifiersForApplication:(NSString *)bundleID {
    NSArray<NSString *> *all = [self containerIdentifiersForApplication:bundleID];
    NSString *defaultID = [self defaultContainerIdentifierForApplication:bundleID];

    // Sans identification certaine du conteneur par defaut, aucune suppression
    // n'est proposee. Mieux vaut ne rien faire que detruire le conteneur
    // d'origine de l'utilisateur.
    if (!defaultID) return @[];

    NSMutableArray<NSString *> *deletable = [NSMutableArray array];
    for (NSString *containerID in all) {
        if (![containerID isEqualToString:defaultID]) [deletable addObject:containerID];
    }
    return deletable;
}

#pragma mark - Mutations

+ (NSString *)createContainerNamed:(NSString *)name application:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (!mgr || name.length == 0 || bundleID.length == 0) return nil;
    id created = [mgr createNewContainerWithName:name forApplicationWithIdentifier:bundleID];
    return ([created isKindOfClass:NSString.class] && [(NSString *)created length]) ? created : nil;
}

+ (BOOL)deleteContainer:(NSString *)containerID application:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (!mgr || containerID.length == 0 || bundleID.length == 0) return NO;
    if (![mgr respondsToSelector:@selector(deleteContainerWithIdentifier:forApplicationWithIdentifier:)]) return NO;

    // Garde-fou final : jamais le conteneur par defaut, quel que soit l'appelant.
    NSString *defaultID = [self defaultContainerIdentifierForApplication:bundleID];
    if (defaultID && [defaultID isEqualToString:containerID]) return NO;

    [mgr deleteContainerWithIdentifier:containerID forApplicationWithIdentifier:bundleID];
    return YES;
}

+ (BOOL)setActiveContainer:(NSString *)containerID application:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    SEL sel = @selector(setActiveContainerIdentifier:forApplicationWithIdentifier:);
    if (!mgr || ![mgr respondsToSelector:sel]) return NO;
    [mgr setActiveContainerIdentifier:containerID forApplicationWithIdentifier:bundleID];
    return YES;
}

+ (void)flushAndReloadApplication:(NSString *)bundleID {
    CraneManager *mgr = [self manager];
    if (!mgr || bundleID.length == 0) return;
    if ([mgr respondsToSelector:@selector(flushCFPrefsdCacheForApplicationWithIdentifier:)]) {
        [mgr flushCFPrefsdCacheForApplicationWithIdentifier:bundleID];
    }
    if ([mgr respondsToSelector:@selector(reloadApplicationWithIdentifier:)]) {
        [mgr reloadApplicationWithIdentifier:bundleID];
    }
}

#pragma mark - Diagnostic

+ (NSString *)writeDiagnosticForApplication:(NSString *)bundleID {
    NSString *path = @"/tmp/cranebulk-diagnostic.txt";
    NSMutableString *out = [NSMutableString string];

    [out appendFormat:@"CraneBulk diagnostic - %@\n", [NSDate date]];
    [out appendFormat:@"Application  : %@\n", bundleID];
    [out appendFormat:@"Crane dispo  : %@\n", [self isAvailable] ? @"oui" : @"non"];

    CraneManager *mgr = [self manager];
    if (!mgr) {
        [out appendString:@"CraneManager introuvable : Crane absent, ou edition Lite.\n"];
    } else {
        NSArray *all = [self containerIdentifiersForApplication:bundleID];
        NSString *defaultID = [self defaultContainerIdentifierForApplication:bundleID];
        [out appendFormat:@"Actif        : %@\n", [self activeContainerIdentifierForApplication:bundleID] ?: @"(nil)"];
        [out appendFormat:@"Defaut       : %@\n", defaultID ?: @"(NON DETECTE)"];
        [out appendFormat:@"Conteneurs   : %lu\n", (unsigned long)all.count];
        for (NSString *containerID in all) {
            [out appendFormat:@"  - %@  =>  %@\n", containerID,
                              [self displayNameForContainer:containerID application:bundleID]];
        }
        if ([mgr respondsToSelector:@selector(applicationSettingsForApplicationWithIdentifier:)]) {
            [out appendFormat:@"\nReglages application :\n%@\n",
                              [mgr applicationSettingsForApplicationWithIdentifier:bundleID]];
        }
    }

    [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    return path;
}

@end
