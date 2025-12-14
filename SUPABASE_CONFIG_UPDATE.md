# 🔧 Configuration Supabase - Instructions de Mise à Jour

## ✅ Configurations Mises à Jour Automatiquement

### 1. **Admin App** (`admin/lib/supabase/supabase_config.dart`)
✅ **URL mise à jour** : `https://vsdmcqldshttrbilcvle.supabase.co`  
✅ **Anon Key mise à jour** : Clé correcte déjà en place

### 2. **Elcora Dely App** (`elcora_dely/lib/config/api_config.dart`)
✅ **URL mise à jour** : `https://vsdmcqldshttrbilcvle.supabase.co`  
✅ **Anon Key mise à jour** : Nouvelle clé correcte

---

## 📝 Configuration Manuelle Requise

### 3. **Elcora Fast App** - Créer le fichier `.env`

L'app `elcora_fast` utilise un fichier `.env` pour les configurations (plus sécurisé).

**Étapes :**

1. **Créez le fichier** `elcora_fast/.env` (à la racine du projet elcora_fast)

2. **Copiez-collez le contenu suivant** :

```env
# ================================================
# Configuration Supabase (PRODUCTION)
# ================================================
SUPABASE_URL=https://vsdmcqldshttrbilcvle.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZG1jcWxkc2h0dHJiaWxjdmxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyMTY5MDcsImV4cCI6MjA4MDc5MjkwN30.LW28V62UX0q7omv0zmD_G5DKqiWDoWXfBCM4eQrvXZA

# ================================================
# Configuration PayDunya (Mode Test)
# ================================================
PAYDUNYA_MASTER_KEY=your-paydunya-master-key
PAYDUNYA_PRIVATE_KEY=your-paydunya-private-key
PAYDUNYA_TOKEN=your-paydunya-token
PAYDUNYA_IS_SANDBOX=true

# ================================================
# Configuration PayDunya (Mode Production)
# ================================================
PAYDUNYA_PRODUCTION_MASTER_KEY=your-production-master-key
PAYDUNYA_PRODUCTION_PRIVATE_KEY=your-production-private-key
PAYDUNYA_PRODUCTION_TOKEN=your-production-token

# ================================================
# Configuration Google Maps
# ================================================
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# ================================================
# Configuration Firebase
# ================================================
FIREBASE_API_KEY=your-api-key
FIREBASE_AUTH_DOMAIN=your-project-id.firebaseapp.com
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
FIREBASE_MESSAGING_SENDER_ID=your-sender-id
FIREBASE_APP_ID=your-app-id

# ================================================
# Configuration Agora RTC
# ================================================
AGORA_APP_ID=your-agora-app-id

# ================================================
# Configuration Backend
# ================================================
BACKEND_URL=http://localhost:3000
ENVIRONMENT=development
```

3. **Sauvegardez le fichier**

---

## 🔐 Vos Identifiants Supabase

### Projet Supabase
- **ID Projet** : `vsdmcqldshttrbilcvle`
- **URL** : `https://vsdmcqldshttrbilcvle.supabase.co`
- **Anon Key** : `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZG1jcWxkc2h0dHJiaWxjdmxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyMTY5MDcsImV4cCI6MjA4MDc5MjkwN30.LW28V62UX0q7omv0zmD_G5DKqiWDoWXfBCM4eQrvXZA`

**Important** : 
- ✅ La clé **anon** est publique et peut être partagée (elle est déjà dans votre code frontend)
- 🔒 Ne partagez **JAMAIS** votre clé **service_role** (clé admin)

---

## ✅ Vérification

Après avoir créé le fichier `.env`, vérifiez que tout fonctionne :

### Pour `elcora_fast` :

1. **Installez les dépendances**
   ```bash
   cd elcora_fast
   flutter pub get
   ```

2. **Lancez l'application**
   ```bash
   flutter run
   ```

3. **Vérifiez les logs** - Vous devriez voir :
   ```
   ✅ Supabase initialized successfully
   ```

### Pour `admin` et `elcora_dely` :

Aucune action supplémentaire requise, les configurations ont déjà été mises à jour automatiquement.

---

## 📊 Configuration de la Base de Données

N'oubliez pas d'exécuter le script SQL pour créer toutes les tables :

1. **Allez sur** : [Supabase Dashboard](https://supabase.com/dashboard/project/vsdmcqldshttrbilcvle/sql)
2. **Ouvrez le SQL Editor**
3. **Exécutez** le contenu de `database_setup_complete.sql`

---

## 🔧 Autres Configurations à Compléter

### PayDunya (Paiements Mobile Money)
Obtenez vos clés sur : https://app.paydunya.com/developers

### Google Maps API
Obtenez votre clé sur : https://console.cloud.google.com/apis/credentials

### Firebase (Notifications Push)
Obtenez vos identifiants sur : https://console.firebase.google.com

### Agora (Appels vidéo - optionnel)
Obtenez votre App ID sur : https://console.agora.io

---

## 🆘 Problèmes Courants

### Erreur: "Supabase not initialized"
**Solution** : Vérifiez que le fichier `.env` existe et contient les bonnes valeurs

### Erreur: "Invalid API key"
**Solution** : Vérifiez que l'anon key est correcte (sans espaces supplémentaires)

### Erreur: "Network error"
**Solution** : Vérifiez votre connexion internet et que l'URL Supabase est correcte

---

## 📞 Support

Si vous rencontrez des problèmes :
1. Vérifiez le fichier `SCHEMA_BDD_COMPLET.md` pour la structure de la base de données
2. Consultez le fichier `DATABASE_SETUP_INSTRUCTIONS.md` pour l'installation de la base de données
3. Vérifiez vos logs de console Flutter pour des erreurs spécifiques

---

**Dernière mise à jour** : Décembre 2024









