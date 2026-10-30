-- PHOMAB Supabase foundation
-- Run this in Supabase SQL Editor before switching the website from Firebase.
-- Keep Firebase active until data and authentication migration are verified.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  title text not null,
  area text not null,
  property_type text,
  rooms integer,
  rent numeric,
  status text not null default 'available',
  whatsapp_enabled boolean not null default false,
  phone text,
  description text,
  photo_urls jsonb not null default '[]'::jsonb,
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rental_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references auth.users(id) on delete set null,
  query text,
  rooms integer,
  budget numeric,
  areas jsonb not null default '[]'::jsonb,
  matches integer not null default 0,
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.wanted (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  areas jsonb not null default '[]'::jsonb,
  budget numeric,
  status text not null default 'open',
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.listing_photos (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  storage_path text,
  photo_url text,
  position integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references public.listings(id) on delete set null,
  tenant_id uuid references auth.users(id) on delete set null,
  landlord_id uuid references auth.users(id) on delete set null,
  title text,
  area text,
  rent numeric,
  agreed boolean,
  last_message text,
  last_message_at timestamptz,
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_members (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (chat_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  body text not null,
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  whatsapp_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references auth.users(id) on delete cascade,
  chat_id uuid references public.chats(id) on delete cascade,
  title text,
  status text not null default 'pending',
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  listing_id uuid references public.listings(id) on delete set null,
  reason text,
  details text,
  status text not null default 'open',
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists listings_status_created_idx on public.listings(status, created_at desc);
create index if not exists listings_area_idx on public.listings(area);
create index if not exists rental_requests_tenant_idx on public.rental_requests(tenant_id, created_at desc);
create index if not exists wanted_status_created_idx on public.wanted(status, created_at desc);
create index if not exists messages_chat_created_idx on public.messages(chat_id, created_at);
create index if not exists notifications_recipient_status_idx on public.notifications(recipient_id, status, created_at desc);

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.rental_requests enable row level security;
alter table public.wanted enable row level security;
alter table public.listing_photos enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.contacts enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;

-- Public can browse available rental listings. Only the owner can create/change their listings.
create policy "Anyone can read available listings" on public.listings for select using (status = 'available' or owner_id = auth.uid());
create policy "Signed-in users can create listings" on public.listings for insert to authenticated with check (owner_id = auth.uid());
create policy "Owners can update listings" on public.listings for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "Owners can delete listings" on public.listings for delete to authenticated using (owner_id = auth.uid());

create policy "Users can read own profile" on public.profiles for select to authenticated using (id = auth.uid());
create policy "Users can create own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "Users can update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "Users can read own rental requests" on public.rental_requests for select to authenticated using (tenant_id = auth.uid());
create policy "Users can create own rental requests" on public.rental_requests for insert to authenticated with check (tenant_id = auth.uid());
create policy "Users can read open wanted posts" on public.wanted for select using (status = 'open' or user_id = auth.uid());
create policy "Users can create wanted posts" on public.wanted for insert to authenticated with check (user_id = auth.uid());
create policy "Owners can update wanted posts" on public.wanted for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "Listing photos visible with listing" on public.listing_photos for select using (
  exists (select 1 from public.listings l where l.id = listing_id and (l.status = 'available' or l.owner_id = auth.uid()))
);
create policy "Listing owners manage photos" on public.listing_photos for all to authenticated using (
  exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid())
) with check (
  exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid())
);

create policy "Chat members can read chats" on public.chats for select to authenticated using (
  exists (select 1 from public.chat_members cm where cm.chat_id = id and cm.user_id = auth.uid())
);
create policy "Chat members can read membership" on public.chat_members for select to authenticated using (user_id = auth.uid());
create policy "Users can join chats they belong to" on public.chat_members for insert to authenticated with check (user_id = auth.uid());
create policy "Chat members can read messages" on public.messages for select to authenticated using (
  exists (select 1 from public.chat_members cm where cm.chat_id = chat_id and cm.user_id = auth.uid())
);
create policy "Chat members can send messages" on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and exists (select 1 from public.chat_members cm where cm.chat_id = chat_id and cm.user_id = auth.uid())
);

create policy "Users manage own contact" on public.contacts for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users read own notifications" on public.notifications for select to authenticated using (recipient_id = auth.uid());
create policy "Users update own notifications" on public.notifications for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
create policy "Users create reports" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "Users read own reports" on public.reports for select to authenticated using (reporter_id = auth.uid());

-- Keep updated_at current for listing edits.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at before update on public.listings
for each row execute function public.set_updated_at();
