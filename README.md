# Deskflow

> Мобильная CRM для e-commerce команд с контекстным чатом внутри каждого заказа.

Deskflow объединяет заказы, клиентов, каталог товаров, уведомления и рабочие обсуждения в одном Flutter-приложении. Проект построен вокруг multi-org модели на Supabase с RLS-изоляцией, ролями `Owner / Admin / Member` и интерфейсом в стиле Liquid Glass.

## Что уже есть

- Управление заказами: список, фильтры, карточка, статусы, шаблоны, дублирование, audit log
- Контекстный чат по заказу: realtime-сообщения, вложения, optimistic UI
- Клиенты и товары: каталоги, карточки, поиск, CRUD для ролей с доступом
- Организации и инвайты: создание, выбор, join по коду, email invite flow
- Профиль и уведомления: multi-account, org settings, in-app notifications, search history

## Технологии

- Flutter 3 + Dart 3.10
- Riverpod, Flutter Hooks, GoRouter
- Supabase Auth, PostgreSQL, Realtime, Storage, Edge Functions
- SharedPreferences, logger, intl, image_picker, file_picker

## Быстрый старт

```bash
flutter pub get
copy env.example.json assets/env.json
flutter run
```

Перед запуском заполните `assets/env.json` значениями `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` и `GOOGLE_IOS_CLIENT_ID`.

## Структура проекта

```text
lib/
  core/       shared config, router, theme, widgets, utils
  features/   admin, auth, chat, customers, notifications, orders, org, products, profile, search
supabase/     migrations and backend-side logic
docs/         implementation plans and design specs
```

Архитектурно проект использует feature-first MVVM: внутри каждой фичи слои `data`, `domain`, `presentation`, а общая инфраструктура вынесена в `lib/core/`.

## Скриншоты

| Экран | Скриншот |
|-------|----------|
| Основной рабочий экран | ![Main screen](../media/Screenshot_20260314_122743.jpg) |
| Экран заказов / деталей | ![Orders screen](../media/Screenshot_20260314_122819.jpg) |
| Управление и CRM-поток | ![CRM flow](../media/Screenshot_20260314_122910.jpg) |
| Дополнительный сценарий | ![Additional screen](../media/Screenshot_20260314_122917.jpg) |

## Документация

| Документ | Что внутри |
|----------|------------|
| [.ai-factory/DESCRIPTION.md](.ai-factory/DESCRIPTION.md) | Продуктовое описание, фичи, стек и требования |
| [.ai-factory/ARCHITECTURE.md](.ai-factory/ARCHITECTURE.md) | Архитектурные правила, структура модулей и зависимости |
| [docs/superpowers/plans](docs/superpowers/plans) | Планы реализации по задачам и изменениям |
| [docs/superpowers/specs](docs/superpowers/specs) | Дизайн-спеки и детализация перед реализацией |

## Ключевые возможности

- Мульти-организационная модель с RLS-изоляцией данных
- Ролевая система доступа для `Owner`, `Admin`, `Member`
- Универсальный поиск по заказам, клиентам и товарам
- Liquid Glass UI-kit: `GlassCard`, `PillButton`, `FloatingIslandNav`, aurora background
- Поддержка Android, iOS, Web, macOS, Linux и Windows

## Репозиторий и публикация

Сейчас локальный `origin` указывает на `https://github.com/SilaVoin/deskflow.git`. Для нового репозитория `https://github.com/SilaVoin/DeskflowPrj.git` нужно перенастроить remote и выполнить push уже после решения, какие из текущих незакоммиченных изменений должны попасть в первый коммит.
