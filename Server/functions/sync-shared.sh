#!/bin/sh
# Копирует общий код из Server/functions/shared/ в src/shared/ каждой функции.
# Каждая функция выкладывается на сервер отдельной папкой и соседние папки не видит, поэтому нужна копия.
# Запускать после любой правки в shared/: тест sharedCodeIsUpToDate в каждой функции проверяет, что копии свежие.
set -eu
cd "$(dirname "$0")"
for dir in */; do
    dir=${dir%/}
    [ -f "$dir/package.json" ] || continue
    rm -rf "$dir/src/shared"
    mkdir -p "$dir/src/shared"
    cp shared/*.js "$dir/src/shared/"
    echo "обновлено: $dir/src/shared"
done
