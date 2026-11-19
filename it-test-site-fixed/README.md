# Входной тест по информатике

Сайт для GitHub Pages + база в Supabase.

- `index.html`, `app.js`, `styles.css`: сам сайт
- `config.js`: адрес проекта и publishable-ключ Supabase (публичные)
- `schema.sql`: база, права доступа и 30 вопросов; запускается в Supabase → SQL Editor
- `vendor/`, `fonts/`: библиотека Supabase и шрифты (сайт не зависит от внешних CDN)

Правильные ответы лежат только в базе, в таблице `question_keys`, и видны только учителю.
Баллы считает функция `submit_attempt` на стороне базы.
