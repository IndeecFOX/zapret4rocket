# ---- Provider detector integration ----
# Используем provider.txt как основной источник правды (просто строка "Provider - City")
PROVIDER_CACHE="/opt/zapret/extra_strats/cache/provider.txt"
PROVIDER_MENU="Не определён"
PROVIDER_INIT_DONE=0

# Вспомогательная функция: делает запрос к API и пишет в файл
_detect_api_simple() {
    # 1. Скачиваем ответ во временный файл (чтобы точно видеть, что пришло)
    local tmp_file="/tmp/z4r_provider_debug.txt"
    curl -s --max-time 10 "http://ip-api.com/line?fields=isp,city" > "$tmp_file"

    # 2. Читаем построчно (без пайпов, чтобы не терять код возврата)
    local p_name=$(head -n 1 "$tmp_file")
    local p_city=$(head -n 2 "$tmp_file" | tail -n 1)

    # 3. Чистим жестко (оставляем только латиницу, цифры и пробелы)
    # Удаляем вообще все странные символы
    p_name=$(echo "$p_name" | tr -cd 'a-zA-Z0-9 ._-')
    p_city=$(echo "$p_city" | tr -cd 'a-zA-Z0-9 ._-')

    # Убираем дублирование, если API вернул 1 строку
    if [ "$p_city" = "$p_name" ]; then p_city=""; fi

    # 4. Формируем результат
    local res="$p_name"
    if [ -n "$p_city" ]; then
        res="$res - $p_city"
    fi

    # 5. Проверка результата перед записью
    if [ -n "$res" ]; then
        mkdir -p "$(dirname "$PROVIDER_CACHE")"
        echo "$res" > "$PROVIDER_CACHE"
    else
        echo "DEBUG: Результат парсинга пустой! (Raw: $(cat $tmp_file))" >&2
    fi

    # Чистим за собой
    rm -f "$tmp_file"
}

provider_init_once() {
  [ "$PROVIDER_INIT_DONE" = "1" ] && return 0
  PROVIDER_INIT_DONE=1

  # Если кэша нет или он пустой — пробуем определить
  if [ ! -s "$PROVIDER_CACHE" ]; then
    echo "Определяем провайдера..."
    _detect_api_simple
  fi

  # Читаем результат в переменную меню
  if [ -s "$PROVIDER_CACHE" ]; then
      PROVIDER_MENU="$(cat "$PROVIDER_CACHE")"
  else
      PROVIDER_MENU="Не определён"
  fi
}

provider_force_redetect() {
  echo "Обновляем данные о провайдере..."
  rm -f "$PROVIDER_CACHE"
  _detect_api_simple

  if [ -s "$PROVIDER_CACHE" ]; then
      PROVIDER_MENU="$(cat "$PROVIDER_CACHE")"
  else
      PROVIDER_MENU="Не удалось определить"
  fi
}

provider_set_manual_menu() {
  read -re -p "Провайдер (например MTS/Beeline): " p
  read -re -p "Город (можно пусто): " c

  # Чистим ввод
  p=$(echo "$p" | tr -cd '[:alnum:] ._-')
  c=$(echo "$c" | tr -cd '[:alnum:] ._-')

  local res="$p"
  [ -n "$c" ] && res="$res - $c"

  mkdir -p "$(dirname "$PROVIDER_CACHE")"
  echo "$res" > "$PROVIDER_CACHE"
  PROVIDER_MENU="$res"
}
# ---- /Provider detector integration ----


