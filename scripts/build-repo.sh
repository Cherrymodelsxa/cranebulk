#!/usr/bin/env bash
# Regenere l'index APT servi par GitHub Pages depuis docs/.
#
# Sileo et Cydia lisent Packages* et Release a la racine de l'URL du depot.
# Les chemins de Packages sont relatifs a cette racine, donc dpkg-scanpackages
# doit imperativement tourner depuis docs/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
DEBS_DIR="$DOCS_DIR/debs"

mkdir -p "$DEBS_DIR"

# Recuperation des paquets fraichement compiles.
if compgen -G "$REPO_ROOT/packages/*.deb" > /dev/null; then
    cp -f "$REPO_ROOT"/packages/*.deb "$DEBS_DIR/"
    echo "Paquets copies dans docs/debs/"
fi

if ! compgen -G "$DEBS_DIR/*.deb" > /dev/null; then
    echo "Aucun .deb trouve dans docs/debs/, index non genere." >&2
    exit 1
fi

cd "$DOCS_DIR"

echo "Generation de Packages..."
dpkg-scanpackages -m debs /dev/null > Packages 2>/dev/null

# Les trois compressions sont fournies : Sileo prefere .zst ou .bz2, les
# anciens clients Cydia ne lisent que .gz ou le fichier brut.
gzip  -9 -c Packages > Packages.gz
bzip2 -9 -c Packages > Packages.bz2
if command -v zstd > /dev/null; then
    zstd -q -f -19 -o Packages.zst Packages
fi

echo "Generation de Release..."
cat > Release <<EOF
Origin: CraneBulk Repo
Label: CraneBulk Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm64
Components: main
Description: CraneBulk - creation et suppression groupees de conteneurs Crane
EOF

echo
echo "Index genere. Contenu de docs/ :"
ls -la
echo
echo "Paquets indexes :"
grep -E '^(Package|Version|Filename):' Packages || true
