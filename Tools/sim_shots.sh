#!/bin/zsh
# Помощник для съёмки исходников скриншотов App Store в симуляторе.
#   Tools/sim_shots.sh lang <en|uk>        — язык всего симулятора (перезагрузка)
#   Tools/sim_shots.sh prep                — чистый статус-бар, демо ~74 %
#   Tools/sim_shots.sh app <light|dark> [аргументы]  — запустить Wattleft
#   Tools/sim_shots.sh shot <файл.png>     — снимок экрана
#   Tools/sim_shots.sh lock                — экран блокировки (выкл/вкл экран)
# Нужна переменная D=<UDID симулятора>.
set -e
: ${D:?set D to simulator UDID}
APP=app.wattleft.ios

group_prefs() {
  local G=$(xcrun simctl get_app_container $D $APP groups | awk -F'\t' '/group.app.wattleft.ios/{print $2}')
  echo "$G/Library/Preferences/group.app.wattleft.ios"
}

case $1 in
  lang)
    locale=$([[ $2 == uk ]] && echo uk_UA || echo en_US)
    xcrun simctl spawn $D defaults write -g AppleLanguages -array $2
    xcrun simctl spawn $D defaults write -g AppleLocale $locale
    xcrun simctl shutdown $D 2>/dev/null || true
    xcrun simctl boot $D
    xcrun simctl bootstatus $D -b >/dev/null
    ;;
  prep)
    xcrun simctl status_bar $D override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported
    P=$(group_prefs)
    xcrun simctl spawn $D defaults write "$P" demoSoc -float 74
    for k in chargeHistory samples lastSnapshot; do xcrun simctl spawn $D defaults delete "$P" $k 2>/dev/null || true; done
    ;;
  app)
    xcrun simctl ui $D appearance $2
    shift 2
    xcrun simctl launch --terminate-running-process $D $APP "$@" >/dev/null
    sleep 5
    ;;
  shot)
    xcrun simctl io $D screenshot "$2" >/dev/null 2>&1
    ;;
esac
