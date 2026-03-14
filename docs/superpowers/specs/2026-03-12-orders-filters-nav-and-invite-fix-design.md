# Orders Filters, Navbar, Template Dialog, And Invite RPC Design

## Goal

Исправить четыре связанных дефекта:

- активный пункт нижнего navbar выходит за границы капсулы;
- диалог `Новый шаблон` слишком прозрачен и визуально наслаивается на контент;
- верхний блок `Сортировка` на экране заказов не соответствует ожидаемому поведению фильтров;
- приглашение участника падает на SQL-ошибке `function gen_random_bytes(integer) does not exist`.

## Scope

- `FloatingIslandNav`
- экран `Orders`
- диалог сохранения шаблона на `CreateOrder` и `EditOrder`
- invite RPC / migration в Supabase

## Problems

### Navbar overflow

Активная капсула внутри `FloatingIslandNav` сейчас растягивается по содержимому. На длинной подписи `Профиль` она визуально вылезает за правую границу island, что видно на скриншотах.

### Template dialog transparency

Диалог `Новый шаблон` использует слишком прозрачную glass-подложку. На AMOLED black фоне это выглядит как полупрозрачный слой поверх уже читаемого списка, а не как самостоятельный modal surface.

### Orders controls mismatch

Текущий блок подписан как `Сортировка`, но пользователь ожидает другое поведение:

- при нажатии на стрелку у даты должен открываться календарь с выбором конкретного дня;
- при нажатии на сумму должен открываться двусторонний ползунок диапазона;
- статус нужно убрать, потому что фильтр статуса уже есть выше.

Кроме того, текущая реализация хранит только `sort` и `periodPreset`, хотя реальный UX теперь требует именно фильтров `selectedDate` и `amountRange`.

### Invite RPC failure

`invite_member_by_email_v2` в БД использует `gen_random_bytes(...)`, но функция недоступна в текущем `search_path` или расширение не создано в нужной схеме. Для Supabase это нужно чинить миграцией, а не UI-обходом. Supabase также рекомендует schema-qualified вызовы функций расширений, чтобы logical restore и runtime не зависели от `search_path`.

## Design

### 1. Navbar layout guard

- Сохранить общую floating glass-form.
- Активный tab оставить в виде внутренней капсулы, но ограничить её ширину рамками ячейки.
- Текст активной вкладки рендерить через `Flexible` + `TextOverflow.ellipsis`.
- Горизонтальные padding активной капсулы сделать компактнее, чтобы `Профиль` и `Клиенты` оставались внутри island на узких экранах.

### 2. Template dialog as denser modal

- Для диалога `Новый шаблон` уйти с полупрозрачного `glassSurfaceElevated` на более плотный modal background.
- Усилить затемнение barrier, чтобы фон не спорил с модальным окном.
- Не менять сам flow сохранения шаблона: только визуальная плотность и читаемость.

### 3. Replace pseudo-sorting with explicit filters

- Убрать пункт `По статусу`.
- Блок на Orders перевести из абстрактной сортировки в два явных filter controls:
  - `Дата` открывает `showDatePicker`;
  - `Сумма` открывает bottom sheet c `RangeSlider`.
- В state заменить dependence on `OrdersSort`/`OrdersPeriodPreset` для UI-управления на:
  - `selectedDate`
  - `amountRange`
- Отображать выбранные значения в pill summary:
  - дата в локальном формате;
  - сумма как `min-max` или `Любая`.
- Сохранять текущий статус chip bar без изменений.

### 4. Repository filtering

- `getOrders()` должен поддерживать:
  - фильтр по конкретному дню через `[startOfDayUtc, nextDayUtc)`;
  - фильтр по диапазону суммы;
  - default ordering оставить по дате создания (`created_at desc`), так как явной сортировки больше не требуется.
- Поиск (`ordersSearch`) не трогать.

### 5. Invite RPC migration

- Добавить миграцию в канонический `supabase/migrations/`.
- Миграция должна:
  - включить `pgcrypto` в схеме `extensions`, если ещё не включено;
  - обновить `invite_member_by_email_v2`, заменив bare `gen_random_bytes(...)` на schema-qualified `extensions.gen_random_bytes(...)`.
- Если функция использует другие extension-вызовы, их тоже schema-qualify там же.

## Files

- Modify: `lib/core/widgets/floating_island_nav.dart`
- Modify: `test/core/widgets/floating_island_nav_test.dart`
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `lib/features/orders/domain/orders_list_controls.dart`
- Modify: `lib/features/orders/domain/order_providers.dart`
- Modify: `lib/features/orders/data/order_repository.dart`
- Modify: `test/features/orders/presentation/orders_list_screen_test.dart`
- Modify: `test/features/orders/data/order_repository_test.dart`
- Modify: `lib/features/orders/presentation/create_order_screen.dart`
- Modify: `lib/features/orders/presentation/edit_order_screen.dart`
- Modify: `lib/features/admin/data/admin_repository.dart`
- Modify: `test/features/admin/data/admin_repository_test.dart`
- Create: `supabase/migrations/20260312075010_fix_invite_rpc_and_orders_filters.sql`

## Validation

- navbar не обрезает и не выпускает активную вкладку наружу;
- диалог `Новый шаблон` визуально читается как modal, а не как прозрачный overlay;
- `Дата` открывает календарь, `Сумма` открывает диапазон, `Статус` убран из второго ряда controls;
- фильтрация заказов реально меняет данные по выбранной дате и диапазону суммы;
- приглашение участника больше не падает с `gen_random_bytes(integer) does not exist`;
- `flutter analyze` по затронутым файлам проходит;
- widget/unit tests закрывают regression cases;
- migration успешно применяется через Supabase MCP.
