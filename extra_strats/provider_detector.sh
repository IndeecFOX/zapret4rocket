#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Provider Detector для zapret4rocket
# Автор: AloofLibra
# Версия: 1.0
# ═══════════════════════════════════════════════════════════════════

set -u

PROVIDER_CACHE="/opt/zapret/extra_strats/cache/provider.json"
PROVIDER_CACHE_DIR="/opt/zapret/extra_strats/cache"

# Цвета: НЕ перезатираем, если z4r.sh уже определил их
: "${red:='\033[0;31m'}"
: "${green:='\033[0;32m'}"
: "${yellow:='\033[1;33m'}"
: "${blue:='\033[0;34m'}"
: "${cyan:='\033[0;36m'}"
: "${plain:='\033[0m'}"

# База ASN → Провайдер
# Ключи в формате "AS12345"
declare -A AS_DATABASE=(
  # Ростелеком
  ["AS12389"]="Rostelecom"
  ["AS42610"]="Rostelecom"
  ["AS8369"]="Rostelecom"

  # МТС
  ["AS8359"]="MTS"
  ["AS3216"]="MTS"
  ["AS29280"]="MTS"

  # Билайн
  ["AS8402"]="Beeline"
  ["AS3267"]="Beeline"
  ["AS13335"]="Beeline"

  # Теле2
  ["AS41330"]="Tele2"
  ["AS31163"]="Tele2"

  # МегаФон
  ["AS25159"]="MegaFon"
  ["AS25513"]="MegaFon"
  ["AS31133"]="MegaFon"

  # Дом.ру / ER-Telecom
  ["AS41733"]="Dom.ru"
  ["AS51604"]="Dom.ru"

  # ТТК / TransTeleCom
  ["AS20485"]="TTK"

  # Другие
  ["AS47775"]="Yota"
  ["AS203978"]="Akado"
  ["AS31200"]="Enforta"
  ["AS50928"]="Enforta"
)

init_cache_dir() {
  [ -d "$PROVIDER_CACHE_DIR" ] || mkdir -p "$PROVIDER_CACHE_DIR"
}

have_jq() {
  command -v jq >/dev/null 2>&1
}

# Универсальная безопасная запись JSON-кэша (через jq)
# Аргументы:
# 1 provider, 2 asn("ASxxxx" или пусто), 3 isp, 4 org, 5 city, 6 country, 7 ip, 8 source
write_cache() {
  local provider="${1:-}"
  local asn="${2:-}"
  local isp="${3:-}"
  local org="${4:-}"
  local city="${5:-}"
  local country="${6:-}"
  local ip="${7:-}"
  local source="${8:-auto}"
  local updated_at
  updated_at="$(date -Iseconds)"

  init_cache_dir

  # jq обязателен, потому что дальше меню/скрипт читают JSON тоже через jq
  if ! have_jq; then
    return 1
  fi

  jq -n \
    --arg provider "$provider" \
    --arg asn "$asn" \
    --arg isp "$isp" \
    --arg org "$org" \
    --arg city "$city" \
    --arg country "$country" \
    --arg ip "$ip" \
    --arg source "$source" \
    --arg updated_at "$updated_at" \
    '{
      provider: $provider,
      asn: $asn,
      isp: $isp,
      org: $org,
      city: $city,
      country: $country,
      ip: $ip,
      source: $source,
      updated_at: $updated_at
    }' > "$PROVIDER_CACHE"
}

# save_to_cache provider asn isp org city country ip
save_to_cache() {
  write_cache "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}" "auto"
}

get_external_ip() {
  # ifconfig.me (HTTPS) + fallback
  curl -fsS --max-time 7 https://ifconfig.me 2>/dev/null \
    || curl -fsS --max-time 7 https://api.ipify.org 2>/dev/null
}

# Нормализуем строку для матчей
_lc() { tr '[:upper:]' '[:lower:]' <<<"${1:-}"; }

# Эвристики по ISP/ORG (если ASN не в базе)
guess_provider_by_strings() {
  local isp_lc="$(_lc "${1:-}")"
  local org_lc="$(_lc "${2:-}")"
  local s="${isp_lc} ${org_lc}"

  case "$s" in
    *rostelecom*|*ростелеком*|*rttk*) echo "Rostelecom" ;;
    *mts*|*мтс*|*mgts*|*мгтс*)       echo "MTS" ;;
    *beeline*|*vimpelcom*|*вымпел*)  echo "Beeline" ;;
    *tele2*|*теле2*)                echo "Tele2" ;;
    *megafon*|*мегафон*)            echo "MegaFon" ;;
    *dom.ru*|*er-telecom*|*эр-телеком*) echo "Dom.ru" ;;
    *ttk*|*transtel*|*trans telecom*|*ттк*|*транстелеком*) echo "TTK" ;;
    *) echo "" ;;
  esac
}

# Определение провайдера + город через ipwho.is (HTTPS)
detect_provider_api() {
  if ! have_jq; then
    echo "Unknown"
    return 1
  fi

  echo -e "${cyan}Определяю провайдера...${plain}" >&2

  local external_ip
  external_ip="$(get_external_ip || true)"
  if [ -z "${external_ip:-}" ]; then
    echo -e "${red}Не удалось получить внешний IP${plain}" >&2
    echo "Unknown"
    return 1
  fi
  echo -e "${blue}IP: ${external_ip}${plain}" >&2

  # Берём только нужные поля
  local url
  url="https://ipwho.is/${external_ip}?fields=success,message,ip,city,country,connection.asn,connection.isp,connection.org"

  local api_response success
  api_response="$(curl -fsS --max-time 12 "$url" 2>/dev/null || true)"
  success="$(jq -r '.success // false' <<<"$api_response" 2>/dev/null || echo "false")"

  if [ "$success" != "true" ]; then
    echo -e "${red}API ipwho.is недоступен или вернул ошибку${plain}" >&2
    echo "Unknown"
    return 1
  fi

  local asn_num asn_key isp org city country
  asn_num="$(jq -r '.connection.asn // empty' <<<"$api_response" 2>/dev/null)"
  isp="$(jq -r '.connection.isp // empty' <<<"$api_response" 2>/dev/null)"
  org="$(jq -r '.connection.org // empty' <<<"$api_response" 2>/dev/null)"
  city="$(jq -r '.city // empty' <<<"$api_response" 2>/dev/null)"
  country="$(jq -r '.country // empty' <<<"$api_response" 2>/dev/null)"

  if [ -n "${asn_num:-}" ] && [ "${asn_num:-}" != "null" ]; then
    asn_key="AS${asn_num}"
  else
    asn_key=""
  fi

  echo -e "${blue}ASN: ${asn_key:-N/A}${plain}" >&2
  echo -e "${blue}ISP: ${isp:-N/A}${plain}" >&2
  echo -e "${blue}Город: ${city:-N/A}${plain}" >&2

  local provider=""
  if [ -n "${asn_key:-}" ] && [ -n "${AS_DATABASE[$asn_key]+x}" ]; then
    provider="${AS_DATABASE[$asn_key]}"
  fi

  if [ -z "$provider" ]; then
    provider="$(guess_provider_by_strings "$isp" "$org")"
  fi

  if [ -z "$provider" ]; then
    # fallback: пусть будет ISP как “провайдер”, но это явно не точное определение
    provider="${isp:-Unknown}"
  fi

  write_cache "$provider" "$asn_key" "$isp" "$org" "$city" "$country" "$external_ip" "auto" || true
  echo "$provider"
  return 0
}

get_cached_provider() {
  [ -f "$PROVIDER_CACHE" ] || return 1
  have_jq || return 1
  jq empty "$PROVIDER_CACHE" 2>/dev/null || return 1

  local provider
  provider="$(jq -r '.provider // empty' "$PROVIDER_CACHE" 2>/dev/null)"
  [ -n "$provider" ] || return 1
  echo "$provider"
}

get_provider_with_city() {
  [ -f "$PROVIDER_CACHE" ] || { echo "Не определён"; return 1; }
  have_jq || { echo "Не определён"; return 1; }
  jq empty "$PROVIDER_CACHE" 2>/dev/null || { echo "Не определён"; return 1; }

  local provider city
  provider="$(jq -r '.provider // empty' "$PROVIDER_CACHE" 2>/dev/null)"
  city="$(jq -r '.city // empty' "$PROVIDER_CACHE" 2>/dev/null)"

  [ -n "$provider" ] || { echo "Не определён"; return 1; }

  if [ -n "$city" ] && [ "$city" != "N/A" ]; then
    echo "$provider - $city"
  else
    echo "$provider"
  fi
}

get_cached_info() {
  [ -f "$PROVIDER_CACHE" ] || return 1
  have_jq || return 1
  jq empty "$PROVIDER_CACHE" 2>/dev/null || return 1
  cat "$PROVIDER_CACHE"
}

# Ручная установка провайдера (можно дергать из меню напрямую)
# set_provider_manual "MTS" "Moscow"
set_provider_manual() {
  local provider="${1:-}"
  local city="${2:-}"

  [ -n "$provider" ] || return 1

  write_cache "$provider" "" "" "" "$city" "" "" "manual"
}
