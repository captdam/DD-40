# ROV tech document - Control software

## Introduction

This document will describe the control software of the ROV in a abstruction level and provide a detail description parts that are important or easy to misunderstand. For a fully detailed description, refer to the code.


## Design requirements

There are two MCU on the ROV, which are the main MCU and the AUX MCU.

The task of the main MCU are:
- Communication with operator-side console, pack the data packet and unpack the control packet
- Voltage monitoring by measureing the voltage of the power supply using ADC
- Collect attitude data by communicate with the gyro sensor via I2C bus
- Collect depth data by measureing the voltage of the pressure sensor
- Auto pilot function calculation
- Drive the pump using PWM
- Control headlight and navigation light
- Send command to AUX controller via I2C

The AUX controller is responsible for:
- Receive data from the main controller
- Control the valves

## Setup MCU

The ROV is powered by 2 ATmega328P MCU. Before using the MCU, it is important to config the fuse of the MCU to make sure the MCU is running in the correct mode. To config an AVR MCU, it is required to modify the fuse using serial programming interface or parellel programming interface using a programmer.

When the factory ships the MCU, the fuse is pre set to be 0xFF, 0xD9, 0x62.

### Extended fuse

__E[2:0]__ BODLEVEL = 0b111: Brown-out detection is off. The brown-out detection is a device that will raise an interrupt when the supply voltage is under the threshold level. Since the ROV is powered by an 12V battery and there is voltage monitoring software, the brown-out detection should be disabled.

### High fuse

__H[7]__ RETDISBL = 1: Pin1 is configed to be RESET pin instead of GPIO PC6. It is important to have a way to physically reset the MCU without cut-off the power. If the software and watchdog are both failed, the RESET pin will be the only way to reset the MCU.

__H[6]__ DWEN = 1: debugWIRE is disabled. debugWIRE is not used during the design and debuging process.

__H[5]__ SPIEN = 0: Serial programming is enabled. The serial programming is way to programming the MCU using the SPI interface. In another word, program the MCU by connecting the programmer to the ICSP of the circuit board. This should be disable when sell the programmed MCU to customers and does not want the customer to re-program the MCU.

__H[4]__ WDTON = 1: By default, the watchdog is disabled. Since the startup of software may be long, it is recommand to turn off the watchdog by default. Instead, the watchdog should be turned on after the software initialized.

__H[3]__ EESAVE = 1: Data stored in EEPROM will be earsed during programming. Since EEPROM is not used, this setting is not important.

__H[2:1]__ BOOTSIZE = 0b00: The size of bootloader is 1024 bytes. Since the bootloader is not used in this system, __this should be modified to 0b11__, which uses the least amount of flash memory space.

__H[0]__ BOOTRST = 1: The MCU will start from main program space instead of bootloader space. Since bootloader is not used in this system, the MCU should start from main program space.

### Low fuse

__L[7]__ CKDIV8 = 0: By default, the clock of the MCU will be divided by 8. Since the MCU will be clocked by internal RC clock, which the frequency is not as stable as external crystal, the clock should be divided by 8 to provide a smoother clock frequency. Divide the clock by 8 will cause the computation power dropped by 8 times, but the compermize is stable and reliable RC clock.

__L[6]__ CKOUT = 1: By default, pin14 of the MCU will be GPIO. If modify this to 0, pin14 will ouitput the clock of the MCU. This is usable when multiple MCU should be working at synchnolize mode, or when trim the internal RC clock.

__L[5:4]__ SUT = 0b10: This config the start-up time of the MCU. Due to capactance of the internal components of the MCU, it takes a while for all the components wo be ready to operat. If this period is too short, the MCU may not work. Since the start-up time is not critical for the ROV system, the SUT is set to be 0b10, which gives the MCU the longest time to prepare.

__L[3:0]__ CKSEL = 0b0010: This set the clock source to be interbnal RC clock. Comparing to external crystal, using internal RC clock requires less external components and provides two extra GPIO.


## Main controller software

### Setup

### Mian task loop


## AUX controller software

### Setup

### Main task loop
