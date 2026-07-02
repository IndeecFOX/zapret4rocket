# Low-level config and custom.d mutations used by profile locks.

z2r_root_dir() {
  echo "${Z2R_ROOT:-/opt/zapret2}"
}

z2r_config_file() {
  echo "${Z2R_CONFIG:-$(z2r_root_dir)/config}"
}

config_line_skip() {
  local cfg="$1"
  local pattern="$2"

  [ -f "$cfg" ] || return 0
  local tmp="${cfg}.tmp.$$"

  awk -v p="$pattern" '
    index($0, p) > 0 {
      match($0, /^[[:space:]]*/)
      pre = substr($0, 1, RLENGTH)
      rest = substr($0, RLENGTH + 1)
      if (rest !~ /^--skip[[:space:]]+/) {
        $0 = pre "--skip " rest
      }
    }
    { print }
  ' "$cfg" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }

  if cmp -s "$cfg" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$cfg"
  fi
}

config_line_unskip() {
  local cfg="$1"
  local pattern="$2"

  [ -f "$cfg" ] || return 0
  local tmp="${cfg}.tmp.$$"

  awk -v p="$pattern" '
    index($0, p) > 0 {
      match($0, /^[[:space:]]*/)
      pre = substr($0, 1, RLENGTH)
      rest = substr($0, RLENGTH + 1)
      if (rest ~ /^--skip[[:space:]]+/) {
        sub(/^--skip[[:space:]]+/, "", rest)
        $0 = pre rest
      }
    }
    { print }
  ' "$cfg" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }

  if cmp -s "$cfg" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$cfg"
  fi
}

config_tcp_hostlist_remove() {
  local cfg="$1"
  local hostlist="$2"
  local tmp

  [ -f "$cfg" ] || return 0
  tmp="${cfg}.tmp.$$"

  awk -v hostlist="$hostlist" '
    function append_field(value) {
      out = out (out == "" ? "" : " ") value
    }
    index($0, "--qnum 300") > 0 && index($0, "--filter-tcp=80,443") > 0 {
      match($0, /^[[:space:]]*/)
      pre = substr($0, 1, RLENGTH)
      rest = substr($0, RLENGTH + 1)
      n = split(rest, fields, /[[:space:]]+/)
      out = ""
      hostlists = 0
      skipped = 0
      for (i = 1; i <= n; i++) {
        if (fields[i] == "") continue
        if (fields[i] == "--hostlist=" hostlist) continue
        if (fields[i] ~ /^--hostlist=/) hostlists++
        if (fields[i] == "--skip") skipped = 1
        append_field(fields[i])
      }
      if (hostlists == 0 && skipped == 0) {
        out = "--skip " out
      }
      $0 = pre out
    }
    { print }
  ' "$cfg" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }

  if cmp -s "$cfg" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$cfg"
  fi
}

config_tcp_hostlist_add() {
  local cfg="$1"
  local hostlist="$2"
  local tmp

  [ -f "$cfg" ] || return 0
  tmp="${cfg}.tmp.$$"

  awk -v hostlist="$hostlist" '
    function append_field(value) {
      out = out (out == "" ? "" : " ") value
    }
    index($0, "--qnum 300") > 0 && index($0, "--filter-tcp=80,443") > 0 {
      match($0, /^[[:space:]]*/)
      pre = substr($0, 1, RLENGTH)
      rest = substr($0, RLENGTH + 1)
      n = split(rest, fields, /[[:space:]]+/)
      out = ""
      seen = 0
      inserted = 0
      for (i = 1; i <= n; i++) {
        if (fields[i] == "--hostlist=" hostlist) seen = 1
      }
      for (i = 1; i <= n; i++) {
        if (fields[i] == "" || fields[i] == "--skip") continue
        if (seen == 0 && inserted == 0 && fields[i] ~ /^--in-range=/) {
          append_field("--hostlist=" hostlist)
          inserted = 1
        }
        append_field(fields[i])
      }
      if (seen == 0 && inserted == 0) {
        append_field("--hostlist=" hostlist)
      }
      $0 = pre out
    }
    { print }
  ' "$cfg" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }

  if cmp -s "$cfg" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$cfg"
  fi
}

config_get_var() {
  local cfg="$1"
  local var="$2"

  sed -n "s/^${var}=//p" "$cfg" 2>/dev/null | head -n1
}

config_set_var() {
  local cfg="$1"
  local var="$2"
  local value="$3"
  local old tmp

  [ -f "$cfg" ] || return 0
  old="$(config_get_var "$cfg" "$var")"
  [ "$old" = "$value" ] && return 0

  tmp="${cfg}.tmp.$$"
  awk -v var="$var" -v value="$value" '
    $0 ~ "^" var "=" && done == 0 {
      print var "=" value
      done = 1
      next
    }
    { print }
  ' "$cfg" > "$tmp" || {
    rm -f "$tmp"
    return 1
  }

  if cmp -s "$cfg" "$tmp"; then
    rm -f "$tmp"
  else
    mv -f "$tmp" "$cfg"
  fi
}

config_ports_remove() {
  local cfg="$1"
  local var="$2"
  local remove_csv="$3"
  local value result port remove keep

  value="$(config_get_var "$cfg" "$var")"
  [ -z "$value" ] && return 0

  result=""
  IFS=',' read -ra current_ports <<< "$value"
  IFS=',' read -ra remove_ports <<< "$remove_csv"
  for port in "${current_ports[@]}"; do
    [ -z "$port" ] && continue
    keep=1
    for remove in "${remove_ports[@]}"; do
      if [ "$port" = "$remove" ]; then
        keep=0
        break
      fi
    done
    [ "$keep" -eq 1 ] && result="${result:+$result,}$port"
  done

  config_set_var "$cfg" "$var" "$result"
}

config_ports_add() {
  local cfg="$1"
  local var="$2"
  local add_csv="$3"
  local value result port add found

  value="$(config_get_var "$cfg" "$var")"
  result="$value"

  IFS=',' read -ra add_ports <<< "$add_csv"
  for add in "${add_ports[@]}"; do
    [ -z "$add" ] && continue
    found=0
    IFS=',' read -ra current_ports <<< "$result"
    for port in "${current_ports[@]}"; do
      if [ "$port" = "$add" ]; then
        found=1
        break
      fi
    done
    [ "$found" -eq 0 ] && result="${result:+$result,}$add"
  done

  config_set_var "$cfg" "$var" "$result"
}

custom_script_dir() {
  if [ -n "${ZAPRET2_INIT:-}" ]; then
    echo "$(dirname "$ZAPRET2_INIT")/custom.d"
  else
    echo "$(z2r_root_dir)/init.d/sysv/custom.d"
  fi
}

custom_script_disable() {
  local script_name="$1"
  local custom_dir disabled_dir

  custom_dir="$(custom_script_dir)"
  disabled_dir="${custom_dir}.disabled"

  if [ -f "$custom_dir/$script_name" ]; then
    mkdir -p "$disabled_dir"
    mv -f "$custom_dir/$script_name" "$disabled_dir/$script_name"
  fi
}

custom_script_enable() {
  local script_name="$1"
  local custom_dir disabled_dir

  custom_dir="$(custom_script_dir)"
  disabled_dir="${custom_dir}.disabled"

  if [ -f "$disabled_dir/$script_name" ]; then
    mkdir -p "$custom_dir"
    mv -f "$disabled_dir/$script_name" "$custom_dir/$script_name"
  fi
}
