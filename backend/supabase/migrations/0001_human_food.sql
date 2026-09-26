-- Human Food: shared cache so each product is analysed by AI only once, ever.

-- Products added by the community via label photos (items missing from Open Food Facts).
create table if not exists public.products (
  barcode     text primary key,
  data        jsonb       not null,           -- normalised Product JSON (same shape as the iOS model)
  source      text        not null default 'community',
  created_at  timestamptz not null default now()
);

-- One AI verdict per product, rubric version and language.
create table if not exists public.verdicts (
  barcode         text        not null,
  rubric_version  int         not null,
  locale          text        not null,
  verdict         jsonb       not null,
  score           int         not null,
  model           text        not null,
  hits            int         not null default 0,
  created_at      timestamptz not null default now(),
  primary key (barcode, rubric_version, locale)
);

-- Daily counter that hard-caps AI spend.
create table if not exists public.ai_usage (
  day    date primary key,
  calls  int  not null default 0
);

-- Only the Edge Function (service role) touches these tables.
alter table public.products enable row level security;
alter table public.verdicts enable row level security;
alter table public.ai_usage enable row level security;

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

create or replace function public.bump_verdict_hits(p_barcode text, p_rubric int, p_locale text)
returns void
language sql
security definer
set search_path = public
as $$
  update verdicts set hits = hits + 1
  where barcode = p_barcode and rubric_version = p_rubric and locale = p_locale;
$$;

revoke all on function public.reserve_ai_call(int) from public, anon, authenticated;
revoke all on function public.bump_verdict_hits(text, int, text) from public, anon, authenticated;
