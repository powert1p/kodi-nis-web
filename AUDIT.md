# Full Audit — kodi-nis-web — 23.02.2026

## 🔴 КРИТИЧЕСКИЕ БАГИ

### BUG-1: Dashboard не обновляется после возврата из секций/тем
**Где:** dashboard_page.dart lines 420, 522, 827, 842, 854
**Проблема:** 6 из 8 навигаций из dashboard НЕ имеют `.then(() => reload)`.
Только "Диагностика" и "Практика" (главные кнопки) обновляют данные.
**Симптом:** Процент точности не меняется после практики из секции/темы.
**Фикс:** Добавить `.then((_) => context.read<DashboardBloc>().add(DashboardLoad()))` ко всем pushNamed.

### BUG-2: Нет API endpoint для жалобы на задачу
**Где:** bot/api/routes/practice.py — отсутствует
**Проблема:** В Telegram боте есть кнопка "Пожаловаться на задачу" (report_problem). На вебе — нет.
**Фикс:** POST /api/practice/report {problem_id, reason, comment}

## 🟡 СРЕДНИЕ БАГИ

### BUG-3: ExamPage нет refresh dashboard
**Где:** exam_page.dart — после завершения экзамена Navigator.pop() без callback
**Фикс:** Уже покрыт BUG-1 (если dashboard перезагружается после /exam)

### BUG-4: LaTeX парсер не покрывает все паттерны
**Паттерны с ошибками:**
- "0.(45)" — периодические дроби не конвертятся
- "x/y=3" — буквенные дроби не распознаются
- "(1 3/4)^2:(1 1/2)^2" — сложные выражения
**Фикс:** Расширить regex в MathText

### BUG-5: Diagnostic page — in-memory state теряется при редеплое Railway
**Где:** bot/api/routes/diagnostic.py — `_sessions: dict[int, DiagnosticState]`
**Проблема:** Railway redeploy = потеря diagnostic state. Не критично если перезапуск быстрый.
**Фикс:** Сохранять state в Redis или DB

## 🟢 ОТСУТСТВУЮЩИЕ ФИЧИ (из бота)

### MISS-1: Кнопка "Пожаловаться" на практике и диагностике
### MISS-2: Решение (solution) в диагностике после неправильного ответа
### MISS-3: Выбор языка (RU/KZ) на сайте
### MISS-4: Профиль пользователя (имя, настройки)
### MISS-5: Pull-to-refresh на dashboard
### MISS-6: Offline state handling (что показать без интернета)

## 📊 АЛГОРИТМ BKT — ТРЕБУЕТ ПРОВЕРКИ
- Нужна симуляция 100 учеников для валидации
- Проверить: сходится ли mastery? Правильно ли selector выбирает задачи?
- Проверить: spaced repetition работает?
