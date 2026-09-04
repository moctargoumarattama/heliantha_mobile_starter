# Exemple de pont privé PrestaShop

Ce dossier montre la direction pour les opérations qui doivent être validées
par PrestaShop lui-même, notamment le login client.

Ce n'est pas à déposer aveuglément en production : le nom des routes,
la version PrestaShop et les modules installés doivent être vérifiés.

Le principe :

```text
Flutter
  ↓
FastAPI
  ↓ secret serveur
/module/helianthamobilebridge/auth
  ↓
PrestaShop valide le compte
```

Pour le checkout :

```text
/module/helianthamobilebridge/checkout?action=preview
/module/helianthamobilebridge/checkout?action=confirm
```

Le secret `X-Heliantha-Bridge-Secret` doit être identique à
`MOBILE_BRIDGE_SECRET` dans FastAPI.

## Pourquoi ce pont ?

La clé Webservice ne doit jamais être mise dans l'APK.
Le Webservice historique n'est pas un système de login client mobile complet.

## Installation de test

Créer :

```text
modules/helianthamobilebridge/
```

et y copier les fichiers du dossier `helianthamobilebridge`.

Ensuite installer le module depuis le back-office.

Avant toute utilisation en production :
- remplacer le secret d'exemple ;
- placer le secret dans la configuration serveur ;
- vérifier la compatibilité avec la version PrestaShop ;
- ajouter du rate limiting côté FastAPI/reverse proxy ;
- activer HTTPS uniquement.

Le checkout passe par le contrôleur `checkout` afin que PrestaShop calcule
le panier, la livraison, les moyens de paiement, les taxes, les remises et
le total TTC. FastAPI garde `CHECKOUT_WRITE_ENABLED=false` tant que le test
réel de commande n'est pas explicitement validé.
