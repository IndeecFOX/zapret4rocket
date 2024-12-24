#!/bin/bash
set -e

# Обновление пакетов и установка unzip
apt update && apt install -y unzip

# Переход в директорию /opt
cd /opt

# Скачивание и распаковка архива zapret 69.8
wget https://github.com/bol-van/zapret/releases/download/v69.8/zapret-v69.8.zip
unzip zapret-v69.8.zip
mv zapret-v69.8 zapret

#Включение обхода дискорда
cp /opt/zapret/init.d/custom.d.examples.linux/50-discord /opt/zapret/init.d/sysv/custom.d/

#Копирование нашего конфига на замену стандартному
wget -O config.default https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/master/config.default
mv config.default /opt/zapret/

# Запуск установочных скриптов
sh zapret/install_bin.sh
sh zapret/install_prereq.sh
sh -i zapret/install_easy.sh

# Перезапуск сервиса zapret
zapret/init.d/sysv/zapret restart
