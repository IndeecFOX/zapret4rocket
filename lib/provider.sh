# ---- Provider detector integration ----
# Используем provider.txt как основной источник правды (просто строка "Provider - City")
PROVIDER_CACHE="/opt/zapret/extra_strats/cache/provider.txt"
PROVIDER_MENU="Не определён"
PROVIDER_INIT_DONE=0

# Вспомогательная функция: делает запрос к API и пишет в файл
_detect_api_simple() {
    # 1. Скачиваем ответ во временный файл (чтобы точно видеть, что пришло)
    local tmp_file="/tmp/z4r_provider_debug.txt"
    : > "$tmp_file"

    local p_name=""
    local p_city=""
    local api_ok=0

    # Сначала пробуем ip-api.com
    if curl -s --max-time 10 --fail "http://ip-api.com/line?fields=isp,city" > "$tmp_file"; then
        p_name=$(head -n 1 "$tmp_file")
        p_city=$(head -n 2 "$tmp_file" | tail -n 1)
        if [ -n "$p_name" ] || [ -n "$p_city" ]; then
            api_ok=1
        fi
    fi

    # Если ip-api.com недоступен/пустой — пробуем ipapi.co
    if [ "$api_ok" -ne 1 ]; then
        local isp_resp=""
        local city_resp=""
        if isp_resp=$(curl -s --max-time 10 --fail "https://ipapi.co/isp/"); then
            :
        fi
        if city_resp=$(curl -s --max-time 10 --fail "https://ipapi.co/city/"); then
            :
        fi
        if [ -n "$isp_resp" ] || [ -n "$city_resp" ]; then
            p_name="$isp_resp"
            p_city="$city_resp"
            echo "$p_name" > "$tmp_file"
            echo "$p_city" >> "$tmp_file"
            api_ok=1
        fi
    fi

    # 2. Читаем построчно (без пайпов, чтобы не терять код возврата)
    if [ -z "$p_name" ]; then p_name=$(head -n 1 "$tmp_file"); fi
    if [ -z "$p_city" ]; then p_city=$(head -n 2 "$tmp_file" | tail -n 1); fi

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

  local res="$p"
  [ -n "$c" ] && res="$res - $c"

  mkdir -p "$(dirname "$PROVIDER_CACHE")"
  echo "$res" > "$PROVIDER_CACHE"
  PROVIDER_MENU="$res"
}
# ---- /Provider detector integration ----


