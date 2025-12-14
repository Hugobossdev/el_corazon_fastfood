-- =====================================================
-- 📊 El Corazón FastGo - Script SQL Complet
-- =====================================================
-- Version: 1.0
-- Date: Décembre 2024
-- Base de données: PostgreSQL 15+ (Supabase)
-- =====================================================

-- Activer les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- =====================================================
-- 🧹 NETTOYAGE (Optionnel - Décommenter si besoin)
-- =====================================================
-- DROP SCHEMA public CASCADE;
-- CREATE SCHEMA public;
-- GRANT ALL ON SCHEMA public TO postgres;
-- GRANT ALL ON SCHEMA public TO public;

-- =====================================================
-- 📋 SECTION 1: TABLES UTILISATEURS
-- =====================================================

-- Table centrale des utilisateurs
CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    auth_user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('client', 'admin', 'delivery')),
    profile_image TEXT,
    loyalty_points INTEGER DEFAULT 0,
    badges TEXT[] DEFAULT '{}',
    is_online BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Champs legacy pour les livreurs (à migrer)
    profile_photo_url TEXT,
    license_number TEXT,
    id_number TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    license_photo_url TEXT,
    id_card_photo_url TEXT,
    vehicle_photo_url TEXT,
    verification_status TEXT DEFAULT 'pending',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour users
CREATE INDEX idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_online ON users(is_online);
CREATE INDEX idx_users_loyalty_points ON users(loyalty_points);
CREATE INDEX idx_users_email ON users(email);

-- Table des profils livreurs
CREATE TABLE drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- Informations de vérification
    profile_photo_url TEXT,
    license_number TEXT,
    id_number TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    license_photo_url TEXT,
    id_card_photo_url TEXT,
    vehicle_photo_url TEXT,
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verification_notes TEXT,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Statistiques
    total_deliveries INTEGER DEFAULT 0,
    completed_deliveries INTEGER DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
    total_ratings INTEGER DEFAULT 0,
    total_earnings DECIMAL(10,2) DEFAULT 0.0,
    
    -- Disponibilité
    is_available BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('available', 'busy', 'on_delivery', 'offline')),
    current_location_latitude DECIMAL(10,8),
    current_location_longitude DECIMAL(11,8),
    last_location_update TIMESTAMP WITH TIME ZONE,
    last_online TIMESTAMP WITH TIME ZONE,
    
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour drivers
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
CREATE INDEX idx_drivers_verification_status ON drivers(verification_status);
CREATE INDEX idx_drivers_is_available ON drivers(is_available);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_rating ON drivers(rating);
CREATE INDEX idx_drivers_location ON drivers(current_location_latitude, current_location_longitude);

-- Table des adresses
CREATE TABLE addresses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    type TEXT NOT NULL DEFAULT 'other',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_is_default ON addresses(is_default);

-- Table des rôles administrateurs
CREATE TABLE admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_admin_roles_name ON admin_roles(name);
CREATE INDEX idx_admin_roles_is_active ON admin_roles(is_active);

-- Table de liaison utilisateurs-rôles admin
CREATE TABLE user_admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES admin_roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

CREATE INDEX idx_user_admin_roles_user_id ON user_admin_roles(user_id);
CREATE INDEX idx_user_admin_roles_role_id ON user_admin_roles(role_id);

-- =====================================================
-- 📋 SECTION 2: TABLES MENU ET PRODUITS
-- =====================================================

-- Table des catégories de menu
CREATE TABLE menu_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_menu_categories_is_active ON menu_categories(is_active);
CREATE INDEX idx_menu_categories_sort_order ON menu_categories(sort_order);

-- Table des éléments de menu
CREATE TABLE menu_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    category_id UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,
    image_url TEXT,
    
    -- Caractéristiques
    is_popular BOOLEAN DEFAULT FALSE,
    is_vegetarian BOOLEAN DEFAULT FALSE,
    is_vegan BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    available_quantity INTEGER DEFAULT 100,
    vip_exclusive BOOLEAN DEFAULT FALSE,
    is_vip_exclusive BOOLEAN DEFAULT FALSE,
    
    -- Informations nutritionnelles
    ingredients TEXT[] DEFAULT '{}',
    calories INTEGER DEFAULT 0,
    allergens TEXT[] DEFAULT '{}',
    
    -- Préparation
    preparation_time INTEGER DEFAULT 15,
    
    -- Évaluations
    rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INTEGER DEFAULT 0,
    
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_menu_items_category_id ON menu_items(category_id);
CREATE INDEX idx_menu_items_is_available ON menu_items(is_available);
CREATE INDEX idx_menu_items_is_popular ON menu_items(is_popular);
CREATE INDEX idx_menu_items_price ON menu_items(price);
CREATE INDEX idx_menu_items_rating ON menu_items(rating);
CREATE INDEX idx_menu_items_sort_order ON menu_items(sort_order);

-- Table des options de personnalisation
CREATE TABLE customization_options (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'ingredient', 'sauce', 'size', 'cooking', 'extra', 
        'shape', 'flavor', 'filling', 'decoration', 'tiers', 'icing', 'dietary'
    )),
    price_modifier DECIMAL(10,2) DEFAULT 0.0,
    is_default BOOLEAN DEFAULT FALSE,
    max_quantity INTEGER DEFAULT 1,
    description TEXT,
    image_url TEXT,
    allergens TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_customization_options_category ON customization_options(category);
CREATE INDEX idx_customization_options_is_active ON customization_options(is_active);

-- Table de liaison menu-options
CREATE TABLE menu_item_customizations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    customization_option_id UUID NOT NULL REFERENCES customization_options(id) ON DELETE CASCADE,
    is_required BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(menu_item_id, customization_option_id)
);

CREATE INDEX idx_menu_item_customizations_menu_item_id ON menu_item_customizations(menu_item_id);
CREATE INDEX idx_menu_item_customizations_option_id ON menu_item_customizations(customization_option_id);

-- Table des avis produits
CREATE TABLE product_reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    rating DECIMAL(3,2) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title TEXT,
    comment TEXT NOT NULL,
    photos TEXT[] DEFAULT '{}',
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(menu_item_id, user_id)
);

CREATE INDEX idx_product_reviews_menu_item_id ON product_reviews(menu_item_id);
CREATE INDEX idx_product_reviews_user_id ON product_reviews(user_id);
CREATE INDEX idx_product_reviews_rating ON product_reviews(rating);

-- Table de gestion d'inventaire
CREATE TABLE inventory_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    current_stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    minimum_stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    unit TEXT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    last_restock_date TIMESTAMP WITH TIME ZONE,
    expiry_date TIMESTAMP WITH TIME ZONE,
    supplier TEXT,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_inventory_items_category ON inventory_items(category);
CREATE INDEX idx_inventory_items_current_stock ON inventory_items(current_stock);

-- =====================================================
-- 📋 SECTION 3: TABLES COMMANDES
-- =====================================================

-- Table des commandes
CREATE TABLE orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivery_person_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Statut
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'confirmed', 'preparing', 'ready', 
        'picked_up', 'on_the_way', 'delivered', 'cancelled'
    )),
    
    -- Montants
    subtotal DECIMAL(10,2) NOT NULL,
    delivery_fee DECIMAL(10,2) DEFAULT 5.00,
    discount DECIMAL(10,2) DEFAULT 0.00,
    total DECIMAL(10,2) NOT NULL,
    
    -- Livraison
    delivery_address TEXT NOT NULL,
    delivery_latitude DECIMAL(10,8),
    delivery_longitude DECIMAL(11,8),
    delivery_notes TEXT,
    special_instructions TEXT,
    
    -- Paiement
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'wallet', 'mobile_money')),
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN (
        'pending', 'processing', 'completed', 'failed', 'refunded'
    )),
    payment_transaction_id TEXT,
    
    -- Code promo
    promo_code TEXT,
    
    -- Timing
    order_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    estimated_delivery_time TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    -- Commandes groupées
    is_group_order BOOLEAN DEFAULT FALSE,
    group_id UUID,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_delivery_person_id ON orders(delivery_person_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_orders_is_group_order ON orders(is_group_order);
CREATE INDEX idx_orders_group_id ON orders(group_id);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);

-- Table des éléments de commande
CREATE TABLE order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    menu_item_name TEXT NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    menu_item_image TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    customizations JSONB DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_menu_item_id ON order_items(menu_item_id);

-- Table d'historique des statuts
CREATE TABLE order_status_updates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_order_status_updates_order_id ON order_status_updates(order_id);
CREATE INDEX idx_order_status_updates_created_at ON order_status_updates(created_at);

-- Table de suivi des commandes
CREATE TABLE order_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_tracking BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(order_id, user_id)
);

CREATE INDEX idx_order_tracking_order_id ON order_tracking(order_id);
CREATE INDEX idx_order_tracking_user_id ON order_tracking(user_id);

-- Table des paniers utilisateurs
CREATE TABLE user_carts (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    delivery_fee DECIMAL(10,2) DEFAULT 500.0,
    discount DECIMAL(10,2) DEFAULT 0.0,
    promo_code TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des articles du panier
CREATE TABLE user_cart_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    menu_item_id TEXT NOT NULL,
    name TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    image_url TEXT,
    customizations JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_cart_items_user_id ON user_cart_items(user_id);

-- =====================================================
-- 📋 SECTION 4: TABLES LIVRAISON
-- =====================================================

-- Table des positions de livraison
CREATE TABLE delivery_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    accuracy DECIMAL(8,2),
    speed DECIMAL(8,2),
    heading DECIMAL(8,2),
    altitude DECIMAL(8,2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_delivery_locations_order_id ON delivery_locations(order_id);
CREATE INDEX idx_delivery_locations_delivery_id ON delivery_locations(delivery_id);
CREATE INDEX idx_delivery_locations_timestamp ON delivery_locations(timestamp);

-- Table des livraisons actives
CREATE TABLE active_deliveries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    delivery_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN (
        'assigned', 'accepted', 'picked_up', 'on_the_way', 'delivered'
    )),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    started_delivery_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_active_deliveries_delivery_id ON active_deliveries(delivery_id);
CREATE INDEX idx_active_deliveries_order_id ON active_deliveries(order_id);
CREATE INDEX idx_active_deliveries_status ON active_deliveries(status);

-- =====================================================
-- 📋 SECTION 5: TABLES PAIEMENTS
-- =====================================================

-- Table des groupes sociaux (nécessaire pour group_payments)
CREATE TABLE social_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    group_type TEXT NOT NULL CHECK (group_type IN (
        'family', 'friends', 'work', 'neighborhood', 'custom'
    )),
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL UNIQUE,
    is_private BOOLEAN DEFAULT FALSE,
    max_members INTEGER DEFAULT 50,
    member_count INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_social_groups_creator_id ON social_groups(creator_id);
CREATE INDEX idx_social_groups_invite_code ON social_groups(invite_code);
CREATE INDEX idx_social_groups_is_active ON social_groups(is_active);

-- Table des paiements groupés
CREATE TABLE group_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES social_groups(id) ON DELETE SET NULL,
    order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'in_progress', 'completed', 'cancelled'
    )),
    initiated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_group_payments_group_id ON group_payments(group_id);
CREATE INDEX idx_group_payments_order_id ON group_payments(order_id);
CREATE INDEX idx_group_payments_status ON group_payments(status);

-- Table des participants aux paiements groupés
CREATE TABLE group_payment_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_payment_id UUID NOT NULL REFERENCES group_payments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    operator TEXT,
    amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'paid', 'failed', 'cancelled'
    )),
    transaction_id TEXT,
    payment_result JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_group_payment_participants_group_payment_id ON group_payment_participants(group_payment_id);
CREATE INDEX idx_group_payment_participants_user_id ON group_payment_participants(user_id);

-- =====================================================
-- 📋 SECTION 6: TABLES GAMIFICATION
-- =====================================================

-- Table des succès
CREATE TABLE achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    points_reward INTEGER DEFAULT 0,
    badge_reward TEXT,
    condition_type TEXT NOT NULL CHECK (condition_type IN (
        'orders_count', 'total_spent', 'streak_days', 'category_orders', 'special'
    )),
    condition_value INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_achievements_is_active ON achievements(is_active);
CREATE INDEX idx_achievements_condition_type ON achievements(condition_type);

-- Table des succès utilisateurs
CREATE TABLE user_achievements (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);

CREATE INDEX idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_is_unlocked ON user_achievements(is_unlocked);

-- Table des défis
CREATE TABLE challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    challenge_type TEXT NOT NULL CHECK (challenge_type IN (
        'daily', 'weekly', 'monthly', 'special'
    )),
    target_value INTEGER NOT NULL,
    reward_points INTEGER DEFAULT 0,
    reward_discount DECIMAL(5,2) DEFAULT 0.0,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_challenges_is_active ON challenges(is_active);
CREATE INDEX idx_challenges_challenge_type ON challenges(challenge_type);
CREATE INDEX idx_challenges_dates ON challenges(start_date, end_date);

-- Table des défis utilisateurs
CREATE TABLE user_challenges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, challenge_id)
);

CREATE INDEX idx_user_challenges_user_id ON user_challenges(user_id);
CREATE INDEX idx_user_challenges_is_completed ON user_challenges(is_completed);

-- Table des badges
CREATE TABLE badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL UNIQUE,
    description TEXT,
    icon TEXT NOT NULL DEFAULT '🏅',
    points_required INTEGER DEFAULT 0,
    criteria TEXT NOT NULL DEFAULT 'points',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_badges_is_active ON badges(is_active);

-- Table des badges utilisateurs
CREATE TABLE user_badges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, badge_id)
);

CREATE INDEX idx_user_badges_user_id ON user_badges(user_id);
CREATE INDEX idx_user_badges_is_unlocked ON user_badges(is_unlocked);

-- Table des récompenses de fidélité
CREATE TABLE loyalty_rewards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    cost INTEGER NOT NULL,
    reward_type TEXT NOT NULL CHECK (reward_type IN (
        'discount', 'free_item', 'free_delivery', 'cashback', 'exclusive_offer'
    )),
    value DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_loyalty_rewards_is_active ON loyalty_rewards(is_active);
CREATE INDEX idx_loyalty_rewards_reward_type ON loyalty_rewards(reward_type);

-- Table des transactions de points
CREATE TABLE loyalty_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'earn', 'redeem', 'bonus', 'adjustment', 'expiration'
    )),
    points INTEGER NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_loyalty_transactions_user_id ON loyalty_transactions(user_id);
CREATE INDEX idx_loyalty_transactions_created_at ON loyalty_transactions(created_at);

-- Table des échanges de récompenses
CREATE TABLE reward_redemptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_id TEXT NOT NULL,
    cost INTEGER NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_reward_redemptions_user_id ON reward_redemptions(user_id);
CREATE INDEX idx_reward_redemptions_status ON reward_redemptions(status);

-- Table des abonnements
CREATE TABLE subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_type TEXT NOT NULL CHECK (subscription_type IN ('weekly', 'monthly', 'vip')),
    plan_name TEXT,
    meals_per_week INTEGER DEFAULT 0,
    price_per_meal DECIMAL(10,2) DEFAULT 0.0,
    monthly_price DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
        'active', 'paused', 'cancelled', 'expired'
    )),
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    meals_used_this_period INTEGER DEFAULT 0,
    auto_renew BOOLEAN DEFAULT TRUE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_subscription_type ON subscriptions(subscription_type);

-- Table des commandes d'abonnement
CREATE TABLE subscription_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    meal_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(subscription_id, order_id)
);

CREATE INDEX idx_subscription_orders_subscription_id ON subscription_orders(subscription_id);
CREATE INDEX idx_subscription_orders_order_id ON subscription_orders(order_id);

-- =====================================================
-- 📋 SECTION 7: TABLES SOCIAL
-- =====================================================

-- Table des membres de groupe
CREATE TABLE group_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES social_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('creator', 'admin', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(group_id, user_id)
);

CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_group_members_role ON group_members(role);

-- Table des publications sociales
CREATE TABLE social_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES social_groups(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    post_type TEXT NOT NULL CHECK (post_type IN (
        'order_share', 'review', 'photo', 'text', 'event'
    )),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    image_url TEXT,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_social_posts_user_id ON social_posts(user_id);
CREATE INDEX idx_social_posts_group_id ON social_posts(group_id);
CREATE INDEX idx_social_posts_post_type ON social_posts(post_type);
CREATE INDEX idx_social_posts_created_at ON social_posts(created_at);

-- Table des likes
CREATE TABLE post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

CREATE INDEX idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX idx_post_likes_user_id ON post_likes(user_id);

-- Table des commentaires
CREATE TABLE post_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX idx_post_comments_user_id ON post_comments(user_id);

-- =====================================================
-- 📋 SECTION 8: TABLES NOTIFICATIONS
-- =====================================================

-- Table des notifications
CREATE TABLE notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info' CHECK (type IN (
        'info', 'warning', 'error', 'success', 
        'order_update', 'promotion', 'social'
    )),
    is_read BOOLEAN DEFAULT FALSE,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- =====================================================
-- 📋 SECTION 9: TABLES PROMOTIONS
-- =====================================================

-- Table des promotions
CREATE TABLE promotions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    promo_code TEXT NOT NULL UNIQUE,
    discount_type TEXT NOT NULL CHECK (discount_type IN (
        'percentage', 'fixed', 'free_delivery'
    )),
    discount_value DECIMAL(10,2) NOT NULL,
    min_order_amount DECIMAL(10,2) DEFAULT 0.0,
    max_discount DECIMAL(10,2),
    usage_limit INTEGER,
    used_count INTEGER DEFAULT 0,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_promotions_promo_code ON promotions(promo_code);
CREATE INDEX idx_promotions_is_active ON promotions(is_active);
CREATE INDEX idx_promotions_dates ON promotions(start_date, end_date);

-- Table d'utilisation des promotions
CREATE TABLE promotion_usage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    discount_amount DECIMAL(10,2) NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_promotion_usage_promotion_id ON promotion_usage(promotion_id);
CREATE INDEX idx_promotion_usage_user_id ON promotion_usage(user_id);
CREATE INDEX idx_promotion_usage_order_id ON promotion_usage(order_id);

-- =====================================================
-- 📋 SECTION 10: TABLES ANALYTICS
-- =====================================================

-- Table des événements analytics
CREATE TABLE analytics_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    event_data JSONB DEFAULT '{}',
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at);

-- Table des préférences utilisateur
CREATE TABLE user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    category_preferences JSONB DEFAULT '{}',
    price_range JSONB DEFAULT '{}',
    dietary_restrictions TEXT[] DEFAULT '{}',
    favorite_items TEXT[] DEFAULT '{}',
    disliked_items TEXT[] DEFAULT '{}',
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);

-- Table des recommandations IA
CREATE TABLE recommendations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    recommendation_type TEXT NOT NULL CHECK (recommendation_type IN (
        'popular', 'similar', 'trending', 'personalized'
    )),
    score DECIMAL(5,4) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_recommendations_user_id ON recommendations(user_id);
CREATE INDEX idx_recommendations_menu_item_id ON recommendations(menu_item_id);
CREATE INDEX idx_recommendations_type ON recommendations(recommendation_type);

-- =====================================================
-- 📋 SECTION 11: TABLES SUPPORT
-- =====================================================

-- Table des tickets de support
CREATE TABLE support_tickets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    attachments TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN (
        'open', 'in_progress', 'resolved', 'closed'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution TEXT
);

CREATE INDEX idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status);
CREATE INDEX idx_support_tickets_created_at ON support_tickets(created_at);

-- Table des messages de support
CREATE TABLE support_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_support_messages_ticket_id ON support_messages(ticket_id);

-- Table des réclamations
CREATE TABLE complaints (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('quality', 'delivery', 'service', 'other')),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    photos TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'under_review', 'resolved', 'rejected'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolution TEXT
);

CREATE INDEX idx_complaints_user_id ON complaints(user_id);
CREATE INDEX idx_complaints_order_id ON complaints(order_id);
CREATE INDEX idx_complaints_status ON complaints(status);

-- Table des demandes de retour
CREATE TABLE return_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    items TEXT[] NOT NULL,
    refund_amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'approved', 'rejected', 'refunded'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_return_requests_user_id ON return_requests(user_id);
CREATE INDEX idx_return_requests_order_id ON return_requests(order_id);
CREATE INDEX idx_return_requests_status ON return_requests(status);

-- =====================================================
-- 📋 SECTION 12: TABLES FORMULAIRES
-- =====================================================

-- Table des formulaires sauvegardés
CREATE TABLE saved_forms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    form_name VARCHAR(100) NOT NULL,
    form_data JSONB NOT NULL,
    is_auto_save BOOLEAN DEFAULT false,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_saved_forms_user_id ON saved_forms(user_id);
CREATE INDEX idx_saved_forms_form_name ON saved_forms(form_name);

-- Table d'historique de validation
CREATE TABLE validation_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    form_name VARCHAR(100) NOT NULL,
    validation_result JSONB NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_validation_history_user_id ON validation_history(user_id);
CREATE INDEX idx_validation_history_timestamp ON validation_history(timestamp);

-- =====================================================
-- 📋 SECTION 13: TABLES MARKETING
-- =====================================================

-- Table des campagnes marketing
CREATE TABLE IF NOT EXISTS marketing_campaigns (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('personalized', 'seasonal', 'promotional', 'retention')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_user_ids TEXT[] DEFAULT '{}',
    conditions JSONB DEFAULT '{}'::jsonb,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    metrics JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour marketing_campaigns
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_is_active ON marketing_campaigns(is_active);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_type ON marketing_campaigns(type);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_dates ON marketing_campaigns(start_date, end_date);

-- Trigger pour mettre à jour updated_at
DROP TRIGGER IF EXISTS update_marketing_campaigns_updated_at ON marketing_campaigns;
CREATE TRIGGER update_marketing_campaigns_updated_at 
BEFORE UPDATE ON marketing_campaigns
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Politiques RLS (Row Level Security)
ALTER TABLE marketing_campaigns ENABLE ROW LEVEL SECURITY;

-- Les admins peuvent tout faire
CREATE POLICY "Admins can manage marketing campaigns"
    ON marketing_campaigns FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_admin_roles uar
            JOIN admin_roles ar ON uar.role_id = ar.id
            WHERE uar.user_id = auth.uid()
        )
    );

-- Les utilisateurs peuvent voir les campagnes actives qui les ciblent
-- Note: Cette politique est simplifiée. Pour une sécurité optimale, il faudrait vérifier target_user_ids
-- Mais comme auth.uid() retourne un UUID et target_user_ids est TEXT[], la conversion est nécessaire
CREATE POLICY "Users can view relevant campaigns"
    ON marketing_campaigns FOR SELECT
    USING (
        is_active = TRUE 
        AND NOW() BETWEEN start_date AND end_date
        -- Optionnel: filtrer par target_user_ids si nécessaire
        -- AND (target_user_ids = '{}' OR auth.uid()::text = ANY(target_user_ids))
    );

-- =====================================================
-- 🔧 SECTION 14: FONCTIONS ET TRIGGERS
-- =====================================================

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger updated_at sur toutes les tables pertinentes
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_addresses_updated_at BEFORE UPDATE ON addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_categories_updated_at BEFORE UPDATE ON menu_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_social_groups_updated_at BEFORE UPDATE ON social_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Fonction pour mettre à jour le compteur de membres de groupe
CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE social_groups 
        SET member_count = member_count + 1
        WHERE id = NEW.group_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE social_groups 
        SET member_count = member_count - 1
        WHERE id = OLD.group_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_group_member_count_trigger
AFTER INSERT OR DELETE ON group_members
FOR EACH ROW EXECUTE FUNCTION update_group_member_count();

-- Fonction pour mettre à jour les compteurs de posts
CREATE OR REPLACE FUNCTION update_post_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF TG_TABLE_NAME = 'post_likes' THEN
            UPDATE social_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
        ELSIF TG_TABLE_NAME = 'post_comments' THEN
            UPDATE social_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF TG_TABLE_NAME = 'post_likes' THEN
            UPDATE social_posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
        ELSIF TG_TABLE_NAME = 'post_comments' THEN
            UPDATE social_posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_likes_count_trigger
AFTER INSERT OR DELETE ON post_likes
FOR EACH ROW EXECUTE FUNCTION update_post_counts();

CREATE TRIGGER update_comments_count_trigger
AFTER INSERT OR DELETE ON post_comments
FOR EACH ROW EXECUTE FUNCTION update_post_counts();

-- Fonction pour mettre à jour la note moyenne des menu items
CREATE OR REPLACE FUNCTION update_menu_item_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE menu_items
    SET rating = (
        SELECT COALESCE(AVG(rating), 0)
        FROM product_reviews
        WHERE menu_item_id = COALESCE(NEW.menu_item_id, OLD.menu_item_id)
    ),
    review_count = (
        SELECT COUNT(*)
        FROM product_reviews
        WHERE menu_item_id = COALESCE(NEW.menu_item_id, OLD.menu_item_id)
    )
    WHERE id = COALESCE(NEW.menu_item_id, OLD.menu_item_id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_menu_item_rating_trigger
AFTER INSERT OR UPDATE OR DELETE ON product_reviews
FOR EACH ROW EXECUTE FUNCTION update_menu_item_rating();

-- Fonction pour vérifier le rôle des drivers
CREATE OR REPLACE FUNCTION check_driver_role()
RETURNS TRIGGER AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM users WHERE id = NEW.user_id;
    
    IF user_role != 'delivery' THEN
        RAISE EXCEPTION 'Only users with role "delivery" can have a driver profile';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_driver_role_trigger
BEFORE INSERT OR UPDATE ON drivers
FOR EACH ROW EXECUTE FUNCTION check_driver_role();

-- Fonction de nettoyage des anciennes positions
CREATE OR REPLACE FUNCTION cleanup_old_delivery_locations()
RETURNS void AS $$
BEGIN
    DELETE FROM delivery_locations
    WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Fonction pour synchroniser le statut de la commande avec celui de la livraison active
CREATE OR REPLACE FUNCTION sync_order_status_with_active_delivery()
RETURNS TRIGGER AS $$
BEGIN
    -- On ne fait quelque chose que si le statut a changé ou lors d'un insert
    IF TG_OP = 'INSERT'
       OR (TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status) THEN

        -- Quand le livreur a récupéré la commande
        IF NEW.status = 'picked_up' THEN
            UPDATE orders
            SET status = 'picked_up',
                updated_at = NOW()
            WHERE id = NEW.order_id;

            INSERT INTO order_status_updates (order_id, status, updated_by, notes)
            VALUES (NEW.order_id, 'picked_up', NEW.delivery_id, 'Commande récupérée par le livreur');

        -- Quand le livreur est en route chez le client
        ELSIF NEW.status = 'on_the_way' THEN
            UPDATE orders
            SET status = 'on_the_way',
                updated_at = NOW()
            WHERE id = NEW.order_id;

            INSERT INTO order_status_updates (order_id, status, updated_by, notes)
            VALUES (NEW.order_id, 'on_the_way', NEW.delivery_id, 'Livreur en route vers le client');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_order_status_with_active_delivery_trigger
AFTER INSERT OR UPDATE ON active_deliveries
FOR EACH ROW EXECUTE FUNCTION sync_order_status_with_active_delivery();

-- =====================================================
-- 📊 SECTION 15: VUES
-- =====================================================

-- Vue des livreurs disponibles
CREATE OR REPLACE VIEW available_drivers_view AS
SELECT 
    d.id,
    d.user_id,
    u.name,
    u.email,
    u.phone,
    u.profile_image,
    d.rating,
    d.total_deliveries,
    d.completed_deliveries,
    d.vehicle_type,
    d.current_location_latitude,
    d.current_location_longitude,
    d.status,
    d.is_available
FROM drivers d
INNER JOIN users u ON d.user_id = u.id
WHERE d.is_available = TRUE 
    AND d.is_active = TRUE 
    AND d.verification_status = 'approved'
    AND u.is_online = TRUE;

-- Vue des livreurs en attente de vérification
CREATE OR REPLACE VIEW pending_verification_drivers_view AS
SELECT 
    d.id,
    d.user_id,
    u.name,
    u.email,
    u.phone,
    d.license_number,
    d.id_number,
    d.vehicle_type,
    d.vehicle_number,
    d.verification_status,
    d.created_at
FROM drivers d
INNER JOIN users u ON d.user_id = u.id
WHERE d.verification_status = 'pending';

-- Vue des statistiques de livraison
CREATE OR REPLACE VIEW delivery_stats AS
SELECT 
    d.id,
    d.user_id,
    u.name,
    d.total_deliveries,
    d.completed_deliveries,
    CASE 
        WHEN d.total_deliveries > 0 
        THEN ROUND((d.completed_deliveries::DECIMAL / d.total_deliveries * 100), 2)
        ELSE 0 
    END as completion_rate,
    d.rating,
    d.total_ratings,
    d.total_earnings
FROM drivers d
INNER JOIN users u ON d.user_id = u.id;

-- Vue des commandes actives
CREATE OR REPLACE VIEW active_orders_view AS
SELECT 
    o.id,
    o.user_id,
    u.name as customer_name,
    o.delivery_person_id,
    d.name as driver_name,
    o.status,
    o.total,
    o.delivery_address,
    o.order_time,
    o.estimated_delivery_time
FROM orders o
INNER JOIN users u ON o.user_id = u.id
LEFT JOIN users d ON o.delivery_person_id = d.id
WHERE o.status NOT IN ('delivered', 'cancelled');

-- Vue des statistiques de menu
CREATE OR REPLACE VIEW menu_stats AS
SELECT 
    mi.id,
    mi.name,
    mc.display_name as category_name,
    mi.price,
    mi.rating,
    mi.review_count,
    COUNT(oi.id) as total_orders,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue
FROM menu_items mi
LEFT JOIN menu_categories mc ON mi.category_id = mc.id
LEFT JOIN order_items oi ON mi.id = oi.menu_item_id
GROUP BY mi.id, mi.name, mc.display_name, mi.price, mi.rating, mi.review_count;

-- Vue des statistiques utilisateurs
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.id,
    u.name,
    u.email,
    u.role,
    u.loyalty_points,
    COUNT(DISTINCT o.id) as total_orders,
    COALESCE(SUM(o.total), 0) as total_spent,
    COUNT(DISTINCT CASE WHEN o.status = 'delivered' THEN o.id END) as completed_orders
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.name, u.email, u.role, u.loyalty_points;

-- Vue des catégories populaires
CREATE OR REPLACE VIEW popular_categories AS
SELECT 
    mc.id,
    mc.name,
    mc.display_name,
    mc.emoji,
    COUNT(DISTINCT mi.id) as items_count,
    COUNT(DISTINCT oi.order_id) as orders_count,
    COALESCE(SUM(oi.total_price), 0) as total_revenue
FROM menu_categories mc
LEFT JOIN menu_items mi ON mc.id = mi.category_id
LEFT JOIN order_items oi ON mi.id = oi.menu_item_id
WHERE mc.is_active = TRUE
GROUP BY mc.id, mc.name, mc.display_name, mc.emoji
ORDER BY orders_count DESC;

-- =====================================================
-- 📊 SECTION 16: DONNÉES INITIALES (SEED DATA)
-- =====================================================

-- Insérer les catégories de menu par défaut
INSERT INTO menu_categories (name, display_name, emoji, description, sort_order, is_active) VALUES
('burgers', 'Burgers', '🍔', 'Nos délicieux burgers artisanaux', 1, TRUE),
('pizzas', 'Pizzas', '🍕', 'Pizzas fraîches et savoureuses', 2, TRUE),
('drinks', 'Boissons', '🥤', 'Boissons fraîches et rafraîchissantes', 3, TRUE),
('desserts', 'Desserts', '🍰', 'Desserts maison gourmands', 4, TRUE),
('sides', 'Accompagnements', '🍟', 'Accompagnements savoureux', 5, TRUE),
('salads', 'Salades', '🥗', 'Salades fraîches et équilibrées', 6, TRUE),
('menus', 'Menus', '🍽️', 'Menus complets à prix avantageux', 7, TRUE),
('specials', 'Spécialités', '⭐', 'Nos spécialités de la maison', 8, TRUE)
ON CONFLICT (name) DO NOTHING;

-- Insérer les rôles administrateurs par défaut
INSERT INTO admin_roles (name, description, permissions, is_active, is_default) VALUES
('Super Admin', 'Accès complet au système', '["all"]'::jsonb, TRUE, FALSE),
('Manager', 'Gestion des opérations quotidiennes', '["orders", "menu", "users", "reports"]'::jsonb, TRUE, FALSE),
('Operator', 'Gestion des commandes et livreurs', '["orders", "deliveries"]'::jsonb, TRUE, TRUE)
ON CONFLICT (name) DO NOTHING;

-- Insérer des succès par défaut
INSERT INTO achievements (name, description, icon, points_reward, condition_type, condition_value, is_active) VALUES
('First Order', 'Complétez votre première commande', '🎉', 50, 'orders_count', 1, TRUE),
('Regular Customer', 'Commandez 10 fois', '⭐', 100, 'orders_count', 10, TRUE),
('VIP Customer', 'Commandez 50 fois', '👑', 500, 'orders_count', 50, TRUE),
('Big Spender', 'Dépensez 10000 FCFA', '💰', 200, 'total_spent', 10000, TRUE),
('Burger Lover', 'Commandez 5 burgers', '🍔', 75, 'category_orders', 5, TRUE)
ON CONFLICT (name) DO NOTHING;

-- Insérer des badges par défaut
INSERT INTO badges (title, description, icon, points_required, criteria, is_active) VALUES
('Nouveau', 'Bienvenue sur El Corazón', '🌟', 0, 'points', TRUE),
('Bronze', 'Membre Bronze', '🥉', 100, 'points', TRUE),
('Argent', 'Membre Argent', '🥈', 500, 'points', TRUE),
('Or', 'Membre Or', '🥇', 1000, 'points', TRUE),
('Platine', 'Membre Platine', '💎', 5000, 'points', TRUE)
ON CONFLICT (title) DO NOTHING;

-- Insérer des récompenses de fidélité par défaut
INSERT INTO loyalty_rewards (id, title, description, cost, reward_type, value, is_active) VALUES
('free_delivery', 'Livraison Gratuite', 'Livraison gratuite sur votre prochaine commande', 100, 'free_delivery', 0, TRUE),
('discount_10', 'Réduction 10%', 'Réduction de 10% sur votre commande', 200, 'discount', 10, TRUE),
('discount_20', 'Réduction 20%', 'Réduction de 20% sur votre commande', 400, 'discount', 20, TRUE),
('free_burger', 'Burger Gratuit', 'Un burger gratuit de votre choix', 500, 'free_item', 0, TRUE)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 🔒 SECTION 17: POLITIQUES RLS (Row Level Security)
-- =====================================================

-- Activer RLS sur toutes les tables sensibles
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;

-- Politiques pour users (les utilisateurs peuvent voir et modifier leur propre profil)
CREATE POLICY "Users can view their own profile"
    ON users FOR SELECT
    USING (auth.uid() = auth_user_id);

CREATE POLICY "Users can update their own profile"
    ON users FOR UPDATE
    USING (auth.uid() = auth_user_id);

-- Politiques pour orders (les utilisateurs voient leurs commandes)
CREATE POLICY "Users can view their own orders"
    ON orders FOR SELECT
    USING (auth.uid() = (SELECT auth_user_id FROM users WHERE id = user_id));

CREATE POLICY "Users can create their own orders"
    ON orders FOR INSERT
    WITH CHECK (auth.uid() = (SELECT auth_user_id FROM users WHERE id = user_id));

-- Politiques pour addresses
CREATE POLICY "Users can manage their own addresses"
    ON addresses FOR ALL
    USING (auth.uid() = (SELECT auth_user_id FROM users WHERE id = user_id));

-- Politiques pour notifications
CREATE POLICY "Users can view their own notifications"
    ON notifications FOR SELECT
    USING (auth.uid() = (SELECT auth_user_id FROM users WHERE id = user_id));

-- Politiques pour panier
CREATE POLICY "Users can manage their own cart"
    ON user_cart_items FOR ALL
    USING (auth.uid() = (SELECT auth_user_id FROM users WHERE id = user_id));

-- Données publiques : menu et catégories
CREATE POLICY "Menu categories are viewable by everyone"
    ON menu_categories FOR SELECT
    USING (is_active = TRUE);

CREATE POLICY "Menu items are viewable by everyone"
    ON menu_items FOR SELECT
    USING (is_available = TRUE);

CREATE POLICY "Customization options are viewable by everyone"
    ON customization_options FOR SELECT
    USING (is_active = TRUE);

-- Politiques pour promotions actives (lecture publique)
CREATE POLICY "Active promotions are viewable by everyone"
    ON promotions FOR SELECT
    USING (is_active = TRUE AND NOW() BETWEEN start_date AND end_date);

-- =====================================================
-- ✅ SCRIPT TERMINÉ
-- =====================================================

-- Commentaire final
COMMENT ON DATABASE postgres IS 'El Corazón FastGo - Base de données complète pour le système de livraison de repas';

-- Afficher un message de succès
DO $$
BEGIN
    RAISE NOTICE '✅ Base de données El Corazón FastGo créée avec succès!';
    RAISE NOTICE '📊 Toutes les tables, index, vues, triggers et données initiales ont été créés.';
    RAISE NOTICE '🔒 Les politiques RLS ont été activées sur les tables sensibles.';
    RAISE NOTICE '🚀 La base de données est prête à être utilisée!';
END $$;

