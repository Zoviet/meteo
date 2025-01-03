#!/bin/bash

if read -p "Подключите плату к USB и нажмите ENTER: " start; then
	line=$(dmesg | grep 'ttyUSB' | tail -1)
	if [[ $line == *"attached"* ]]; then	
		port=`echo "$line" | sed 's/.*ttyUSB\(.\)$/\1/'`
	else 
		printf '\033[91mУстройство не найдено!\033[0m\n'
		exit 0
	fi
	printf '\033[92mУстройство найдено на порту: '$port'\033[0m\n'
fi

if read -p "Для начала прошивки нажмите ENTER: " start; then
	cd ../Firmware
	firmware=($(find -name '*.bin'))
	if [[ $firmware == *"nodemcu"* ]]; then
		printf '\033[92mНайдена прошивка: '$firmware'\033[0m\n\n'
		printf '\n\033[92mСтираем существующую прошивку:\033[0m\n\n'
		python3 -m esptool --port /dev/ttyUSB$port erase_flash
		if [ $? -ne 0 ]; then
			printf '\033[91mОшибка устройства!\033[0m\n'
			exit 0
		fi
		printf '\n\033[92mЗаливаем прошивку nodemcu для Lua:\033[0m\n\n'
		python3 -m esptool --port /dev/ttyUSB$port write_flash -fm dio 0x00000 $firmware
		if [ $? -ne 0 ]; then
			printf '\033[91mОшибка устройства!\033[0m\n'
			exit 0
		fi
	else
		printf '\033[91mПрошивка не найдена!\033[0m\n'
		exit 0
	fi	
fi

if read -p "Для начала заливки скетча нажмите ENTER: " start; then
	echo 'Заливаем Lua скетч:'
	python2 luatool.py --port /dev/ttyUSB$port --src init.lua --dest init.lua --verbose --restart --baud 115200 
	if [ $? -ne 0 ]; then
		printf '\033[91mОшибка заливки скетча!\033[0m\n'
		exit 0
	fi
fi

printf '\n\033[92mЖдем перезагрузки устройства:\033[0m\n\n'
sleep 5
mac=$(python3 -m esptool --port /dev/ttyUSB$port read_mac)
if [ $? -ne 0 ]; then
	printf '\033[91mОшибка чтения из устройства!\033[0m\n'
	exit 0
fi
guid=`echo "$mac" | grep -m 1 MAC | sed 's/\://g' | sed 's/MAC //g'`
echo 'GUID устройства: '$guid
first_byte=${guid:0:2}
new_byte=$((16#$first_byte + 2  | bc))
new_first_byte=`echo "ibase=10; obase=16; ${new_byte}" | bc | sed 's/[A-Z]/\L&/g'`
if (( ${#new_first_byte} == 1 )); then
	new_first_byte='0'$new_first_byte
fi
guid=`echo "$guid" | sed 's/^'$first_byte'/'$new_first_byte'/'`
printf '\033[92mОпределен guid устройства: '$guid' \033[0m\n'

printf '\033[92mУстановка успешно завершена, ID устройства: \033[0m'$guid'\n'
