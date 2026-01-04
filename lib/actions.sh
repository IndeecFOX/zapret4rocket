backup_strats() {
  # Бэкап папки стратегий
  if [ -d /opt/zapret/extra_strats ]; then
    echo -e "${yellow}Сделать бэкап /opt/zapret/extra_strats ?${plain}"
    echo -e "${yellow}5 - Да, Enter - Нет, 0 - отмена и выход в меню${plain}"
    read -r ans
    if [ "$ans" = "0" ]; then
      return 130   # сигнал “отмена/в меню”
    fi
    if [ "$ans" = "5" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      rm -rf /opt/extra_strats 2>/dev/null || true
      cp -rf /opt/zapret/extra_strats /opt/ || true
      echo -e "${green}Бэкап extra_strats сохранён в /opt/extra_strats${plain}"
    fi
  fi

  # Бэкап листа исключений
  if [ -f /opt/zapret/lists/netrogat.txt ]; then
    echo -e "${yellow}Сделать бэкап /opt/zapret/lists/netrogat.txt ?${plain}"
    echo -e "${yellow}5 - Да, Enter - Нет, 0 - отмена и выход в меню${plain}"
    read -r ans2
    if [ "$ans2" = "0" ]; then
      return 130
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

  cp -f /opt/zapret/config.default /opt/zapret/config

  /opt/zapret/init.d/sysv/zapret start

  # ВАЖНО: check_access_list — это по сути интерактивный тест (он сам печатает и может ждать Enter),
  # поэтому лучше вызывать его из get_menu отдельным пунктом ("01"), а не тут.
  # check_access_list

  echo -e "${green}Config файл обновлён. Листы подбора стратегий и исключений сброшены в дефолт, если не просили сохранить. Фейк файлы обновлены.${plain}"
  return 0
}

menu_action_toggle_bolvan_ports() {
  if grep -Eq '^NFQWS_PORTS_UDP=.*443$' "/opt/zapret/config"; then
    sed -i '76s/443$/443,1400,3478-3481,5349,50000-50099,19294-19344/' /opt/zapret/config
    sed -i 's/^--skip --filter-udp=50000/--filter-udp=50000/' "/opt/zapret/config"

    rm -f /opt/zapret/init.d/sysv/custom.d/50-discord-media \
          /opt/zapret/init.d/sysv/custom.d/50-stun4all \
          /opt/zapret/init.d/openwrt/custom.d/50-stun4all \
          /opt/zapret/init.d/openwrt/custom.d/50-discord-media

    echo -e "${green}Уход от скриптов bol-van. Выделены порты 50000-50099,1400,3478-3481,5349 и раскомментированы стратегии DS, WA, TG${plain}"

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
