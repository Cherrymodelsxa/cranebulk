#!/usr/bin/env bash
# Remplace le pseudo GitHub dans toutes les URLs du projet.
#
# Seules les URLs sont touchees. L'identifiant du paquet (com.blaxk.cranebulk)
# est volontairement laisse tel quel : il n'a pas a correspondre au compte
# GitHub, et le changer invaliderait les mises a jour pour ceux qui ont deja
# installe le tweak.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <pseudo-github>" >&2
    exit 1
fi

NEW_USER="$1"
OLD_USER="blaxk"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Le nom d'hote GitHub Pages est resolu par le DNS, qui ignore la casse et se
# sert en minuscules. Les chemins github.com/<user> tolerent la casse, on y
# garde donc l'orthographe exacte du compte.
NEW_USER_LOWER="$(printf '%s' "$NEW_USER" | tr '[:upper:]' '[:lower:]')"

if [ "$NEW_USER" = "$OLD_USER" ]; then
    echo "Le pseudo est deja '$OLD_USER', rien a faire."
    exit 0
fi

cd "$REPO_ROOT"

FILES=(
    "control"
    "README.md"
    "docs/index.html"
    "docs/depiction.html"
    "docs/sileo-depiction.json"
)

for file in "${FILES[@]}"; do
    [ -f "$file" ] || continue
    sed -i.bak \
        -e "s#${OLD_USER}\.github\.io#${NEW_USER_LOWER}.github.io#g" \
        -e "s#github\.com/${OLD_USER}#github.com/${NEW_USER}#g" \
        "$file"
    rm -f "${file}.bak"
    echo "  mis a jour : $file"
done

echo
echo "URLs pointant desormais vers :"
echo "  Depot Sileo : https://${NEW_USER_LOWER}.github.io/cranebulk/"
echo "  Code source : https://github.com/${NEW_USER}/cranebulk"
