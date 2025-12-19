-- Ajout des coordonnées (livraison + restaurant) sur orders + table restaurants.
-- Migration idempotente (safe à rejouer).

-- 1) Table restaurants (si tu veux stocker les points de départ)
CREATE TABLE IF NOT EXISTS public.restaurants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS permissif en dev (à ajuster en prod)
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'restaurants'
  ) THEN
    CREATE POLICY "Enable access to all users" ON public.restaurants
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END$$;

-- 2) Colonnes GPS sur orders (si la table existe déjà)
ALTER TABLE IF EXISTS public.orders
  ADD COLUMN IF NOT EXISTS delivery_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS delivery_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS restaurant_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS restaurant_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS restaurant_name TEXT,
  ADD COLUMN IF NOT EXISTS restaurant_address TEXT,
  ADD COLUMN IF NOT EXISTS restaurant_id UUID REFERENCES public.restaurants(id);

-- Index utiles
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_id ON public.orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_lat_lng ON public.orders(delivery_latitude, delivery_longitude);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_lat_lng ON public.orders(restaurant_latitude, restaurant_longitude);

-- (Optionnel) realtime
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE restaurants;
  EXCEPTION WHEN others THEN
    -- ignore si déjà ajouté / publication absente
  END;
END$$;



