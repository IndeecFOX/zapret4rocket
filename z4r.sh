#!/bin/bash

set -e

#Переменная содержащая версию на случай невозможности получить информацию о lastest с github
DEFAULT_VER="72.9"

#Чтобы удобнее красить текст
plain='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
pink='\033[0;35m'
cyan='\033[0;36m'
Fplain='\033[1;37m'
Fred='\033[1;31m'
Fgreen='\033[1;32m'
Fyellow='\033[1;33m'
Fblue='\033[1;34m'
Fpink='\033[1;35m'
Fcyan='\033[1;36m'
Bplain='\033[47m'
Bred='\033[41m'
Bgreen='\033[42m'
Byellow='\033[43m'
Bblue='\033[44m'
Bpink='\033[45m'
Bcyan='\033[46m'

#___Проверка на наличие необходимых библиотек___#

#Определяем путь скрипта, подгружаем функции
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# Проверяем наличие всех нужных lib-файлов, иначе запускаем внешний скрипт
missing_libs=0
LIB_DIR="$SCRIPT_DIR/zapret/z4r_lib"
for lib in ui.sh provider.sh telemetry.sh recommendations.sh netcheck.sh premium.sh strategies.sh submenus.sh actions.sh; do
  if [ ! -f "$LIB_DIR/$lib" ]; then
    missing_libs=1
    break
  fi
done

if [ "$missing_libs" -ne 0 ]; then
  echo "Не найдены нужные файлы в $LIB_DIR. Запускаю внешний z4r..."
  if which curl >/dev/null 2>&1; then
    exec sh -c 'curl -fsSL "https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r" | sh'
  elif which wget >/dev/null 2>&1; then
    exec sh -c 'wget -qO- "https://raw.githubusercontent.com/IndeecFOX/z4r/main/z4r" | sh'
  else
    echo "Ошибка: нет curl или wget для загрузки внешнего z4r."
    exit 1
  fi
fi

#___Сначала идут анонсы функций____

# UI helpers (пауза/печать пунктов меню/совместимость старого кода)
# Функции: pause_enter, submenu_item, exit_to_menu
source "$SCRIPT_DIR/zapret/z4r_lib/ui.sh" 

# Определение провайдера/города + ручная установка/сброс кэша
# Функции: provider_init_once, provider_force_redetect, provider_set_manual_menu
# (внутр.: _detect_api_simple)
source "$SCRIPT_DIR/zapret/z4r_lib/provider.sh" 

# Телеметрия (вкл/выкл один раз + отправка статистики в Google Forms)
# Функции: init_telemetry, send_stats
source "$SCRIPT_DIR/zapret/z4r_lib/telemetry.sh" 

# База подсказок по стратегиям (скачивание + вывод подсказки по провайдеру)
# Функции: update_recommendations, show_hint
source "$SCRIPT_DIR/zapret/z4r_lib/recommendations.sh" 

# Проверка доступности ресурсов/сети (TLS 1.2/1.3) + получение домена кластера youtube (googlevideo)
# Функции: get_yt_cluster_domain, check_access, check_access_list
source "$SCRIPT_DIR/zapret/z4r_lib/netcheck.sh"

# "Premium" пункты 777/999 и их вспомогательные эффекты (рандом, спиннер, титулы)
# Функции: rand_from_list, spinner_for_seconds, premium_get_or_set_title, zefeer_premium_777, zefeer_space_999
source "$SCRIPT_DIR/zapret/z4r_lib/premium.sh" 

# Логика стратегий: определение активной стратегии, статус строкой, перебор стратегий, быстрый подбор
# Функции: get_active_strat_num, get_current_strategies_info, try_strategies, Strats_Tryer
source "$SCRIPT_DIR/zapret/z4r_lib/strategies.sh" 

# Подменю (UI-обвязка над Strats_Tryer + доп. меню управления: FLOWOFFLOAD, TCP443, провайдер)
# Функции: strategies_submenu, flowoffload_submenu, tcp443_submenu, provider_submenu
source "$SCRIPT_DIR/zapret/z4r_lib/submenus.sh" 

# Действия меню (бэкапы/сбросы/переключатели)
# Функции: backup_strats, menu_action_update_config_reset, menu_action_toggle_bolvan_ports,
#          menu_action_toggle_fwtype, menu_action_toggle_udp_range
source "$SCRIPT_DIR/zapret/z4r_lib/actions.sh" 

change_user() {
   if /opt/zapret/nfq/nfqws --dry-run --user="nobody" 2>&1 | grep -q "queue"; then
    echo "WS_USER=nobody"
    sed -i 's/^#\(WS_USER=nobody\)/\1/' /opt/zapret/config.default
   elif /opt/zapret/nfq/nfqws --dry-run --user="$(head -n1 /etc/passwd | cut -d: -f1)" 2>&1 | grep -q "queue"; then
    echo "WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)"
    sed -i "s/^#WS_USER=nobody$/WS_USER=$(head -n1 /etc/passwd | cut -d: -f1)/" "/opt/zapret/config.default"
   else
    echo -e "${yellow}WS_USER не подошёл. Скорее всего будут проблемы. Если что - пишите в саппорт${plain}"
   fi
}

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo() {
 mkdir -p /opt/zapret/lists /opt/zapret/extra_strats/TCP/{RKN,User,YT,temp,GV} /opt/zapret/extra_strats/UDP/YT
 for listfile in netrogat.txt russia-discord.txt russia-youtube-rtmps.txt russia-youtube.txt russia-youtubeQ.txt tg_cidr.txt; do curl -L -o /opt/zapret/lists/$listfile https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/$listfile; done
 curl -L "https://github.com/IndeecFOX/zapret4rocket/raw/master/fake_files.tar.gz" | tar -xz -C /opt/zapret/files/fake
 curl -L -o /opt/zapret/extra_strats/UDP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/UDP/YT/List.txt
 curl -L -o /opt/zapret/extra_strats/TCP/RKN/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt
 curl -L -o /opt/zapret/extra_strats/TCP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/YT/List.txt
 touch /opt/zapret/lists/autohostlist.txt /opt/zapret/extra_strats/UDP/YT/{1..8}.txt /opt/zapret/extra_strats/TCP/RKN/{1..17}.txt /opt/zapret/extra_strats/TCP/User/{1..17}.txt /opt/zapret/extra_strats/TCP/YT/{1..17}.txt /opt/zapret/extra_strats/TCP/GV/{1..17}.txt /opt/zapret/extra_strats/TCP/temp/{1..17}.txt
 if [ -d /opt/extra_strats ]; then
  rm -rf /opt/zapret/extra_strats
  mv /opt/extra_strats /opt/zapret/
  echo "Восстановление настроек подбора из резерва выполнено."
 fi
 if [ -f "/opt/netrogat.txt" ]; then
   mv -f /opt/netrogat.txt /opt/zapret/lists/netrogat.txt
   echo "Восстановление листа исключений выполнено."
 fi
 #Копирование нашего конфига на замену стандартному и скриптов для войсов DS, WA, TG
 curl -L -o /opt/zapret/config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
 if which nft >/dev/null 2>&1; then
  sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config.default"
 fi
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-stun4all https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
 curl -L -o /opt/zapret/init.d/sysv/custom.d/50-discord-media https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media
 cp -f /opt/zapret/init.d/sysv/custom.d/50-stun4all /opt/zapret/init.d/openwrt/custom.d/50-stun4all
 cp -f /opt/zapret/init.d/sysv/custom.d/50-discord-media /opt/zapret/init.d/openwrt/custom.d/50-discord-media

# cache
mkdir -p /opt/zapret/extra_strats/cache

}

#Удаление старого запрета, если есть
remove_zapret() {
 if [ -f "/opt/zapret/init.d/sysv/zapret" ] && [ -f "/opt/zapret/config" ]; then
    /opt/zapret/init.d/sysv/zapret stop
 fi
 if [ -f "/opt/zapret/config" ] && [ -f "/opt/zapret/uninstall_easy.sh" ]; then
     echo "Выполняем zapret/uninstall_easy.sh"
     sh /opt/zapret/uninstall_easy.sh
     echo "Скрипт uninstall_easy.sh выполнен."
 else
     echo "zapret не инсталлирован в систему. Переходим к следующему шагу."
 fi
 if [ -d "/opt/zapret" ]; then
     echo "Удаляем папку zapret"
     rm -rf /opt/zapret
 else
     echo "Папка zapret не существует."
 fi
 if [[ "$OSystem" == "entware" ]]; then
	rm -fv /opt/etc/init.d/S90-zapret /opt/etc/ndm/netfilter.d/000-zapret.sh /opt/etc/init.d/S00fix
 fi
 read -re -p $'\033[33mУдалить функционал доступа в меню через браузер (web-ssh)? Enter - Да, 1 - нет\033[0m\n' ttyd_answer_del
 case "$ttyd_answer_del" in
    "1")
        echo "Пропущено"
    ;;
    *)
		apk del ttyd 2>/dev/null || true
		opkg remove ttyd 2>/dev/null || true
		rm -f /usr/bin/ttyd
		echo "Процесс удаления завершён"
    ;;
 esac 
}

#Запрос желаемой версии zapret
version_select() {
   while true; do
    read -re -p $'\033[0;32mВведите желаемую версию zapret (Enter для новейшей версии): \033[0m' VER
    # Если пустой ввод — берем значение по умолчанию
    if [ -z "$VER" ]; then
        lastest_release="https://api.github.com/repos/bol-van/zapret/releases/latest"
        # проверяем результаты по порядку
        echo -e "${yellow}Поиск последней версии...${plain}"
        VER1=$(curl -sL $lastest_release | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
        if [ ${#VER1} -ge 2 ]; then
            VER="$VER1"
            echo -e "${green}Выбрано: $VER (метод: sed -E)${plain}"
        else
            VER2=$(curl -sL $lastest_release | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
            if [ ${#VER2} -ge 2 ]; then
                VER="$VER2"
                echo -e "${green}Выбрано: $VER (метод: grep+cut)${plain}"
            else
                VER3=$(curl -sL $lastest_release | grep '"tag_name":' | sed -r 's/.*"v([^"]+)".*/\1/')
                if [ ${#VER3} -ge 2 ]; then
                    VER="$VER3"
                    echo -e "${green}Выбрано: $VER (метод: sed -r)${plain}"
                else
                    VER4=$(curl -sL $lastest_release | grep '"tag_name":' | awk -F'"' '{print $4}' | sed 's/^v//')
                    if [ ${#VER4} -ge 2 ]; then
                        VER="$VER4"
                        echo -e "${green}Выбрано: $VER (метод: awk)${plain}"
                    else
                        echo -e "${yellow}Не удалось получить информацию о последней версии с GitHub. Будет использоваться версия $DEFAULT_VER.${plain}"
                        VER="$DEFAULT_VER"
                    fi
                fi
            fi
        fi
        break
    fi
    #Считаем длину
    LEN=${#VER}
    #Проверка длины и простая валидация формата (цифры и точки)
    if [ "$LEN" -gt 4 ]; then
        echo "Некорректный ввод. Максимальная длина — 4 символа. Попробуйте снова."
        continue
    elif ! echo "$VER" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
        echo "Некорректный формат версии. Пример: 72.3"
        continue
    fi
    echo "Будет использоваться версия: $VER"
    break
done
}

#Скачивание, распаковка архива zapret, очистка от ненужных бинарей
zapret_get() {
 if [[ "$OSystem" == "VPS" ]]; then
     tarfile="zapret-v$VER.tar.gz"
 else
     tarfile="zapret-v$VER-openwrt-embedded.tar.gz"
 fi
 curl -L "https://github.com/bol-van/zapret/releases/download/v$VER/$tarfile" | tar -xz
 mv "zapret-v$VER" zapret
 sh /tmp/zapret/install_bin.sh
 find /tmp/zapret/binaries/* -maxdepth 0 -type d ! -name "$(basename "$(dirname "$(readlink /tmp/zapret/nfq/nfqws)")")" -exec rm -rf {} +
 mv zapret /opt/zapret
}

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot() {
 sh -i /opt/zapret/install_easy.sh
 /opt/zapret/init.d/sysv/zapret restart
 if pidof nfqws >/dev/null; then
  check_access_list
  echo -e "\033[32mzapret перезапущен и полностью установлен\n\033[33mЕсли требуется меню (например не работают какие-то ресурсы) - введите скрипт ещё раз или просто напишите "z4r" в терминале. Саппорт: tg: zee4r\033[0m"
 else
  echo -e "${yellow}zapret полностью установлен, но не обнаружен после запуска в исполняемых задачах через pidof\nСаппорт: tg: zee4r${plain}"
 fi
}

#Для Entware Keenetic + merlin
entware_fixes() {
 if [ "$hardware" = "keenetic" ]; then
  curl -L -o /opt/zapret/init.d/sysv/zapret https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/zapret
  chmod +x /opt/zapret/init.d/sysv/zapret
  echo "Права выданы /opt/zapret/init.d/sysv/zapret"
  curl -L -o /opt/etc/ndm/netfilter.d/000-zapret.sh https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/000-zapret.sh
  chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh
  echo "Права выданы /opt/etc/ndm/netfilter.d/000-zapret.sh"
  curl -L -o /opt/etc/init.d/S00fix https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/S00fix
  chmod +x /opt/etc/init.d/S00fix
  echo "Права выданы /opt/etc/init.d/S00fix"
  cp -a /opt/zapret/init.d/custom.d.examples.linux/10-keenetic-udp-fix /opt/zapret/init.d/sysv/custom.d/10-keenetic-udp-fix
  echo "10-keenetic-udp-fix скопирован"
 elif [ "$hardware" = "merlin" ]; then
  if sed -n '167p' /opt/zapret/install_easy.sh | grep -q '^nfqws_opt_validat'; then
    sed -i '172s/return 1/return 0/' /opt/zapret/install_easy.sh
  fi
  FW="/jffs/scripts/firewall-start"
  if [ ! -f "$FW" ]; then
    echo "$FW не найден, пропускаю добавление правила"
  else
    grep -qxF '/opt/zapret/init.d/sysv/zapret restart' "$FW" || echo '/opt/zapret/init.d/sysv/zapret restart' >> "$FW"
    chmod +x /jffs/scripts/firewall-start
  fi
 fi
 
 sh /opt/zapret/install_bin.sh
 
 # #Раскомменчивание юзера под keenetic или merlin
 change_user
 #Патчинг на некоторых merlin /opt/zapret/common/linux_fw.sh
 if which sysctl >/dev/null 2>&1; then
  echo "sysctl доступен. Патч linux_fw.sh не требуется"
 else
  echo "sysctl отсутствует. MerlinWRT? Патчим /opt/zapret/common/linux_fw.sh"
  sed -i 's|sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=\$1|echo \$1 > /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal|' /opt/zapret/common/linux_fw.sh
  sed -i 's|sysctl -q -w net.ipv4.conf.\$1.route_localnet="\$enable"|echo "\$enable" > /proc/sys/net/ipv4/conf/\$1/route_localnet|' /opt/zapret/common/linux_iphelper.sh
 fi
 #sed для пропуска запроса на прочтение readme, т.к. система entware. Дабы скрипт отрабатывал далее на Enter
 sed -i 's/if \[ -n "\$1" \] || ask_yes_no N "do you want to continue";/if true;/' /opt/zapret/common/installer.sh
 ln -fs /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S90-zapret
 echo "Добавлено в автозагрузку: /opt/etc/init.d/S90-zapret > /opt/zapret/init.d/sysv/zapret"
}

#Alpine Linux fixes
alpine_fixes() {
    echo -e "${yellow}Применяем исправления для Alpine Linux...${plain}"
    
    # Устанавливаем необходимые пакеты
    apk update
    apk add --no-cache coreutils grep gzip ipset xtables-addons nftables
    
    # Проверяем наличие nftables
    if which nft >/dev/null 2>&1; then
        echo "nftables доступен"
        apk add nftables
    fi
    
    # Создаем необходимые симлинки для совместимости
    if [ ! -f /usr/sbin/ip ] && [ -f /sbin/ip ]; then
        ln -sf /sbin/ip /usr/sbin/ip
    fi
    
    if [ ! -f /usr/sbin/iptables ] && [ -f /sbin/iptables ]; then
        ln -sf /sbin/iptables /usr/sbin/iptables
    fi
    
    # Патчим скрипты для работы с OpenRC
    if [ -f /opt/zapret/install_easy.sh ]; then
        # Заменяем sysctl на прямой запись в /proc/sys
        sed -i 's|sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=\$1|echo \$1 > /proc/sys/net/netfilter/nf_conntrack_tcp_be_liberal|' /opt/zapret/common/linux_fw.sh 2>/dev/null || true
        sed -i 's|sysctl -q -w net.ipv4.conf.\$1.route_localnet="\$enable"|echo "\$enable" > /proc/sys/net/ipv4/conf/\$1/route_localnet|' /opt/zapret/common/linux_iphelper.sh 2>/dev/null || true
    fi
    
    # Добавляем zapret в автозагрузку через OpenRC
    if [ -d /etc/init.d ]; then
        ln -sf /opt/zapret/init.d/sysv/zapret /etc/init.d/zapret 2>/dev/null || true
        rc-update add zapret default 2>/dev/null || echo "Не удалось добавить zapret в автозагрузку OpenRC"
    fi
    
    echo -e "${green}Исправления для Alpine Linux применены${plain}"
}

#Запрос на установку 3x-ui или аналогов
get_panel() {
 read -re -p $'\033[33mУстановить ПО для туннелирования?\033[0m \033[32m(3xui, marzban, wg, 3proxy или Enter для пропуска): \033[0m' answer_panel
 # Удаляем лишние символы и пробелы, приводим к верхнему регистру
 clean_answer=$(echo "$answer_panel" | tr '[:lower:]' '[:upper:]')
 if [[ -z "$clean_answer" ]]; then
     echo "Пропуск установки ПО туннелирования."
 elif [[ "$clean_answer" == "3XUI" ]]; then
     echo "Установка 3x-ui панели."
     bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
 elif [[ "$clean_answer" == "WG" ]]; then
     echo "Установка WG (by angristan)"
     bash <(curl -Ls https://raw.githubusercontent.com/angristan/wireguard-install/refs/heads/master/wireguard-install.sh)
 elif [[ "$clean_answer" == "3PROXY" ]]; then
     echo "Установка 3proxy (by SnoyIatk). Доустановка с apt build-essential для сборки (debian/ubuntu)"
	if which apt >/dev/null 2>&1; then
 	   apt update && apt install build-essential -y
	elif which apk >/dev/null 2>&1; then
  	  apk update && apk add build-base
	fi
    bash <(curl -Ls https://raw.githubusercontent.com/SnoyIatk/3proxy/master/3proxyinstall.sh)
    curl -L -o /etc/3proxy/.proxyauth https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/del.proxyauth
    curl -L -o /etc/3proxy/3proxy.cfg https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/3proxy.cfg
 elif [[ "$clean_answer" == "MARZBAN" ]]; then
     echo "Установка Marzban"
     bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
 else
     echo "Пропуск установки ПО туннелирования."
 fi
}

hosters_check() {
	BIN_THR_BYTES=$((24*1024))
	PARALLEL=25

	TESTS=(
	"US.CF-01|🇺🇸 Cloudflare|$BIN_THR_BYTES|1|https://img.wzstats.gg/cleaver/gunFullDisplay"
	"US.CF-02|🇺🇸 Cloudflare|104319|1|https://genshin.jmp.blue/characters/all#"
	"US.CF-03|🇺🇸 Cloudflare|109863|1|https://api.frankfurter.dev/v1/2000-01-01..2002-12-31"
	"US.CF-04|🇨🇦 Cloudflare|79655|1|https://www.bigcartel.com/"
	"US.DO-01|🇺🇸 DigitalOcean|195612|2|https://genderize.io/"
	"DE.HE-01|🇩🇪 Hetzner|$BIN_THR_BYTES|1|https://j.dejure.org/jcg/doctrine/doctrine_banner.webp"
	"DE.HE-02|🇩🇪 Hetzner|162646|1|https://accesorioscelular.com/tienda/css/plugins.css"
	"FI.HE-01|🇫🇮 Hetzner|$BIN_THR_BYTES|1|https://251b5cd9.nip.io/1MB.bin"
	"FI.HE-02|🇫🇮 Hetzner|$BIN_THR_BYTES|1|https://nioges.com/libs/fontawesome/webfonts/fa-solid-900.woff2"
	"FI.HE-03|🇫🇮 Hetzner|$BIN_THR_BYTES|1|https://5fd8bdae.nip.io/1MB.bin"
	"FI.HE-04|🇫🇮 Hetzner|$BIN_THR_BYTES|1|https://5fd8bca5.nip.io/1MB.bin"
	"FR.OVH-01|🇫🇷 OVH|75872|1|https://eu.api.ovh.com/console/rapidoc-min.js"
	"FR.OVH-02|🇫🇷 OVH|$BIN_THR_BYTES|1|https://ovh.sfx.ovh/10M.bin"
	"SE.OR-01|🇸🇪 Oracle|$BIN_THR_BYTES|1|https://oracle.sfx.ovh/10M.bin"
	"DE.AWS-01|🇩🇪 AWS|$BIN_THR_BYTES|1|https://www.getscope.com/assets/fonts/fa-solid-900.woff2"
	"US.AWS-01|🇺🇸 AWS|215419|1|https://corp.kaltura.com/wp-content/cache/min/1/wp-content/themes/airfleet/dist/styles/theme.css"
	"US.GC-01|🇺🇸 Google Cloud|176277|1|https://api.usercentrics.eu/gvl/v3/en.json"
	"US.FST-01|🇺🇸 Fastly|77597|1|https://www.jetblue.com/footer/footer-element-es2015.js"
	"CA.FST-01|🇨🇦 Fastly|84086|1|https://ssl.p.jwpcdn.com/player/v/8.40.5/bidding.js"
	"US.AKM-01|🇺🇸 Akamai|$BIN_THR_BYTES|1|https://www.roxio.com/static/roxio/images/products/creator/nxt9/call-action-footer-bg.jpg"
	"PL.AKM-01|🇵🇱 Akamai|$BIN_THR_BYTES|1|https://media-assets.stryker.com/is/image/stryker/gateway_1?\$max_width_1410\$"
	"US.CDN77-01|🇺🇸 CDN77|$BIN_THR_BYTES|1|https://cdn.eso.org/images/banner1920/eso2520a.jpg"
	"FR.CNTB-01|🇫🇷 Contabo|$BIN_THR_BYTES|1|https://xdmarineshop.gr/index.php?route=index"
	"NL.SW-01|🇳🇱 Scaleway|$BIN_THR_BYTES|1|https://www.velivole.fr/img/header.jpg"
	"US.CNST-01|🇺🇸 Constant|$BIN_THR_BYTES|1|https://cdn.xuansiwei.com/common/lib/font-awesome/4.7.0/fontawesome-webfont.woff2?v=4.7.0"
	)

	echo -e "${yellow}Проверка 16кб блока хостеров:"
	check_one() {
		IFS='|' read -r id provider thr times url <<< "$1"

		total=0
		code=0

		for ((i=1;i<=times;i++)); do
			read bytes code <<< $(curl -L -s \
				-H "Range: bytes=0-${thr}" \
				--connect-timeout 5 \
				--max-time 5 -o /dev/null -w '%{size_download} %{http_code}' "$url")

			total=$((total+bytes))
		done

		avg=$((total/times))

		if (( avg >= thr )) && [[ "$code" =~ ^2|3 ]]; then
			echo -e "\033[0;32m$id OK${plain} ${avg}b [$provider]"
			echo OK >> /tmp/cdn_ok
		else
			echo -e "\033[0;31m$id FAIL${plain} ${avg}b code=$code [$provider]"
			echo FAIL >> /tmp/cdn_fail
		fi
	}

	export -f check_one

	rm -f /tmp/cdn_ok /tmp/cdn_fail

	printf "%s\n" "${TESTS[@]}" | xargs -I{} -P "$PARALLEL" bash -c 'check_one "$@"' _ {}

	OK_COUNT=$( [ -f /tmp/cdn_ok ] && wc -l < /tmp/cdn_ok || echo 0 )
	FAIL_COUNT=$( [ -f /tmp/cdn_fail ] && wc -l < /tmp/cdn_fail || echo 0 )

	echo
	echo -e "${yellow}=== SUMMARY ===${plain}"
	echo -e "${green}OK:${plain} ${OK_COUNT:-0}"
	echo -e "${red}FAIL:${plain} ${FAIL_COUNT:-0}"
}

#webssh ttyd
ttyd_webssh() {
 echo -e $'\033[33mВведите логин для доступа к zeefeer через браузер (0 - отказ от логина через web в z4r и переход на логин в ssh (может помочь в safari). Enter - пустой логин, \033[31mно не рекомендуется, панель может быть доступна из интернета!)\033[0m'
 read -re -p '' ttyd_login
 echo -e "${yellow}Если вы открыли пункт через браузер - вас выкинет. Используйте SSH для установки${plain}"
 
 ttyd_login_have="-c "${ttyd_login}": bash z4r"
 if [[ "$ttyd_login" == "0" ]]; then
    echo "Отключение логина в веб. Перевод с z4r на CLI логин."
    ttyd_login_have="login"
 fi
 
 if [[ "$OSystem" == "VPS" ]]; then
    echo -e "${yellow}Установка ttyd for VPS/LinuxOS${plain}"
    systemctl stop ttyd 2>/dev/null || true
    # Для Alpine используем apk, для других - скачиваем бинарник
    if which apk >/dev/null 2>&1; then
        apk add ttyd
    else
        curl -L -o /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64
        chmod +x /usr/bin/ttyd
    fi
    
    # Для Alpine (OpenRC)
    if [[ "$release" == "alpine" ]]; then
        cat > /etc/init.d/ttyd <<EOF
#!/sbin/openrc-run

name="ttyd"
description="ttyd WebSSH Service"
command="/usr/bin/ttyd"
command_args="-p 17681 -W -a ${ttyd_login_have}"
command_background=true
pidfile="/run/\${RC_SVCNAME}.pid"
output_log="/var/log/ttyd.log"
error_log="/var/log/ttyd.err"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath -d -m 0755 -o root:root /run
}

start_post() {
    echo "ttyd started on port 17681"
}

stop_post() {
    echo "ttyd stopped"
}
EOF
        chmod +x /etc/init.d/ttyd
        rc-update add ttyd default
        rc-service ttyd start
    else
        # Для systemd
        cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd WebSSH Service
After=network.target

[Service]
ExecStart=/usr/bin/ttyd -p 17681 -W -a ${ttyd_login_have}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ttyd
        systemctl start ttyd
    fi
 elif [[ "$OSystem" == "WRT" ]]; then
    echo -e "${yellow}Установка ttyd for WRT${plain}"
    /etc/init.d/ttyd stop 2>/dev/null || true
    if which opkg >/dev/null 2>&1; then
        opkg install ttyd 2>/dev/null
    elif which apk >/dev/null 2>&1; then
        apk add ttyd 2>/dev/null
    fi
    if [ -f /etc/config/ttyd ]; then
        uci set ttyd.@ttyd[0].interface=''
        uci set ttyd.@ttyd[0].command="-p 17681 -W -a ${ttyd_login_have}"
        uci commit ttyd
    fi
    if [ -f /etc/init.d/ttyd ]; then
        /etc/init.d/ttyd enable
        /etc/init.d/ttyd start
    else
        echo "ttyd init скрипт не найден"
    fi
 elif [[ "$OSystem" == "entware" ]]; then
    echo -e "${yellow}Установка ttyd for Entware${plain}"
    /opt/etc/init.d/S99ttyd stop 2>/dev/null || true
    if which opkg >/dev/null 2>&1; then
        opkg install ttyd 2>/dev/null
    elif which apk >/dev/null 2>&1; then
        apk add ttyd 2>/dev/null
    fi
    
    cat > /opt/etc/init.d/S99ttyd <<EOF
#!/bin/sh

START=99

case "\$1" in
  start)
    echo "Starting ttyd..."
    ttyd -p 17681 -W -a ${ttyd_login_have} &
    ;;
  stop)
    echo "Stopping ttyd..."
    killall ttyd
    ;;
  restart)
    \$0 stop
    sleep 1
    \$0 start
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart}"
    exit 1
    ;;
esac
EOF

  chmod +x /opt/etc/init.d/S99ttyd
  /opt/etc/init.d/S99ttyd start
  sleep 1
  if netstat -tuln 2>/dev/null | grep -q ':17681'; then
    echo -e "${green}Порт 17681 для службы ttyd слушается${plain}"
  else
    echo -e "${red}Порт 17681 для службы ttyd не прослушивается${plain}"
  fi
 fi

 if pidof ttyd >/dev/null; then
    echo -e "Проверка...${green}Служба ttyd запущена.${plain}"
 else
    echo -e "Проверка...${red}Служба ttyd не запущена! Если у вас Entware, то после перезагрузки роутера служба скорее всего заработает!${plain}"
 fi
 echo -e "${plain}Выполнение установки завершено. ${green}Доступ по ip вашего роутера/VPS в формате ip:17681, например 192.168.1.1:17681 или mydomain.com:17681 ${yellow}логин: ${ttyd_login} пароль - не используется.${plain} Был выполнен выход из скрипта для сохранения состояния."
}

#Меню, проверка состояний и вывод с чтением ответа
get_menu() {
    TITLE_MENU_LINE=""
    if [[ -s "$PREMIUM_TITLE_FILE" ]]; then
      TITLE_MENU_LINE="\n${pink}Титул:${plain} $(cat "$PREMIUM_TITLE_FILE")${yellow}\n"
    fi
    provider_init_once
    init_telemetry
    update_recommendations  
  while true; do
    local strategies_status
    strategies_status=$(get_current_strategies_info)
    TITLE_MENU_LINE=""
    if [[ -s "$PREMIUM_TITLE_FILE" ]]; then
      TITLE_MENU_LINE="\n${pink}Титул:${plain} $(cat "$PREMIUM_TITLE_FILE")${yellow}\n"
    fi
    #clear
    echo -e '
░░░▀▀█░█▀▀░█▀▀░█▀▀░█▀▀░█▀▀░█▀▄░░░
░░░▄▀░░█▀▀░█▀▀░█▀▀░█▀▀░█▀▀░█▀▄░░░
░░░▀▀▀░▀▀▀░▀▀▀░▀░░░▀▀▀░▀▀▀░▀░▀░░░

'"Город/провайдер: ${plain}${PROVIDER_MENU}${yellow}"'
'"${TITLE_MENU_LINE}"'
'"${green}"'Выберите необходимое действие:'"${yellow}"'
'"${cyan}"'Enter'"${yellow}"' (без цифр) - переустановка/обновление zapret
'"${cyan}"'0'"${yellow}"'. Выход
'"${cyan}"'01'"${yellow}"'. Проверить доступность сервисов (Тест не всегда точен). '"${cyan}"'001'"${yellow}"' - проверка 16кб блока зарубежных хостеров (актуально для безразборного режима)
'"${cyan}"'1'"${yellow}"'. Сменить стратегии или добавить домен в хост-лист. Текущие: '"${plain}"'[ '"${strategies_status}"' ]'"${yellow}"'
'"${cyan}"'2'"${yellow}"'. Стоп/пере(запуск) zapret (сейчас: '"$(pidof nfqws >/dev/null && echo "${green}Запущен${yellow}" || echo "${red}Остановлен${yellow}")"') Для restart введите '"${cyan}"'22'"${yellow}"'
'"${cyan}"'3'"${yellow}"'. Показать домены которые zapret посчитал не доступными
'"${cyan}"'4'"${yellow}"'. Удалить zapret
'"${cyan}"'5'"${yellow}"'. Обновить стратегии, сбросить листы подбора стратегий и исключений (есть бэкап)
'"${cyan}"'6'"${yellow}"'. Исключить домен из zapret обработки
'"${cyan}"'7'"${yellow}"'. Открыть в редакторе config (Установит nano редактор ~250kb)
'"${cyan}"'8'"${yellow}"'. Преключатель скриптов bol-van обхода войсов DS,WA,TG на стандартные страты или возврат к скриптам. Сейчас: '"${plain}"'['"$(grep -Eq '^NFQWS_PORTS_UDP=.*443$' /opt/zapret/config && echo "Скрипты" || (grep -Eq '443,1400,3478-3481,5349,50000-50099,19294-19344$' /opt/zapret/config && echo "Классические стратегии" || echo "Неизвестно"))"']'"${yellow}"'
'"${cyan}"'9'"${yellow}"'. Переключатель zapret на nftables/iptables (На всё жать Enter). Актуально для OpenWRT 21+. Может помочь с войсами. Сейчас: '"${plain}"'['"$(grep -q '^FWTYPE=iptables$' /opt/zapret/config && echo "iptables" || (grep -q '^FWTYPE=nftables$' /opt/zapret/config && echo "nftables" || echo "Неизвестно"))"']'"${yellow}"'
'"${cyan}"'10'"${yellow}"'. (Де)активировать обход UDP на 1026-65531 портах (BF6, Fifa и т.п.). Сейчас: '"${plain}"'['"$(grep -q '^NFQWS_PORTS_UDP=443' /opt/zapret/config && echo "Выключен" || (grep -q '^NFQWS_PORTS_UDP=1026-65531,443' /opt/zapret/config && echo "Включен" || echo "Неизвестно"))"']'"${yellow}"'
'"${cyan}"'11'"${yellow}"'. Управление аппаратным ускорением zapret. Может увеличить скорость на роутере. Сейчас: '"${plain}"'['"$(grep '^FLOWOFFLOAD=' /opt/zapret/config)"']'"${yellow}"'
'"${cyan}"'12'"${yellow}"'. Меню (Де)Активации работы по всем доменам TCP-443 без хост-листов (не затрагивает youtube стратегии) (безразборный режим) Сейчас: '"${plain}"'['"$(num=$(sed -n '112,128p' /opt/zapret/config | grep -n '^--filter-tcp=443 --hostlist-domains= --' | head -n1 | cut -d: -f1); [ -n "$num" ] && echo "$num" || echo "Отключен")"']'"${yellow}"'
'"${cyan}"'13'"${yellow}"'. Активировать доступ в меню через браузер (web-ssh) (~3мб места)
'"${cyan}"'14'"${yellow}"'. Сменить sni fake-файла для дефолтной стратегии РКН-листа и 2,4,12 стратегий. Сейчас:'"${plain}[$(grep -oE '=sni=[^[:space:]]+ --' /opt/zapret/config | tail -n1 | cut -d= -f3 | cut -d' ' -f1)]${yellow}"' (дефолтный sni: ilovepdf.com)
'"${cyan}"'15'"${yellow}"'. Провайдер (Поверхностные рекомендации стратетий)
'"${cyan}"'777'"${yellow}"'. Активировать zeefeer premium (Нажимать только Valery ProD, avg97, Xoz, GeGunT, blagodarenya, mikhyan, Xoz, andric62, Whoze, Necronicle, Andrei_5288515371, Nomand, Dina_turat, Nergalss, Александру, АлександруП, vecheromholodno, ЕвгениюГ, Dyadyabo, skuwakin, izzzgoy, Grigaraz, Reconnaissance, comandante1928, umad, rudnev2028, rutakote, railwayfx, vtokarev1604, Grigaraz, a40letbezurojaya и subzeero452 и остальным поддержавшим проект. Но если очень хочется - можно нажать и другим)\033[0m'
    if [[ -f "$PREMIUM_FLAG" ]]; then
      echo -e "${red}999. Секретный пункт. Нажимать на свой страх и риск${plain}"
    fi
  read -re -p "" answer_menu
    case "$answer_menu" in
  "")
    echo -e "${yellow}Вы уверены, что хотите переустановить/обновить zapret?${plain}"
    echo -e "${yellow}5 - Да, Enter/0 - Нет (вернуться в меню)${plain}"
    read -r ans
    if [ "$ans" = "5" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      # подтверждение: выходим из get_menu и уходим в "тело" (переустановка/обновление)
      return 0
    else
      # отмена: остаёмся в меню, цикл while true продолжится
      :
    fi
    ;;

  "0")
    echo "Выход выполнен"
    exit 0
    ;;

  "01")
    check_access_list
    pause_enter
    ;;

  "001")
    hosters_check
    pause_enter
    ;;

  "1")
    echo "Режим подбора других стратегий"
    strategies_submenu     # strategies_submenu сам в цикле и выходит через return
    ;;

  "2")
    if pidof nfqws >/dev/null; then
      /opt/zapret/init.d/sysv/zapret stop
      echo -e "${green}Выполнена команда остановки zapret${plain}"
    else
      /opt/zapret/init.d/sysv/zapret restart
      echo -e "${green}Выполнена команда перезапуска zapret${plain}"
    fi
    pause_enter
    ;;

  "3")
    cat /opt/zapret/lists/autohostlist.txt
    pause_enter
    ;;

  "4")
    remove_zapret
    echo -e "${yellow}zapret удалён${plain}"
    pause_enter
    ;;

  "5")
    menu_action_update_config_reset
    pause_enter
    ;;

  "6")
    read -re -p "Показать список доменов в исключениях? 1 - да, enter - нет: " open_netrogat
    if [ "$open_netrogat" == "1" ]; then
        cat /opt/zapret/lists/netrogat.txt
        open_netrogat=""
    fi
    echo "Через пробел можно указывать сразу несколько доменов"
    read -re -p "Введите домен, который добавить в исключения (например: test.com или https://test.com/ или 0 для выхода): " user_domain
    user_domain=$(sed -E 's~https?://~~g; s~([^[:space:]]+)/~\1~g' <<< "$user_domain")
    user_domain="$(echo "$user_domain" | sed 's/[[:space:]]\+/\n/g')"
    if [ "$user_domain" == "0" ] ; then
     echo "Ввод отменён"
    elif [ -n "$user_domain" ]; then
      echo "$user_domain" >> /opt/zapret/lists/netrogat.txt
      echo -e "Домен ${yellow}$user_domain${plain} добавлен в исключения (netrogat.txt)."
    else
      echo "Ввод пустой, ничего не добавлено"
    fi
    pause_enter
    ;;

  "7")
    if [[ "$OSystem" == "VPS" ]]; then
      if which apt >/dev/null 2>&1; then
        apt install nano -y
      elif which apk >/dev/null 2>&1; then
        apk add nano
      fi
    else
      if which opkg >/dev/null 2>&1; then
        opkg remove nano 2>/dev/null
        opkg install nano-full 2>/dev/null
      elif which apk >/dev/null 2>&1; then
        apk del nano 2>/dev/null
        apk add nano 2>/dev/null
      fi
    fi
    nano /opt/zapret/config
    # после выхода из nano
    ;;

  "8")
    menu_action_toggle_bolvan_ports
    pause_enter
    ;;

  "9")
    menu_action_toggle_fwtype
    pause_enter
    ;;

  "10")
    menu_action_toggle_udp_range
    pause_enter
    ;;

  "11")
    flowoffload_submenu   # сабменю само в цикле и выходит через return
    ;;

  "12")
    tcp443_submenu        # сабменю само в цикле и выходит через return
    ;;

  "13")
    ttyd_webssh
    pause_enter
    ;;

  "14")
    read -re -p "Введите новый SNI для fake файла или Enter для выхода без изменений: " NEW_SNI
	if [[ -z "$NEW_SNI" ]]; then
		echo "Пустой ввод. Изменений не будет."
	else
		sed -i -E "s|(=sni=)[^[:space:]]+( --)|\1${NEW_SNI}\2|g" "/opt/zapret/config"
		/opt/zapret/init.d/sysv/zapret restart
		echo -e "${green}Выполнен перезапуск zapret. SNI теперь фейкуется под:${plain} $NEW_SNI"
		hosters_check
	fi
	pause_enter
    ;;
	
  "15")
    provider_submenu      # сабменю само в цикле и выходит через return
    ;;

  "22")
    /opt/zapret/init.d/sysv/zapret restart
    echo -e "${green}Выполнена команда перезапуска zapret${plain}"
    ;;

  "777")
   echo -e "${green}Специальный zeefeer premium для Valery ProD, avg97, Xoz, GeGunT, Nomand, Kovi, blagodarenya, mikhyan, andric62, Whoze, Necronicle, Andrei_5288515371, Dina_turat, Nergalss, Александра, АлександраП, vecheromholodno, ЕвгенияГ, Dyadyabo, skuwakin, izzzgoy, Grigaraz, Reconnaissance, comandante1928, rudnev2028, umad, rutakote, railwayfx, vtokarev1604, Grigaraz, a40letbezurojaya и subzeero452 активирован. Наверное. Так же благодарю поддержавших проект yavladik, hey_enote, VssA, vladdrazz, Alexey_Tob, Bor1sBr1tva, Azamatstd, iMLT, Qu3Bee, SasayKudasay1, alexander_novikoff, MarsKVV, porfenon123, bobrishe_dazzle, kotov38, Levonkas, DA00001, geodomin, I_ZNA_I, CMyTHblN PacKoJlbHNK и анонимов${plain}"
   zefeer_premium_777
   exit_to_menu
   ;;
  "999")
    zefeer_space_999
    pause_enter
    ;;

  *)
    echo -e "${yellow}Неверный ввод.${plain}"
    sleep 1
    ;;
esac

  done
}

#___Само выполнение скрипта начинается тут____

#Проверка ОС
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
elif [[ -f /opt/etc/entware_release ]]; then
    release="entware"
elif [[ -f /etc/entware_release ]]; then
    release="entware"
elif [[ "$ID" == "alpine" ]] || grep -qi "alpine" /etc/os-release 2>/dev/null || [ -f /etc/alpine-release ]; then
    release="alpine"
else
    echo "Не удалось определить ОС. Прекращение работы скрипта." >&2
    exit 1
fi

if [[ "$release" == "entware" ]]; then
 if [ -d /jffs ] || uname -a | grep -qi "Merlin"; then
    hardware="merlin"
 elif grep -Eqi "netcraze|keenetic" /proc/version; then
    hardware="keenetic"
 else
  echo -e "${yellow}Железо не определено. Будем считать что это Keenetic. Если будут проблемы - пишите в саппорт.${plain}"
  hardware="keenetic"
 fi
fi

#По просьбе наших слушателей) Теперь netcraze официально детектится скриптом не как keenetic, а отдельно)
if grep -q "netcraze" "/bin/ndmc" 2>/dev/null; then
 echo "OS: $release Netcraze"
else
 echo "OS: $release $hardware"
fi

#Запуск скрипта под нужную версию
if [[ "$release" == "ubuntu" || "$release" == "debian" || "$release" == "endeavouros" || "$release" == "arch" || "$release" == "vyos" ]]; then
    OSystem="VPS"
elif [[ "$release" == "openwrt" || "$release" == "immortalwrt" || "$release" == "asuswrt" || "$release" == "x-wrt" || "$release" == "kwrt" || "$release" == "istoreos" ]]; then
    OSystem="WRT"
elif [[ "$release" == "entware" || "$hardware" = "keenetic" ]]; then
    OSystem="entware"
elif [[ "$release" == "alpine" ]]; then
    OSystem="alpine"
else
    read -re -p $'\033[31mДля этой ОС нет подходящей функции. Или ОС определение выполнено некорректно.\033[33m Рекомендуется обратиться в чат поддержки
Enter - выход
1 - Плюнуть и продолжить как OpenWRT
2 - Плюнуть и продолжить как entware
3 - Плюнуть и продолжить как VPS/LinuxOS
4 - Плюнуть и продолжить как Alpine\033[0m\n' os_answer
    case "$os_answer" in
    "1")
        OSystem="WRT"
    ;;
    "2")
        OSystem="entware"
    ;;
    "3")
        OSystem="VPS"
    ;;
    "4")
        OSystem="alpine"
    ;;
    *)
        echo "Выбран выход"
        exit 0
    ;;
    esac 
fi

#Инфа о времени обновления скрипта
commit_date=$(curl -s --max-time 15 "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4)
if [[ -z "$commit_date" ]]; then
    echo -e "${red}Не был получен доступ к api.github.com (таймаут 15 сек). Возможны проблемы при установке.${plain}"
    if [ "$hardware" = "keenetic" ]; then
        echo "Добавляем ip с от DNS 8.8.8.8 к api.github.com и пытаемся снова"
        IP_ghub=$(nslookup api.github.com 8.8.8.8 | sed -n '/^Name:/,$ s/^Address [0-9]*: \([0-9.]\{7,15\}\).*/\1/p' | head -n1)
        if [ -z "$IP_ghub" ]; then
            echo "ERROR: api.github.com not resolved with 8.8.8.8 DNS"
        else
            echo $IP_ghub
            ndmc -c "ip host api.github.com $IP_ghub"
            echo -e "${yellow}zeefeer обновлен (UTC +0): $(curl -s --max-time 10 "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=z4r.sh&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
        fi
    fi
else
    echo -e "${yellow}zeefeer обновлен (UTC +0): $commit_date ${plain}"
fi

#Проверка доступности raw.githubusercontent.com
if [[ -z "$(curl -s --max-time 10 "https://raw.githubusercontent.com/test")" ]]; then
    echo -e "${red}Не был получен доступ к raw.githubusercontent.com (таймаут 10 сек). Возможны проблемы при установке.${plain}"
    if [ "$hardware" = "keenetic" ]; then
        echo "Добавляем ip с от DNS 8.8.8.8 к raw.githubusercontent.com и пытаемся снова"
        IP_ghub2=$(nslookup raw.githubusercontent.com 8.8.8.8 | sed -n '/^Name:/,$ s/^Address [0-9]*: \([0-9.]\{7,15\}\).*/\1/p' | head -n1)
        if [ -z "$IP_ghub2" ]; then
            echo "ERROR: raw.githubusercontent.com not resolved with 8.8.8.8 DNS"
        else
            echo $IP_ghub2
            ndmc -c "ip host raw.githubusercontent.com $IP_ghub2"
        fi
    fi
fi

#Выполнение общего для всех ОС кода с ответвлениями под ОС
#Запрос на установку 3x-ui или аналогов для VPS
if [[ "$OSystem" == "VPS" ]] && [ ! $1 ]; then
 get_panel
fi

#Меню и быстрый запуск подбора стратегии
 if [ -d /opt/zapret/extra_strats ] && [ -f "/opt/zapret/config" ]; then
    if [ $1 ]; then
        Strats_Tryer $1
    fi
    get_menu
 fi
 
#entware keenetic and merlin preinstal env.
if [ "$hardware" = "keenetic" ]; then
 if which opkg >/dev/null 2>&1; then
    opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null
 elif which apk >/dev/null 2>&1; then
    apk add coreutils-sort grep gzip ipset iptables xtables-addons 2>/dev/null
 fi
 if which opkg >/dev/null 2>&1; then
    opkg install kmod_ndms 2>/dev/null || echo -e "\033[31mНе удалось установить kmod_ndms. Если у вас не keenetic - игнорируйте.\033[0m"
 fi
elif [ "$hardware" = "merlin" ]; then
 if which opkg >/dev/null 2>&1; then
    opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy 2>/dev/null
 elif which apk >/dev/null 2>&1; then
    apk add coreutils-sort grep gzip ipset iptables xtables-addons 2>/dev/null
 fi
fi

# Alpine Linux preinstall
if [[ "$OSystem" == "alpine" ]]; then
    echo -e "${yellow}Обнаружен Alpine Linux, устанавливаем необходимые пакеты...${plain}"
    apk update
    apk add --no-cache curl wget grep gzip ipset iptables coreutils
    if which nft >/dev/null 2>&1; then
        apk add nftables
    fi
fi

#Проверка наличия каталога opt и его создание при необходимости (для некоторых роутеров), переход в tmp
mkdir -p /opt
cd /tmp

#Запрос на резервирование стратегий, если есть что резервировать
backup_strats

#Удаление старого запрета, если есть
remove_zapret

#Запрос желаемой версии zapret
echo -e "${yellow}Конфиг обновлен (UTC +0): $(curl -s "https://api.github.com/repos/IndeecFOX/zapret4rocket/commits?path=config.default&per_page=1" | grep '"date"' | head -n1 | cut -d'"' -f4) ${plain}"
version_select

#Запрос на установку web-ssh
read -re -p $'\033[33mАктивировать доступ в меню через браузер (web-ssh) (~3мб места)? 1 - Да, Enter - нет\033[0m\n' ttyd_answer
case "$ttyd_answer" in
    "1")
        ttyd_webssh
    ;;
    *)
        echo "Пропуск (пере)установки web-терминала"
    ;;
esac 
 
#Скачивание, распаковка архива zapret и его удаление
zapret_get

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo

#Для Alpine Linux
if [[ "$OSystem" == "alpine" ]]; then
    alpine_fixes
fi

#Для Keenetic и merlin
if [[ "$OSystem" == "entware" ]]; then
    entware_fixes
fi

#Для x-wrt
if [[ "$release" == "x-wrt" ]]; then
    sed -i 's/kmod-nft-nat kmod-nft-offload/kmod-nft-nat/' /opt/zapret/common/installer.sh
fi

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot
