-- =====================================================
-- 🍔 SEED DATA: PLATS ET ARTICLES DE MENU
-- =====================================================
-- Ce script insère les catégories PUIS des plats réalistes.

-- 0. ASSURER QUE LES CATÉGORIES EXISTENT
-- On insère les catégories si elles n'existent pas déjà pour éviter l'erreur de category_id NULL
INSERT INTO menu_categories (name, display_name, emoji, description, sort_order, is_active) 
VALUES
('burgers', 'Burgers', '🍔', 'Nos délicieux burgers artisanaux', 1, TRUE),
('pizzas', 'Pizzas', '🍕', 'Pizzas fraîches et savoureuses', 2, TRUE),
('drinks', 'Boissons', '🥤', 'Boissons fraîches et rafraîchissantes', 3, TRUE),
('desserts', 'Desserts', '🍰', 'Desserts maison gourmands', 4, TRUE),
('sides', 'Accompagnements', '🍟', 'Accompagnements savoureux', 5, TRUE),
('salads', 'Salades', '🥗', 'Salades fraîches et équilibrées', 6, TRUE),
('menus', 'Menus', '🍽️', 'Menus complets à prix avantageux', 7, TRUE),
('specials', 'Spécialités', '⭐', 'Nos spécialités de la maison', 8, TRUE)
ON CONFLICT (name) DO NOTHING;

-- 1. BURGERS
INSERT INTO menu_items (category_id, name, description, price, image_url, ingredients, calories, is_popular, is_vegetarian, preparation_time)
VALUES
(
    (SELECT id FROM menu_categories WHERE name = 'burgers' LIMIT 1),
    'Le Classique Signature',
    'Un burger authentique avec steak de bœuf charolais 150g, cheddar affiné, laitue croquante, tomates fraîches et notre sauce secrète maison sur un pain brioché toasté.',
    8500,
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800&q=80',
    ARRAY['Pain brioché', 'Boeuf 150g', 'Cheddar', 'Laitue', 'Tomate', 'Oignons rouges', 'Sauce maison'],
    850,
    TRUE,
    FALSE,
    15
),
(
    (SELECT id FROM menu_categories WHERE name = 'burgers' LIMIT 1),
    'Double Bacon Cheese',
    'Pour les gros appétits : double steak, double cheddar fondant et bacon croustillant fumé au bois de hêtre.',
    10500,
    'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?auto=format&fit=crop&w=800&q=80',
    ARRAY['Double Boeuf', 'Double Cheddar', 'Bacon fumé', 'Sauce BBQ'],
    1100,
    TRUE,
    FALSE,
    20
),
(
    (SELECT id FROM menu_categories WHERE name = 'burgers' LIMIT 1),
    'Le Veggie Gourmet',
    'Galette de légumes maison croustillante, avocat frais, roquette et mayonnaise au citron vert.',
    9000,
    'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=800&q=80',
    ARRAY['Galette végétale', 'Avocat', 'Roquette', 'Tomate', 'Mayo citron vert'],
    650,
    FALSE,
    TRUE,
    15
),
(
    (SELECT id FROM menu_categories WHERE name = 'burgers' LIMIT 1),
    'Chicken Spicy',
    'Filet de poulet pané épicé, coleslaw croquant et sauce pimentée douce.',
    9500,
    'https://images.unsplash.com/photo-1615297348960-cf0b62c046e6?auto=format&fit=crop&w=800&q=80',
    ARRAY['Poulet pané', 'Coleslaw', 'Pickles', 'Sauce Spicy'],
    780,
    TRUE,
    FALSE,
    18
);

-- 2. PIZZAS
INSERT INTO menu_items (category_id, name, description, price, image_url, ingredients, calories, is_popular, is_vegetarian, preparation_time)
VALUES
(
    (SELECT id FROM menu_categories WHERE name = 'pizzas' LIMIT 1),
    'Margherita D.O.P',
    'La reine des pizzas : sauce tomate San Marzano, mozzarella di bufala, basilic frais et huile d''olive extra vierge.',
    7500,
    'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=800&q=80',
    ARRAY['Sauce tomate', 'Mozzarella di Bufala', 'Basilic', 'Huile d''olive'],
    800,
    TRUE,
    TRUE,
    20
),
(
    (SELECT id FROM menu_categories WHERE name = 'pizzas' LIMIT 1),
    'Pepperoni Lovers',
    'Généreusement garnie de tranches de pepperoni croustillantes sur un lit de mozzarella fondante.',
    9500,
    'https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=800&q=80',
    ARRAY['Sauce tomate', 'Mozzarella', 'Pepperoni'],
    1200,
    TRUE,
    FALSE,
    20
),
(
    (SELECT id FROM menu_categories WHERE name = 'pizzas' LIMIT 1),
    '4 Fromages',
    'Un mélange crémeux de Gorgonzola, Mozzarella, Parmesan et Chèvre avec une base crème.',
    10000,
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80',
    ARRAY['Crème fraîche', 'Gorgonzola', 'Mozzarella', 'Parmesan', 'Chèvre', 'Miel'],
    1300,
    FALSE,
    TRUE,
    20
),
(
    (SELECT id FROM menu_categories WHERE name = 'pizzas' LIMIT 1),
    'Truffe & Champignons',
    'Base crème truffée, mélange de champignons forestiers, persillade et copeaux de parmesan.',
    12500,
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80',
    ARRAY['Crème truffée', 'Champignons', 'Persil', 'Ail', 'Parmesan'],
    950,
    FALSE,
    TRUE,
    25
);

-- 3. SALADES
INSERT INTO menu_items (category_id, name, description, price, image_url, ingredients, calories, is_popular, is_vegetarian, preparation_time)
VALUES
(
    (SELECT id FROM menu_categories WHERE name = 'salads' LIMIT 1),
    'César Poulet',
    'Laitue romaine croquante, filet de poulet grillé, copeaux de parmesan, croûtons à l''ail et la véritable sauce César.',
    6500,
    'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?auto=format&fit=crop&w=800&q=80',
    ARRAY['Romaine', 'Poulet grillé', 'Parmesan', 'Croûtons', 'Sauce César', 'Oeuf mollet'],
    450,
    TRUE,
    FALSE,
    10
),
(
    (SELECT id FROM menu_categories WHERE name = 'salads' LIMIT 1),
    'Bowl Saumon Avocat',
    'Base de quinoa, saumon frais mariné, avocat, edamame, concombre et graines de sésame.',
    8500,
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
    ARRAY['Quinoa', 'Saumon', 'Avocat', 'Edamame', 'Concombre', 'Sésame'],
    550,
    FALSE,
    FALSE,
    15
),
(
    (SELECT id FROM menu_categories WHERE name = 'salads' LIMIT 1),
    'Grecque Authentique',
    'Tomates, concombres, oignons rouges, olives kalamata et véritable feta grecque AOP.',
    6000,
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=800&q=80',
    ARRAY['Tomate', 'Concombre', 'Feta', 'Olives', 'Oignon rouge', 'Origan'],
    350,
    FALSE,
    TRUE,
    10
);

-- 4. DESSERTS
INSERT INTO menu_items (category_id, name, description, price, image_url, ingredients, calories, is_popular, is_vegetarian, preparation_time)
VALUES
(
    (SELECT id FROM menu_categories WHERE name = 'desserts' LIMIT 1),
    'Cheesecake New-Yorkais',
    'Onctueux cheesecake à la vanille sur une base de biscuit spéculoos, servi avec un coulis de fruits rouges.',
    4500,
    'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?auto=format&fit=crop&w=800&q=80',
    ARRAY['Cream cheese', 'Biscuit', 'Vanille', 'Fruits rouges'],
    500,
    TRUE,
    TRUE,
    5
),
(
    (SELECT id FROM menu_categories WHERE name = 'desserts' LIMIT 1),
    'Mi-cuit au Chocolat',
    'Gâteau au chocolat noir intense avec un cœur coulant, servi tiède.',
    5000,
    'https://images.unsplash.com/photo-1624353365286-3f8d62daad51?auto=format&fit=crop&w=800&q=80',
    ARRAY['Chocolat noir', 'Beurre', 'Oeufs', 'Farine'],
    650,
    TRUE,
    TRUE,
    15
),
(
    (SELECT id FROM menu_categories WHERE name = 'desserts' LIMIT 1),
    'Tiramisu Classique',
    'Recette traditionnelle italienne au mascarpone et café espresso.',
    4000,
    'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=800&q=80',
    ARRAY['Mascarpone', 'Café', 'Boudoirs', 'Cacao', 'Amaretto'],
    450,
    FALSE,
    TRUE,
    5
);

-- 5. BOISSONS (Drinks)
INSERT INTO menu_items (category_id, name, description, price, image_url, ingredients, calories, is_popular, is_vegetarian, preparation_time)
VALUES
(
    (SELECT id FROM menu_categories WHERE name = 'drinks' LIMIT 1),
    'Jus d''Orange Pressé',
    'Oranges fraîches pressées à la commande, sans sucre ajouté.',
    3000,
    'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?auto=format&fit=crop&w=800&q=80',
    ARRAY['Orange 100%'],
    120,
    TRUE,
    TRUE,
    5
),
(
    (SELECT id FROM menu_categories WHERE name = 'drinks' LIMIT 1),
    'Smoothie Tropical',
    'Mélange onctueux de mangue, ananas et fruit de la passion.',
    4000,
    'https://images.unsplash.com/photo-1505252585461-04db1eb84625?auto=format&fit=crop&w=800&q=80',
    ARRAY['Mangue', 'Ananas', 'Passion', 'Lait de coco'],
    250,
    FALSE,
    TRUE,
    5
),
(
    (SELECT id FROM menu_categories WHERE name = 'drinks' LIMIT 1),
    'Coca-Cola Zéro',
    'Canette 33cl, servi bien frais.',
    1500,
    'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=800&q=80',
    ARRAY['Soda'],
    0,
    TRUE,
    TRUE,
    2
);

-- 6. SIDES (Accompagnements)
INSERT INTO menu_items (category_id, name, description, price, image_url, ingredients, calories, is_popular, is_vegetarian, preparation_time)
VALUES
(
    (SELECT id FROM menu_categories WHERE name = 'sides' LIMIT 1),
    'Frites Maison',
    'Pommes de terre fraîches coupées à la main, double cuisson.',
    2500,
    'https://images.unsplash.com/photo-1630384060421-cb20d0e0649d?auto=format&fit=crop&w=800&q=80',
    ARRAY['Pommes de terre', 'Sel'],
    350,
    TRUE,
    TRUE,
    10
),
(
    (SELECT id FROM menu_categories WHERE name = 'sides' LIMIT 1),
    'Onion Rings',
    'Beignets d''oignons dorés et croustillants, servis avec sauce barbecue.',
    3000,
    'https://images.unsplash.com/photo-1639024471283-03518883512d?auto=format&fit=crop&w=800&q=80',
    ARRAY['Oignons', 'Panure', 'Sauce BBQ'],
    400,
    FALSE,
    TRUE,
    10
);
