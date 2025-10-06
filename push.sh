#!/bin/bash

# Preguntar mensaje de commit
read -p "Escribe el mensaje del commit: " user_message

# Agregar todos los archivos
git add .

# Crear commit con fecha y hora
commit_message="$(date '+%Y-%m-%d %H:%M:%S') - $user_message"
git commit -m "$commit_message"

# Push al branch main
git push origin main

echo "✅ Commit y push completados: $commit_message"

