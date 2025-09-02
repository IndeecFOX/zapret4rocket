#!/bin/bash
#Команда установки
#curl -O https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/z4r.sh && bash z4r.sh && rm z4r.sh
#В случае отсутствия curl или bash: 
#Для роутеров: opkg update && opkg install curl bash
#Для Ubuntu/Debian: apt update && apt install curl bash

set -e
#Для Valery ProD. Переменная содержащая версию на случай невозможности получить информацию о lastest с github
DEFAULT_VER="71.4"

#Чтобы удобнее красить
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

#___Сначала идут анонсы функций____

#Проверка наличия каталога opt и его создание при необходиомости (для некоторых роутеров), переход в него
dir_select(){
 cd /
 if [ -d /opt ]; then
     echo "Каталог /opt уже существует"
 else
     echo "Создаём каталог /opt"
     mkdir /opt
 fi
 cd /opt
}

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo() {
 mkdir -p /opt/zapret/lists /opt/zapret/extra_strats/TCP/{RKN,User,YT,temp} /opt/zapret/extra_strats/UDP/YT
 for listfile in autohostlist.txt cloudflare-ipset.txt cloudflare-ipset_v6.txt mycdnlist.txt myhostlist.txt netrogat.txt russia-blacklist.txt russia-discord.txt russia-youtube-rtmps.txt russia-youtube.txt russia-youtubeQ.txt; do wget -P /opt/zapret/lists https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/lists/$listfile; done
 for fakefile in http_fake_MS.bin quic_{1..7}.bin syn_packet.bin tls_clienthello_{1..18}.bin tls_clienthello_2n.bin tls_clienthello_6a.bin; do wget -P /opt/zapret/files/fake/ https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/fake/$fakefile; done
 wget -O /opt/zapret/extra_strats/UDP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/UDP/YT/List.txt
 wget -O /opt/zapret/extra_strats/TCP/RKN/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/RKN/List.txt
 wget -O /opt/zapret/extra_strats/TCP/YT/List.txt https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/extra_strats/TCP/YT/List.txt
 touch /opt/zapret/extra_strats/UDP/YT/{1..8}.txt /opt/zapret/extra_strats/TCP/RKN/{1..17}.txt /opt/zapret/extra_strats/TCP/User/{1..17}.txt /opt/zapret/extra_strats/TCP/YT/{1..17}.txt /opt/zapret/extra_strats/TCP/temp/{1..17}.txt
 #Копирование нашего конфига на замену стандартному и скриптов для войсов DS, WA, TG
 wget -O /opt/zapret/config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
 if command -v nft >/dev/null 2>&1; then
  sed -i 's/^FWTYPE=iptables$/FWTYPE=nftables/' "/opt/zapret/config.default"
 fi
 wget -O /opt/zapret/init.d/sysv/custom.d/50-stun4all https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-stun4all
 wget -O /opt/zapret/init.d/sysv/custom.d/50-discord-media https://raw.githubusercontent.com/bol-van/zapret/master/init.d/custom.d.examples.linux/50-discord-media
}

#Функция для функции подбора стратегий
try_strategies() {
    local count="$1"
    local base_path="$2"
    local list_file="$3"
    local final_action="$4"

    for ((i=1; i<=count; i++)); do
        if [[ $i -ge 2 ]]; then
            prev=$((i - 1))
            echo -n > "$base_path/${prev}.txt"
        fi

        if [[ "$list_file" != "/dev/null" ]]; then
            cp "$list_file" "$base_path/${i}.txt"
        else
            echo "$user_domain" > "$base_path/${i}.txt"
        fi
        #/opt/zapret/init.d/sysv/zapret restart (Проверил, работает без перезагрузки)
        echo "Стратегия номер $i активирована"

        read -p "Проверьте работоспособность, например, в браузере и введите (\"Y\" - сохранить и выйти, Enter - далее): " answer
        clean_answer=$(echo "$answer" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
        if [[ "$clean_answer" == "Y" ]]; then
            echo "Стратегия $i сохранена. Выходим."
            eval "$final_action"
            exit 0
        fi
    done

    echo -n > "$base_path/${count}.txt"
    echo "Все стратегии испробованы. Ничего не подошло."
    exit 0
}

#Сама функция подбора стратегий
Strats_Tryer() {
    if [ ! -f "/opt/zapret/uninstall_easy.sh" ]; then
        echo "zapret не установлен, пропускаем скрипт подбора профиля"
        return
    fi

    read -p $'\033[33mПодобрать стратегию? (1-4 или Enter для пропуска):\033[0m\n\033[32m1. YT (UDP QUIC)\n2. YT (TCP)\n3. RKN\n4. Кастомный домен\033[0m\n' answer
    clean_answer=$(echo "$answer" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

    case "$clean_answer" in
        "1")
            echo "Режим YT (UDP QUIC)"
            try_strategies 8 "/opt/zapret/extra_strats/UDP/YT" "/opt/zapret/extra_strats/UDP/YT/List.txt" ""
            ;;
        "2")
            echo "Режим YT (TCP)"
            try_strategies 17 "/opt/zapret/extra_strats/TCP/YT" "/opt/zapret/extra_strats/TCP/YT/List.txt" ""
            ;;
        "3")
            echo "Режим RKN"
            try_strategies 17 "/opt/zapret/extra_strats/TCP/RKN" "/opt/zapret/extra_strats/TCP/RKN/List.txt" ""
            ;;
        "4")
            echo "Режим кастомного домена"
            read -p "Введите домен (например, mydomain.com): " user_domain
            user_domain=$(echo "$user_domain" | tr -d '[:space:]')
			echo "Введён домен: $user_domain"

            # Отключаем активный RKN-лист временно
            for emp in {1..17}; do
                file="/opt/zapret/extra_strats/TCP/RKN/${emp}.txt"
                if [[ -s "$file" ]]; then
                    echo -n > "$file"
                    break
                fi
            done

            try_strategies 17 "/opt/zapret/extra_strats/TCP/temp" "/dev/null" \
            "echo -n > \"/opt/zapret/extra_strats/TCP/temp/\${i}.txt\"; \
             echo \"$user_domain\" > \"/opt/zapret/extra_strats/TCP/User/\${i}.txt\"; \
             cp \"/opt/zapret/extra_strats/TCP/RKN/List.txt\" \"/opt/zapret/extra_strats/TCP/RKN/${emp}.txt\""
            ;;
        *)
            echo "Пропуск подбора альтернативной стратегии"
            ;;
    esac
}

#Удаление старого запрета, если есть
remove_zapret() {
 if [ -f "/opt/zapret/uninstall_easy.sh" ]; then
     echo "Файл zapret/uninstall_easy.sh найден. Выполняем его"
	 /opt/zapret/init.d/sysv/zapret stop
     sh /opt/zapret/uninstall_easy.sh
     echo "Скрипт uninstall_easy.sh выполнен."
 else
     echo "Файл zapret/uninstall_easy.sh не найден. Переходим к следующему шагу."
 fi
 if [ -d "/opt/zapret" ]; then
     echo "Удаляем папку zapret"
     rm -rf /opt/zapret
 else
     echo "Папка zapret не существует."
 fi
}

#Запрос желаемой версии zapret или выход из скрипта для удаления
version_select() {
    while true; do
		read -p $'\033[0;32mВведите желаемую версию zapret (Enter для новейшей версии): \033[0m' USER_VER
        # Если пустой ввод — берем значение по умолчанию
		if [ -z "$USER_VER" ]; then
    	 if [ -z "$USER_VER" ]; then
    	 VER1=$(wget -qO- https://api.github.com/repos/bol-van/zapret/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    	 VER2=$(wget -qO- https://api.github.com/repos/bol-van/zapret/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
    	 VER3=$(wget -qO- https://api.github.com/repos/bol-van/zapret/releases/latest | grep '"tag_name":' | sed -r 's/.*"v([^"]+)".*/\1/')
    	 VER4=$(wget -qO- https://api.github.com/repos/bol-van/zapret/releases/latest | grep '"tag_name":' | awk -F'"' '{print $4}' | sed 's/^v//')
		 fi
	     # проверяем результаты по порядку
    	 if [ ${#VER1} -ge 2 ]; then
       	  VER="$VER1"
       	  METHOD="sed -E"
    	 elif [ ${#VER2} -ge 2 ]; then
       	  VER="$VER2"
       	  METHOD="grep+cut"
    	 elif [ ${#VER3} -ge 2 ]; then
          VER="$VER3"
          METHOD="sed -r"
    	 elif [ ${#VER4} -ge 2 ]; then
       	  VER="$VER4"
       	  METHOD="awk"
    	 else
          echo -e "${yellow}Не удалось получить информацию о последней версии с GitHub. Будет использоваться версия $DEFAULT_VER.${plain}"
          VER="$DEFAULT_VER"
          METHOD="default"
    	 fi
	     # краткий отчёт
    	 echo -e "${yellow}Проверка версий:${plain}"
    	 echo "  sed -E   : $VER1"
    	 echo "  grep+cut : $VER2"
    	 echo "  sed -r   : $VER3"
    	 echo "  awk      : $VER4"
    	 echo -e "${green}Выбрано: $VER (метод: $METHOD)${plain}"
    	 break
		fi
        # Считаем длину
        LEN=${#USER_VER}
        # Проверка длины и знака %
        if (( LEN > 4 )) || [[ "$USER_VER" == *%* ]]; then
            echo "Некорректный ввод. Максимальная длина — 4 символа и без знака %. Попробуйте снова. (использование backspace может давать ошибку)"
            continue
        fi
        VER="$USER_VER"
        break
    done
    echo "Будет использоваться версия: $VER"
}

#Скачивание, распаковка архива zapret и его удаление
zapret_get() {
 if [[ "$OSystem" == "VPS" ]]; then
     tarfile="zapret-v$VER.tar.gz"
 else
     tarfile="zapret-v$VER-openwrt-embedded.tar.gz"
 fi
 wget -O "$tarfile" "https://github.com/bol-van/zapret/releases/download/v$VER/$tarfile"
 tar -xzf "$tarfile"
 rm -f "$tarfile"
 mv "zapret-v$VER" /opt/zapret
}

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot() {
 sh -i /opt/zapret/install_easy.sh
 /opt/zapret/init.d/sysv/zapret restart
 echo -e "\033[32mzeefeer перезапущен и полностью установлен\nЕсли требуется меню - введите скрипт ещё раз. Саппорт: tg: zee4r\033[0m"
}

#Для Entware Keenetic + merlin
entware_fixes() {
 if [ "$hardware" = "keenetic" ]; then
  wget -O /opt/zapret/init.d/sysv/zapret https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/zapret
  chmod +x /opt/zapret/init.d/sysv/zapret
  echo "Права выданы /opt/zapret/init.d/sysv/zapret"
  wget -q -O /opt/etc/ndm/netfilter.d/000-zapret.sh https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/000-zapret.sh
  chmod +x /opt/etc/ndm/netfilter.d/000-zapret.sh
  echo "Права выданы /opt/etc/ndm/netfilter.d/000-zapret.sh"
  wget -q -O /opt/etc/init.d/S00fix https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/Entware/S00fix
  chmod +x /opt/etc/init.d/S00fix
  echo "Права выданы /opt/etc/init.d/S00fix"
  cp -a /opt/zapret/init.d/custom.d.examples.linux/10-keenetic-udp-fix /opt/zapret/init.d/sysv/custom.d/10-keenetic-udp-fix
  echo "10-keenetic-udp-fix скопирован"
 fi
 #Раскомменчивание юзера под keenetic или merlin
 if [ "$hardware" = "keenetic" ]; then
  sed -i 's/^#\(WS_USER=nobody\)/\1/' /opt/zapret/config.default
 elif [ "$hardware" = "merlin" ]; then
  merlin_user=$(head -n1 /etc/passwd | cut -d: -f1)
  sed -i "s/^#WS_USER=nobody$/WS_USER=$merlin_user/" "/opt/zapret/config.default"  
 fi
 #sed для пропуска запроса на прочтение readme, т.к. система entware. Дабы скрипт отрабатывал далее на Enter
 sed -i 's/if \[ -n "\$1" \] || ask_yes_no N "do you want to continue";/if true;/' /opt/zapret/common/installer.sh
 ln -fs /opt/zapret/init.d/sysv/zapret /opt/etc/init.d/S90-zapret
 echo "Добавлено в автозагрузку: /opt/etc/init.d/S90-zapret > /opt/zapret/init.d/sysv/zapret"
}

#Запрос на установку 3x-ui или аналогов
get_panel() {
 read -p $'\033[33mУстановить ПО для туннелирования?\033[0m \033[32m(3xui, marzban, wg, 3proxy или Enter для пропуска): \033[0m' answer
 # Удаляем лишние символы и пробелы, приводим к верхнему регистру
 clean_answer=$(echo "$answer" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
 if [[ -z "$clean_answer" ]]; then
     echo "Пропуск установки ПО туннелирования."
 elif [[ "$clean_answer" == "3XUI" ]]; then
     echo "Установка 3x-ui панели."
     bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
 elif [[ "$clean_answer" == "WG" ]]; then
     echo "Установка WG (by angristan)"
     bash <(curl -Ls https://raw.githubusercontent.com/angristan/wireguard-install/refs/heads/master/wireguard-install.sh)
 elif [[ "$clean_answer" == "3PROXY" ]]; then
     echo "Установка 3proxy (by SnoyIatk)"
     bash <(curl -Ls https://raw.githubusercontent.com/SnoyIatk/3proxy/master/3proxyinstall.sh)
     wget -O /etc/3proxy/.proxyauth https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/del.proxyauth
     wget -O /etc/3proxy/3proxy.cfg https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/3proxy.cfg
     #mv del.proxyauth .proxyauth
     #mv .proxyauth /etc/3proxy/
     #mv 3proxy.cfg /etc/3proxy/
     /opt/zapret/init.d/sysv/zapret restart
 elif [[ "$clean_answer" == "MARZBAN" ]]; then
     echo "Установка Marzban"
     bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
 else
     echo "Пропуск установки ПО туннелирования."
 fi
}

#Меню
get_menu() {
 if [ ! -f "/opt/zapret/uninstall_easy.sh" ]; then
        echo "zapret не установлен, пропускаем скрипт меню"
        return
 fi
 read -p $'\033[33mВыберите необходимое действие? (1-10 или Enter для перехода к переустановке):\033[0m\n\033[32m1. Подобрать другие стратегии\n2. Остановить zapret\n3. Пере(запустить) zapret\n4. Удалить zapret\n5. Обновить стратегии, сбросить листы подбора стратегий и исключений\n6. Добавить домен в исключения zapret\n7. Открыть в редакторе config\n8. Активировать альтернативные страты разблокировки войса DS,WA,TG вместо скриптов bol-van или вернуться снова к скриптам (переключатель)\n9. Переключить zapret на nftables или вернуть iptables (переключатель)(На все вопросы жать Enter). Актуально для OpenWRT 21+. Может помочь с войсами\n10. Активировать zeefeer premium (Нажимать только Valery ProD)\033[0m\n' answer
 clean_answer=$(echo "$answer" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
 case "$clean_answer" in
  "1")
   echo "Режим подбора других стратегий"
   Strats_Tryer
   ;;
  "2")
   /opt/zapret/init.d/sysv/zapret stop
   echo -e "${green}zapret остановлен${plain}"
   exit 0
   ;;
  "3")
   /opt/zapret/init.d/sysv/zapret restart
   echo -e "${green}zapret пере(запущен)${plain}"
   exit 0
   ;;
  "4")
   remove_zapret
   echo -e "${yellow}zapret удалён${plain}"
   exit 0
   ;;
  "5")
   /opt/zapret/init.d/sysv/zapret stop
   rm -rf /opt/zapret/lists /opt/zapret/extra_strats
   rm -f /opt/zapret/files/fake/http_fake_MS.bin /opt/zapret/files/fake/quic_{1..7}.bin /opt/zapret/files/fake/syn_packet.bin /opt/zapret/files/fake/tls_clienthello_{1..18}.bin /opt/zapret/files/fake/tls_clienthello_2n.bin /opt/zapret/files/fake/tls_clienthello_6a.bin
   get_repo
   #Раскомменчивание юзера под keenetic или merlin
   if [ "$hardware" = "keenetic" ]; then
    sed -i 's/^#\(WS_USER=nobody\)/\1/' /opt/zapret/config.default
   elif [ "$hardware" = "merlin" ]; then
    merlin_user=$(head -n1 /etc/passwd | cut -d: -f1)
    sed -i "s/^#WS_USER=nobody$/WS_USER=$merlin_user/" "/opt/zapret/config"  
   fi
   cp -f /opt/zapret/config.default /opt/zapret/config
   /opt/zapret/init.d/sysv/zapret start
   echo -e "${green}Config файл обновлён. Листы подбора стратегий и исключений сброшены в дефолт. Фейк файлы обновлены.${plain}"
   exit 0
   ;;
  "6")
   read -p "Введите домен, который добавить в исключения (например, mydomain.com): " user_domain
   user_domain=$(echo "$user_domain" | tr -d '[:space:]')
   if [ -n "$user_domain" ]; then
    echo "$user_domain" >> /opt/zapret/lists/netrogat.txt
	/opt/zapret/init.d/sysv/zapret restart
    echo -e "Домен ${yellow}$user_domain${plain} добавлен в исключения (netrogat.txt). zapret перезапущен. ${yellow}Если в домене присутствуют некорректные символы - значит случился баг при вводе (сначала писали на русском языке). Передобавьте.${plain}"
   else
    echo "Ввод пустой, ничего не добавлено"
   fi
   exit 0
   ;;
  "7")
   nano /opt/zapret/config
   exit 0
   ;;
  "8")
	if grep -q '^NFQWS_PORTS_UDP=443$' "/opt/zapret/config"; then
     # Был только 443 → добавляем порты и убираем --skip
     sed -i 's/^NFQWS_PORTS_UDP=443$/NFQWS_PORTS_UDP=443,1400,3478-3481,5349,50000-50099/' "/opt/zapret/config"
     sed -i '168,169s/^--skip //' "/opt/zapret/config"
     echo -e "${green}Уход от скриптов bol-van. Выделены порты 50000-50099,1400,3478-3481,5349 и раскомментированы стратегии DS, WA, TG (строки 168, 169).${plain}"
	elif grep -q '^NFQWS_PORTS_UDP=443,1400,3478-3481,5349,50000-50099$' "/opt/zapret/config"; then
     # Уже расширенный список → возвращаем к 443 и добавляем --skip
     sed -i 's/^NFQWS_PORTS_UDP=443,1400,3478-3481,5349,50000-50099$/NFQWS_PORTS_UDP=443/' "/opt/zapret/config"
     sed -i '168,169s/^/--skip /' "/opt/zapret/config"
     echo -e "${green}Работа от скриптов bol-van. Вернули строку к виду NFQWS_PORTS_UDP=443 и добавили "--skip " в начале строк 168–169.${plain}"
	else
     echo -e "${yellow}Неизвестное состояние строки NFQWS_PORTS_UDP. Проверь конфиг вручную.${plain}"
	fi
	/opt/zapret/init.d/sysv/zapret restart
   exit 0
   ;;
  "9")
	if grep -q '^FWTYPE=iptables$' "/opt/zapret/config"; then
     # Был только 443 → добавляем порты и убираем --skip
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
   exit 0
   ;;
  "10")
   echo -e "${green}Специальный zeefeer premium для Valery ProD активирован. Наверное.${plain}"
   exit 0
   ;;
  esac
 }

#___Сам код начинается тут____

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
else
    echo "Не удалось определить ОС. Прекращение работы скрипта." >&2
    exit 1
fi
if [[ "$release" == "entware" ]]; then
 if grep -qi "merlin" /proc/version; then
    hardware="merlin"
 elif grep -qi "keenetic" /proc/version; then
   	hardware="keenetic"
 else
  echo -e "${yellow}Железо не определено. Будем считать что это Keenetic. Если будут проблемы - пишите в саппорт.${plain}"
  hardware="keenetic"
 fi
fi
echo "OS: $release $hardware"

#Запуск скрипта под нужную версию
if [[ "$release" == "ubuntu" || "$release" == "debian" || "$release" == "endeavouros" ]]; then
	OSystem="VPS"
elif [[ "$release" == "openwrt" || "$release" == "immortalwrt" || "$release" == "asuswrt" ]]; then
	OSystem="WRT"
elif [[ "$release" == "entware" ]]; then
	OSystem="Entware"
else
    echo "Для этой ОС нет подходящей функции. Или ОС определение выполнено некорректно."
	exit 0
fi

#Выполнение общего для всех ОС кода с ответвлениями под ОС
#Запрос на установку 3x-ui или аналогов для VPS
if [[ "$OSystem" == "VPS" ]]; then
 get_panel     
fi

#Меню
get_menu
 
#entware keenetic and merlin preinstal env. merlin wget repair
if [ "$hardware" = "keenetic" ]; then
 opkg install coreutils-sort grep gzip ipset iptables kmod_ndms xtables-addons_legacy
elif [ "$hardware" = "merlin" ]; then
 opkg install coreutils-sort grep gzip ipset iptables xtables-addons_legacy
 touch /root/.wget-hsts
 chmod 644 /root/.wget-hsts
fi

#Проверка наличия каталога opt и его создание при необходиомости (для некоторых роутеров), переход в него
dir_select

#Удаление старого запрета, если есть
remove_zapret

#Запрос желаемой версии zapret
version_select
 
#Скачивание, распаковка архива zapret и его удаление
zapret_get

#Создаём папки и забираем файлы папок lists, fake, extra_strats, копируем конфиг, скрипты для войсов DS, WA, TG
get_repo

#Для Keenetic и merlin
if [[ "$OSystem" == "Entware" ]]; then
 entware_fixes
fi

#Запуск установочных скриптов и перезагрузка
install_zapret_reboot
