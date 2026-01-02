#!/bin/bash

BRANCH="GV-Fix"
RAW_URL="https://raw.githubusercontent.com/AloofLibra/zapret4rocket/${BRANCH}"
API_URL="https://api.github.com/repos/AloofLibra/zapret4rocket/contents/lib?ref=${BRANCH}"
INSTALL_DIR="/opt"
BIN_PATH="/usr/bin/z4r"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "Ошибка: Скрипт должен быть запущен с правами root (используйте sudo)"
    exit 1
fi

# Самоустановка в /usr/bin/z4r
SCRIPT_PATH="$(readlink -f "$0")"
if [ "$SCRIPT_PATH" != "$BIN_PATH" ]; then
    if [ ! -f "$BIN_PATH" ] || ! cmp -s "$SCRIPT_PATH" "$BIN_PATH"; then
        echo "Установка команды z4r в систему..."
        cp "$SCRIPT_PATH" "$BIN_PATH"
        chmod +x "$BIN_PATH"
        echo "✓ Команда z4r установлена. Теперь можно использовать: sudo z4r"
        echo ""
    fi
fi

echo "=== Обновление zapret4rocket ==="

# Проверка wget или curl
if command -v wget &> /dev/null; then
    DOWNLOADER="wget"
    DL_CMD="wget -q -O"
elif command -v curl &> /dev/null; then
    DOWNLOADER="curl"
    DL_CMD="curl -sS -L -o"
else
    echo "Ошибка: wget или curl не найдены"
    exit 1
fi

# Создание директорий
mkdir -p "${INSTALL_DIR}/lib"

# Скачивание основного скрипта
echo "Загрузка z4r.sh..."
if $DL_CMD "${INSTALL_DIR}/z4r.sh" "${RAW_URL}/z4r.sh"; then
    chmod +x "${INSTALL_DIR}/z4r.sh"
    echo "✓ z4r.sh загружен"
else
    echo "⚠ Не удалось загрузить z4r.sh"
    if [ ! -f "${INSTALL_DIR}/z4r.sh" ]; then
        echo "Ошибка: z4r.sh отсутствует, невозможно продолжить"
        exit 1
    fi
    echo "Использую существующую версию"
fi

# Получение списка файлов из lib
echo "Загрузка библиотек..."
TEMP_JSON=$(mktemp)

if [ "$DOWNLOADER" = "wget" ]; then
    wget -q -O "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
else
    curl -sS -L -o "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
fi

# Парсинг JSON
LIB_FILES=($(grep -o '"name":"[^"]*"' "$TEMP_JSON" 2>/dev/null | cut -d'"' -f4 | grep '\.sh$'))

rm -f "$TEMP_JSON"

if [ ${#LIB_FILES[@]} -eq 0 ]; then
    echo "⚠ Не удалось получить список через API, использую стандартный набор"
    LIB_FILES=("actions.sh" "netcheck.sh" "provider.sh" "recommendations.sh" "strategies.sh" "submenus.sh" "telemetry.sh" "ui.sh")
fi

# Скачивание библиотек
LIB_UPDATED=0
for file in "${LIB_FILES[@]}"; do
    if $DL_CMD "${INSTALL_DIR}/lib/${file}" "${RAW_URL}/lib/${file}" 2>/dev/null; then
        chmod +x "${INSTALL_DIR}/lib/${file}"
        LIB_UPDATED=$((LIB_UPDATED + 1))
    fi
done

echo "✓ Загружено библиотек: ${LIB_UPDATED}/${#LIB_FILES[@]}"
echo ""

# Запуск z4r.sh
cd "${INSTALL_DIR}"
exec /bin/bash ./z4r.sh "$@"
