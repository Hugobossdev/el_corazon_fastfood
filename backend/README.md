# Backend Proxy Server

Serveur proxy Node.js pour les services externes (Agora, Google Maps, PayDunya).

## Installation

```bash
npm install
```

## Configuration

Créez un fichier `.env` à la racine du dossier `backend` avec les variables suivantes :

```env
# Port du serveur
PORT=3000

# Agora RTC (pour les appels audio/vidéo)
# Obtenez ces valeurs depuis https://console.agora.io/
AGORA_APP_ID=your_agora_app_id_here
AGORA_APP_CERT=your_agora_app_certificate_here

# Google APIs (optionnel - utilisé pour les proxies)
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here

# PayDunya (optionnel - utilisé pour le proxy)
PAYDUNYA_MASTER_KEY=your_paydunya_master_key
PAYDUNYA_PRIVATE_KEY=your_paydunya_private_key
PAYDUNYA_TOKEN=your_paydunya_token
```

### Obtenir les clés Agora

1. Créez un compte sur [Agora Console](https://console.agora.io/)
2. Créez un nouveau projet
3. Copiez l'**App ID** et l'**App Certificate** dans votre fichier `.env`

## Démarrage

```bash
npm start
# ou
npm run dev
```

Le serveur démarre sur `http://localhost:3000` par défaut.

## Endpoints

### Health Check
- `GET /health` - Vérifie que le serveur fonctionne

### Agora RTC Token
- `GET /api/agora/rtc-token?channel=...&uid=...&expire=3600` - Génère un token Agora pour les appels

### Google Maps Proxies
- `GET /api/google/places/autocomplete` - Proxy pour Google Places Autocomplete
- `GET /api/google/places/details` - Proxy pour Google Places Details
- `GET /api/google/geocode` - Proxy pour Google Geocoding
- `GET /api/google/directions` - Proxy pour Google Directions
- `GET /api/google/distance-matrix` - Proxy pour Google Distance Matrix

### PayDunya Proxy
- `ALL /api/paydunya/*` - Proxy pour les requêtes PayDunya

## Notes

- Les variables d'environnement sont chargées automatiquement depuis le fichier `.env`
- En production, configurez les variables d'environnement directement sur votre plateforme d'hébergement
- Le serveur utilise CORS permissif en développement (à restreindre en production)

