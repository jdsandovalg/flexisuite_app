#!/bin/bash
# -----------------------------------------------------------
# Script de limpieza completa para Flutter + iOS (Xcode)
# Ejecutar desde la carpeta raíz de flexisuite_app
# -----------------------------------------------------------

echo "🚀 Iniciando limpieza de Flutter y Xcode..."

# 1. Limpiar build de Flutter
echo "🧹 Limpiando build de Flutter..."
flutter clean

# 2. Limpiar cache de paquetes Dart/Flutter
echo "🧹 Reparando cache de paquetes Flutter..."
flutter pub cache repair

# 3. Limpiar Pods de iOS y reinstalar
echo "🧹 Limpiando Pods de iOS..."
cd ios || { echo "Error: no se encontró carpeta ios"; exit 1; }
rm -rf Pods Podfile.lock
pod install
cd ..

# 4. Limpiar derivados de Xcode (build temporales)
echo "🧹 Limpiando DerivedData de Xcode..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 5. Limpiar simuladores no disponibles
echo "🧹 Eliminando simuladores no disponibles..."
xcrun simctl delete unavailable

echo "✅ Limpieza completa ejecutada correctamente."

