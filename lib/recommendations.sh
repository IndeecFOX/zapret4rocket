# ---- Recomendations module ----

RECS_URL="https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/recommendations.txt"
RECS_FILE="/opt/zapret/extra_strats/cache/recommendations.txt"

# 1. Функция обновления базы
update_recommendations() {
  mkdir -p "$(dirname "$RECS_FILE")"

  # Проверка: если файл существует И он моложе 1 дня (24 часа) - выходим.
  # -mtime -1 означает "изменен менее 1 дня назад"
  if [ -f "$RECS_FILE" ] && [ -n "$(find "$RECS_FILE" -mtime -1 2>/dev/null)" ]; then
    # Файл свежий, обновлять не нужно
    return 0
  fi

  # Если файла нет или он старый - качаем
  curl -s --max-time 5 "$RECS_URL" -o "$RECS_FILE" || rm -f "$RECS_FILE"
  return 0
}

filter_builtin_recommendations() {
  local value="$1"
  local out="" item num

  value="$(echo "$value" | sed 's/,/ /g')"
  for item in $value; do
    num="${item%%[^0-9]*}"
    case "$num" in
      ''|*[!0-9]*) continue ;;
    esac
    [ "$num" -ge 1000 ] && continue
    if [ -n "$out" ]; then
      out="$out,$num"
    else
      out="$num"
    fi
  done

  echo "$out"
}

# 2. Функция показа подсказки (Logic + UI)
show_hint() {
  local strat_type="$1" # UDP, TCP, GV или RKN
  local my_isp=""

  # А. Узнаем провайдера
  if [ -s "/opt/zapret/extra_strats/cache/provider.txt" ]; then
    my_isp="$(cat "/opt/zapret/extra_strats/cache/provider.txt")"
  fi

  # Б. Проверяем наличие базы
  if [ -z "$my_isp" ] || [ ! -f "$RECS_FILE" ]; then
    return 0
  fi

  # В. Ищем строку (grep -F для безопасности спецсимволов)
  local line
  line="$(grep -F "$my_isp|" "$RECS_FILE" | head -n 1)"
  [ -z "$line" ] && return 0

  # Г. Парсим (актуальный формат у тебя: ISP|UDP:...|TCP:...|GV:...|RKN:...
  local part=""
  case "$strat_type" in
    "UDP") part="$(echo "$line" | cut -d'|' -f2 | cut -d':' -f2)" ;;
    "TCP") part="$(echo "$line" | cut -d'|' -f3 | cut -d':' -f2)" ;;
    "GV")  part="$(echo "$line" | cut -d'|' -f4 | cut -d':' -f2)" ;;
    "RKN") part="$(echo "$line" | cut -d'|' -f5 | cut -d':' -f2)" ;;
    *) return 0 ;;
  esac
  part="$(filter_builtin_recommendations "$part")"

  # Д. Выводим
  if [ -n "$part" ] && [ "$part" != "-" ]; then
    echo ""
    echo -e "${cyan}💡 Подсказка:${plain} Пользователи ${green}$my_isp${plain} часто выбирают: ${yellow}$part${plain}"
    echo -e "Попробуйте начать с них."
    echo ""
  fi

  return 0
}

# ---- /Recomendations module ----
