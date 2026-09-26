-- Human Food: shared cache so each product is analysed by AI only once, ever.

-- Products added by the community via label photos (items missing from Open Food Facts).
create table if not exists public.products (
  barcode     text primary key,
  data        jsonb       not null,           -- normalised Product JSON (same shape as the iOS model)
  source      text        not null default 'community',
  created_at  timestamptz not null default now()
);

-- One AI verdict per product, rubric version, language and score payload.
-- payload_hash = sha256 of the exact score data sent to the model, so a client that
-- sends a tampered score can only ever poison a cache entry honest clients never read.
create table if not exists public.verdicts (
  barcode         text        not null,
  rubric_version  int         not null,
  locale          text        not null,
  payload_hash    text        not null,
  verdict         jsonb       not null,
  score           int         not null,
  model           text        not null,
  hits            int         not null default 0,
  created_at      timestamptz not null default now(),
  primary key (barcode, rubric_version, locale, payload_hash)
);

-- Daily counter that hard-caps AI spend.
create table if not exists public.ai_usage (
  day    date primary key,
  calls  int  not null default 0
);

-- Per-client (hashed IP) fixed-window counters, so one caller can't drain the daily budget.
create table if not exists public.rate_limits (
  bucket        text        not null,
  window_start  timestamptz not null,
  hits          int         not null default 0,
  primary key (bucket, window_start)
);

-- Only the Edge Function (service role) touches these tables. RLS with no policies
-- means the public anon key can read or write nothing.
alter table public.products enable row level security;
alter table public.verdicts enable row level security;
alter table public.ai_usage enable row level security;
alter table public.rate_limits enable row level security;

-- Atomically reserves one AI call for today; returns false once the cap is hit.
create or replace function public.reserve_ai_call(daily_limit int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  used int;
begin
  insert into ai_usage (day, calls) values (current_date, 1)
  on conflict (day) do update set calls = ai_usage.calls + 1
  returning calls into used;
  return used <= daily_limit;
end;
$$;

-- Returns false once `p_bucket` has used `p_limit` hits in the current window.
create or replace function public.hit_rate_limit(p_bucket text, p_limit int, p_window_seconds int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  w timestamptz := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  used int;
begin
  insert into rate_limits (bucket, window_start, hits) values (p_bucket, w, 1)
  on conflict (bucket, window_start) do update set hits = rate_limits.hits + 1
  returning hits into used;
  if random() < 0.01 then
    delete from rate_limits where window_start < now() - interval '1 day';
  end if;
  return used <= p_limit;
end;
$$;

create or replace function public.bump_verdict_hits(p_barcode text, p_rubric int, p_locale text, p_hash text)
returns void
language sql
security definer
set search_path = public
as $$
  update verdicts set hits = hits + 1
  where barcode = p_barcode and rubric_version = p_rubric and locale = p_locale and payload_hash = p_hash;
$$;

revoke all on function public.reserve_ai_call(int) from public, anon, authenticated;
revoke all on function public.hit_rate_limit(text, int, int) from public, anon, authenticated;
revoke all on function public.bump_verdict_hits(text, int, text, text) from public, anon, authenticated;
