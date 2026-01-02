#!/bin/sh
# Используем /bin/sh вместо /bin/bash для максимальной совместимости

BRANCH="GV-Fix"
RAW_URL="https://raw.githubusercontent.com/AloofLibra/zapret4rocket/${BRANCH}"
API_URL="https://api.github.com/repos/AloofLibra/zapret4rocket/contents/lib?ref=${BRANCH}"
INSTALL_DIR="/opt"
INSTALLER_URL="${RAW_URL}/install_z4r.sh"

# Определение правильного пути для команды z4r
# Приоритет путей для различных систем
if [ -d /opt/bin ]; then
    # Keenetic/Entware, OpenWRT с Entware
    BIN_PATH="/opt/bin/z4r"
    IS_EMBEDDED=1
elif [ -d /jffs/scripts ]; then
    # Asus Merlin, DD-WRT
    BIN_PATH="/jffs/scripts/z4r"
    IS_EMBEDDED=1
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    # Стандартные Linux системы, предпочтительно /usr/local/bin
    BIN_PATH="/usr/local/bin/z4r"
    IS_EMBEDDED=0
elif [ -d /usr/bin ] && [ -w /usr/bin ]; then
    # Fallback на /usr/bin
    BIN_PATH="/usr/bin/z4r"
    IS_EMBEDDED=0
else
    echo "Ошибка: не найдено подходящее место для установки"
    exit 1
fi

# Включить для отладки
DEBUG=0

debug_log() {
    if [ "$DEBUG" = "1" ]; then
        echo "[DEBUG] $1"
    fi
}

# Проверка прав root (где это применимо)
if [ "$(id -u)" != "0" ] && [ "$IS_EMBEDDED" = "0" ]; then 
    echo "Ошибка: Скрипт должен быть запущен с правами root (используйте sudo)"
    exit 1
fi

debug_log "Целевой путь установки: $BIN_PATH"
debug_log "Embedded режим: $IS_EMBEDDED"

# Проверка wget или curl
if command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
    DL_CMD="wget -q -O"
    debug_log "Используется wget"
elif command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
    DL_CMD="curl -sS -L -o"
    debug_log "Используется curl"
else
    echo "Ошибка: wget или curl не найдены"
    exit 1
fi

# Определение откуда запущен скрипт (совместимо с busybox)
get_script_path() {
    if [ -n "$BASH_SOURCE" ]; then
        echo "$BASH_SOURCE"
    elif command -v readlink >/dev/null 2>&1; then
        readlink -f "$0" 2>/dev/null || echo "$0"
    elif command -v realpath >/dev/null 2>&1; then
        realpath "$0" 2>/dev/null || echo "$0"
    else
        # Fallback для систем без readlink/realpath
        echo "$0"
    fi
}

SCRIPT_PATH="$(get_script_path)"
debug_log "Путь скрипта: $SCRIPT_PATH"

# Если скрипт запущен из установленной команды z4r - проверяем обновления
if [ "$SCRIPT_PATH" = "$BIN_PATH" ] || [ "$(basename "$SCRIPT_PATH")" = "z4r" ]; then
    debug_log "Запуск из установленной команды z4r"
    echo "Проверка обновлений установщика..."

    TEMP_INSTALLER="$(mktemp 2>/dev/null || echo "/tmp/z4r_inst_$$")"
    if $DL_CMD "$TEMP_INSTALLER" "$INSTALLER_URL" 2>/dev/null; then
        # Сравниваем с текущей версией (busybox-compatible)
        if ! cmp "$SCRIPT_PATH" "$TEMP_INSTALLER" >/dev/null 2>&1; then
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
    # Первый запуск - устанавливаем себя
    debug_log "Первый запуск, выполняется установка"
    if [ -f "$SCRIPT_PATH" ]; then
        if [ "$IS_EMBEDDED" = "1" ]; then
            echo "Обнаружена embedded система, установка в $BIN_PATH..."
        else
            echo "Установка команды z4r в систему..."
        fi

        # Создаем директорию если не существует
        mkdir -p "$(dirname "$BIN_PATH")"

        cp "$SCRIPT_PATH" "$BIN_PATH"
        chmod +x "$BIN_PATH"
        echo "✓ Команда z4r установлена в $BIN_PATH"
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

TEMP_JSON="$(mktemp 2>/dev/null || echo "/tmp/z4r_json_$$")"
debug_log "Временный файл: $TEMP_JSON"

if [ "$DOWNLOADER" = "wget" ]; then
    wget -q -O "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
else
    curl -sS -L -o "$TEMP_JSON" "$API_URL" 2>/dev/null || echo "[]" > "$TEMP_JSON"
fi

debug_log "Содержимое JSON (первые 500 символов):"
if [ "$DEBUG" = "1" ]; then
    head -c 500 "$TEMP_JSON" 2>/dev/null || dd if="$TEMP_JSON" bs=500 count=1 2>/dev/null
    echo ""
fi

# Улучшенный парсинг JSON (busybox-compatible)
LIB_FILES=""
while IFS= read -r line; do
    case "$line" in
        *'"name"'*)
            # Извлекаем имя файла (busybox-compatible sed)
            filename=$(echo "$line" | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            case "$filename" in
                *.sh)
                    LIB_FILES="$LIB_FILES $filename"
                    debug_log "Найден файл: $filename"
                    ;;
            esac
            ;;
    esac
done < "$TEMP_JSON"

rm -f "$TEMP_JSON"

# Фолбэк на стандартный набор
if [ -z "$LIB_FILES" ]; then
    echo "⚠ Список файлов пуст, использую стандартный набор"
    LIB_FILES="actions.sh netcheck.sh provider.sh recommendations.sh strategies.sh submenus.sh telemetry.sh ui.sh"
fi

# Подсчет количества файлов
LIB_COUNT=0
for f in $LIB_FILES; do
    LIB_COUNT=$((LIB_COUNT + 1))
done

echo "Найдено библиотек для загрузки: $LIB_COUNT"
if [ "$DEBUG" = "1" ]; then
    echo "Список файлов:"
    for f in $LIB_FILES; do
        echo "  - $f"
    done
fi

# Скачивание библиотек
echo "Загрузка библиотек..."
LIB_UPDATED=0
for file in $LIB_FILES; do
    debug_log "Загрузка: ${RAW_URL}/lib/${file}"
    if $DL_CMD "${INSTALL_DIR}/lib/${file}" "${RAW_URL}/lib/${file}" 2>/dev/null; then
        chmod +x "${INSTALL_DIR}/lib/${file}"
        LIB_UPDATED=$((LIB_UPDATED + 1))
        debug_log "✓ $file загружен"
    else
        debug_log "✗ $file не загружен"
    fi
done

echo "✓ Загружено библиотек: ${LIB_UPDATED}/${LIB_COUNT}"
echo ""

# Запуск z4r.sh
echo "=== Запуск z4r.sh ==="
debug_log "Рабочая директория: ${INSTALL_DIR}"

cd "${INSTALL_DIR}" || exit 1

# Определяем какой shell использовать
if command -v bash >/dev/null 2>&1; then
    SHELL_CMD="$(command -v bash)"
    debug_log "Найден bash: $SHELL_CMD"
elif command -v ash >/dev/null 2>&1; then
    SHELL_CMD="$(command -v ash)"
    debug_log "Найден ash: $SHELL_CMD"
else
    SHELL_CMD="/bin/sh"
    debug_log "Используется sh"
fi

debug_log "Используемый shell: $SHELL_CMD"
debug_log "Команда: $SHELL_CMD ${INSTALL_DIR}/z4r.sh"

# Перенаправляем stdin на терминал если запущено через pipe
if [ -t 0 ]; then
    debug_log "stdin подключен к терминалу"
    exec $SHELL_CMD ./z4r.sh "$@"
else
    debug_log "stdin это pipe, переподключение к /dev/tty"
    exec $SHELL_CMD ./z4r.sh "$@" < /dev/tty
fi
