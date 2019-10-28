#!/bin/bash
# Shell script to backup MySql database and files

# Первый аргумент скрипту -  юзер БД,  Второй - Пароль пользователя БД

# Ток рут может юзать скрипт (Гарантирует доступ ко всем файлам)
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Дефольные значения настройки БД
DB_USER="root"              # USERNAME
DB_USER_PASSWORD=""         # PASSWORD
HOSTNAME="localhost"        # Hostname
# BK_USER_DIR               # Заюзать потом. 
BK_FILES_OWNER="whiskeyman" # владелец файлов бэкапов

# Удаление логов и дампов отладки у Телеграм бота. 
rm -rf /var/www/html/Projects/Bender/Dumps/* && rm -rf /var/www/html/Projects/Bender/Logs/*

# Проверяет переданные аргументы в скрипт 
# Первый аргумент - это имя пользователя БД, второй - его пароль (Можно указать по умолчанию в переменных DB_USER и DB_USER_PASSWORD)
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
        echo -n "Введите имя пользователя БД: "
        read DB_USER

        echo -n "Теперь его пароль: "
        read -s DB_USER_PASSWORD
        echo -e "\n"
    fi
   # echo "Юзер $DB_USER, пас $DB_USER_PASSWORD" # debug
fi

# Main config variables. !Не забыть бы минимализировать
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

# PROJ_CAT_NAME - это название файла или папки (тип проекта / категория) в основной папке веб каталогов. 
# У меня это: Sites, Orders, Tasks, Projects, Bots, Frameworks, etc.

# Создает структуру папок в каталоге, куда будут создаваться бэкапы
for PROJ_CAT_NAME in $(ls  $WWW_ROOT | grep -v /) ; do
    # Создает структуру карталога www в каталоге, в который будут помещены бэкапы
    if [[ -d $WWW_ROOT$PROJ_CAT_NAME ]]; then
        [ ! -d $BK_FILES_DIR"www/" ] && mkdir -p $BK_FILES_DIR"www"  || :
        [ ! -d $BK_FILES_DIR"www/"$PROJ_CAT_NAME ] && mkdir -p $BK_FILES_DIR"www/"$PROJ_CAT_NAME  || :

        iterator=0

        # Выполнить архивирование папки в виде: 
        # корень www + название категории проекта (просто папка из wwww) + название самого проекта / сайта / файла
        for PROJ_NAME in $( ls $WWW_ROOT$PROJ_CAT_NAME ); do
            echo -e "\e[34mВыполняю бэкап:\e[0m" $WWW_ROOT$PROJ_CAT_NAME"/"${PROJ_NAME[$iterator]}
            tar czf $BK_FILES_DIR"www/"$PROJ_CAT_NAME"/"${PROJ_NAME[$iterator]}.tar.gz  $WWW_ROOT$PROJ_CAT_NAME"/"${PROJ_NAME[$iterator]}*
        done

        ((iterator++)) 

    else # Или же сразу создает бэкап, если это файл
        echo -e "\e[34mВыполняю бэкап файла:\e[0m" $WWW_ROOT$PROJ_CAT_NAME
        tar czf $BK_FILES_DIR"www/"$PROJ_CAT_NAME.tar.gz $WWW_ROOT$PROJ_CAT_NAME
    fi
done

# Выполняет архивирование сайтов (Хоста в целом). Использовать, если не нужно структурировать все, но тогда нужно удалить цикл выше
# tar czfv $BK_FILES_DIR/$NOW.tar.gz $WWW_ROOT

# Создает бэкап /ect
echo -e "\e[34mВыполняю бэкап:\e[0m" /etc
tar czf $BK_FILES_DIR""etc.tar /etc

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
        echo -e "\e[34mВыполняю бэкап БД:\e[0m "$db
        $MYSQLDUMP -u $DB_USER -h $HOSTNAME -p$DB_USER_PASSWORD $db | $GZIP -9 > $FILE
    fi
done

# Do remote copy via SSH                                                                                                        (Нужно дописать)
# echo 'Капирование на удаленный хост'
# scp ./BackUps/www/*$(date +%y%m%d).*  whiskeyman@192.168.0.2:~/BackUps/www

#php -f ./send_bk_status.php
echo -e "\e[32m Бэкап на \e[1m$NOW выполнен\e[0m"

echo -e "\e[34mИзменение владельца папки с бэкапом ($BK_DIR) на:\e[0m "$BK_FILES_OWNER "\n"
chown -R $BK_FILES_OWNER ./BackUps

# Доделать отправку почты, если скрипт был вызван из crontab
