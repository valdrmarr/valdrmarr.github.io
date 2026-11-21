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

-- ---------- Диагностический тест: 20 заданий + 10 вопросов об интересах ----------

delete from public.question_keys where question_id not between 1 and 30;

delete from public.questions where id not between 1 and 30;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (1, 10, 'knowledge', 'pc', $prompt$Какое расширение чаще всего встречается у обычной фотографии?$prompt$, null, false, $opts$[{"id":"a","text":".jpg"},{"id":"b","text":".xlsx"},{"id":"c","text":".mp3"},{"id":"d","text":".html"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (1, array['a'], 1, $ex$Файлы JPG/JPEG обычно содержат фотографии. XLSX — электронные таблицы, MP3 — звук, HTML — разметку веб-страниц.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (2, 20, 'knowledge', 'pc', $prompt$Какая программа предназначена для открытия сайтов и перехода по веб-страницам?$prompt$, null, false, $opts$[{"id":"a","text":"Текстовый редактор"},{"id":"b","text":"Браузер"},{"id":"c","text":"Архиватор"},{"id":"d","text":"Графический редактор"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (2, array['b'], 1, $ex$Браузер — программа для просмотра сайтов. Примеры: Chrome, Firefox, Safari и Edge.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (3, 30, 'knowledge', 'pc', $prompt$Когда на компьютере одновременно открыто несколько программ, какая часть временно хранит данные, которые им нужны прямо сейчас?$prompt$, null, false, $opts$[{"id":"a","text":"Оперативная память (RAM)"},{"id":"b","text":"SSD или жёсткий диск"},{"id":"c","text":"Монитор"},{"id":"d","text":"Клавиатура"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (3, array['a'], 1, $ex$Оперативная память хранит данные работающих программ временно. SSD и HDD предназначены для долговременного хранения файлов.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (4, 40, 'knowledge', 'net', $prompt$Документ сохранён в облачном хранилище. В чём главное удобство такого хранения?$prompt$, null, false, $opts$[{"id":"a","text":"Документ автоматически становится доступен всем людям"},{"id":"b","text":"Документ можно открыть с разных устройств через свой аккаунт"},{"id":"c","text":"Документ больше нельзя случайно удалить"},{"id":"d","text":"Для открытия документа всегда не нужен интернет"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (4, array['b'], 1, $ex$Облачное хранилище позволяет обращаться к файлу с разных устройств через аккаунт и сеть. Само по себе облако не делает файл публичным и не гарантирует его вечное хранение.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (5, 50, 'logic', 'logic', $prompt$Продолжи последовательность: 3, 6, 12, 24, …$prompt$, null, false, $opts$[{"id":"a","text":"30"},{"id":"b","text":"36"},{"id":"c","text":"48"},{"id":"d","text":"42"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (5, array['c'], 1, $ex$Каждое следующее число в два раза больше предыдущего: 24 × 2 = 48.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (6, 60, 'logic', 'logic', $prompt$Известно: действие А должно произойти раньше действия Б, а действие Б — раньше действия В. Какой порядок точно соблюдает оба условия?$prompt$, null, false, $opts$[{"id":"a","text":"В – Б – А"},{"id":"b","text":"Б – А – В"},{"id":"c","text":"А – В – Б"},{"id":"d","text":"А – Б – В"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (6, array['d'], 1, $ex$Если А раньше Б, а Б раньше В, то А обязательно будет раньше В. Полный порядок А – Б – В соблюдает оба условия.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (7, 70, 'logic', 'logic', $prompt$Робот стоит в клетке и смотрит вправо. Он проходит 3 клетки вперёд, поворачивает налево, проходит 2 клетки, снова поворачивает налево и проходит 1 клетку. Где он окажется относительно старта?$prompt$, null, false, $opts$[{"id":"a","text":"На 2 клетки вправо и на 2 вверх"},{"id":"b","text":"На 4 клетки вправо и на 2 вверх"},{"id":"c","text":"На 2 клетки вправо и на 1 вниз"},{"id":"d","text":"На 2 клетки влево и на 2 вверх"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (7, array['a'], 2, $ex$После первых трёх шагов робот на 3 клетки правее старта. Затем поднимается на 2 клетки и после поворота идёт на 1 клетку влево. Итог: 2 вправо и 2 вверх.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (8, 80, 'logic', 'logic', $prompt$Работает правило: «Если включена сигнализация, мигает красная лампа». Сейчас красная лампа не мигает. Что следует из этого правила?$prompt$, null, false, $opts$[{"id":"a","text":"Сигнализация точно включена"},{"id":"b","text":"Сигнализация не включена"},{"id":"c","text":"Лампа сломана"},{"id":"d","text":"Нельзя сделать никакого вывода"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (8, array['b'], 2, $ex$По условию включённая сигнализация обязательно заставляет лампу мигать. Если лампа не мигает, сигнализация не включена. О других неисправностях условие ничего не говорит.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (9, 90, 'logic', 'logic', $prompt$Три ученицы выступают по очереди. Алина выступает раньше Даши, а Даша — раньше Вики. Кто выступает последней?$prompt$, null, false, $opts$[{"id":"a","text":"Алина"},{"id":"b","text":"Даша"},{"id":"c","text":"Вика"},{"id":"d","text":"Определить нельзя"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (9, array['c'], 1, $ex$Из двух условий получается порядок Алина → Даша → Вика. Последней выступает Вика.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (10, 100, 'logic', 'logic', $prompt$Нужно найти самое большое число среди восьми записанных чисел. Какой способ гарантирует правильный результат?$prompt$, null, false, $opts$[{"id":"a","text":"Посмотреть только на первое и последнее числа"},{"id":"b","text":"Сложить все числа и выбрать самое большое из цифр суммы"},{"id":"c","text":"Сравнить числа по очереди, сохраняя наибольшее из уже просмотренных"},{"id":"d","text":"Выбрать число, которое записано посередине списка"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (10, array['c'], 2, $ex$Последовательное сравнение проверяет все восемь чисел. После каждого шага сохраняется наибольшее из просмотренных, поэтому в конце будет найден максимум.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (11, 110, 'logic', 'logic', $prompt$Загадано целое число от 1 до 16. Каждый вопрос с ответом «да» или «нет» позволяет разделить оставшиеся варианты примерно пополам. Какого максимального числа вопросов достаточно, чтобы гарантированно найти число?$prompt$, null, false, $opts$[{"id":"a","text":"2"},{"id":"b","text":"3"},{"id":"c","text":"4"},{"id":"d","text":"8"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (11, array['c'], 2, $ex$Каждый вопрос может вдвое уменьшить число вариантов. После четырёх вопросов можно различить до 2⁴ = 16 вариантов.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (12, 120, 'knowledge', 'code', $prompt$Что выведет программа?$prompt$, $code$price = 100
discount = 20
final_price = price - discount
print(final_price)$code$, false, $opts$[{"id":"a","text":"20"},{"id":"b","text":"80"},{"id":"c","text":"100"},{"id":"d","text":"120"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (12, array['b'], 1, $ex$В переменной price находится 100, а discount равен 20. Выражение 100 − 20 даёт 80.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (13, 130, 'knowledge', 'code', $prompt$Что выведет программа, если score равен 55?$prompt$, $code$score = 55
if score >= 60:
    print("Зачёт")
else:
    print("Попробуй ещё")$code$, false, $opts$[{"id":"a","text":"Зачёт"},{"id":"b","text":"Попробуй ещё"},{"id":"c","text":"55"},{"id":"d","text":"Ничего"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (13, array['b'], 1, $ex$Условие score >= 60 ложно, потому что 55 меньше 60. Поэтому выполняется ветка else.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (14, 140, 'knowledge', 'code', $prompt$Какие числа выведет программа? В Python команда range(1, 4) перебирает 1, 2 и 3, не включая 4.$prompt$, $code$for i in range(1, 4):
    print(i)$code$, false, $opts$[{"id":"a","text":"1 2 3"},{"id":"b","text":"1 2 3 4"},{"id":"c","text":"0 1 2 3"},{"id":"d","text":"3 2 1"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (14, array['a'], 2, $ex$Цикл перебирает значения от 1 до числа, не включая правую границу 4: это 1, 2 и 3.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (15, 150, 'knowledge', 'code', $prompt$Что напечатает программа?$prompt$, $code$count = 3
count = count + 2
count = count * 2
print(count)$code$, false, $opts$[{"id":"a","text":"7"},{"id":"b","text":"9"},{"id":"c","text":"10"},{"id":"d","text":"12"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (15, array['c'], 1, $ex$Сначала count становится 3 + 2 = 5. Затем значение умножается на 2: 5 × 2 = 10.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (16, 160, 'knowledge', 'ai', $prompt$Ты хочешь научить программу отличать фотографии кошек от фотографий собак. Что лучше всего подготовить для обучения?$prompt$, null, false, $opts$[{"id":"a","text":"Много фотографий с правильными пометками «кошка» и «собака»"},{"id":"b","text":"Одну фотографию кошки и пароль от компьютера"},{"id":"c","text":"Список сайтов, где встречаются слова «кошка» и «собака»"},{"id":"d","text":"Только инструкцию на русском языке без примеров"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (16, array['a'], 2, $ex$Для обучения классификатора нужны примеры. Подписанные изображения показывают модели, какие признаки встречаются у кошек и собак.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (17, 170, 'knowledge', 'data', $prompt$У тебя есть оценки пяти учеников. Нужно наглядно сравнить их между собой. Какой способ представления данных подойдёт лучше всего?$prompt$, null, false, $opts$[{"id":"a","text":"Столбчатая диаграмма"},{"id":"b","text":"Длинный текст без чисел"},{"id":"c","text":"Случайный набор цветов"},{"id":"d","text":"Музыкальная запись"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (17, array['a'], 1, $ex$Столбчатая диаграмма удобна для сравнения значений разных категорий — в данном случае оценок учеников.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (18, 180, 'knowledge', 'sql', $prompt$В электронной базе библиотеки каждая книга записана отдельно. Что обычно представляет собой одна строка таблицы?$prompt$, null, false, $opts$[{"id":"a","text":"Всю библиотеку целиком"},{"id":"b","text":"Одну книгу с её данными: названием, автором и годом"},{"id":"c","text":"Только цвет обложки"},{"id":"d","text":"Пароль библиотекаря"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (18, array['b'], 1, $ex$В таблице одна строка обычно описывает одну запись или объект. Для каталога это может быть одна книга с набором полей.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (19, 190, 'knowledge', 'safety', $prompt$Какой вариант лучше защищает твои аккаунты?$prompt$, null, false, $opts$[{"id":"a","text":"Один короткий пароль для всех сайтов"},{"id":"b","text":"Пароль с именем и датой рождения"},{"id":"c","text":"Длинный уникальный пароль для каждого важного сервиса и дополнительное подтверждение входа"},{"id":"d","text":"Записать пароль в открытом посте, чтобы не забыть"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (19, array['c'], 2, $ex$Уникальный длинный пароль снижает риск массового взлома при утечке на одном сайте. Дополнительное подтверждение входа создаёт ещё один уровень защиты.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (20, 200, 'knowledge', 'safety', $prompt$На почту пришло сообщение «Твой аккаунт заблокируют через 10 минут», а внутри — ссылка для ввода пароля. Что безопаснее сделать сначала?$prompt$, null, false, $opts$[{"id":"a","text":"Сразу открыть ссылку и ввести пароль"},{"id":"b","text":"Переслать письмо всем знакомым"},{"id":"c","text":"Не переходить по ссылке и проверить сообщение через официальный сайт или приложение"},{"id":"d","text":"Ответить отправителю и сообщить код из SMS"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (20, array['c'], 2, $ex$Срочность и просьба ввести пароль по ссылке — частые признаки фишинга. Проверять состояние аккаунта следует через официальный сайт или приложение, открытые самостоятельно.$ex$, null)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (21, 210, 'interest', 'interest', $prompt$Представь, что тебе дали свободный вечер и ноутбук. Какой мини-проект ты бы выбрала?$prompt$, null, false, $opts$[{"id":"a","text":"Сделать красивую страницу, которой смогут пользоваться другие"},{"id":"b","text":"Попробовать научить программу распознавать изображения"},{"id":"c","text":"Разобрать результаты опроса и найти интересные закономерности"},{"id":"d","text":"Создать удобный электронный каталог с поиском"},{"id":"e","text":"Настроить домашнюю сеть или небольшой сервер"},{"id":"f","text":"Проверить учебный сайт на слабые места и предложить защиту"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (21, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (22, 220, 'interest', 'interest', $prompt$Какую задачу тебе было бы интереснее решать в команде?$prompt$, null, false, $opts$[{"id":"a","text":"Продумать внешний вид сайта и удобство для пользователя"},{"id":"b","text":"Придумать, как компьютер сможет делать прогноз по примерам"},{"id":"c","text":"Понять по цифрам, почему изменился результат проекта"},{"id":"d","text":"Продумать, как хранить информацию без путаницы"},{"id":"e","text":"Сделать так, чтобы сервис стабильно работал у всех"},{"id":"f","text":"Найти возможные угрозы и закрыть уязвимости"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (22, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (23, 230, 'interest', 'interest', $prompt$Какую статью ты скорее открыла бы из любопытства?$prompt$, null, false, $opts$[{"id":"a","text":"Как создают приложения с удобным и красивым интерфейсом"},{"id":"b","text":"Как нейросеть учится понимать изображения и речь"},{"id":"c","text":"Как данные помогают предсказывать спрос и события"},{"id":"d","text":"Как устроены большие каталоги и поисковые системы"},{"id":"e","text":"Как работают облака, серверы и компьютерные сети"},{"id":"f","text":"Как специалисты расследуют кибератаки"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (23, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (24, 240, 'interest', 'interest', $prompt$Что из этого принесло бы тебе больше удовлетворения?$prompt$, null, false, $opts$[{"id":"a","text":"Люди пользуются сайтом, который я сделала"},{"id":"b","text":"Моя модель научилась находить закономерность"},{"id":"c","text":"Я нашла объяснение сложной ситуации по данным"},{"id":"d","text":"Информация хранится аккуратно и находится за секунды"},{"id":"e","text":"Сложная система работает надёжно и без сбоев"},{"id":"f","text":"Я обнаружила риск и помогла предотвратить проблему"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (24, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (25, 250, 'interest', 'interest', $prompt$Какую практику ты бы выбрала на первом знакомстве с IT?$prompt$, null, false, $opts$[{"id":"a","text":"Собрать простую веб-страницу из блоков"},{"id":"b","text":"Поиграть с готовой моделью распознавания изображений"},{"id":"c","text":"Построить диаграмму по реальным данным"},{"id":"d","text":"Собрать таблицу-каталог и настроить поиск"},{"id":"e","text":"Подключить устройства в локальную сеть"},{"id":"f","text":"Разобрать учебный пример фишингового письма"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (25, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (26, 260, 'interest', 'interest', $prompt$Если приложение работает медленно, какую часть проблемы интереснее исследовать?$prompt$, null, false, $opts$[{"id":"a","text":"Как сделать интерфейс понятнее и легче для браузера"},{"id":"b","text":"Можно ли улучшить алгоритм, который делает прогноз"},{"id":"c","text":"Какие данные показывают, когда и почему возникают задержки"},{"id":"d","text":"Как организовано хранение и получение записей"},{"id":"e","text":"Что происходит с сервером и сетевым соединением"},{"id":"f","text":"Не связано ли замедление с подозрительной активностью"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (26, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (27, 270, 'interest', 'interest', $prompt$Какой школьный или учебный проект тебе ближе по формату?$prompt$, null, false, $opts$[{"id":"a","text":"Создать сайт-путеводитель по интересному месту"},{"id":"b","text":"Сделать эксперимент с распознаванием объектов"},{"id":"c","text":"Провести опрос и проанализировать результаты"},{"id":"d","text":"Организовать электронную библиотеку или архив"},{"id":"e","text":"Собрать и настроить небольшую компьютерную инфраструктуру"},{"id":"f","text":"Подготовить памятку и демонстрацию цифровой безопасности"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (27, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (28, 280, 'interest', 'interest', $prompt$Что тебе важнее в цифровом продукте, над которым ты работаешь?$prompt$, null, false, $opts$[{"id":"a","text":"Чтобы им было приятно и просто пользоваться"},{"id":"b","text":"Чтобы он умел находить закономерности и помогать с решениями"},{"id":"c","text":"Чтобы его выводы опирались на данные"},{"id":"d","text":"Чтобы информация была организована и быстро находилась"},{"id":"e","text":"Чтобы он был быстрым, доступным и надёжным"},{"id":"f","text":"Чтобы данные и пользователи были защищены"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (28, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (29, 290, 'interest', 'interest', $prompt$Какую роль ты бы скорее выбрала в большой IT-команде?$prompt$, null, false, $opts$[{"id":"a","text":"Создавать пользовательскую часть продукта"},{"id":"b","text":"Работать над интеллектуальными функциями продукта"},{"id":"c","text":"Исследовать показатели и объяснять результаты"},{"id":"d","text":"Отвечать за устройство и качество хранилищ данных"},{"id":"e","text":"Поддерживать платформу, серверы и автоматизацию"},{"id":"f","text":"Заниматься защитой и проверкой безопасности"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (29, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

insert into public.questions (id, position, kind, topic, prompt, code, multi, options)
values (30, 300, 'interest', 'interest', $prompt$Какой трёхчасовой мастер-класс ты бы выбрала без оглядки на оценки и сложность?$prompt$, null, false, $opts$[{"id":"a","text":"С нуля сделать свой небольшой сайт"},{"id":"b","text":"Познакомиться с нейросетью и попробовать её обучить"},{"id":"c","text":"Найти неожиданный вывод в наборе данных"},{"id":"d","text":"Создать базу данных для личного проекта"},{"id":"e","text":"Разобраться, как устроен интернет и настроить сервер"},{"id":"f","text":"Попробовать себя в роли специалиста по кибербезопасности"}]$opts$::jsonb)
on conflict (id) do update set position=excluded.position, kind=excluded.kind, topic=excluded.topic, prompt=excluded.prompt, code=excluded.code, multi=excluded.multi, options=excluded.options;
insert into public.question_keys (question_id, correct, points, explanation, interest_map)
values (30, null, 1, null, $map${"a":{"web":2},"b":{"ml":2},"c":{"data":2},"d":{"db":2},"e":{"net":2},"f":{"sec":2}}$map$::jsonb)
on conflict (question_id) do update set correct=excluded.correct, points=excluded.points, explanation=excluded.explanation, interest_map=excluded.interest_map;

-- ============================================================
--  НАЗНАЧИТЬ УЧИТЕЛЯ: впиши свой email (тот, с которым ты
--  создал себе пользователя в Authentication → Users).
-- ============================================================
update public.profiles set role = 'teacher'
where email = lower('valdrmarr@gmail.com');

-- Проверка: у тебя должно быть teacher, у ученицы — student
select email, role, full_name from public.profiles order by role desc, email;
