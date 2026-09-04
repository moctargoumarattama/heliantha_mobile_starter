# Génération des fichiers Android

Le dossier contient le code Dart/Flutter du projet.

Comme la version des fichiers Android générés dépend de la version Flutter
installée sur ton PC, exécute simplement :

```powershell
cd mobile
flutter create .
flutter pub get
```

Cela génère automatiquement :
- android/
- ios/
- web/
- windows/
- linux/
- macos/

Pour notre V1, on utilise seulement Android.

Puis :

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```
