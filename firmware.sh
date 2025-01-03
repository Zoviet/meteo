dmesg | grep tty
python3 -m esptool --port /dev/ttyUSB0 erase_flash
python3 -m esptool --port /dev/ttyUSB0 write_flash -fm dio 0x00000 nodemcu-release-17-modules-2025-01-01-15-13-22-float.bin
