# Материалы для App Store

- `metadata.md` — все тексты карточки (RU и EN), заметка для проверяющего, настройки App Store Connect.
- `screenshots/` — готовые скриншоты iPhone 6.9″ (1320×2868).

## Как пересобрать скриншоты

Исходники снимаются в симуляторе iPhone (отладочная сборка, демо-режим) — отдельно для каждого языка. Язык переключается для всего симулятора, иначе экран блокировки и виджеты останутся на прежнем языке.

```bash
export D=<UDID симулятора>
Tools/sim_shots.sh lang en          # или uk; перезагружает симулятор
Tools/sim_shots.sh prep             # статус-бар 9:41, демо ~74 %
Tools/sim_shots.sh app light -hideDemoBanner
Tools/sim_shots.sh shot <папка>/dash.png
```

Нужные кадры в папке исходников:

| Файл | Что на экране |
| --- | --- |
| `dash.png` | главный экран, светлая тема (`app light -hideDemoBanner`) |
| `dash_dark.png` | главный экран, тёмная тема (`app dark -hideDemoBanner`) |
| `menu.png` | прокрутка до калькулятора, открыто меню «Appliance» |
| `dash_charging.png` | главный экран в фазе заряда с баннером «Power is back»: `defaults write <group prefs> demoSoc -float 46`, `demoCharging -bool true`, `gridOnline -bool true` (чтобы не всплыло системное уведомление) |
| `lock.png` | экран блокировки с Live Activity (кнопка блокировки дважды) |
| `wg_light.png`, `wg_dark.png` | витрина виджетов (`app light -widgetGallery`, `app dark -widgetGallery`) |

Затем:

```bash
swift Tools/appstore_screens.swift <исходники en> AppStore/screenshots/en en
swift Tools/appstore_screens.swift <исходники uk> AppStore/screenshots/uk uk
python3 Tools/check_metadata.py
```

Тексты заголовков на картинках — в таблице `copy` в начале раздела «Тексты» файла `Tools/appstore_screens.swift`. Флаги `-hideDemoBanner`, `-widgetGallery` и `demoSoc` работают только в отладочной сборке.
