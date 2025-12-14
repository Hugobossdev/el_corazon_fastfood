-- =====================================================
-- 🛠️ FIX SCHEMA: CHAT MESSAGES & DRIVER PERMISSIONS
-- =====================================================

-- 1. Table des messages (utilisée par elcora_dely et elcora_fast)
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  sender_id uuid references auth.users(id) not null, -- Supabase Auth User ID
  sender_name text,
  content text,
  is_from_driver boolean default false,
  image_url text,
  type text default 'text', -- 'text', 'image', 'location'
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  is_read boolean default false,
  read_at timestamp with time zone
);

-- Index pour les performances
create index if not exists messages_order_id_idx on public.messages(order_id);
create index if not exists messages_sender_id_idx on public.messages(sender_id);

-- Activer RLS
alter table public.messages enable row level security;

-- Politiques RLS pour MESSAGES

-- Lecture: Le client (owner du order) et le livreur (delivery_person_id du order) peuvent lire
drop policy if exists "Users can view messages for their orders" on public.messages;
create policy "Users can view messages for their orders"
on public.messages for select
using (
  exists (
    select 1 from public.orders o
    where o.id = messages.order_id
    and (
        o.user_id = (select id from public.users where auth_user_id = auth.uid())
        or 
        o.delivery_person_id = (select id from public.users where auth_user_id = auth.uid())
    )
  )
);

-- Insertion: L'auteur doit être authentifié
drop policy if exists "Users can insert messages" on public.messages;
create policy "Users can insert messages"
on public.messages for insert
with check (
  auth.uid() = sender_id
);

-- Mise à jour (ex: marquer comme lu)
drop policy if exists "Users can update messages" on public.messages;
create policy "Users can update messages"
on public.messages for update
using (
  exists (
    select 1 from public.orders o
    where o.id = messages.order_id
    and (
        o.user_id = (select id from public.users where auth_user_id = auth.uid())
        or 
        o.delivery_person_id = (select id from public.users where auth_user_id = auth.uid())
    )
  )
);

-- =====================================================
-- 2. FIX DRIVER PERMISSIONS (ORDERS)
-- =====================================================

-- Activer RLS sur orders si ce n'est pas déjà fait
alter table public.orders enable row level security;

-- Politique pour que les livreurs puissent VOIR les commandes disponibles (sans livreur) OU celles qui leur sont assignées
drop policy if exists "Drivers can view available and assigned orders" on public.orders;
create policy "Drivers can view available and assigned orders"
on public.orders for select
using (
  -- Si c'est l'utilisateur qui a passé la commande (déjà couvert par une autre politique mais on peut combiner)
  user_id = (select id from public.users where auth_user_id = auth.uid())
  OR
  -- Si l'utilisateur est un livreur
  exists (
    select 1 from public.users
    where auth_user_id = auth.uid()
    and role = 'delivery'
    and (
        -- Il peut voir les commandes sans livreur (disponibles)
        delivery_person_id is null
        OR
        -- Ou celles qui lui sont assignées
        delivery_person_id = public.users.id
    )
  )
);

-- Politique pour que les livreurs puissent ACCEPTER une commande (update delivery_person_id null -> me)
drop policy if exists "Drivers can accept available orders" on public.orders;
create policy "Drivers can accept available orders"
on public.orders for update
using (
  delivery_person_id is null
  and exists (
    select 1 from public.users
    where auth_user_id = auth.uid()
    and role = 'delivery'
  )
)
with check (
  -- Le livreur s'assigne lui-même
  delivery_person_id = (select id from public.users where auth_user_id = auth.uid())
);

-- Politique pour que les livreurs puissent METTRE À JOUR le statut de leurs commandes
drop policy if exists "Drivers can update assigned orders" on public.orders;
create policy "Drivers can update assigned orders"
on public.orders for update
using (
  delivery_person_id = (select id from public.users where auth_user_id = auth.uid())
);

-- =====================================================
-- 3. FIX ACTIVE DELIVERIES
-- =====================================================
alter table public.active_deliveries enable row level security;

drop policy if exists "Drivers can manage their active deliveries" on public.active_deliveries;
create policy "Drivers can manage their active deliveries"
on public.active_deliveries for all
using (
  delivery_id = (select id from public.users where auth_user_id = auth.uid())
);
