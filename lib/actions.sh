CONFIG_ROLLBACK_CACHE_DIR="/opt/zapret/extra_strats/cache"
CONFIG_ROLLBACK_FILE="$CONFIG_ROLLBACK_CACHE_DIR/config.rollback.bak"

ensure_keenetic_policy_config_defaults() {
  local config_file="${1:-/opt/zapret/config}"

  [ -f "$config_file" ] || return 0

  grep -q '^POLICY_NAME=' "$config_file" || echo 'POLICY_NAME=' >> "$config_file"
  grep -q '^POLICY_EXCLUDE=' "$config_file" || echo 'POLICY_EXCLUDE=0' >> "$config_file"
}

ensure_keenetic_policy_hooks() {
  local config_file="${1:-/opt/zapret/config}"

  [ -f "$config_file" ] || return 0

  grep -q '^INIT_FW_POST_UP_HOOK=' "$config_file" || echo 'INIT_FW_POST_UP_HOOK=' >> "$config_file"
  grep -q '^INIT_FW_PRE_DOWN_HOOK=' "$config_file" || echo 'INIT_FW_PRE_DOWN_HOOK=' >> "$config_file"

  sed -i 's|^INIT_FW_POST_UP_HOOK=.*|INIT_FW_POST_UP_HOOK="/opt/zapret/init.d/sysv/keenetic-policy.sh up"|' "$config_file"
  sed -i 's|^INIT_FW_PRE_DOWN_HOOK=.*|INIT_FW_PRE_DOWN_HOOK="/opt/zapret/init.d/sysv/keenetic-policy.sh down"|' "$config_file"
}

get_keenetic_policy_name() {
  if [ ! -f /opt/zapret/config ]; then
    echo ""
    return 0
  fi

  sed -n 's/^POLICY_NAME=//p' /opt/zapret/config | tail -n1
}

get_keenetic_policy_mode_label() {
  local exclude_value

  if [ ! -f /opt/zapret/config ]; then
    echo "Только устройства из политики"
    return 0
  fi

  exclude_value="$(sed -n 's/^POLICY_EXCLUDE=//p' /opt/zapret/config | tail -n1)"
  if [ "$exclude_value" = "1" ]; then
    echo "Все, кроме устройств из политики"
  else
    echo "Только устройства из политики"
  fi
}

get_keenetic_policy_status() {
  local policy_name

  policy_name="$(get_keenetic_policy_name)"
  if [ -z "$policy_name" ]; then
    echo "Не задана"
  else
    echo "$policy_name | $(get_keenetic_policy_mode_label)"
  fi
}

menu_action_set_keenetic_policy_name() {
  local policy_name=""

  ensure_keenetic_policy_config_defaults
  ensure_keenetic_policy_hooks /opt/zapret/config
  read -re -p "Введите имя Keenetic-политики. Enter очистит настройку, 0 - отмена: " policy_name

  if [ "$policy_name" = "0" ]; then
    echo "Изменение отменено."
    return 0
  fi

  sed -i "s|^POLICY_NAME=.*|POLICY_NAME=$policy_name|" /opt/zapret/config

  if [ -n "$policy_name" ]; then
    echo -e "${green}Установлена Keenetic-политика:${plain} $policy_name"
  else
    echo -e "${yellow}Ограничение по Keenetic-политике отключено.${plain}"
  fi

  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}zapret перезапущен.${plain}"
  return 0
}

menu_action_toggle_keenetic_policy_mode() {
  local current_value next_value next_label

  ensure_keenetic_policy_config_defaults
  ensure_keenetic_policy_hooks /opt/zapret/config
  current_value="$(sed -n 's/^POLICY_EXCLUDE=//p' /opt/zapret/config | tail -n1)"
  [ -n "$current_value" ] || current_value="0"

  if [ "$current_value" = "1" ]; then
    next_value="0"
    next_label="Только из политики"
  else
    next_value="1"
    next_label="Все кроме политики"
  fi

  sed -i "s/^POLICY_EXCLUDE=.*/POLICY_EXCLUDE=$next_value/" /opt/zapret/config
  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}Режим Keenetic-политики изменён:${plain} $next_label"
  return 0
}

# Возвращает строку-подсказку для пункта 5 главного меню, если есть бэкап конфига для отката.
get_config_rollback_menu_hint() {
  if [ -s "$CONFIG_ROLLBACK_FILE" ]; then
    local backup_ts
    backup_ts="$(stat -c '%y' "$CONFIG_ROLLBACK_FILE" 2>/dev/null | cut -d'.' -f1)"
    if [ -n "$backup_ts" ]; then
      backup_ts="$backup_ts UTC"
    fi
    [ -z "$backup_ts" ] && backup_ts="неизвестно"
    echo -e " | ${cyan}50${yellow} - откат на бэкап от $backup_ts"
  fi
}

# Восстанавливает /opt/zapret/config из последнего сохраненного бэкапа и перезапускает zapret.
menu_action_restore_config_backup() {
  if [ ! -s "$CONFIG_ROLLBACK_FILE" ]; then
    echo -e "${yellow}Бэкап для отката не найден.${plain}"
    return 0
  fi

  cp -f "$CONFIG_ROLLBACK_FILE" /opt/zapret/config
  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}Откат выполнен. Восстановлен /opt/zapret/config из бэкапа.${plain}"
  return 0
}

backup_strats() {
  # Бэкап папок состояния и пользовательских стратегий
  if [ -d /opt/zapret/extra_strats ] || [ -d /opt/zapret/z4r_strategies ]; then
    echo -e "${yellow}Сделать бэкап /opt/zapret/extra_strats и /opt/zapret/z4r_strategies ?${plain}"
    echo -e "${yellow}5 - Да, Enter - Нет, 0 - отмена${plain}"
    read -r ans
    if [ "$ans" = "0" ]; then
        get_menu # сигнал “отмена/в меню”
    fi
    if [ "$ans" = "5" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      rm -rf /opt/extra_strats 2>/dev/null || true
      rm -rf /opt/z4r_strategies 2>/dev/null || true
      [ -d /opt/zapret/extra_strats ] && cp -rf /opt/zapret/extra_strats /opt/ || true
      [ -d /opt/zapret/z4r_strategies ] && cp -rf /opt/zapret/z4r_strategies /opt/ || true
      echo -e "${green}Бэкап extra_strats/z4r_strategies сохранён в /opt${plain}"
    fi
  fi

  # Бэкап листа исключений
  if [ -f /opt/zapret/lists/netrogat.txt ]; then
    echo -e "${yellow}Сделать бэкап /opt/zapret/lists/netrogat.txt ?${plain}"
    echo -e "${yellow}5 - Да, Enter - Нет, 0 - отмена и выход в меню${plain}"
    read -r ans2
    if [ "$ans2" = "0" ]; then
      get_menu
    fi
    if [ "$ans2" = "5" ] || [ "$ans2" = "y" ] || [ "$ans2" = "Y" ]; then
      cp -f /opt/zapret/lists/netrogat.txt /opt/netrogat.txt || true
      echo -e "${green}Бэкап netrogat.txt сохранён в /opt/netrogat.txt${plain}"
    fi
  fi

  return 0
}


menu_action_update_config_reset() {
  echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"

  mkdir -p "$CONFIG_ROLLBACK_CACHE_DIR" 2>/dev/null || true
  if [ -f /opt/zapret/config ]; then
    cp -f /opt/zapret/config "$CONFIG_ROLLBACK_FILE"
    echo -e "${green}Создан бэкап текущего config для отката.${plain}"
  fi

  backup_strats

  /opt/zapret/init.d/sysv/zapret stop

  rm -rf /opt/zapret/lists /opt/zapret/extra_strats

  rm -f /opt/zapret/files/fake/http_fake_MS.bin \
        /opt/zapret/files/fake/quic_{1..7}.bin \
        /opt/zapret/files/fake/syn_packet.bin \
        /opt/zapret/files/fake/tls_clienthello_{1..18}.bin \
        /opt/zapret/files/fake/tls_clienthello_2n.bin \
        /opt/zapret/files/fake/tls_clienthello_6a.bin \
        /opt/zapret/files/fake/tls_clienthello_4pda_to.bin

  get_repo

  # Раскомменчивание юзера под keenetic или merlin
  change_user

  ensure_keenetic_policy_config_defaults /opt/zapret/config
  ensure_keenetic_policy_hooks /opt/zapret/config
  build_config_from_strategies /opt/zapret/config.default /opt/zapret/config

  /opt/zapret/init.d/sysv/zapret start

  # ВАЖНО: check_access_list — это по сути интерактивный тест (он сам печатает и может ждать Enter),
  # поэтому лучше вызывать его из get_menu отдельным пунктом ("01"), а не тут.
  # check_access_list

  echo -e "${green}Config файл обновлён. Листы подбора стратегий и исключений сброшены в дефолт, если не просили сохранить. Фейк файлы обновлены.${plain}"
  return 0
}

menu_action_toggle_bolvan_ports() {
  if grep -Eq '^NFQWS_PORTS_UDP=.*443$' "/opt/zapret/config"; then
    sed -i '83s/443$/443,1400,3478-3481,5349,50000-50099,19294-19344/' /opt/zapret/config
    sed -i 's/^--skip --filter-udp=50000/--filter-udp=50000/' "/opt/zapret/config"

    rm -f /opt/zapret/init.d/sysv/custom.d/50-discord-media \
          /opt/zapret/init.d/sysv/custom.d/50-stun4all \
          /opt/zapret/init.d/openwrt/custom.d/50-stun4all \
          /opt/zapret/init.d/openwrt/custom.d/50-discord-media

    echo -e "${green}Уход от скриптов bol-van. Выделены порты 50000-50099,1400,3478-3481,5349${plain}"

  elif grep -q '443,1400,3478-3481,5349,50000-50099,19294-19344$' "/opt/zapret/config"; then
    sed -i 's/443,1400,3478-3481,5349,50000-50099,19294-19344$/443/' /opt/zapret/config
    sed -i 's/^--filter-udp=50000/--skip --filter-udp=50000/' "/opt/zapret/config"

    curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all \
      https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
    curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media \
      https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media

    cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
    cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media

    echo -e "${green}Работа от скриптов bol-van. Вернули строку к виду NFQWS_PORTS_UDP=443 и добавили \"--skip \" в начале строк стратегии войса${plain}"
  else
    echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
    return 0
  fi

  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}Выполнение переключений завершено.${plain}"
  return 0
}

menu_action_toggle_fwtype() {
  if grep -q '^FWTYPE=iptables$' "/opt/zapret/config"; then
    sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config"
    /opt/zapret/install_prereq.sh
    /opt/zapret/init.d/sysv/zapret restart
    echo -e "${green}Zapret moode: nftables.${plain}"

  elif grep -q '^FWTYPE=nftables$' "/opt/zapret/config"; then
    sed -i 's/^FWTYPE=nftables$/FWTYPE=iptables/' "/opt/zapret/config"
    /opt/zapret/install_prereq.sh
    /opt/zapret/init.d/sysv/zapret restart
    echo -e "${green}Zapret moode: iptables.${plain}"

  else
    echo -e "${yellow}Неизвестное состояние строки FWTYPE. Проверь конфиг вручную.${plain}"
  fi

  return 0
}

menu_action_toggle_udp_range() {
  if grep -q '^NFQWS_PORTS_UDP=443' "/opt/zapret/config"; then
    sed -i 's/^NFQWS_PORTS_UDP=443/NFQWS_PORTS_UDP=1026-65531,443/' "/opt/zapret/config"
    sed -i 's/^--skip --filter-udp=1026/--filter-udp=1026/' "/opt/zapret/config"
    echo -e "${green}Стратегия UDP обхода активирована. Выделены порты 1026-65531${plain}"

  elif grep -q '^NFQWS_PORTS_UDP=1026-65531,443' "/opt/zapret/config"; then
    sed -i 's/^NFQWS_PORTS_UDP=1026-65531,443/NFQWS_PORTS_UDP=443/' "/opt/zapret/config"
    sed -i 's/^--filter-udp=1026/--skip --filter-udp=1026/' "/opt/zapret/config"
    echo -e "${green}Стратегия UDP обхода ДЕактивирована. Выделенные порты 1026-65531 убраны${plain}"

  else
    echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
    return 0
  fi

  /opt/zapret/init.d/sysv/zapret restart
  echo -e "${green}Выполнение переключений завершено.${plain}"
  return 0
}
