# Fennec Source

This folder contains the assembly source and data files for the current prototype testing program, these are separated into 2 parts that must be assembled seperately, as followed using CapyASM:

* `capyasm -i boot.asm` - This is the boot rom, placed within an assumed 8Kb EEPROM, it initializes an sd card and loads a run.65x file from it. Placed at address **$E000**
* `capyasm -i run.asm` - This is the executable program that is stored on the sd card, the resulting file should be named "RUN.65X" and stored in the root of the card, which should be formated to FAT32. Placed at address **$0800** to **$7FFF** (using bank 0).