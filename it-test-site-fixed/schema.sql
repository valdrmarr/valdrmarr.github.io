-- ============================================================
--  Входной тест по информатике — база для Supabase
--  Запускать целиком: SQL Editor → New query → вставить → Run.
--  Скрипт можно запускать повторно: он обновит вопросы,
--  но не тронет результаты учеников.
--
--  ОДНО МЕСТО, КОТОРОЕ НУЖНО ПОПРАВИТЬ, — в самом конце файла:
--  впиши свой email учителя вместо teacher@example.com.
-- ============================================================


-- ---------- Таблицы ----------

create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  full_name  text,
  role       text not null default 'student' check (role in ('student', 'teacher')),
  created_at timestamptz not null default now()
);

-- Вопросы видит ученик. Правильных ответов здесь нет.
create table if not exists public.questions (
  id       int primary key,
  position int not null,
  kind     text not null check (kind in ('knowledge', 'logic', 'interest')),
  topic    text not null,
  prompt   text not null,
  code     text,
  multi    boolean not null default false,
  options  jsonb not null
);

-- Ключи: правильные ответы, баллы, объяснения. Видит только учитель.
create table if not exists public.question_keys (
  question_id  int primary key references public.questions (id) on delete cascade,
  correct      text[],
  points       int not null default 1,
  explanation  text,
  interest_map jsonb
);

-- Одна попытка на ученика. Учитель может её удалить, чтобы дать пересдать.
create table if not exists public.attempts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null unique references public.profiles (id) on delete cascade,
  answers      jsonb not null,
  result       jsonb not null,
  duration_sec int,
  created_at   timestamptz not null default now()
);

-- ---------- Профиль создаётся сам при добавлении пользователя ----------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, lower(new.email), nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Для пользователей, созданных до запуска скрипта
insert into public.profiles (id, email)
select id, lower(email) from auth.users
on conflict (id) do nothing;

-- ---------- Права доступа ----------

create or replace function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher');
$$;

alter table public.profiles      enable row level security;
alter table public.questions     enable row level security;
alter table public.question_keys enable row level security;
alter table public.attempts      enable row level security;

-- Сначала забираем все права, потом выдаём только нужные.
-- Неавторизованные посетители (anon) не видят ничего.
revoke all on public.profiles, public.questions, public.question_keys, public.attempts from anon, authenticated;

grant usage on schema public to authenticated;
grant select, update                 on public.profiles      to authenticated;
grant select, insert, update, delete on public.questions     to authenticated;
grant select, insert, update, delete on public.question_keys to authenticated;
grant select, delete                 on public.attempts      to authenticated;

drop policy if exists profiles_read           on public.profiles;
drop policy if exists profiles_teacher_update on public.profiles;
drop policy if exists questions_read          on public.questions;
drop policy if exists questions_teacher_write on public.questions;
drop policy if exists keys_teacher            on public.question_keys;
drop policy if exists attempts_read           on public.attempts;
drop policy if exists attempts_teacher_delete on public.attempts;

create policy profiles_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_teacher());

create policy profiles_teacher_update on public.profiles
  for update to authenticated
  using (public.is_teacher()) with check (public.is_teacher());

create policy questions_read on public.questions
  for select to authenticated
  using (true);

create policy questions_teacher_write on public.questions
  for all to authenticated
  using (public.is_teacher()) with check (public.is_teacher());

create policy keys_teacher on public.question_keys
  for all to authenticated
  using (public.is_teacher()) with check (public.is_teacher());

-- Полную запись попытки (включая ключи правильных ответов) читает только учитель.
-- Ученик получает безопасную проекцию через get_my_attempt().
create policy attempts_read on public.attempts
  for select to authenticated
  using (public.is_teacher());

create policy attempts_teacher_delete on public.attempts
  for delete to authenticated
  using (public.is_teacher());

-- ---------- Ученик сам вписывает своё имя ----------

create or replace function public.set_my_name(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  p_name := btrim(coalesce(p_name, ''));
  if p_name = '' or length(p_name) > 80 then
    raise exception 'bad_name';
  end if;
  update public.profiles set full_name = p_name where id = auth.uid();
end;
$$;

-- ---------- Проверка теста: считает база, ответы наружу не уходят ----------

create or replace function public.submit_attempt(p_answers jsonb, p_duration int default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_dirs       text[] := array['web', 'ml', 'data', 'db', 'net', 'sec'];
  q            record;
  d            text;
  v_raw        jsonb;
  v_given      text[];
  v_correct    text[];
  v_ok         boolean;
  v_best       int;
  v_got        int;
  v_t          jsonb;
  v_k_score    int := 0;
  v_k_max      int := 0;
  v_l_score    int := 0;
  v_l_max      int := 0;
  v_topics     jsonb := '{}';
  v_review     jsonb := '{}';
  v_dir_got    jsonb := '{}';
  v_dir_max    jsonb := '{}';
  v_directions jsonb := '{}';
  v_result     jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' or length(p_answers::text) > 20000 then
    raise exception 'bad_answers';
  end if;
  if exists (select 1 from public.attempts where user_id = v_uid) then
    raise exception 'already_submitted';
  end if;

  insert into public.profiles (id, email)
  select id, lower(email) from auth.users where id = v_uid
  on conflict (id) do nothing;

  foreach d in array v_dirs loop
    v_dir_got := v_dir_got || jsonb_build_object(d, 0);
    v_dir_max := v_dir_max || jsonb_build_object(d, 0);
  end loop;

  for q in
    select qq.id, qq.kind, qq.topic, k.correct, k.points, k.explanation, k.interest_map
    from public.questions qq
    join public.question_keys k on k.question_id = qq.id
    order by qq.position
  loop
    v_raw := p_answers -> (q.id::text);
    if v_raw is null or jsonb_typeof(v_raw) <> 'array' then
      v_raw := '[]'::jsonb;
    end if;
    v_given := array(select x from jsonb_array_elements_text(v_raw) as t(x) order by x);

    if q.kind in ('knowledge', 'logic') then
      v_correct := array(select x from unnest(q.correct) as t(x) order by x);
      v_ok := cardinality(v_given) > 0 and v_given = v_correct;

      if q.kind = 'knowledge' then
        v_k_max := v_k_max + q.points;
        if v_ok then v_k_score := v_k_score + q.points; end if;
      else
        v_l_max := v_l_max + q.points;
        if v_ok then v_l_score := v_l_score + q.points; end if;
      end if;

      v_t := coalesce(v_topics -> q.topic, '{"score": 0, "max": 0}'::jsonb);
      v_topics := v_topics || jsonb_build_object(q.topic, jsonb_build_object(
        'score', (v_t ->> 'score')::int + case when v_ok then q.points else 0 end,
        'max',   (v_t ->> 'max')::int + q.points));

      v_review := v_review || jsonb_build_object(q.id::text, jsonb_build_object(
        'ok', v_ok,
        'idk', v_given = array['idk'],
        'given', to_jsonb(v_given),
        'correct', to_jsonb(q.correct),
        'points', q.points,
        'explanation', q.explanation));
    else
      foreach d in array v_dirs loop
        select coalesce(max((m.value ->> d)::int), 0) into v_best
        from jsonb_each(q.interest_map) as m;
        select coalesce(sum((q.interest_map -> g ->> d)::int), 0) into v_got
        from unnest(v_given) as g;
        v_dir_max := jsonb_set(v_dir_max, array[d], to_jsonb((v_dir_max ->> d)::int + v_best));
        v_dir_got := jsonb_set(v_dir_got, array[d], to_jsonb((v_dir_got ->> d)::int + v_got));
      end loop;
      v_review := v_review || jsonb_build_object(q.id::text, jsonb_build_object('given', to_jsonb(v_given)));
    end if;
  end loop;

  foreach d in array v_dirs loop
    v_directions := v_directions || jsonb_build_object(d,
      case when (v_dir_max ->> d)::int = 0 then 0
           else least(100, round(100.0 * (v_dir_got ->> d)::int / (v_dir_max ->> d)::int))::int end);
  end loop;

  v_result := jsonb_build_object(
    'version', 1,
    'knowledge', jsonb_build_object('score', v_k_score, 'max', v_k_max),
    'logic', jsonb_build_object('score', v_l_score, 'max', v_l_max),
    'topics', v_topics,
    'directions', v_directions,
    'review', v_review);

  begin
    insert into public.attempts (user_id, answers, result, duration_sec)
    values (v_uid, p_answers, v_result, least(greatest(coalesce(p_duration, 0), 0), 86400));
  exception when unique_violation then
    raise exception 'already_submitted';
  end;

  -- Не отдаём ученику review: там содержатся правильные ответы и объяснения.
  -- Полная версия остаётся в attempts.result и доступна только учителю.
  if public.is_teacher() then
    return v_result;
  end if;
  return v_result - 'review';
end;
$$;

-- Безопасное получение собственной попытки учеником.
-- SECURITY DEFINER нужен, потому что прямое чтение attempts разрешено только учителю.
create or replace function public.get_my_attempt()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt public.attempts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_attempt
  from public.attempts
  where user_id = auth.uid();

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_attempt.id,
    'answers', v_attempt.answers,
    'result', v_attempt.result - 'review',
    'duration_sec', v_attempt.duration_sec,
    'created_at', v_attempt.created_at
  );
end;
$$;

revoke all on function public.is_teacher()                 from public, anon;
revoke all on function public.set_my_name(text)            from public, anon;
revoke all on function public.submit_attempt(jsonb, int)   from public, anon;
revoke all on function public.get_my_attempt()               from public, anon;
revoke all on function public.handle_new_user()            from public, anon, authenticated;
grant execute on function public.is_teacher()               to authenticated;
grant execute on function public.set_my_name(text)          to authenticated;
grant execute on function public.submit_attempt(jsonb, int) to authenticated;
grant execute on function public.get_my_attempt()            to authenticated;

-- ---------- Вопросы и ключи ----------

delete from public.question_keys where question_id not in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30);
delete from public.questions where id not in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30);

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (1, 10, 'knowledge', 'pc', $q$Что из этого — операционная система?$q$, null, false, $q$[{"id": "a", "text": "Excel"}, {"id": "b", "text": "Google Chrome"}, {"id": "c", "text": "Windows"}, {"id": "d", "text": "Zoom"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (1, array['c'], 1, $q$Операционная система управляет компьютером и запускает другие программы: Windows, macOS, Linux, Android. Excel, Chrome и Zoom — это программы, которые работают внутри неё.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (2, 20, 'knowledge', 'pc', $q$Ты набираешь текст в программе без автосохранения, и компьютер внезапно выключается. Почему текст пропадает?$q$, null, false, $q$[{"id": "a", "text": "Операционная система удаляет такие файлы как подозрительные"}, {"id": "b", "text": "Текст был только в оперативной памяти, а она хранит данные, пока есть питание"}, {"id": "c", "text": "SSD-накопитель стирается при резком выключении"}, {"id": "d", "text": "Текст хранился в облаке, а интернет отключился"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (2, array['b'], 2, $q$Пока файл не сохранён, он живёт в оперативной памяти (RAM). Она быстрая, но без питания всё забывает. Сохранение записывает данные на диск (SSD или HDD), который хранит их и без электричества.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (3, 30, 'knowledge', 'net', $q$Чем браузер отличается от поисковой системы?$q$, null, false, $q$[{"id": "a", "text": "Ничем, это одно и то же"}, {"id": "b", "text": "Браузер работает только без интернета"}, {"id": "c", "text": "Браузер ищет страницы, а поисковая система их показывает"}, {"id": "d", "text": "Браузер — программа, которая открывает сайты (Chrome, Firefox), а поисковая система — сайт, который ищет страницы (Яндекс, Google)"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (3, array['d'], 1, $q$Браузер — это «окно» в интернет, программа на компьютере. Поисковая система — один из сайтов, который ты открываешь в браузере, чтобы что-то найти.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (4, 40, 'knowledge', 'net', $q$Что делает DNS?$q$, null, false, $q$[{"id": "a", "text": "Превращает имя сайта (например, ya.ru) в числовой IP-адрес сервера"}, {"id": "b", "text": "Шифрует пароли пользователей"}, {"id": "c", "text": "Ускоряет Wi-Fi"}, {"id": "d", "text": "Блокирует рекламу на сайтах"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (4, array['a'], 2, $q$DNS — «телефонная книга» интернета. Компьютеры общаются по числовым адресам, а людям удобнее имена. DNS находит, какой IP-адрес стоит за именем сайта.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (5, 50, 'knowledge', 'net', $q$Какой из этих адресов может быть правильным IPv4-адресом?$q$, null, false, $q$[{"id": "a", "text": "192.168.1.256"}, {"id": "b", "text": "172.16.1"}, {"id": "c", "text": "10.0.0.1"}, {"id": "d", "text": "300.1.1.1"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (5, array['c'], 2, $q$IPv4-адрес — это четыре числа от 0 до 255 через точку. 256 и 300 больше 255, а в 172.16.1 только три числа.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (6, 60, 'knowledge', 'net', $q$Протокол — это набор правил, по которым компьютеры обмениваются данными. Выбери все протоколы.$q$, null, true, $q$[{"id": "a", "text": "HTTP"}, {"id": "b", "text": "Python"}, {"id": "c", "text": "SMTP"}, {"id": "d", "text": "JPEG"}, {"id": "e", "text": "FTP"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (6, array['a', 'c', 'e'], 3, $q$HTTP — для сайтов, SMTP — для отправки почты, FTP — для передачи файлов. Python — язык программирования, JPEG — формат картинок.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (7, 70, 'knowledge', 'data', $q$Сколько бит в одном байте?$q$, null, false, $q$[{"id": "a", "text": "2"}, {"id": "b", "text": "8"}, {"id": "c", "text": "10"}, {"id": "d", "text": "1024"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (7, array['b'], 1, $q$Бит — самая маленькая единица информации: 0 или 1. Восемь бит образуют байт.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (8, 80, 'knowledge', 'data', $q$Чему равно двоичное число 101 в обычной десятичной записи?$q$, null, false, $q$[{"id": "a", "text": "3"}, {"id": "b", "text": "101"}, {"id": "c", "text": "6"}, {"id": "d", "text": "5"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (8, array['d'], 2, $q$В двоичной системе разряды справа налево весят 1, 2, 4, 8… Значит, 101 = 1·4 + 0·2 + 1·1 = 5.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (9, 90, 'knowledge', 'data', $q$На сайтах цвет часто записывают как #FF0000. Какой это цвет?$q$, null, false, $q$[{"id": "a", "text": "Красный"}, {"id": "b", "text": "Зелёный"}, {"id": "c", "text": "Синий"}, {"id": "d", "text": "Чёрный"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (9, array['a'], 2, $q$Запись #RRGGBB — это доли красного, зелёного и синего в шестнадцатеричной системе. FF — максимум (255), 00 — ноль. Здесь красный на максимуме, остальных нет.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (10, 100, 'knowledge', 'code', $q$Что выведет эта программа на Python?$q$, $q$x = 5
y = 3
print(x + y)$q$, false, $q$[{"id": "a", "text": "53"}, {"id": "b", "text": "8"}, {"id": "c", "text": "x + y"}, {"id": "d", "text": "Ошибку"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (10, array['b'], 1, $q$x и y — переменные, в них лежат числа 5 и 3. print выводит значение выражения x + y, то есть 8.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (11, 110, 'knowledge', 'code', $q$Что выведет программа? Подсказка: range(1, 5) перебирает числа, начиная с 1 и не доходя до 5.$q$, $q$s = 0
for i in range(1, 5):
    s = s + i
print(s)$q$, false, $q$[{"id": "a", "text": "15"}, {"id": "b", "text": "4"}, {"id": "c", "text": "10"}, {"id": "d", "text": "5"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (11, array['c'], 2, $q$Цикл проходит по 1, 2, 3, 4 (пятёрка не входит) и прибавляет каждое число к s: 1 + 2 + 3 + 4 = 10.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (12, 120, 'knowledge', 'code', $q$Что выведет программа? Знак % означает остаток от деления.$q$, $q$a = 7
if a % 2 == 0:
    print("A")
else:
    print("B")$q$, false, $q$[{"id": "a", "text": "A"}, {"id": "b", "text": "B"}, {"id": "c", "text": "A, а потом B"}, {"id": "d", "text": "Ничего не выведет"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (12, array['b'], 2, $q$7 % 2 = 1, потому что 7 = 2·3 + 1. Условие «остаток равен 0» не выполняется, поэтому срабатывает ветка else и выводится B. Так в программах проверяют, чётное ли число.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (13, 130, 'knowledge', 'code', $q$Что выведет программа?$q$, $q$def f(n):
    if n > 3:
        return n * 2
    return n + 1

print(f(f(2)))$q$, false, $q$[{"id": "a", "text": "3"}, {"id": "b", "text": "8"}, {"id": "c", "text": "6"}, {"id": "d", "text": "4"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (13, array['d'], 3, $q$Сначала считается внутренний вызов: f(2) — 2 не больше 3, значит, 2 + 1 = 3. Потом f(3) — 3 тоже не больше 3, значит, 3 + 1 = 4.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (14, 140, 'knowledge', 'sql', $q$В таблице students есть столбцы id, name (имя) и grade (класс). Какой запрос выведет имена всех учеников 11 класса?$q$, null, false, $q$[{"id": "a", "text": "SELECT grade FROM students WHERE name = 11;"}, {"id": "b", "text": "SELECT name FROM students WHERE grade = 11;"}, {"id": "c", "text": "DELETE name FROM students WHERE grade = 11;"}, {"id": "d", "text": "INSERT name INTO students WHERE grade = 11;"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (14, array['b'], 2, $q$SELECT — «выбери» столбец name, FROM — «из» таблицы students, WHERE — «где» класс равен 11. DELETE удалил бы данные, а INSERT добавляет новые строки.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (15, 150, 'knowledge', 'sql', $q$Что такое первичный ключ (PRIMARY KEY) в таблице базы данных?$q$, null, false, $q$[{"id": "a", "text": "Пароль для доступа к таблице"}, {"id": "b", "text": "Первая строка таблицы"}, {"id": "c", "text": "Столбец, по значению которого можно однозначно найти каждую строку"}, {"id": "d", "text": "Ключ, которым шифруются данные"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (15, array['c'], 2, $q$Первичный ключ уникален для каждой строки, как номер паспорта у человека. Обычно это столбец id.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (16, 160, 'knowledge', 'sql', $q$Есть две таблицы: customers (клиенты) и orders (заказы, в каждом записан customer_id). Какой оператор SQL позволяет получить заказы вместе с именами клиентов?$q$, null, false, $q$[{"id": "a", "text": "GROUP BY"}, {"id": "b", "text": "ORDER BY"}, {"id": "c", "text": "LIMIT"}, {"id": "d", "text": "JOIN"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (16, array['d'], 3, $q$JOIN соединяет строки двух таблиц по общему полю, здесь по customer_id. GROUP BY группирует строки, ORDER BY сортирует, LIMIT ограничивает их количество.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (17, 170, 'logic', 'logic', $q$Продолжи ряд: 2, 6, 12, 20, 30, …$q$, null, false, $q$[{"id": "a", "text": "40"}, {"id": "b", "text": "42"}, {"id": "c", "text": "44"}, {"id": "d", "text": "36"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (17, array['b'], 2, $q$Разности между соседними числами растут на 2: 4, 6, 8, 10, значит, дальше +12: 30 + 12 = 42. Ещё можно заметить, что это 1·2, 2·3, 3·4, 4·5, 5·6, а дальше 6·7.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (18, 180, 'logic', 'logic', $q$Известно, что все программисты в этой команде пьют кофе. Аня пьёт кофе. Что из этого следует?$q$, null, false, $q$[{"id": "a", "text": "Аня — программист"}, {"id": "b", "text": "Аня точно не программист"}, {"id": "c", "text": "Ничего определённого: Аня может быть программистом, а может и нет"}, {"id": "d", "text": "Все, кто пьёт кофе, работают в этой команде"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (18, array['c'], 2, $q$Из «все программисты пьют кофе» не следует «все, кто пьёт кофе, — программисты». Это частая логическая ловушка, и в программировании она встречается постоянно.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (19, 190, 'logic', 'logic', $q$Робот стоит на клетчатом поле и смотрит вверх. Он выполняет команды: вперёд на 2, повернуть направо, вперёд на 1, повернуть направо, вперёд на 2. Где он окажется относительно стартовой клетки?$q$, null, false, $q$[{"id": "a", "text": "В стартовой клетке"}, {"id": "b", "text": "На 1 клетку правее старта"}, {"id": "c", "text": "На 2 клетки выше старта"}, {"id": "d", "text": "На 1 клетку левее и на 2 ниже старта"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (19, array['b'], 3, $q$Вверх на 2, поворот направо, вправо на 1, ещё поворот направо — теперь робот смотрит вниз — и вниз на 2. Он вернулся на исходную высоту, но на 1 клетку правее.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (20, 200, 'logic', 'logic', $q$Есть 8 одинаковых на вид монет, одна из них чуть тяжелее остальных. Есть чашечные весы без гирь. За какое наименьшее число взвешиваний можно гарантированно найти тяжёлую монету?$q$, null, false, $q$[{"id": "a", "text": "1"}, {"id": "b", "text": "3"}, {"id": "c", "text": "2"}, {"id": "d", "text": "4"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (20, array['c'], 3, $q$Делим монеты на кучки 3, 3 и 2. Сравниваем тройки. Если перевесила одна, тяжёлая среди её трёх монет: кладём на весы две из них, и либо одна перевесит, либо тяжёлая — третья. Если тройки равны, тяжёлая среди двух оставшихся, это ещё одно взвешивание. Всего 2.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (21, 210, 'logic', 'logic', $q$В тёмной комнате в ящике лежат 5 чёрных и 5 белых носков. Сколько носков нужно вытащить, чтобы среди них точно нашлась пара одного цвета?$q$, null, false, $q$[{"id": "a", "text": "3"}, {"id": "b", "text": "2"}, {"id": "c", "text": "5"}, {"id": "d", "text": "6"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (21, array['a'], 2, $q$Цветов всего два. Первые два носка могут оказаться разными, но третий обязательно совпадёт с одним из них. Это принцип Дирихле.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (22, 220, 'logic', 'logic', $q$Загадано целое число от 1 до 100. Можно задавать вопросы, на которые отвечают только «да» или «нет». Сколько вопросов гарантированно хватит, чтобы точно узнать число, если спрашивать с умом?$q$, null, false, $q$[{"id": "a", "text": "5"}, {"id": "b", "text": "10"}, {"id": "c", "text": "50"}, {"id": "d", "text": "7"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (22, array['d'], 3, $q$Каждый вопрос вида «число больше 50?» делит варианты пополам: 100 → 50 → 25 → 13 → 7 → 4 → 2 → 1. Выходит 7 вопросов, потому что 2⁷ = 128 — это больше 100. Этот приём называется бинарным поиском.$q$, null)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (23, 230, 'interest', 'interest', $q$Свободный вечер, компьютер под рукой. Чем захочется заняться?$q$, null, false, $q$[{"id": "a", "text": "Сделать свой сайт: придумать дизайн, цвета, анимации"}, {"id": "b", "text": "Научить программу отличать кошек от собак на фотографиях"}, {"id": "c", "text": "Скачать открытые данные, например о фильмах, и найти в них интересные закономерности"}, {"id": "d", "text": "Собрать систему, где удобно хранить и быстро искать много информации, например каталог книг"}, {"id": "e", "text": "Разобраться, как устроен домашний Wi-Fi, и настроить роутер по-умному"}, {"id": "f", "text": "Решать хакерские головоломки: найти секрет, спрятанный в файле"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (23, null, 1, null, $q${"a": {"web": 2}, "b": {"ml": 2}, "c": {"data": 2}, "d": {"db": 2}, "e": {"net": 2}, "f": {"sec": 2}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (24, 240, 'interest', 'interest', $q$Какая новость зацепила бы тебя сильнее всего?$q$, null, false, $q$[{"id": "a", "text": "«Нейросеть научилась сочинять музыку и рисовать картины»"}, {"id": "b", "text": "«Хакеры взломали крупный сервис: разбор, как это произошло»"}, {"id": "c", "text": "«Новое приложение набрало миллион пользователей за неделю»"}, {"id": "d", "text": "«Аналитики по данным выяснили, когда люди чаще всего покупают подарки»"}, {"id": "e", "text": "«Популярный сервис не работал три часа: инженеры нашли причину в серверах»"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (24, null, 1, null, $q${"a": {"ml": 2, "data": 1}, "b": {"sec": 2, "net": 1}, "c": {"web": 2, "db": 1}, "d": {"data": 2}, "e": {"net": 2, "db": 1}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (25, 250, 'interest', 'interest', $q$Что приятнее всего увидеть в конце своей работы?$q$, null, false, $q$[{"id": "a", "text": "Страницу, которую можно показать друзьям: красиво, и всё нажимается"}, {"id": "b", "text": "График, по которому сразу видна закономерность"}, {"id": "c", "text": "Модель, которая сама правильно предсказывает результат"}, {"id": "d", "text": "Базу данных, которая находит нужное среди миллиона записей за долю секунды"}, {"id": "e", "text": "Сервер или сеть, которые работают без сбоев"}, {"id": "f", "text": "Защиту, которую никто не смог обойти"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (25, null, 1, null, $q${"a": {"web": 2}, "b": {"data": 2}, "c": {"ml": 2}, "d": {"db": 2}, "e": {"net": 2}, "f": {"sec": 2}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (26, 260, 'interest', 'interest', $q$С чем тебе больше нравится возиться?$q$, null, false, $q$[{"id": "a", "text": "С внешним видом: цвета, шрифты, расположение элементов"}, {"id": "b", "text": "С таблицами и цифрами"}, {"id": "c", "text": "С задачами на логику и математику"}, {"id": "d", "text": "С тем, как всё устроено «под капотом» и как компьютеры общаются друг с другом"}, {"id": "e", "text": "С поиском слабых мест и хитрых обходных путей"}, {"id": "f", "text": "С порядком: разложить всё по полочкам, чтобы ничего не потерялось"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (26, null, 1, null, $q${"a": {"web": 2}, "b": {"data": 2, "db": 1}, "c": {"ml": 2, "sec": 1}, "d": {"net": 2, "sec": 1}, "e": {"sec": 2}, "f": {"db": 2, "data": 1}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (27, 270, 'interest', 'interest', $q$Как ты относишься к математике?$q$, null, false, $q$[{"id": "a", "text": "Нравятся вероятности и статистика"}, {"id": "b", "text": "Нравятся логика и доказательства"}, {"id": "c", "text": "Нормально, если понятно, зачем это нужно на практике"}, {"id": "d", "text": "Не люблю, хочу меньше формул и больше практики"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (27, null, 1, null, $q${"a": {"ml": 2, "data": 2}, "b": {"sec": 1, "db": 1, "ml": 1}, "c": {"web": 1, "net": 1, "db": 1, "data": 1}, "d": {"web": 2, "net": 1}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (28, 280, 'interest', 'interest', $q$Какая профессия звучит интереснее?$q$, null, false, $q$[{"id": "a", "text": "Фронтенд-разработчик: делает то, что пользователь видит и нажимает на сайте"}, {"id": "b", "text": "Специалист по машинному обучению: учит программы находить закономерности и принимать решения"}, {"id": "c", "text": "Аналитик данных: по цифрам объясняет, что происходит и что делать дальше"}, {"id": "d", "text": "Разработчик баз данных: отвечает за хранение данных и быстрый доступ к ним"}, {"id": "e", "text": "Сетевой инженер или DevOps: строит и поддерживает серверы и сети"}, {"id": "f", "text": "Специалист по кибербезопасности: защищает системы и ищет в них уязвимости"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (28, null, 1, null, $q${"a": {"web": 2}, "b": {"ml": 2}, "c": {"data": 2}, "d": {"db": 2}, "e": {"net": 2}, "f": {"sec": 2}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (29, 290, 'interest', 'interest', $q$Что для тебя важнее всего в будущей работе?$q$, null, false, $q$[{"id": "a", "text": "Чтобы мою работу видели и ею пользовались люди"}, {"id": "b", "text": "Чтобы мои выводы помогали принимать важные решения"}, {"id": "c", "text": "Чтобы получалось что-то «умное», что решает задачи само"}, {"id": "d", "text": "Чтобы всё надёжно работало в фоне, незаметно для пользователей"}, {"id": "e", "text": "Чтобы защищать людей и их данные"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (29, null, 1, null, $q${"a": {"web": 2}, "b": {"data": 2}, "c": {"ml": 2}, "d": {"db": 2, "net": 1}, "e": {"sec": 2}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options) values (30, 300, 'interest', 'interest', $q$Как тебе удобнее браться за трудную задачу?$q$, null, false, $q$[{"id": "a", "text": "Быстро сделать черновик, посмотреть, как выглядит, и улучшать"}, {"id": "b", "text": "Собрать данные и проверить догадку экспериментом"}, {"id": "c", "text": "Нарисовать аккуратную схему и продумать всё заранее"}, {"id": "d", "text": "Разобрать на части и найти, где именно ломается"}, {"id": "e", "text": "Придумать нестандартный обходной путь"}]$q$::jsonb)
on conflict (id) do update set position = excluded.position, kind = excluded.kind, topic = excluded.topic, prompt = excluded.prompt, code = excluded.code, multi = excluded.multi, options = excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map) values (30, null, 1, null, $q${"a": {"web": 2}, "b": {"data": 2, "ml": 1}, "c": {"db": 2, "net": 1}, "d": {"net": 2, "sec": 1}, "e": {"sec": 2, "ml": 1}}$q$::jsonb)
on conflict (question_id) do update set correct = excluded.correct, points = excluded.points, explanation = excluded.explanation, interest_map = excluded.interest_map;


-- ============================================================
--  НАЗНАЧИТЬ УЧИТЕЛЯ: впиши свой email (тот, с которым ты
--  создал себе пользователя в Authentication → Users).
-- ============================================================
update public.profiles set role = 'teacher'
where email = lower('valdrmarr@gmail.com');

-- Проверка: у тебя должно быть teacher, у ученицы — student
select email, role, full_name from public.profiles order by role desc, email;
