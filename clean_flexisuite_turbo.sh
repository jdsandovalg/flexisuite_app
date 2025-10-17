#!/bin/bash
# -----------------------------------------------------------
# Script de limpieza turbo para Flutter + iOS (Xcode)
# Ejecutar desde la carpeta raíz de flexisuite_app
# -----------------------------------------------------------

echo "🚀 Iniciando limpieza TURBO de Flutter y Xcode..."

# 1. Limpiar build de Flutter
echo "🧹 Limpiando build de Flutter..."
flutter clean

# 2. Limpiar cache de paquetes Dart/Flutter del proyecto
echo "🧹 Limpiando paquetes del proyecto..."
flutter pub cache repair

# 3. Limpiar cache global de Flutter
echo "🧹 Limpiando cache global de Flutter (~/.pub-cache)..."
rm -rf ~/.pub-cache/*

# 4. Limpiar versiones antiguas de Flutter (si existen varias)
echo "🧹 Eliminando versiones antiguas de Flutter (si aplica)..."
FLUTTER_ROOT=$(flutter --version | head -1 | awk '{print $4}')
if [ -d "$FLUTTER_ROOT" ]; then
    echo "   ✨ Flutter actual en uso: $FLUTTER_ROOT"
else
    echo "   ⚠️ No se detectó Flutter en ruta estándar"
fi
# Nota: no borra la versión actual para evitar romper Flutter

# 5. Limpiar Pods de iOS y reinstalar
echo "🧹 Limpiando Pods de iOS..."
cd ios || { echo "Error: no se encontró carpeta ios"; exit 1; }
rm -rf Pods Podfile.lock
pod install
cd ..

# 6. Limpiar derivados de Xcode (build temporales)
echo "🧹 Limpiando DerivedData de Xcode..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 7. Limpiar simuladores no disponibles
echo "🧹 Eliminando simuladores no disponibles..."
xcrun simctl delete unavailable

# 8. Limpiar logs y caches temporales de Xcode
echo "🧹 Limpiando caches y logs temporales de Xcode..."
rm -rf ~/Library/Developer/Xcode/Archives/*
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
rm -rf ~/Library/Developer/Xcode/Products/*

echo "✅ Limpieza TURBO completada. Mac lista para compilar Flutter + iOS limpio."

