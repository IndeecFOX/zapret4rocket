#!/bin/bash

BRANCH="GV-Fix"
RAW_URL="https://raw.githubusercontent.com/AloofLibra/zapret4rocket/${BRANCH}"
API_URL="https://api.github.com/repos/AloofLibra/zapret4rocket/contents/lib?ref=${BRANCH}"
INSTALL_DIR="/opt"
BIN_PATH="/usr/bin/z4r"
INSTALLER_URL="${RAW_URL}/install_z4r.sh"

# Включить для отладки
DEBUG=0
debug_log() {
    if [ "$DEBUG" = "1" ]; then
        echo "[DEBUG] $1"
    fi
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "Ошибка: Скрипт должен быть запущен с правами root (используйте sudo)"
    exit 1
fi

# Проверка wget или curl
if command -v wget &> /dev/null; then
    DOWNLOADER="wget"
    DL_CMD="wget -q -O"
    debug_log "Используется wget"
elif command -v curl &> /dev/null; then
    DOWNLOADER="curl"
    DL_CMD="curl -sS -L -o"
    debug_log "Используется curl"
else
    echo "Ошибка: wget или curl не найдены"
    exit 1
fi

# Определение откуда запущен скрипт
SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
debug_log "Путь скрипта: $SCRIPT_PATH"

# Если скрипт запущен из /usr/bin/z4r - проверяем обновления для себя
if [ "$SCRIPT_PATH" = "$BIN_PATH" ]; then
    debug_log "Запуск из установленной команды z4r"
    echo "Проверка обновлений установщика..."

    TEMP_INSTALLER=$(mktemp)
    if $DL_CMD "$TEMP_INSTALLER" "$INSTALLER_URL" 2>/dev/null; then
        # Сравниваем с текущей версией
        if ! cmp -s "$SCRIPT_PATH" "$TEMP_INSTALLER" 2>/dev/null; then
            echo "✓ Найдено обновление установщика"
            cp "$TEMP_INSTALLER" "$BIN_PATH"
            chmod +x "$BIN_PATH"
            rm -f "$TEMP_INSTALLER"
            echo "✓ Установщик обновлен, перезапуск..."
            echo ""
            exec "$BIN_PATH" "$@"
        else
            debug_log "Установщик актуален"
        fi
        rm -f "$TEMP_INSTALLER"
    else
        debug_log "Не удалось проверить обновления установщика"
    fi
else
    # Первый запуск - устанавливаем себя в /usr/bin/z4r
    debug_log "Первый запуск, выполняется установка"
    if [ -f "$SCRIPT_PATH" ]; then
        echo "Установка команды z4r в систему..."
        cp "$SCRIPT_PATH" "$BIN_PATH"
        chmod +x "$BIN_PATH"
        echo "✓ Команда z4r установлена"
        echo ""
    fi
fi

echo "=== Обновление zapret4rocket ==="

# Создание директорий
mkdir -p "${INSTALL_DIR}/lib"
debug_log "Создана директория ${INSTALL_DIR}/lib"

# Скачивание основного скрипта
echo "Загрузка z4r.sh..."
debug_log "URL: ${RAW_URL}/z4r.sh"
if $DL_CMD "${INSTALL_DIR}/z4r.sh" "${RAW_URL}/z4r.sh"; then
    chmod +x "${INSTALL_DIR}/z4r.sh"
    echo "✓ z4r.sh загружен"
else
    echo "⚠ Не удалось загрузить z4r.sh"
    if [ ! -f "${INSTALL_DIR}/z4r.sh" ]; then
        echo "Ошибка: z4r.sh отсутствует"
        exit 1
    fi
    echo "Использую существующую версию"
fi

# Получение списка файлов из lib
echo "Загрузка списка библиотек..."
debug_log "API URL: $API_URL"

TEMP_JSON=$(mktemp)
debug_log "Временный файл: $TEMP_JSON"

if [ "$DOWNLOADER" = "wget" ]; then
    wget -q -O "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
else
    curl -sS -L -o "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
fi

debug_log "Содержимое JSON (первые 500 символов):"
if [ "$DEBUG" = "1" ]; then
    head -c 500 "$TEMP_JSON"
    echo ""
fi

# Улучшенный парсинг JSON
LIB_FILES=()
while IFS= read -r line; do
    if echo "$line" | grep -q '"name"'; then
        filename=$(echo "$line" | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        if echo "$filename" | grep -q '\.sh$'; then
            LIB_FILES+=("$filename")
            debug_log "Найден файл: $filename"
        fi
    fi
done < "$TEMP_JSON"

rm -f "$TEMP_JSON"

# Фолбэк на стандартный набор
if [ ${#LIB_FILES[@]} -eq 0 ]; then
    echo "⚠ Список файлов пуст, использую стандартный набор"
    LIB_FILES=("actions.sh" "netcheck.sh" "provider.sh" "recommendations.sh" "strategies.sh" "submenus.sh" "telemetry.sh" "ui.sh")
fi

echo "Найдено библиотек для загрузки: ${#LIB_FILES[@]}"
if [ "$DEBUG" = "1" ]; then
    echo "Список файлов:"
    for f in "${LIB_FILES[@]}"; do
        echo "  - $f"
    done
fi

# Скачивание библиотек
echo "Загрузка библиотек..."
LIB_UPDATED=0
for file in "${LIB_FILES[@]}"; do
    debug_log "Загрузка: ${RAW_URL}/lib/${file}"
    if $DL_CMD "${INSTALL_DIR}/lib/${file}" "${RAW_URL}/lib/${file}" 2>/dev/null; then
        chmod +x "${INSTALL_DIR}/lib/${file}"
        LIB_UPDATED=$((LIB_UPDATED + 1))
        debug_log "✓ $file загружен"
    else
        debug_log "✗ $file не загружен"
    fi
done

echo "✓ Загружено библиотек: ${LIB_UPDATED}/${#LIB_FILES[@]}"
echo ""

# Запуск z4r.sh
debug_log "Запуск: /bin/bash ${INSTALL_DIR}/z4r.sh"
cd "${INSTALL_DIR}"
exec /bin/bash ./z4r.sh "$@"
