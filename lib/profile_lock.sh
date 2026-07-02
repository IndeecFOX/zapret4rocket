# Persistent profile lock state.
# Missing row means auto/current behavior. Stored values are "skip" or N.

profile_lock_file() {
  echo "${Z2R_PROFILE_STATE_FILE:-/opt/etc/z2r/profile.lock}"
}

profile_lock_get() {
  local profile="$1"
  local file
  file="$(profile_lock_file)"

  if [ ! -f "$file" ]; then
    echo "auto"
    return 0
  fi

  awk -v p="$profile" '
    /^[[:space:]]*#/ || NF == 0 { next }
    $1 == p { print $2; found = 1; exit }
    END { if (!found) print "auto" }
  ' "$file"
}

profile_lock_set() {
  local profile="$1"
  local state="$2"
  local current file dir tmp max

  [ "$state" = "0" ] && state="skip"

  case "$state" in
    ""|"auto")
      profile_lock_clear "$profile"
      return
      ;;
    "skip")
      ;;
    *)
      if ! echo "$state" | grep -Eq '^[1-9][0-9]*$'; then
        echo "Некорректное состояние профиля: $state"
        return 1
      fi
      max="$(profile_strategy_max "$profile" 2>/dev/null || true)"
      if [ -z "$max" ] || [ "$state" -gt "$max" ]; then
        echo "Стратегия $state вне диапазона для $profile"
        return 1
      fi
      ;;
  esac

  current="$(profile_lock_get "$profile")"
  [ "$current" = "$state" ] && return 0

  file="$(profile_lock_file)"
  dir="${file%/*}"
  tmp="${file}.tmp.$$"

  mkdir -p "$dir"
  if [ -f "$file" ]; then
    awk -v p="$profile" '
      BEGIN { OFS = "\t" }
      /^[[:space:]]*#/ || NF == 0 { print; next }
      $1 != p { print }
    ' "$file" > "$tmp" || {
      rm -f "$tmp"
      return 1
    }
  else
    : > "$tmp"
  fi

  printf '%s\t%s\n' "$profile" "$state" >> "$tmp"

  if [ -f "$file" ] && cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$file"
  fi
}

profile_lock_clear() {
  local profile="$1"
  local current file dir tmp

  current="$(profile_lock_get "$profile")"
  [ "$current" = "auto" ] && return 0

  file="$(profile_lock_file)"
  dir="${file%/*}"
  tmp="${file}.tmp.$$"

  mkdir -p "$dir"
  if [ -f "$file" ]; then
    awk -v p="$profile" '
      BEGIN { OFS = "\t" }
      /^[[:space:]]*#/ || NF == 0 { print; next }
      $1 != p { print }
    ' "$file" > "$tmp" || {
      rm -f "$tmp"
      return 1
    }
  else
    : > "$tmp"
  fi

  if [ -f "$file" ] && cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$file"
  fi
}

profile_strategy_base() {
  local root
  root="$(z2r_root_dir)"

  case "$1" in
    "YT_UDP") echo "$root/extra_strats/UDP/YT" ;;
    "YT_TCP") echo "$root/extra_strats/TCP/YT" ;;
    "YT_GV")  echo "$root/extra_strats/TCP/GV" ;;
    "RKN")    echo "$root/extra_strats/TCP/RKN" ;;
    *)        return 1 ;;
  esac
}

profile_strategy_max() {
  case "$1" in
    "YT_UDP") echo "8" ;;
    "YT_TCP"|"YT_GV"|"RKN") echo "17" ;;
    *) return 1 ;;
  esac
}

profile_strategy_list_file() {
  local profile="$1"
  local root nested flat
  root="$(z2r_root_dir)"

  case "$profile" in
    "YT_UDP")
      nested="$root/extra_strats/UDP/YT/List.txt"
      flat="$root/extra_strats/UDP_YT_list.txt"
      ;;
    "YT_TCP")
      nested="$root/extra_strats/TCP/YT/List.txt"
      flat="$root/extra_strats/TCP_YT_list.txt"
      ;;
    "RKN")
      nested="$root/extra_strats/TCP/RKN/List.txt"
      flat="$root/extra_strats/TCP_RKN_list.txt"
      ;;
    *)
      return 1
      ;;
  esac

  if [ -s "$nested" ]; then
    echo "$nested"
  else
    echo "$flat"
  fi
}

profile_can_skip() {
  case "$1" in
    "YT_UDP"|"YT_TCP"|"RKN"|"VOICE_UDP") return 0 ;;
    *) return 1 ;;
  esac
}

profile_write_if_changed() {
  local dest="$1"
  local content="$2"
  local tmp

  mkdir -p "$(dirname "$dest")"
  tmp="${dest}.tmp.$$"
  printf '%s\n' "$content" > "$tmp"

  if [ -f "$dest" ] && cmp -s "$dest" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$dest"
  fi
}

profile_clear_strategy_files() {
  local profile="$1"
  local base max i file

  base="$(profile_strategy_base "$profile")" || return 0
  max="$(profile_strategy_max "$profile")" || return 0

  mkdir -p "$base"
  for ((i=1; i<=max; i++)); do
    file="$base/$i.txt"
    [ -s "$file" ] && : > "$file"
  done

  return 0
}

profile_apply_strategy_num() {
  local profile="$1"
  local strat_num="$2"
  local base max list_file i

  base="$(profile_strategy_base "$profile")" || return 0
  max="$(profile_strategy_max "$profile")" || return 0

  if [ "$strat_num" -lt 1 ] || [ "$strat_num" -gt "$max" ]; then
    echo "Стратегия $strat_num вне диапазона для $profile"
    return 1
  fi

  mkdir -p "$base"
  for ((i=1; i<=max; i++)); do
    if [ "$i" -eq "$strat_num" ]; then
      case "$profile" in
        "YT_GV")
          profile_write_if_changed "$base/$i.txt" "googlevideo.com"
          ;;
        *)
          list_file="$(profile_strategy_list_file "$profile")"
          if [ -s "$list_file" ]; then
            if [ ! -f "$base/$i.txt" ] || ! cmp -s "$list_file" "$base/$i.txt"; then
              cp -f "$list_file" "$base/$i.txt"
            fi
          fi
          ;;
      esac
    else
      [ -s "$base/$i.txt" ] && : > "$base/$i.txt"
    fi
  done

  return 0
}

profile_apply_yt_udp_skip() {
  local cfg="$1"
  local root
  root="$(z2r_root_dir)"

  profile_clear_strategy_files "YT_UDP"
  config_line_skip "$cfg" "--filter-udp=443 --hostlist=$root/extra_strats/UDP_YT_list.txt"
}

profile_apply_yt_udp_enable() {
  local cfg="$1"
  local root
  root="$(z2r_root_dir)"

  config_line_unskip "$cfg" "--filter-udp=443 --hostlist=$root/extra_strats/UDP_YT_list.txt"
}

profile_apply_yt_tcp_skip() {
  local cfg="$1"
  local root
  root="$(z2r_root_dir)"

  profile_clear_strategy_files "YT_TCP"
  config_tcp_hostlist_remove "$cfg" "$root/extra_strats/TCP_YT_list.txt"
}

profile_apply_yt_tcp_enable() {
  local cfg="$1"
  local root
  root="$(z2r_root_dir)"

  config_tcp_hostlist_add "$cfg" "$root/extra_strats/TCP_YT_list.txt"
}

profile_apply_rkn_skip() {
  local cfg="$1"
  local root
  root="$(z2r_root_dir)"

  profile_clear_strategy_files "RKN"
  config_tcp_hostlist_remove "$cfg" "$root/extra_strats/TCP_RKN_list.txt"
}

profile_apply_rkn_enable() {
  local cfg="$1"
  local root
  root="$(z2r_root_dir)"

  config_tcp_hostlist_add "$cfg" "$root/extra_strats/TCP_RKN_list.txt"
}

profile_apply_voice_skip() {
  local cfg="$1"
  local voice_ports="50000-50099,1400,3478-3481,5349,19294-19344"

  config_line_skip "$cfg" "--filter-udp=50000-50099,1400,3478-3481,5349,19294-19344"
  config_ports_remove "$cfg" "NFQWS2_PORTS_UDP" "$voice_ports"
  custom_script_disable "50-stun4all"
  custom_script_disable "50-discord-media"
}

profile_apply_voice_auto() {
  local cfg="$1"
  local voice_ports="50000-50099,1400,3478-3481,5349,19294-19344"

  config_ports_remove "$cfg" "NFQWS2_PORTS_UDP" "$voice_ports"
  config_line_unskip "$cfg" "--filter-udp=50000-50099,1400,3478-3481,5349,19294-19344"
  custom_script_enable "50-stun4all"
  custom_script_enable "50-discord-media"
}

profile_apply_voice_classic() {
  local cfg="$1"
  local voice_ports="1400,3478-3481,5349,50000-50099,19294-19344"

  config_ports_add "$cfg" "NFQWS2_PORTS_UDP" "$voice_ports"
  config_line_unskip "$cfg" "--filter-udp=50000-50099,1400,3478-3481,5349,19294-19344"
  custom_script_disable "50-stun4all"
  custom_script_disable "50-discord-media"
}

profile_apply_skip() {
  local profile="$1"
  local cfg="$2"

  if ! profile_can_skip "$profile"; then
    echo "Профиль $profile пока нельзя безопасно отключить через --skip."
    return 0
  fi

  case "$profile" in
    "YT_UDP")    profile_apply_yt_udp_skip "$cfg" ;;
    "YT_TCP")    profile_apply_yt_tcp_skip "$cfg" ;;
    "RKN")       profile_apply_rkn_skip "$cfg" ;;
    "VOICE_UDP") profile_apply_voice_skip "$cfg" ;;
  esac
}

profile_apply_enable() {
  local profile="$1"
  local cfg="$2"

  case "$profile" in
    "YT_UDP")    profile_apply_yt_udp_enable "$cfg" ;;
    "YT_TCP")    profile_apply_yt_tcp_enable "$cfg" ;;
    "RKN")       profile_apply_rkn_enable "$cfg" ;;
    "VOICE_UDP") profile_apply_voice_classic "$cfg" ;;
  esac
}

profile_apply_one() {
  local profile="$1"
  local state="${2:-$(profile_lock_get "$profile")}"
  local cfg="${3:-$(z2r_config_file)}"
  local max

  case "$state" in
    "auto"|"")
      return 0
      ;;
    "skip")
      profile_apply_skip "$profile" "$cfg"
      ;;
    *)
      if echo "$state" | grep -Eq '^[1-9][0-9]*$'; then
        max="$(profile_strategy_max "$profile" 2>/dev/null || true)"
        if [ -z "$max" ] || [ "$state" -gt "$max" ]; then
          echo "Пропуск profile lock: $profile=$state вне диапазона."
          return 0
        fi
        profile_apply_enable "$profile" "$cfg"
        profile_apply_strategy_num "$profile" "$state"
      fi
      ;;
  esac
}

profile_apply_all() {
  local cfg="${1:-$(z2r_config_file)}"
  local file profile state

  file="$(profile_lock_file)"
  [ -f "$file" ] || return 0

  while read -r profile state _; do
    case "$profile" in
      ""|\#*) continue ;;
    esac
    profile_apply_one "$profile" "$state" "$cfg"
  done < "$file"
}
