# Deskflow

> Мобильная CRM-система для e-commerce команд с контекстным чатом внутри каждого заказа.

Deskflow объединяет заказы, клиентов, каталог товаров, уведомления и рабочие обсуждения в одном Flutter-приложении. Проект построен на Supabase, использует multi-org модель с изоляцией данных через RLS и поддерживает роли `Owner`, `Admin`, `Member`.

## Overview

Deskflow рассчитан на команды интернет-магазинов, где работа с заказом включает не только статус и состав, но и постоянную коммуникацию. Приложение собирает в одном месте CRM-данные, чат по заказу, каталог товаров, клиентскую базу, уведомления и организационные настройки.

Ключевой акцент проекта:

- единый рабочий поток вокруг заказа
- контекстный realtime-чат внутри заказа
- multi-account и multi-organization сценарии
- role-based access для командной работы
- визуальный стиль Liquid Glass

## Core Features

### Orders

- список заказов с пагинацией и фильтрами
- карточка заказа с клиентом, суммой, доставкой, заметками и позициями
- создание, редактирование и дублирование заказов
- шаблоны заказов
- кастомный pipeline статусов
- журнал событий и смен статуса

### Chat

- realtime-чат внутри заказа
- вложения и предпросмотр файлов
- системные сообщения для событий заказа
- optimistic UI для отправки сообщений

### Customers and Products

- клиентская база с карточками и историей заказов
- каталог товаров с поиском и статусами
- CRUD-операции для ролей с нужным уровнем доступа

### Organizations and Access

- создание и выбор организации
- вход по invite-коду
- email-приглашения в организацию
- роли `Owner`, `Admin`, `Member`
- изоляция данных между организациями на уровне PostgreSQL RLS

### Search and Notifications

- универсальный поиск по заказам, клиентам и товарам
- история поиска
- in-app уведомления по заказам, сообщениям и статусам

## Tech Stack

- Flutter 3
- Dart 3.10
- Riverpod, Flutter Hooks, Riverpod Generator
- GoRouter
- Supabase Auth
- Supabase PostgreSQL
- Supabase Realtime
- Supabase Storage
- SharedPreferences
- logger, intl, uuid, image_picker, file_picker, cached_network_image

## Architecture

Проект организован по подходу feature-first MVVM. Общая инфраструктура и UI-kit находятся в `lib/core`, а прикладная логика разбита по фичам в `lib/features`.

Базовая структура:

```text
lib/
  core/
    config/
    constants/
    errors/
    models/
    providers/
    router/
    theme/
    utils/
    widgets/
  features/
    admin/
    auth/
    chat/
    customers/
    notifications/
    orders/
    org/
    products/
    profile/
    search/
  main.dart
supabase/
  migrations/
test/
docs/
```

Внутри каждой feature используются слои:

```text
feature/
  data/
  domain/
  presentation/
```

Архитектурные принципы:

- `presentation` работает через providers и domain-модели
- `data` инкапсулирует доступ к Supabase
- общие виджеты, тема, ошибки и утилиты вынесены в `core`
- навигация построена через GoRouter
- безопасность и границы доступа опираются на RLS-политики в базе

## UI and Screenshots

Проект использует визуальный стиль Liquid Glass с акцентом на тёмный фон, glassmorphism-элементы, pill-кнопки и floating island navigation.

<p align="center">
  <img src="assets/readme/main-screen.jpg" alt="Deskflow main screen" width="45%" />
  <img src="assets/readme/orders-screen.jpg" alt="Deskflow orders screen" width="45%" />
</p>
<p align="center">
  <img src="assets/readme/crm-flow.jpg" alt="Deskflow CRM flow" width="45%" />
  <img src="assets/readme/additional-screen.jpg" alt="Deskflow additional screen" width="45%" />
</p>

## Environment Setup

Проект использует runtime-конфигурацию через `assets/env.json`.

Создайте файл на основе шаблона:

```bash
copy env.example.json assets/env.json
```

Заполните в `assets/env.json` следующие поля:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_WEB_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID`

Также поддерживается запуск через `--dart-define`, но основной сценарий проекта рассчитан на `assets/env.json`.

## Run

Установка зависимостей:

```bash
flutter pub get
```

Запуск приложения:

```bash
flutter run
```

Запуск на конкретной платформе:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## Code Generation

Для Riverpod generator и других generated-файлов:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Для режима наблюдения:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Testing

Запуск всех тестов:

```bash
flutter test
```

Запуск конкретного файла тестов:

```bash
flutter test test/features/orders/presentation/orders_list_screen_test.dart
```

В проекте есть unit, widget и integration tests для ключевых сценариев.

## Backend

Backend-часть проекта построена на Supabase:

- PostgreSQL как основная база данных
- RLS для multi-org изоляции
- Realtime для чатов и live-обновлений
- Storage для вложений и изображений
- SQL migrations в `supabase/migrations`

## Repository Notes

- основной репозиторий: `https://github.com/SilaVoin/DeskflowPrj.git`
- локальные секреты и runtime-конфиги не должны попадать в git
- скриншоты для README лежат в `assets/readme/`
