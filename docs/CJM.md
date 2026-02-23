# Customer Journey Map — NIS Math Web

> Last updated: 2026-02-23

## Overview

NIS Math — веб-приложение для подготовки к математическому экзамену в НИШ (Назарбаев Интеллектуальные Школы). Целевая аудитория: ученики 5-6 классов и их родители.

---

## Journey 1: Новый ученик (первый визит)

### Точки контакта

```mermaid
graph LR
    A["1. Открыл сайт"] --> B["2. Экран входа\n(LoginPage)"]
    B --> C["3. Ввёл телефон"]
    C --> D{"Телефон найден?"}
    D -->|"Нет"| E["4. Регистрация\n(имя + PIN)"]
    D -->|"Да"| F["4. Ввёл PIN"]
    E --> G["5. Dashboard\n(Onboarding)"]
    F --> G
    G --> H["6. Начал диагностику"]
    H --> I["7. Решает 15 тем\n(DiagnosticPage)"]
    I --> J["8. Результаты\n(освоено / пробелы)"]
    J --> K["9. Dashboard\n(полный вид)"]
    K --> L["10. Практика\nпо слабым темам"]
```

### Детальный путь

| Шаг | Экран | Действие пользователя | Ответ системы | Эмоция |
|-----|-------|----------------------|---------------|--------|
| 1 | — | Открывает сайт | Проверяет JWT → нет токена | Ожидание |
| 2 | LoginPage | Видит форму входа | Показывает поле телефона + кнопку Telegram | Нейтрально |
| 3 | PhoneLoginPage | Вводит номер (+7...), нажимает "Продолжить" | `POST /api/auth/phone/check` → "Новый ученик!" | Интерес |
| 4 | PhoneLoginPage | Вводит имя и придумывает 4-значный PIN | `POST /api/auth/phone/register` → JWT | Вовлечённость |
| 5 | DashboardPage (Onboarding) | Видит приветствие и 3 шага | Показывает карточки: диагностика → пробелы → тренировка | Мотивация |
| 6 | DashboardPage | Нажимает "Начать диагностику" | Переход на `/diagnostic` | Готовность |
| 7 | DiagnosticPage | Решает задачи (по 1 на тему, 15 тем) | Адаптивный BKT: подбирает сложность | Концентрация |
| 8 | DiagnosticPage (Results) | Видит результаты | Список освоенных и слабых тем | Понимание |
| 9 | DashboardPage | Возвращается на главную | Полный dashboard с разделами, процентами, статистикой | Удовлетворение |
| 10 | PracticePage | Выбирает слабую тему, решает задачи | Бесконечный цикл: задача → ответ → обратная связь | Рост |

### Болевые точки (из AUDIT.md)

- **BUG-1**: После возврата из практики по теме dashboard НЕ обновляется — ученик не видит свой прогресс
- **MISS-3**: Нет выбора языка (RU/KZ) — казахоязычные ученики видят всё на русском
- **MISS-6**: Нет offline handling — если пропал интернет, ничего не показывается

---

## Journey 2: Возвращающийся ученик

### Точки контакта

```mermaid
graph LR
    A["1. Открыл сайт"] --> B{"JWT валиден?"}
    B -->|"Да"| C["2. Dashboard\n(автовход)"]
    B -->|"Нет"| D["2. LoginPage\n(ввод PIN)"]
    D --> C
    C --> E{"Что делать?"}
    E --> F["3a. Практика\n(общая / по теме)"]
    E --> G["3b. Экзамен\n(с таймером)"]
    E --> H["3c. Граф знаний"]
    E --> I["3d. Рейтинг"]
    F --> J["4. Решает задачи"]
    J --> K["5. Видит прогресс\nна Dashboard"]
```

### Детальный путь

| Шаг | Экран | Действие пользователя | Ответ системы | Эмоция |
|-----|-------|----------------------|---------------|--------|
| 1 | — | Открывает сайт | `AuthCheckRequested` → JWT из SharedPreferences → `GET /api/auth/me` | Ожидание |
| 2a | DashboardPage | Видит свой прогресс | Параллельная загрузка: student + stats + graph + leaderboard | Узнавание |
| 2b | LoginPage | (если токен истёк) Вводит телефон + PIN | `POST /api/auth/phone/login` → JWT | Небольшое раздражение |
| 3a | — | Нажимает "Практика" | Переход на `/practice` (общая) | Готовность |
| 3a' | — | Раскрывает раздел → нажимает на тему | Переход на `/practice?nodeId=X` (по теме) | Целенаправленность |
| 3b | — | Нажимает "Экзамен" | Переход на `/exam`, выбирает 10/20/30 задач | Волнение |
| 3c | — | Нажимает "Граф" (в AppBar) | Переход на `/graph` — все темы по категориям | Обзор |
| 3d | — | Нажимает "Рейтинг" | Переход на `/leaderboard` — сравнение с другими | Соревновательность |
| 4 | PracticePage | Решает задачи, видит обратную связь | Задача → ответ → правильно/неправильно + решение + mastery bar | Обучение |
| 5 | DashboardPage | Возвращается | Dashboard перезагружается (`.then(DashboardLoad)`) | Прогресс |

### Ключевые сценарии практики

```mermaid
stateDiagram-v2
    [*] --> LoadProblem: Открыл PracticePage
    LoadProblem --> ShowProblem: "GET /practice/next"
    ShowProblem --> WaitAnswer: Ученик думает
    WaitAnswer --> SubmitAnswer: Ввёл ответ + Enter
    WaitAnswer --> SkipProblem: Нажал "Пропустить"
    SubmitAnswer --> ShowResult: "POST /practice/answer"
    SkipProblem --> LoadProblem: "POST /practice/skip"
    ShowResult --> LoadProblem: "Следующая" / → / пробел
    ShowResult --> ReportProblem: "Пожаловаться"
    ReportProblem --> ShowResult: Отправлено
```

### Ключевые сценарии экзамена

```mermaid
stateDiagram-v2
    [*] --> Setup: Открыл ExamPage
    Setup --> TimerStart: "Начать экзамен"
    TimerStart --> ShowProblem: "POST /practice/exam/start"
    ShowProblem --> WaitAnswer
    WaitAnswer --> SubmitAnswer: Ввёл ответ
    WaitAnswer --> SkipProblem: Пропустить
    SubmitAnswer --> ShowFeedback: "POST /practice/answer"
    SkipProblem --> NextProblem
    ShowFeedback --> NextProblem: "Следующая"
    NextProblem --> ShowProblem: Есть ещё задачи
    NextProblem --> Results: Все задачи решены
    WaitAnswer --> Results: Время вышло
    Results --> Setup: "Ещё раз"
    Results --> [*]: "На главную"
```

---

## Journey 3: Ученик из Telegram-бота

### Точки контакта

```mermaid
graph LR
    A["1. Используeт\nTelegram бота"] --> B["2. Получил ссылку\nна веб-версию"]
    B --> C["3. Открыл сайт"]
    C --> D["4. LoginPage"]
    D --> E["5. Нажал\n'Войти через Telegram'"]
    E --> F["6. Popup:\nTelegram авторизация"]
    F --> G["7. Подтвердил\nв Telegram"]
    G --> H["8. Dashboard\n(данные из бота)"]
```

### Детальный путь

| Шаг | Экран | Действие пользователя | Ответ системы | Эмоция |
|-----|-------|----------------------|---------------|--------|
| 1 | Telegram | Пользуется ботом `@nis_math_test_bot` | — | Привычка |
| 2 | Telegram | Получает ссылку или видит кнопку "Веб-версия" | — | Любопытство |
| 3 | — | Открывает сайт | Проверяет JWT → нет | Ожидание |
| 4 | LoginPage | Видит форму входа | Два варианта: телефон / Telegram | Выбор |
| 5 | LoginPage | Нажимает "Войти через Telegram" | `window.open(telegram_login.html?bot=...)` — popup 400x500 | Привычность |
| 6 | Popup | Видит Telegram Login Widget | Telegram загружает виджет авторизации | Узнавание |
| 7 | Popup | Нажимает "Authorize" в Telegram | `onTelegramAuth(user)` → `postMessage` → popup закрывается | Быстрота |
| 8 | DashboardPage | Видит свои данные из бота | `POST /api/auth/telegram` → JWT → `GET /api/auth/me` → данные | Удовлетворение |

### Особенности

- Telegram и веб-версия делят **одну и ту же базу данных** — прогресс синхронизирован
- Telegram-аккаунт связывается с тем же Student, что и в боте
- Ученик может переключаться между Telegram-ботом и веб-версией без потери данных

---

## Карта экранов и переходов

```mermaid
graph TD
    Start["Открытие приложения"] --> AuthCheck{"JWT в\nSharedPreferences?"}
    AuthCheck -->|"Есть + валиден"| Dashboard
    AuthCheck -->|"Нет / истёк"| Login

    Login["LoginPage\n/login"] -->|"Телефон + PIN"| Dashboard
    Login -->|"Telegram popup"| Dashboard

    Dashboard["DashboardPage\n/"] -->|"Практика"| Practice
    Dashboard -->|"Диагностика"| Diagnostic
    Dashboard -->|"Экзамен"| Exam
    Dashboard -->|"Граф"| Graph
    Dashboard -->|"Рейтинг"| Leaderboard
    Dashboard -->|"Раздел → тема"| PracticeByTopic
    Dashboard -->|"Logout"| Login

    Practice["PracticePage\n/practice"] -->|"Назад"| Dashboard
    PracticeByTopic["PracticePage\n/practice?nodeId=X"] -->|"Назад"| Dashboard
    Diagnostic["DiagnosticPage\n/diagnostic"] -->|"Завершено"| Dashboard
    Exam["ExamPage\n/exam"] -->|"Назад / Завершено"| Dashboard
    Graph["GraphPage\n/graph"] -->|"Назад"| Dashboard
    Leaderboard["LeaderboardPage\n/leaderboard"] -->|"Назад"| Dashboard

    Dashboard -.->|"Onboarding\n(нет mastery)"| OnboardingView
    OnboardingView["Onboarding View\n(внутри Dashboard)"] -->|"Начать диагностику"| Diagnostic
    OnboardingView -->|"Экзамен с таймером"| Exam
    OnboardingView -->|"Просто порешать"| Practice
```

---

## Метрики пути пользователя

### Ключевые конверсии

| Этап | Метрика | Как измерить |
|------|---------|-------------|
| Регистрация | % посетителей → зарегистрировались | phone/register или telegram auth |
| Onboarding | % зарегистрированных → начали диагностику | diagnostic/start после registration |
| Первая практика | % завершивших диагностику → начали практику | practice/next после diagnostic/finish |
| Ретеншен | % вернувшихся на следующий день | currentStreak > 0 |
| Мастерство | % тем со статусом mastered | masteredCount / totalNodes |

### Время на ключевых экранах

| Экран | Ожидаемое время | Максимум |
|-------|----------------|----------|
| LoginPage | 30-60 сек | 2 мин |
| Diagnostic | 10-15 мин | 30 мин |
| Practice (сессия) | 5-20 мин | без ограничений |
| Exam | 20-60 мин (по настройке) | время по таймеру |
| Dashboard | 10-30 сек (обзор) | — |

---

## Болевые точки и возможности

| ID | Проблема | Где в пути | Влияние | Статус |
|----|---------|-----------|---------|--------|
| BUG-1 | Dashboard не обновляется после возврата из темы/секции | Journey 2, шаг 5 | Ученик не видит свой прогресс | Открыт |
| BUG-4 | LaTeX не парсит сложные выражения | Journey 2, шаг 4 | Задача отображается некорректно | Открыт |
| MISS-1 | Нет кнопки "Пожаловаться" в диагностике | Journey 1, шаг 7 | Нельзя сообщить об ошибке в задаче | Открыт |
| MISS-2 | Нет решения после неправильного ответа в диагностике | Journey 1, шаг 7 | Ученик не понимает ошибку | Открыт |
| MISS-3 | Нет выбора языка RU/KZ | Все пути | Казахоязычные ученики без поддержки | Открыт |
| MISS-4 | Нет профиля пользователя | Journey 2 | Нельзя изменить имя/настройки | Открыт |
| MISS-5 | Нет pull-to-refresh | Journey 2, шаг 2a | Застаревшие данные | Открыт |
| MISS-6 | Нет offline handling | Все пути | Белый экран без интернета | Открыт |
