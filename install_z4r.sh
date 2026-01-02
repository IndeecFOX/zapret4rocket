#!/bin/sh

BRANCH="GV-Fix"
RAW_URL="https://raw.githubusercontent.com/AloofLibra/zapret4rocket/${BRANCH}"
API_URL="https://api.github.com/repos/AloofLibra/zapret4rocket/contents/lib?ref=${BRANCH}"
INSTALL_DIR="/opt"
INSTALLER_URL="${RAW_URL}/install_z4r.sh"

# Определение пути для команды z4r
if [ -d /opt/bin ]; then
    BIN_PATH="/opt/bin/z4r"
elif [ -d /jffs/scripts ]; then
    BIN_PATH="/jffs/scripts/z4r"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    BIN_PATH="/usr/local/bin/z4r"
elif [ -d /usr/bin ] && [ -w /usr/bin ]; then
    BIN_PATH="/usr/bin/z4r"
else
    echo "Ошибка: не найдено подходящее место для установки"
    exit 1
fi

# Проверка прав root для стандартных систем
if [ "$(id -u)" != "0" ] && [ ! -d /opt/bin ] && [ ! -d /jffs/scripts ]; then 
    echo "Ошибка: Скрипт должен быть запущен с правами root (используйте sudo)"
    exit 1
fi

# Проверка wget или curl
if command -v curl >/dev/null 2>&1; then
    DL_CMD="curl -sS -L -o"
elif command -v wget >/dev/null 2>&1; then
    DL_CMD="wget -q -O"
else
    echo "Ошибка: wget или curl не найдены"
    exit 1
fi

# Определение откуда запущен скрипт
if command -v readlink >/dev/null 2>&1; then
    SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || echo "$0")
elif command -v realpath >/dev/null 2>&1; then
    SCRIPT_PATH=$(realpath "$0" 2>/dev/null || echo "$0")
else
    SCRIPT_PATH="$0"
fi

# Если запущен из установленной команды - проверяем обновления
if [ "$SCRIPT_PATH" = "$BIN_PATH" ]; then
    echo "Проверка обновлений установщика..."
    TEMP_INSTALLER="/tmp/z4r_inst_$$"

    if $DL_CMD "$TEMP_INSTALLER" "$INSTALLER_URL" 2>/dev/null; then
        if ! cmp "$SCRIPT_PATH" "$TEMP_INSTALLER" >/dev/null 2>&1; then
            echo "✓ Найдено обновление установщика"
            cp "$TEMP_INSTALLER" "$BIN_PATH"
            chmod +x "$BIN_PATH"
            rm -f "$TEMP_INSTALLER"
            echo "✓ Установщик обновлен, перезапуск..."
            echo ""
            exec "$BIN_PATH" "$@"
        fi
        rm -f "$TEMP_INSTALLER"
    fi
else
    # Первый запуск - установка
    echo "Установка команды z4r в $BIN_PATH..."
    mkdir -p "$(dirname "$BIN_PATH")"

    # Копируем файл или скачиваем
    if [ -f "$SCRIPT_PATH" ]; then
        cp "$SCRIPT_PATH" "$BIN_PATH"
    else
        $DL_CMD "$BIN_PATH" "$INSTALLER_URL" 2>/dev/null || {
            echo "⚠ Не удалось установить команду z4r"
        }
    fi

    [ -f "$BIN_PATH" ] && chmod +x "$BIN_PATH" && echo "✓ Команда z4r установлена"
    echo ""
fi

echo "=== Обновление zapret4rocket ==="

# Создание директорий и загрузка основного скрипта
mkdir -p "${INSTALL_DIR}/lib"
echo "Загрузка z4r.sh..."

if $DL_CMD "${INSTALL_DIR}/z4r.sh" "${RAW_URL}/z4r.sh" 2>/dev/null; then
    chmod +x "${INSTALL_DIR}/z4r.sh"
    echo "✓ z4r.sh загружен"
elif [ ! -f "${INSTALL_DIR}/z4r.sh" ]; then
    echo "Ошибка: z4r.sh отсутствует"
    exit 1
else
    echo "⚠ Не удалось загрузить z4r.sh, использую существующую версию"
fi

# Получение списка библиотек
echo "Загрузка списка библиотек..."
TEMP_JSON="/tmp/z4r_json_$$"

if command -v curl >/dev/null 2>&1; then
    curl -sS -L --max-time 3 -o "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
else
    wget -q -T 3 -O "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
fi

# Парсинг JSON
LIB_FILES=$(grep '"name":' "$TEMP_JSON" 2>/dev/null | grep '\.sh"' | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | tr '\n' ' ')
rm -f "$TEMP_JSON"

# Fallback на стандартный набор
if [ -z "$LIB_FILES" ] || [ "$LIB_FILES" = " " ]; then
    LIB_FILES="actions.sh netcheck.sh provider.sh recommendations.sh strategies.sh submenus.sh telemetry.sh ui.sh"
fi

# Параллельная загрузка библиотек
echo "Загрузка библиотек..."
for file in $LIB_FILES; do
    {
        if $DL_CMD "${INSTALL_DIR}/lib/${file}" "${RAW_URL}/lib/${file}" 2>/dev/null; then
            chmod +x "${INSTALL_DIR}/lib/${file}"
        fi
    } &
done
wait

# Подсчет загруженных файлов
LIB_UPDATED=$(ls -1 "${INSTALL_DIR}/lib"/*.sh 2>/dev/null | wc -l)
echo "✓ Загружено библиотек: $LIB_UPDATED"
echo ""

# Запуск z4r.sh
echo "=== Запуск z4r.sh ==="
cd "${INSTALL_DIR}" || exit 1

# Определяем shell
if command -v bash >/dev/null 2>&1; then
    SHELL_CMD="bash"
elif command -v ash >/dev/null 2>&1; then
    SHELL_CMD="ash"
else
    SHELL_CMD="sh"
fi

# Перенаправляем stdin на терминал если запущено через pipe
if [ -t 0 ]; then
    exec $SHELL_CMD ./z4r.sh "$@"
else
    exec $SHELL_CMD ./z4r.sh "$@" < /dev/tty
fi
