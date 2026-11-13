# Wattleft — тексты для App Store Connect

Языки интерфейса и страницы: английский (основной) и украинский. Лимиты App Store указаны в скобках; длина проверена скриптом `Tools/check_metadata.py`.

## Общее (одинаково для всех языков)

| Поле | Значение |
| --- | --- |
| Bundle ID | `app.wattleft.ios` |
| SKU | `wattleft-ios-1` |
| Основная категория | Утилиты (Utilities) |
| Дополнительная категория | Образ жизни (Lifestyle) |
| Возрастной рейтинг | 4+ (на все вопросы анкеты — «Нет») |
| Цена | Бесплатно |
| Copyright | `2026 Wattleft` |
| Support URL | `https://<ник>.github.io/wattleft/` |
| Privacy Policy URL | `https://<ник>.github.io/wattleft/privacy.html` |
| App Privacy | Data Not Collected |
| Шифрование | Не используется (в Info.plist уже `ITSAppUsesNonExemptEncryption = NO`) |

---

## Українська

### Назва (30)
```
Wattleft
```

### Підзаголовок (30)
```
На скільки вистачить станції
```

### Рекламний текст (170)
```
Заряд домашньої станції Marstek у годинах і хвилинах: прогноз до резерву, віджети й таймер на заблокованому екрані. Без акаунтів і хмари — лише ваша Wi‑Fi мережа.
```

### Опис (4000)
```
Wattleft перетворює заряд домашньої станції на зрозумілий час: не «62 %», а «вистачить до 21:40».

Застосунок підключається до станції Marstek Venus через вашу Wi‑Fi мережу, стежить за навантаженням і показує, скільки ще протримається світло — або скільки лишилося до повного заряду.

ЧАС, А НЕ ВІДСОТКИ
• Час, що лишився, за поточного навантаження — з урахуванням резерву, нижче якого станція не розряджається
• Час завершення: «до 19:40» або «повна через 2 год 10 хв»
• Середнє навантаження за 10 хвилин — прогноз не стрибає від увімкненого чайника

ГРАФІК І ПРОГНОЗ
• Історія заряду за останні години
• Пунктиром — прогноз до резерву або до 100 %
• Проведіть пальцем — побачите заряд у будь-який момент

ЗАВЖДИ ПІД РУКОЮ
• Віджети для екрана «Початок» — світлі й темні
• Таймер на заблокованому екрані та в Dynamic Island — іде сам щосекунди
• Віджети для заблокованого екрана
• Сповіщення «Світло дали», коли станція почала заряджатися від мережі

КАЛЬКУЛЯТОР НАВАНТАЖЕННЯ
• «А якщо увімкнути обігрівач?» — оберіть прилад або задайте потужність і дізнайтеся, на скільки вистачить

ПРИВАТНО
• Без акаунтів, реклами та аналітики
• Дані не залишають телефон: застосунок спілкується лише зі станцією у вашій мережі

ЯК ПІДКЛЮЧИТИ
1. Увімкніть Open API (Local API) у застосунку Marstek
2. Вкажіть IP-адресу станції у Wattleft
Немає станції поруч? Натисніть «Переглянути демо».

Підтримуються Marstek Venus E, C, A і D з увімкненим Open API.

Wattleft — незалежний застосунок і не пов’язаний із компанією Marstek. Marstek — товарний знак відповідного власника.
```

### Ключові слова (100, через кому без пробілів)
```
станція,батарея,акумулятор,електростанція,заряд,відключення,світло,енергія,ват,резерв,віджет
```

### Що нового (версія 1.0)
```
Перша версія Wattleft.
```

---

## English (основна мова / primary language)

### Name (30)
```
Wattleft
```

### Subtitle (30)
```
Home battery time remaining
```

### Promotional text (170)
```
See your Marstek home battery in hours and minutes: forecast to reserve, widgets and a Lock Screen timer. No accounts, no cloud — just your Wi‑Fi network.
```

### Description (4000)
```
Wattleft turns your home battery's charge into time you can understand: not "62%", but "lasts until 9:40 PM".

The app connects to your Marstek Venus over your Wi‑Fi network, watches the load and shows how long the power will last — or how long until it's fully charged.

TIME, NOT PERCENT
• Time left at the current load, down to the reserve your station keeps
• End time: "lasts until 7:40 PM" or "full by 2:10 PM"
• 10-minute average load, so the forecast doesn't jump when you boil a kettle

CHART AND FORECAST
• Charge history for the last hours
• Dotted forecast to reserve or to 100%
• Drag across the chart to see the charge at any moment

ALWAYS AT HAND
• Home Screen widgets in light and dark
• Lock Screen and Dynamic Island timer that counts down every second
• Lock Screen widgets
• A “Power is back” notification when the station starts charging from the grid

LOAD CALCULATOR
• "What if I turn on the heater?" — pick an appliance or set the power to see how long the battery lasts

PRIVATE
• No accounts, ads or analytics
• Your data never leaves the phone: the app talks only to the station on your network

SETUP
1. Turn on Open API (Local API) in the Marstek app
2. Enter the station's IP address in Wattleft
No station nearby? Tap "See demo".

Supports Marstek Venus E, C, A and D with Open API enabled.

Wattleft is an independent app and is not affiliated with Marstek. Marstek is a trademark of its respective owner.
```

### Keywords (100, comma-separated, no spaces)
```
battery,home battery,power station,charge,outage,backup,energy,watt,reserve,widget,solar,ups
```

### What's New (1.0)
```
First release of Wattleft.
```

---

## Заметка для проверяющего (App Review Information → Notes)

```
Wattleft connects to a Marstek Venus home battery over the local network (UDP, the station's own Open API). A physical station is not required for review:

1. Launch the app.
2. On the first screen tap "See demo" under the main button.
3. The app opens with a simulated station: live charge, time-left forecast, chart, load calculator. Widgets and the Lock Screen Live Activity use the same demo data.

Demo mode can be turned off in Settings (gear icon) → "Demo mode".
The app requests Local Network permission only to reach the user's station. No account or sign-in is needed. No data is collected.
```

Контакт для проверяющего: имя, телефон и `wattleft.app@gmail.com`. Демо-аккаунт не нужен (галочку «Sign-in required» не ставить).

---

## Скриншоты

Папки `AppStore/screenshots/en/` и `AppStore/screenshots/uk/`, iPhone 6.9″ (1320 × 2868), без альфа-канала — App Store сам масштабирует их для остальных iPhone. В App Store Connect загрузите `en` в английскую локализацию, `uk` — в украинскую.

| № | Файл | English | Українська |
| --- | --- | --- | --- |
| 1 | `01-dashboard.png` | How long will it last? | На скільки ще вистачить? |
| 2 | `02-lock-screen.png` | Countdown on the Lock Screen | Таймер на екрані блокування |
| 3 | `03-widgets.png` | Widgets for your Home Screen | Віджети для екрана «Початок» |
| 4 | `04-calculator.png` | What if I boil the kettle? | А якщо увімкнути чайник? |
| 5 | `05-private.png` | Just your Wi‑Fi | Лише ваша Wi‑Fi мережа |

Пересобрать: см. `AppStore/README.md`.
