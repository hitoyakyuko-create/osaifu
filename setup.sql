-- おさいふ わけわけ：Supabase セットアップ
-- Supabase の SQL Editor に、まるごと貼り付けて Run してください。
-- 何度実行してもエラーにならないように作ってあります。

-- 1) 記録（入金・出金・移動）を入れる表
create table if not exists public.wakewake_tx (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date        date not null,
  kind        text not null check (kind in ('in','out','move')),
  wallet      text not null check (wallet in ('allow','save')),
  amount      bigint not null check (amount > 0),
  memo        text not null default '',
  created_at  timestamptz not null default now()
);

-- 2) はじめの残高・銀行残高を入れる表（1人1行）
create table if not exists public.wakewake_settings (
  user_id       uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  opening_allow bigint not null default 0,
  opening_save  bigint not null default 0,
  bank          bigint,
  updated_at    timestamptz not null default now()
);

create index if not exists wakewake_tx_user_date_idx on public.wakewake_tx (user_id, date desc);

-- 3) 「ログインした本人の行だけ」読み書きできるようにする（RLS）
alter table public.wakewake_tx       enable row level security;
alter table public.wakewake_settings enable row level security;

drop policy if exists "wakewake_tx_own" on public.wakewake_tx;
create policy "wakewake_tx_own" on public.wakewake_tx
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "wakewake_settings_own" on public.wakewake_settings;
create policy "wakewake_settings_own" on public.wakewake_settings
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 4) 別のブラウザの変更がすぐ届くように、リアルタイム配信をオンにする
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'wakewake_tx') then
    alter publication supabase_realtime add table public.wakewake_tx;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'wakewake_settings') then
    alter publication supabase_realtime add table public.wakewake_settings;
  end if;
end $$;
