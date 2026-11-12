# Roblox Save + Main Menu Pack · v0.1.0

**Окружение / Environment:** [Save Lobby Kit](assets/save-lobby/README.md)
— шесть оригинальных моделей мебели, готовый импорт и Python-генератор.

**Инструмент разработчика / Developer tool:** [Studio XML Sync](tools/README.md)
— проверка и перенос изменений Luau в модель и демоместо без внешних библиотек.
См. [журнал изменений](CHANGELOG.md) и [результаты проверок](tools/VALIDATION.md).

**СЫРОЙ ШАБЛОН / RAW TEMPLATE. Бесплатный пак + бесплатная помощь по шаблону.**

**DataStore saves · Play / Continue menu · Settings · Checkpoints · Coins · RU/EN**

[Скачать / Download](https://github.com/Ramzan584/roblox-save-menu-pack/releases/tag/v0.1.0) · [Оставить комментарий / Leave a comment](https://github.com/Ramzan584/Ramzan584/issues/1) · [Другие паки / More packs](https://github.com/Ramzan584)

## Русский

Стартовая система сохранения прогресса и начальное меню для Roblox Studio. Автор: **timura032**. Это сырой вариант для адаптации: свободно меняй оформление, настройки, скрипты и состав сохраняемых данных под свою игру.

**Всё в этом паке бесплатно. Помощь по этому шаблону тоже бесплатная.** Нужна помощь с установкой или доработкой? **Напиши комментарий [в теме помощи и отзывов](https://github.com/Ramzan584/Ramzan584/issues/1)**. Укажи название пака, версию, что хочешь получить и что уже получилось. Для ошибок приложи текст Output и шаги воспроизведения. Можно написать «установил, чекпоинты сохраняются» или предложить дополнение — реальные отзывы помогут выбрать следующие обновления.

### Что есть

| Система | Поведение |
|---|---|
| Начальное меню | Вкладки «Игра», «Настройки», «Помощь»; кнопка «Играть» или «Продолжить» после загрузки |
| Сохранение | Чекпоинт, монеты, игровое время и две настройки в DataStore |
| Автосохранение | Каждые 45 с; ручная кнопка, выход игрока и закрытие сервера |
| Защита загрузки | Ошибка загрузки блокирует старт; пустой профиль не подставляется поверх старого |
| Владение сессией | UpdateAsync, временная блокировка сессии, повторные запросы и идентификатор записи |
| Чекпоинты | Только следующий этап; после смерти и нового входа — последний сохранённый чекпоинт |
| Монеты | Серверный пример подбора; одна общая монета возвращается через 10 с |
| Настройки | Громкость SoundGroup SaveMenuMusic и отключение покачивания камеры меню |
| HUD | Этап, монеты и кнопка открытия меню; интерфейс через обычные сенсорные кнопки |
| Демокарта | Простая площадка с этапами 0–3, монетами и камерой меню |

### Быстрый запуск

1. Скачай `Roblox_Save_Menu_Pack_v0.1.0.zip` из **Releases → Assets** и распакуй.
2. Открой `SaveMenuDemo.rbxlx` как файл места в Roblox Studio.
3. Нажми **Play**. По умолчанию в Studio включён **деморежим в памяти**: он показывает меню и механику, но после остановки теста данные исчезнут. На экране есть соответствующая пометка.
4. Нажми «Играть», пройди чекпоинты по порядку, собери монету, открой «Меню» и измени настройки.
5. Для проверки постоянных сохранений используй отдельную опубликованную тестовую игру и инструкцию ниже.

### Установка в свою игру

Импортируй `SaveMenuStarterPack.rbxmx`. Папки внутри модели — контейнеры для переноса:

| Из модели | В настоящий сервис |
|---|---|
| ReplicatedStorage → SaveMenuPack | ReplicatedStorage → SaveMenuPack: Config и UIFactory |
| ServerScriptService → SaveMenuPack | ServerScriptService → SaveMenuPack: 8 серверных Script/ModuleScript |
| StarterPlayerScripts → 4 LocalScript | StarterPlayer → StarterPlayerScripts |
| SaveMenuDemo | Workspace → SaveMenuDemo |

Содержимое папок должно совпадать с `catalogue.json`. Сохрани имена ModuleScript. Удали пустую модель-контейнер. Не устанавливай второй комплект скриптов поверх демоместа.

Если переносишь код вручную: `.server.lua` — Script, `.client.lua` — LocalScript, остальные `.lua` — ModuleScript. На GitHub файлы лежат в корне для просмотра; в подготовленном ZIP сохранены папки установки.

### Проверить постоянное сохранение

- Опубликуй **отдельную тестовую игру**, установи пак и запусти её в Roblox-клиенте. В опубликованном сервере используется DataStore, а не демопамять.
- В Config задай `STORE_NAME` для своего проекта. Значение по умолчанию — `SaveMenuPack_Test_v1`. Хранилища ограничены одной experience; это не перенос между разными играми.
- Для проверки DataStore именно в Studio: в тестовой игре включи **Experience Settings → Security → Enable Studio Access to API Services**, затем поставь `STUDIO_MEMORY_PREVIEW = false`. Studio работает с теми же данными, поэтому не используй для таких тестов рабочую игру с реальными сохранениями.
- Сохранись кнопкой, выйди и войди снова. Проверь этап, монеты, время и настройки. Повтори с двумя игроками.
- При сетевой ошибке сохранение может не завершиться; ручная кнопка и статус помогают увидеть сбой. Блокировка освобождается при успешном выходе, а после аварии может потребоваться дождаться окончания её срока (по умолчанию 180 с).

### Что менять

- **Config:** TITLE, имя хранилища, интервалы и контакты. `AUTOSAVE_SECONDS` должен быть заметно меньше `LEASE_SECONDS`; стандартные значения — 45 и 180.
- **Данные:** добавляй поля в Schema.defaults / Schema.copy, UI и серверные методы. Новая версия формата требует продуманной миграции; неподдерживаемый формат этот выпуск не перезаписывает.
- **Карта:** Workspace.SaveMenuDemo.Checkpoints — отдельные Parts с именами `0,1,2,...`. `0` — старт. CanTouch=true. Сохраняй старые ID этапов при обновлении карты; если точка исчезла, персонаж попадёт на 0, а записанный номер не будет автоматически стёрт.
- **Монеты:** Parts в SaveMenuDemo.Coins. Если пример не нужен, удали Coins.server.lua и папку Coins. Серверную награду меняй в серверном коде.
- **Музыка:** добавь свой разрешённый SoundId и назначь Sound.SoundGroup = SoundService.SaveMenuMusic. Аудио в пак не включено.
- **Камера:** поверни невидимую Part SaveMenuDemo.MenuCamera. Для своего контроллера удали необязательный MenuCamera.client.lua.
- **Меню:** цвета и элементы в UIFactory и MainMenu.client.lua. RU выбирается по LocaleId игрока, остальные языки получают EN.
- **Внешние системы:** изменение leaderstats само по себе не сохраняется. Подключай игровые события через ProfileService.AddCoins / AdvanceCheckpoint / SetSetting на сервере.

Сохраняется выбранный набор данных игрока, а не вся карта, каждый Instance или точная позиция персонажа. Предметы инвентаря, квесты, покупки, мировые постройки и перенос данных из других систем нужно реализовать дополнительно. Возврат в меню после старта не ставит мультиплеер на паузу. Контроллеры движения/камеры другого пака требуют интеграции.

### Проверка и сырой статус

Синтаксис 14 файлов и 104 проверка логики с заглушками прошли; состав XML-модели и демоместа соответствует исходникам. `verify_pack.py` воспроизводит проверки (Python 3 + Linux `liblua5.4.so.0`).

**Реальный запуск в Roblox Studio / Roblox-клиенте и настоящее облачное сохранение здесь не выполнялись.** Репликацию, интерфейс на телефоне, камеру, реальные сбои DataStore, лимиты запросов и закрытие сервера необходимо проверить в тестовой игре. Подробности — VALIDATION.txt. Сырой шаблон можно свободно дополнять.

## English

A **raw starter template** for Roblox Studio: DataStore player progress and a main menu with **Play / Continue, Settings and Help**. By **timura032**. Customize the code, UI and saved data to fit your game.

**The pack is free. Help with this template is free too.** Leave a comment in the [help and feedback thread](https://github.com/Ramzan584/Ramzan584/issues/1), including the pack/version, your goal, setup and any Output errors. Share what worked and suggest improvements.

### Included

Fourteen connected Luau files provide session-owned profiles, bounded retries, idempotent write retries, autosave/manual/leave/shutdown saves, ordered checkpoints, an optional shared coin example, menu tabs, HUD, saved music volume and reduced menu camera motion. The sample persists checkpoint ID, coins, playtime and settings; it is not a whole-world snapshot, inventory, purchase or quest system.

### Install and test

1. Extract the release ZIP and open `SaveMenuDemo.rbxlx`, then press **Play**.
2. Studio defaults to **memory preview**, clearly labeled in the UI. Data disappears when the test stops.
3. Or import `SaveMenuStarterPack.rbxmx`: move the SaveMenuPack folders into the real ReplicatedStorage and ServerScriptService, the four LocalScripts into StarterPlayer → StarterPlayerScripts, and SaveMenuDemo into Workspace. Remove the empty container. Do not install duplicate copies.
4. For real persistence, publish a separate test experience and play through the Roblox client. Configure STORE_NAME for your project.
5. To test cloud storage inside Studio, enable API service access only on that test experience and set STUDIO_MEMORY_PREVIEW=false. Studio accesses the same data as published servers.
6. Save, leave and rejoin; test stage, coins, time and settings with two players. Test failures and server shutdown. Reopening the menu after starting does not pause the server.

Use numbered checkpoint Parts, server-only reward methods and your own permitted audio assets. Music Sounds must use the SaveMenuMusic SoundGroup. Keep checkpoint IDs stable when updating your map. Add your own data schema migrations before changing SchemaVersion; unsupported records are rejected instead of overwritten. Camera and movement controllers from other packs need integration.

**This release has not been run in Roblox Studio or tested against real DataStores.** Fourteen syntax checks, 104 mocked behavior assertions and model/place source parity passed. See `VALIDATION.txt` and run `python verify_pack.py` on Linux with liblua5.4. Mock tests do not verify engine behavior, replication, mobile layout, cloud limits or network failure handling in production.

## Свободное использование / Free reuse

**CC0 1.0 Universal.** Можно бесплатно копировать, использовать, изменять и распространять исходный пак, в том числе в коммерческих играх. Отзыв и указание автора приветствуются, но не обязательны. / You may use, copy, modify and redistribute the original pack for free, including commercially. Feedback and attribution are welcome, not required.

See [LICENSE.txt](LICENSE.txt), [COPYING.txt](COPYING.txt) and [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Added third-party assets retain their own terms. This CC0 statement applies to this pack; other repositories keep their own license terms.

## Официальные материалы / Official references

- https://create.roblox.com/docs/cloud-services/data-stores
- https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- https://creativecommons.org/publicdomain/zero/1.0/
