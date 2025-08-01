#SSH Instal command: opkg install bash curl && bash <(curl -Ls https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/fast_install_for_OWRT.sh)

#New Script Warning
bold_red='\033[1;31m'
reset='\033[0m'
echo -e "${bold_red}Это версия скрипта более не поддерживается, новая версия в репозитарии https://github.com/IndeecFOX/zapret4rocket
Скрипт новой версии:
curl -O https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/z4r.sh && bash z4r.sh && rm z4r.sh${reset}"

#pre
opkg update
opkg install unzip
opkg install git-http

#directories
cd /
mkdir opt
cd /opt

#Удаление старого запрета, если есть
if [ -f "zapret/uninstall_easy.sh" ]; then
    echo "Файл zapret/uninstall_easy.sh найден. Выполняем его"
    sh zapret/uninstall_easy.sh
    echo "Скрипт uninstall_easy.sh выполнен."
else
    echo "Файл zapret/uninstall_easy.sh не найден. Переходим к следующему шагу."
fi
if [ -d "zapret" ]; then
    echo "Удаляем папку zapret"
    rm -rf zapret
    echo "Папка zapret успешно удалена."
else
    echo "Папка zapret не существует."
fi

# Распаковка архива zapret и его удаление
wget -O zapret-v71.1-openwrt-embedded.tar.gz "https://github.com/bol-van/zapret/releases/download/v71.1/zapret-v71.1-openwrt-embedded.tar.gz"
tar -xzf zapret-v71.1-openwrt-embedded.tar.gz
rm -f zapret-v71.1-openwrt-embedded.tar.gz
tar -xf zapret-v71.1-openwrt-embedded.tar
rm -f zapret-v71.1-openwrt-embedded.tar
mv zapret-v71.1 zapret

#Клонируем репозиторий и забираем папки lists и fake, удаляем репозиторий
git clone https://github.com/IndeecFOX/zapret4rocket.git
cp -r zapret4rocket/lists /opt/zapret/
cp -r zapret4rocket/fake /opt/zapret/files/
rm -rf zapret4rocket

#Копирование нашего конфига на замену стандартному
wget -O config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
mv config.default /opt/zapret/

# Запуск установочных скриптов
sh zapret/install_bin.sh
sh zapret/install_prereq.sh
sh -i zapret/install_easy.sh
/etc/init.d/zapret restart
echo "zeefeer перезапущен и полностью установлен"
