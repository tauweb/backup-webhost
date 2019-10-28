#!/bin/bash
# Shell script to backup MySql database and files
#
# Первый аргумент скрипту -  юзер БД
# Второй - Пароль пользователя БД

# Дефольные значения настройки БД
DB_USER="root"              # USERNAME
DB_USER_PASSWORD=""         # PASSWORD
HOSTNAME="localhost"        # Hostname
# BK_USER_DIR               # Заюзать потом. 
# BOT_BASE_DIR="/var/www/html/Projects/Bender"
BK_FILES_OWNER="whiskeyman" # владелец файлов бэкапов

# Очистка логов бота
# cd $BOT_BASE_DIR/Dumps/
# rm -rf ./*
# cd $BOT_BASE_DIR/Logs/
# rm -rf ./*
# cd ~/


# Ток рут может юзать скрипт (Гарантирует доступ ко всем файлам)
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


# Проверяет переданные аргументы в скрипт 
# Первый аргумент - это имя пользователя БД, второй - его пароль
if [ -n "$1" ]; then
    if [[ -n "$1" && -n "$2" ]]; then
        echo "Пользователь БД: $1 с заданным паролем"
        DB_USER=$1
        DB_USER_PASSWORD=$2
    else
        echo "Задан пользователь БД $1 без пароля. Завершаю работу"
        exit
    fi
else
    if [[ $DB_USER==="" ]]; then
        echo -n "Введите имя пользователя БД > "
        read DB_USER

        echo -n "Теперь его пароль > "
        read -s DB_USER_PASSWORD
    fi
   # echo "Юзер $DB_USER, пас $DB_USER_PASSWORD" # debug
fi


# Main config variables. !Не забыть бы минимализировать
# !Подумать как реализовать резервное копирование отдельными архивами для проектов в категориях по одному

# Linux bin paths, change this if it can not be autodetected via which command
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"

# Get data in dd-mm-yyyy format
NOW="$(date +"%d-%m-%Y")"
# Get hostname
HOST="$(hostname)"
# Backup BK_DIR directory, change this if you have someother location
BK_DIR="./BackUps/$HOST/$NOW"
# Main directory where backup will be stored
DB_BK_DIR="$BK_DIR/mysql"
BK_FILES_DIR="$BK_DIR/files/"
# WWW root dir
WWW_ROOT="/var/www/html/"
# File to store current backup file
FILE=""
# Store list of databases
DBS=""
# DO NOT BACKUP these databases
IGGY="information_schema phpmyadmin"

# Создает базовую структуру дерева бэкапа 
[ ! -d $DB_BK_DIR ] && mkdir -p $DB_BK_DIR || :
[ ! -d $BK_FILES_DIR ] && mkdir -p $BK_FILES_DIR || :

# Only root can access it!
#$CHOWN 0.0 -R $BK_DIR
#$CHMOD 0600 $BK_DIR

#PROJ_CAT_NAME - это название файла или папки (тип проекта) в основной папке веб каталогов

# Создает структуру папок в каталоге, куда будут создаваться бэкапы
for PROJ_CAT_NAME in $(ls  $WWW_ROOT | grep -v /) ; do
    # echo $PROJ_CAT_NAME # debug

    # Создает структуру карталога www в каталоге, в который будут помещены бэкапы
    if [[ -d $WWW_ROOT$PROJ_CAT_NAME ]]; then
        [ ! -d $BK_FILES_DIR"www/" ] && mkdir -p $BK_FILES_DIR"www"  || :
        [ ! -d $BK_FILES_DIR"www/"$PROJ_CAT_NAME ] && mkdir -p $BK_FILES_DIR"www/"$PROJ_CAT_NAME  || :

        iterator=0

        # Выполнить архивирование папки в виде: 
        # корень www + название категории проекта (просто папка из wwww) + название самого проекта / сайта / файла
        for PROJ_NAME in $( ls $WWW_ROOT$PROJ_CAT_NAME ); do
            echo -e "\e[34mВыполняю бэкап директории:\e[0m" $WWW_ROOT$PROJ_CAT_NAME"/"${PROJ_NAME[$iterator]}"\n"
            tar czf $BK_FILES_DIR"www/"$PROJ_CAT_NAME"/"${PROJ_NAME[$iterator]}.tar.gz  $WWW_ROOT$PROJ_CAT_NAME"/"${PROJ_NAME[$iterator]}*
        done

        ((iterator++)) 

    else # Или же сразу создает бэкап, если это файл
        echo -e "\e[34mВыполняю бэкап файла:\e[0m" $WWW_ROOT$PROJ_CAT_NAME"\n"
        tar czf $BK_FILES_DIR"www/"$PROJ_CAT_NAME.tar.gz $WWW_ROOT$PROJ_CAT_NAME
    fi

done

# Создает бэкап /ect
echo -e "\e[34mВыполняю бэкап директории:\e[0m" /etc"\n"
tar czf $BK_FILES_DIR""etc.tar /etc

# exit





# Get all database list first
DBS="$($MYSQL -u $DB_USER -h $HOSTNAME -p$DB_USER_PASSWORD -Bse 'show databases')"

for db in $DBS
do
    skipdb=-1
    if [ "$IGGY" != "" ];
    then
    for i in $IGGY
    do
        [ "$db" == "$i" ] && skipdb=1 || :
    done
    fi

    if [ "$skipdb" == "-1" ] ; then
    #FILE="$DB_BK_DIR/$db.$HOST.$NOW.gz"
    FILE="$DB_BK_DIR/$db.gz"
    # do all inone job in pipe,
    # connect to mysql using mysqldump for select mysql database
    # and pipe it out to gz file in backup dir :)
        echo -e "\e[34mВыполняю бэкап БД:\e[0m "$db "\n"
        $MYSQLDUMP -u $DB_USER -h $HOSTNAME -p$DB_USER_PASSWORD $db | $GZIP -9 > $FILE
    fi
done


# Выполняет архивирование сайтов (Хоста в целом).
# tar czfv $BK_FILES_DIR/$NOW.tar.gz $WWW_ROOT

# Изменяем владельца на директорию с бэкапами
# chown $(whoami) $BK_DIR

# Do remote copy via SSH                                                                                                        (Нужно дописать)
# echo 'Капирование на удаленный хост'
# scp ./BackUps/www/*$(date +%y%m%d).*  whiskeyman@192.168.0.2:~/BackUps/www

#php -f ./send_bk_status.php
echo -e "\e[32m Бэкап на \e[1m$NOW выполнен\e[0m"

echo -e "\e[34mИзменение владельца папки с бэкапом ($BK_DIR) на :\e[0m "$BK_FILES_OWNER "\n"
chown -R $BK_FILES_OWNER ./BackUps
