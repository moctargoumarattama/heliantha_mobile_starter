# Périmètre décidé

## Plateforme
- Android d'abord
- Flutter

## Backend
- FastAPI / Python
- Pas de grosse base de données applicative
- PrestaShop reste la source de vérité
- FastAPI agit comme API intermédiaire sécurisée

## Données
PrestaShop conserve :
- produits
- catégories
- images
- prix
- promotions
- stocks
- clients
- adresses
- paniers / commandes
- états de commandes

## Accès sans compte
Le visiteur peut :
- ouvrir l'application
- voir l'accueil
- parcourir les catégories
- rechercher
- consulter une fiche produit
- ajouter au panier

## Compte client
Facultatif pour consulter la boutique.
Même compte que le site PrestaShop.

Le compte permet notamment :
- profil
- adresses
- historique
- suivi des commandes

## Fonctions V1 ciblées
- catalogue
- recherche
- panier
- favoris
- alertes
- compte client
- historique des commandes
- suivi des commandes

## Paiement
Pas de paiement bancaire intégré.
Règlement prévu hors de l'application :
- espèces
- versement / numéro de compte

## Commandes
Une commande mobile doit apparaître dans le même back-office PrestaShop que les commandes web.
