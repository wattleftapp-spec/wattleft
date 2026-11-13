#!/bin/zsh
# Экспортирует строки проекта, подставляет украинские переводы из Tools/uk_translations.json
# и импортирует обратно в String Catalog. Печатает строки, для которых перевода нет.
set -e
cd "$(dirname $0)/.."
T=$(mktemp -d)
xcodebuild -exportLocalizations -project MarstekBattery.xcodeproj -localizationPath $T -exportLanguage uk -sdk iphonesimulator >/dev/null
X="$T/uk.xcloc/Localized Contents/uk.xliff"
python3 -I - "$X" Tools/uk_translations.json <<'PY'
import sys, json, xml.etree.ElementTree as ET
NS='urn:oasis:names:tc:xliff:document:1.2'; ET.register_namespace('', NS)
tr=json.load(open(sys.argv[2], encoding='utf-8'))
skip={'CFBundleDisplayName','CFBundleName','NSHumanReadableCopyright','NSLocalNetworkUsageDescription'}
t=ET.parse(sys.argv[1]); missing=[]
for u in t.getroot().iter(f'{{{NS}}}trans-unit'):
    key=u.get('id')
    if key in skip: continue
    src=u.find(f'{{{NS}}}source').text or ''
    val=tr.get(key)
    if val is None:
        val=src
        if any(c.isalpha() for c in key.replace('%lld','').replace('%@','')) and key not in ('Wattleft','Dashboard'):
            missing.append(key)
    tgt=u.find(f'{{{NS}}}target')
    if tgt is None: tgt=ET.SubElement(u, f'{{{NS}}}target')
    tgt.text=val; tgt.set('state','translated')
t.write(sys.argv[1], encoding='utf-8', xml_declaration=True)
print("missing uk:", missing or "none")
PY
xcodebuild -importLocalizations -project MarstekBattery.xcodeproj -localizationPath "$T/uk.xcloc" 2>&1 | grep -i "error" || true
rm -rf $T
