-- =====================================================
-- 🇹🇬 SEED DATA: El Corazón FastGo (Togo & Fast Food)
-- =====================================================
-- Ce script peuple la base de données avec :
-- 1. Catégories (dont Plats Togolais)
-- 2. Options de customisation (Sauces, Suppléments...)
-- 3. 45+ Plats (Fast Food, Togo, Boissons, Desserts) avec prix CFA
-- 4. Liaisons Plats-Options
-- =====================================================

DO $$
DECLARE
    -- IDs des Catégories
    cat_togo UUID;
    cat_burgers UUID;
    cat_pizzas UUID;
    cat_drinks UUID;
    cat_desserts UUID;
    cat_sides UUID;
    cat_menus UUID;
    
    -- IDs des Plats (pour les liaisons)
    item_id UUID;
    
    -- IDs des Options
    opt_sauce_piment UUID;
    opt_sauce_verte UUID;
    opt_supplement_oeuf UUID;
    opt_supplement_fromage UUID;
    opt_supplement_viande UUID;
    opt_cuisson_bien_cuit UUID;
    opt_taille_xl UUID;

BEGIN
    -- 1. RÉCUPÉRATION / CRÉATION DES CATÉGORIES
    -- ==========================================
    
    -- Plats Togolais (Nouvelle catégorie)
    INSERT INTO menu_categories (name, display_name, emoji, description, sort_order, is_active)
    VALUES ('togolese', 'Plats Togolais', '🍲', 'Saveurs authentiques du Togo', 0, TRUE)
    ON CONFLICT (name) DO UPDATE SET display_name = EXCLUDED.display_name
    RETURNING id INTO cat_togo;

    -- Récupération des catégories existantes
    SELECT id INTO cat_burgers FROM menu_categories WHERE name = 'burgers';
    SELECT id INTO cat_pizzas FROM menu_categories WHERE name = 'pizzas';
    SELECT id INTO cat_drinks FROM menu_categories WHERE name = 'drinks';
    SELECT id INTO cat_desserts FROM menu_categories WHERE name = 'desserts';
    SELECT id INTO cat_sides FROM menu_categories WHERE name = 'sides';
    SELECT id INTO cat_menus FROM menu_categories WHERE name = 'menus';

    -- Si elles n'existent pas (cas d'une base vide), on les crée
    IF cat_burgers IS NULL THEN 
        INSERT INTO menu_categories (name, display_name, emoji, sort_order) VALUES ('burgers', 'Burgers', '🍔', 1) RETURNING id INTO cat_burgers; 
    END IF;
    IF cat_pizzas IS NULL THEN 
        INSERT INTO menu_categories (name, display_name, emoji, sort_order) VALUES ('pizzas', 'Pizzas', '🍕', 2) RETURNING id INTO cat_pizzas; 
    END IF;
    IF cat_drinks IS NULL THEN 
        INSERT INTO menu_categories (name, display_name, emoji, sort_order) VALUES ('drinks', 'Boissons', '🥤', 3) RETURNING id INTO cat_drinks; 
    END IF;
    IF cat_desserts IS NULL THEN 
        INSERT INTO menu_categories (name, display_name, emoji, sort_order) VALUES ('desserts', 'Desserts', '🍰', 4) RETURNING id INTO cat_desserts; 
    END IF;
    IF cat_sides IS NULL THEN 
        INSERT INTO menu_categories (name, display_name, emoji, sort_order) VALUES ('sides', 'Accompagnements', '🍟', 5) RETURNING id INTO cat_sides; 
    END IF;

    -- 2. CRÉATION DES OPTIONS DE CUSTOMISATION
    -- ========================================

    -- Sauces
    INSERT INTO customization_options (name, category, price_modifier, is_default, max_quantity) VALUES 
    ('Piment Noir (Shito)', 'sauce', 0, FALSE, 1),
    ('Piment Rouge', 'sauce', 0, FALSE, 1),
    ('Sauce Verte', 'sauce', 0, FALSE, 1),
    ('Mayonnaise', 'sauce', 0, TRUE, 1),
    ('Ketchup', 'sauce', 0, TRUE, 1)
    ON CONFLICT DO NOTHING;
    
    SELECT id INTO opt_sauce_piment FROM customization_options WHERE name = 'Piment Noir (Shito)';
    SELECT id INTO opt_sauce_verte FROM customization_options WHERE name = 'Sauce Verte';

    -- Suppléments
    INSERT INTO customization_options (name, category, price_modifier, description) VALUES 
    ('Oeuf Dur', 'extra', 300, 'Un oeuf dur entier'),
    ('Oeuf Frit', 'extra', 300, 'Oeuf au plat'),
    ('Fromage Supplémentaire', 'extra', 500, 'Tranche de cheddar ou emmental'),
    ('Viande Extra', 'extra', 1000, 'Portion supplémentaire de viande'),
    ('Frites Extra', 'extra', 800, 'Portion de frites')
    ON CONFLICT DO NOTHING;

    SELECT id INTO opt_supplement_oeuf FROM customization_options WHERE name = 'Oeuf Dur';
    SELECT id INTO opt_supplement_fromage FROM customization_options WHERE name = 'Fromage Supplémentaire';
    SELECT id INTO opt_supplement_viande FROM customization_options WHERE name = 'Viande Extra';

    -- Tailles et Cuisson
    INSERT INTO customization_options (name, category, price_modifier) VALUES 
    ('Taille XL', 'size', 1500),
    ('Bien Cuit', 'cooking', 0),
    ('À Point', 'cooking', 0)
    ON CONFLICT DO NOTHING;

    SELECT id INTO opt_taille_xl FROM customization_options WHERE name = 'Taille XL';
    SELECT id INTO opt_cuisson_bien_cuit FROM customization_options WHERE name = 'Bien Cuit';


    -- 3. INSERTION DES PLATS (MENU ITEMS)
    -- ===================================

    -- === CATÉGORIE: PLATS TOGOLAIS (15 items) ===
    
    -- 1. Fufu Sauce Arachide
    INSERT INTO menu_items (name, description, price, category_id, image_url, ingredients, preparation_time, is_popular, calories)
    VALUES (
        'Fufu Sauce Arachide', 
        'Pâte d''igname pilée accompagnée d''une onctueuse sauce arachide au poulet.', 
        2500, cat_togo, 
        'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=800&q=80',
        ARRAY['Igname', 'Arachide', 'Poulet', 'Tomate', 'Epices'], 
        30, TRUE, 800
    ) RETURNING id INTO item_id;
    -- Liaison options
    INSERT INTO menu_item_customizations (menu_item_id, customization_option_id) VALUES (item_id, opt_sauce_piment) ON CONFLICT DO NOTHING;
    INSERT INTO menu_item_customizations (menu_item_id, customization_option_id) VALUES (item_id, opt_supplement_viande) ON CONFLICT DO NOTHING;

    -- 2. Ayimolou (Riz et Haricots)
    INSERT INTO menu_items (name, description, price, category_id, image_url, ingredients, preparation_time, is_popular)
    VALUES (
        'Ayimolou Royal', 
        'Le classique togolais : mélange de riz et haricots, servi avec spaghetti, friture de tomate et piment noir.', 
        1500, cat_togo, 
        'https://images.unsplash.com/photo-1626804475297-411dbe6648e5?auto=format&fit=crop&w=800&q=80',
        ARRAY['Riz', 'Haricots', 'Huile', 'Tomate', 'Piment'], 
        15, TRUE
    );

    -- 3. Kom & Yébessé Fionfion
    INSERT INTO menu_items (name, description, price, category_id, image_url, ingredients)
    VALUES (
        'Kom Complet', 
        'Pâte de maïs fermentée (Kenkey) servie avec poisson frit et piment noir écrasé.', 
        2000, cat_togo, 
        'https://images.unsplash.com/photo-1594041680534-e8c8cdebd659?auto=format&fit=crop&w=800&q=80',
        ARRAY['Maïs', 'Poisson', 'Piment', 'Oignon']
    );

    -- 4. Ablo & Poisson
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Ablo Poisson Braisé', 
        'Petites galettes de riz cuites à la vapeur, légèrement sucrées, avec poisson braisé.', 
        2500, cat_togo, 
        'https://images.unsplash.com/photo-1580476262716-6b3693166861?auto=format&fit=crop&w=800&q=80'
    );

    -- 5. Djenkoume (Pâte Rouge)
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Djenkoume Poulet', 
        'Pâte rouge à base de farine de maïs et tomate, servie avec du poulet frit.', 
        2200, cat_togo, 
        'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?auto=format&fit=crop&w=800&q=80'
    );

    -- 6. Gboma Dessi (Sauce Épinard)
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Gboma Dessi', 
        'Sauce aux épinards et viande de boeuf, accompagnée d''Ablo ou Akoumé.', 
        2800, cat_togo, 
        'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
        FALSE
    );

    -- 7. Sauce Adémè
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Sauce Adémè & Akoumé', 
        'Sauce gluante aux feuilles d''Adémè, servie avec pâte de maïs blanche et poisson fumé.', 
        2000, cat_togo, 
        'https://images.unsplash.com/photo-1574484284008-be9d62827669?auto=format&fit=crop&w=800&q=80'
    );

    -- 8. Pinon Rouge
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Pinon au Porc', 
        'Pâte de gari (manioc) mélangée à une sauce tomate et morceaux de porc frits.', 
        2500, cat_togo, 
        'https://images.unsplash.com/photo-1606728035253-49e8a23146de?auto=format&fit=crop&w=800&q=80'
    );

    -- 9. Riz Gras (Jollof)
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular)
    VALUES (
        'Riz Gras (Jollof)', 
        'Riz cuit dans une sauce tomate riche avec légumes et poulet.', 
        2500, cat_togo, 
        'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 10. Koklo Memé (Poulet Braisé)
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Koklo Memé (Poulet Braisé)', 
        'Poulet local mariné aux épices du terroir et braisé au charbon.', 
        4500, cat_togo, 
        'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=800&q=80'
    );

    -- 11. Couscous de Manioc (Attiéké)
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Attiéké Poisson', 
        'Semoule de manioc fermentée avec poisson braisé, alloco et sauce tomate.', 
        3000, cat_togo, 
        'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=800&q=80'
    );

    -- 12. Sauce Graines (Déni)
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Fufu Sauce Graines', 
        'Fufu accompagné d''une sauce riche à base de noix de palme (Déni).', 
        2800, cat_togo, 
        'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=800&q=80'
    );

    -- 13. Akpan (Yaourt Végétal)
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Akpan Glacé', 
        'Dessert fermenté à base de maïs, servi avec lait et glaçons.', 
        500, cat_togo, 
        'https://images.unsplash.com/photo-1571212515416-f6314460064a?auto=format&fit=crop&w=800&q=80'
    );

    -- 14. Ragout d'igname
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Ragout d''Igname', 
        'Morceaux d''igname cuits dans une sauce tomate avec viande de boeuf.', 
        2000, cat_togo, 
        'https://images.unsplash.com/photo-1623961990059-28356e22bc8e?auto=format&fit=crop&w=800&q=80'
    );

    -- 15. Wasawasa
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Wasawasa', 
        'Couscous d''igname noir typique du Nord Togo, servi épicé.', 
        1500, cat_togo, 
        'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?auto=format&fit=crop&w=800&q=80'
    );


    -- === CATÉGORIE: BURGERS (10 items) ===

    -- 16. Classic Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular)
    VALUES (
        'Classic Cheeseburger', 
        'Steak haché pur boeuf, cheddar fondant, salade, tomate, oignon, sauce maison.', 
        2500, cat_burgers, 
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800&q=80',
        TRUE
    ) RETURNING id INTO item_id;
    INSERT INTO menu_item_customizations (menu_item_id, customization_option_id) VALUES (item_id, opt_supplement_fromage) ON CONFLICT DO NOTHING;
    INSERT INTO menu_item_customizations (menu_item_id, customization_option_id) VALUES (item_id, opt_supplement_oeuf) ON CONFLICT DO NOTHING;

    -- 17. Double Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url, calories)
    VALUES (
        'Double Monster Burger', 
        'Deux steaks hachés (300g), double cheddar, bacon, oeuf, sauce barbecue.', 
        4500, cat_burgers, 
        'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?auto=format&fit=crop&w=800&q=80',
        1200
    );

    -- 18. Chicken Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Crispy Chicken Burger', 
        'Filet de poulet pané croustillant, mayonnaise, laitue.', 
        3000, cat_burgers, 
        'https://images.unsplash.com/photo-1615297928064-24977384d0f9?auto=format&fit=crop&w=800&q=80'
    );

    -- 19. Veggie Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Veggie Delight', 
        'Galette de haricots rouges et quinoa, avocat, sauce yaourt.', 
        3000, cat_burgers, 
        'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 20. Bacon BBQ Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Bacon BBQ Burger', 
        'Steak de boeuf, bacon fumé, oignons frits, sauce barbecue.', 
        3500, cat_burgers, 
        'https://images.unsplash.com/photo-1551782450-a2132b4ba21d?auto=format&fit=crop&w=800&q=80'
    );

    -- 21. Fish Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Fish Burger', 
        'Filet de poisson pané, sauce tartare, fromage.', 
        2800, cat_burgers, 
        'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?auto=format&fit=crop&w=800&q=80'
    );

    -- 22. Spicy Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Spicy Volcano Burger', 
        'Boeuf, jalapeños, sauce pimentée, fromage pimenté.', 
        3200, cat_burgers, 
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80'
    );

    -- 23. Mushroom Swiss
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Mushroom Swiss', 
        'Boeuf, champignons sautés, fromage suisse fondant.', 
        3800, cat_burgers, 
        'https://images.unsplash.com/photo-1553979459-d2229ba7433b?auto=format&fit=crop&w=800&q=80'
    );

    -- 24. Slider Trio
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Mini Burgers Trio', 
        'Trois mini burgers : Classique, Poulet, BBQ.', 
        4000, cat_burgers, 
        'https://images.unsplash.com/photo-1513185158878-8d8c2a2a3da3?auto=format&fit=crop&w=800&q=80'
    );

    -- 25. Egg Burger
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Sunrise Egg Burger', 
        'Boeuf, oeuf au plat, bacon, fromage.', 
        3500, cat_burgers, 
        'https://images.unsplash.com/photo-1596662951482-0c4ba74a6df6?auto=format&fit=crop&w=800&q=80'
    );


    -- === CATÉGORIE: PIZZAS (8 items) ===

    -- 26. Margherita
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Pizza Margherita', 
        'Sauce tomate, mozzarella, basilic frais, huile d''olive.', 
        3500, cat_pizzas, 
        'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=800&q=80',
        TRUE
    ) RETURNING id INTO item_id;
    INSERT INTO menu_item_customizations (menu_item_id, customization_option_id) VALUES (item_id, opt_taille_xl) ON CONFLICT DO NOTHING;

    -- 27. Pepperoni
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular)
    VALUES (
        'Pizza Pepperoni', 
        'Sauce tomate, mozzarella, tranches de pepperoni épicé.', 
        4000, cat_pizzas, 
        'https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 28. Reine
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Pizza Reine (Regina)', 
        'Sauce tomate, mozzarella, jambon, champignons.', 
        4200, cat_pizzas, 
        'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80'
    );

    -- 29. 4 Fromages
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Pizza 4 Fromages', 
        'Mozzarella, Gorgonzola, Chèvre, Parmesan.', 
        4500, cat_pizzas, 
        'https://images.unsplash.com/photo-1571407970349-bc487d773fe0?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 30. Hawaïenne
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Pizza Hawaïenne', 
        'Sauce tomate, mozzarella, jambon, ananas.', 
        4000, cat_pizzas, 
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80'
    );

    -- 31. Carnivore
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Pizza Carnivore', 
        'Boeuf haché, poulet, jambon, pepperoni, sauce barbecue.', 
        5000, cat_pizzas, 
        'https://images.unsplash.com/photo-1600028068383-ea11a7a101f3?auto=format&fit=crop&w=800&q=80'
    );

    -- 32. Végétarienne
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Pizza Végétarienne', 
        'Poivrons, oignons, champignons, olives noires, maïs.', 
        3800, cat_pizzas, 
        'https://images.unsplash.com/photo-1566843972142-a7fcb70de55a?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 33. Calzone
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Calzone Soufflée', 
        'Pizza chausson fourrée au jambon, fromage et oeuf.', 
        4000, cat_pizzas, 
        'https://images.unsplash.com/photo-1628151016154-1a3b53f66c04?auto=format&fit=crop&w=800&q=80'
    );


    -- === CATÉGORIE: SIDES / FAST FOOD AUTRES (7 items) ===

    -- 34. Chawarma Poulet
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular)
    VALUES (
        'Chawarma Poulet', 
        'Galette libanaise, poulet mariné, frites, sauce ail, crudités.', 
        1500, cat_sides, 
        'https://images.unsplash.com/photo-1633321769407-af3c48347b09?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 35. Chawarma Mixte
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Chawarma Mixte (Viande & Poulet)', 
        'Le meilleur des deux mondes : boeuf et poulet.', 
        2000, cat_sides, 
        'https://images.unsplash.com/photo-1625938145244-e462645ec727?auto=format&fit=crop&w=800&q=80'
    );

    -- 36. French Fries
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Grande Portion de Frites', 
        'Frites dorées et croustillantes.', 
        1000, cat_sides, 
        'https://images.unsplash.com/photo-1630384060421-cb20d0e0649d?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 37. Chicken Wings
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Ailes de Poulet (6pcs)', 
        'Ailes de poulet épicées ou BBQ.', 
        2500, cat_sides, 
        'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?auto=format&fit=crop&w=800&q=80'
    );

    -- 38. Nuggets
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Nuggets de Poulet (9pcs)', 
        'Bouchées de poulet panées.', 
        2000, cat_sides, 
        'https://images.unsplash.com/photo-1562967960-f55430ed51f8?auto=format&fit=crop&w=800&q=80'
    );

    -- 39. Tacos French
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'French Tacos L', 
        'Tacos gratiné avec sauce fromagère, frites et 2 viandes au choix.', 
        3000, cat_sides, 
        'https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=800&q=80'
    );

    -- 40. Alloco
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Alloco (Banane plantain)', 
        'Bananes plantains frites douces.', 
        1000, cat_sides, 
        'https://images.unsplash.com/photo-1604542031651-549b0bb3b879?auto=format&fit=crop&w=800&q=80',
        TRUE
    );


    -- === CATÉGORIE: BOISSONS & DESSERTS (6 items) ===

    -- 41. Bissap
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Jus de Bissap (50cl)', 
        'Jus de fleurs d''hibiscus, menthe et vanille. Fait maison.', 
        500, cat_drinks, 
        'https://images.unsplash.com/photo-1546171753-97d7676e4602?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 42. Coca Cola
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Coca Cola (33cl)', 
        'Boisson gazeuse rafraîchissante.', 
        500, cat_drinks, 
        'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=800&q=80'
    );

    -- 43. Jus d'Orange
    INSERT INTO menu_items (name, description, price, category_id, image_url)
    VALUES (
        'Jus d''Orange Pressé', 
        '100% naturel, sans sucre ajouté.', 
        1500, cat_drinks, 
        'https://images.unsplash.com/photo-1600271886742-f049cd451bba?auto=format&fit=crop&w=800&q=80'
    );

    -- 44. Crêpe Nutella
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Crêpe Nutella', 
        'Crêpe fine garnie de pâte à tartiner.', 
        1500, cat_desserts, 
        'https://images.unsplash.com/photo-1519676867240-f03562e64548?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

    -- 45. Salade de Fruits
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian, is_vegan)
    VALUES (
        'Salade de Fruits Exotiques', 
        'Mélange de fruits de saison (Ananas, Papaye, Mangue, Pastèque).', 
        1500, cat_desserts, 
        'https://images.unsplash.com/photo-1543362906-ac1b48261626?auto=format&fit=crop&w=800&q=80',
        TRUE, TRUE
    );
    
    -- 46. Gauffre
    INSERT INTO menu_items (name, description, price, category_id, image_url, is_vegetarian)
    VALUES (
        'Gauffre Liégeoise', 
        'Gauffre au sucre perlé, croustillante et moelleuse.', 
        1500, cat_desserts, 
        'https://images.unsplash.com/photo-1562376552-0d160a2f238d?auto=format&fit=crop&w=800&q=80',
        TRUE
    );

END $$;
