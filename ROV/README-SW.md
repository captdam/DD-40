# ROV tech document - Control software

## Introduction

This document will describe the control software of the ROV in a abstruction level and provide a detail description parts that are important or easy to misunderstand. For a fully detailed description, refer to the code.

In this document, the following terms will be used:
- SFR: Special function register. A SFR is a special register that controls the behavior of a specific components of the MCU.
- Polling: The CPU will wait for reply. During the waiting period, the CPU will not do any job other than continuous checking for result. Once the reply is ready, the CPU fetch the data and go to next job.
- Interrupt: The CPU will not wait for reply. Instead, the CPU will go to next job. When the reply is ready, an interrupt will be raised. The CPU will then return back to fetch the data.

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

__L[6]__ CKOUT = 1: By default, pin14 of the MCU will be GPIO. If __modify this to 0, pin14 will ouitput the clock of the MCU. This is usable when multiple MCU should be working at synchnolize mode, or when trim the internal RC clock__.

__L[5:4]__ SUT = 0b10: This config the start-up time of the MCU. Due to capactance of the internal components of the MCU, it takes a while for all the components wo be ready to operat. If this period is too short, the MCU may not work. Since the start-up time is not critical for the ROV system, the SUT is set to be 0b10, which gives the MCU the longest time to prepare.

__L[3:0]__ CKSEL = 0b0010: This set the clock source to be interbnal RC clock. Comparing to external crystal, using internal RC clock requires less external components and provides two extra GPIO.

### Trim the internal RC clock

The RC clock has been trim by factory within 10% error. However, in order to reduce the BAUD error when proform UART communication, the clock should be as acurate as possible. To trim the internal clock, first program the low fuse to 0x22. By doing this, the clock will be output on pin 14 of the MCU.

The following graph shows the clock before calibrate:
![Before calibration](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/doc/calib-before.jpg "Before calibration")


then, connect a scope to that pin, and program the MCU with the following code:
```C
#include <avr/io.h>
#include <avr/interrupt.h>

#define RC_CLOCK_CALIBRATE 0xA0

int main(void) {
	CLKPR = 0x80;
	CLKPR = 0x03; //Clk divider = 8
	OSCCAL = RC_CLOCK_CALIBRATE;
	
	for(;;);
}

```
where ```RC_CLOCK_CALIBRATE``` is a perdefined 8 bits long constabne. Writing this value into SFR OSCCAL will trime the frequency of the internal RC clock. The value of ```RC_CLOCK_CALIBRATE``` is determined by using brute force.

The voltage of MCU has a very monir effect on the frequency of the RC clock. A trimed RC clock proforms 1MHz frequency when powered by 5V power supply, and proforms 997kHz when powered by 3.3V power supply. However, it is recommanded to calibrate the RC clock under the desired working voltage for best possible accuaracy.

After calibration, the clock output is shown below::
![After calibration](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/doc/calib-before.jpg "After calibration")



## Main controller software

The task of the MCU is to communicate with operator-side console via UART interface, communicate with local sensor and AUX controller using I2C and ADC, and drive some acturators using GPIO.

### Setup

When the main controller is powered up, the following task will be proformed:
- Trim the RC clock
- Init UART
  - Set up BAUD rate generator to provide 2400 BAUD rate clock to the UART module.
  - Turn on Tx, Rx and enable Tx, Rx interrupt.
- Init IO
  - Setup port direction and pull down all the output, make sure no actuactor is energized.
- Init ADC
- Init I2C
  - Setup I2C in master mode, config the I2C module to provide 38.46kHz clock.
- Init gyro sensor MPU-9250:
  - Reset motion sensor and signal path. This is used to reset and zero the sensor.
  - Config the AUX I2C bus to connect the compass AK8963.
  - Init compass AK-8963.
- Init timer0
  - Setup prescaler and compare vale, working in CTC mode. The timer0 will be reset and raise a compare interrupt every 250'000 CPU cycle. Since the CPU is working at 1MHz, it will be 250ms.
  - Once the timer0 raise the interrupt, the MCU execute the main task loop once.
  - The timer0 is a 8-bit timer. Since the time interval for executing the main tack loop is not critical, a low-resolution interrupt could satisfy the requirement.
- init timer1
  - Setup the reset value to 100, working in fast PWM mode. PWM frequency is 1.25kHz.
  - By modify the compare register ```OCR1A``` and ```OCR1B```, the timer outputs PWM on pin15 and pin16 with the given duty cycle. For example, writing 34 to the SFR ```OCR``` will generate 34% duty cycle PWM signal.
  

### Mian task loop
During the main task loop, the following task will be proformed:

__Check control packet__

The MCU first check for control packet send by the operator-side console during the last main task loop. The packet is saved in Rx buffer.

If the packet is verified, which means the packet is fully received and the checksum is matched with the packet content, the packet will be unpacket. In this case, the ROV will be proformed in such way that the control packet requires.

Otherwise, the packet will be dropped. In this case, the behavir of the ROV will not be changed. In another word, the ROV will be proformed in such way that the last verified control packet requires.

__Get ROV status form sensor__

The ROV will then collect data from sensor.

Attitude data will be collected from gryo sensor using I2C; depth of the ROV and voltage of the ROV will be collect from ADC interface of the MCU. Since the I2C is working in a high frequency, the ROV will use polling method.

the data provided by sensors are raw data. In order to use those data, the MCU will do some calculations. For the attitude data, the CPU will proform some trigonometric calculation. For example, the pitch of the ROV can be calculated by using the arctan of the upward-axis and the forward-axis.

for depth and battery voltage, lookup table will be used. Compare to arithmatic calculation, lookup table provides the result in only one CPU cycle. If the amount of possible input is limited, lookup table provides higher performance with not too much program memory space comsumption.

These informations will be saved for further use.

__Send data packet to operator-side__

Next, the ROV will send data to the operator, include the depth, pitch, compass, temperature and supply voltage. All data is in BCD format.

To send the packet, the MCU will put all the data in the Tx buffer memory space, and calculate the checksum. To send a packet, the main routine will send a synch signal to start the transmission process. Once the data is sent out, the next word in the Tx buffer will be send in the interrupt service routine. This process will contine until the last word being sent out.

__Control packet analysis and AP function__

While the MCU sending the data packet, the main process of the MCU will analysis the user's input. Base on the user's command in the control packet, desired valve should be open. If the auto pilot function is enabled, the status of the ROV and the Auto pilot configuration will be consider as well.

At the end of this process, the ROV could figure out the duty of each valve. In another word, how long should the valve open in order to proform the desired action.

__Drive the actuactors__

the main controller is connected with the headlight, navigation light, and the pump. In this process, the main controller will apply digital signal to the pins where the headlight and the navigation light are connected; PWM signal to the pin where the pump is connected.

To control the valves, which are connected to the AUX controller. The main controller will send command to the AUX controller via I2C bus.



## AUX controller software

The task of the AUX controller is to control the valve bas on command given by the main controller. Because there is 10 valves, and the valves should be driving using PWM. In another word, in a given period of time, the valve should be turn on for a specified period. There is only 6 hardware PWM channel in ATmega328P, which is not sufficient. Fortunately, the valve is working at very low frequency; therefore, a software PWM could be used.

### Setup

When the AUX controller is powered up, the following task will be proformed:
- Trim the RC clock
- Init UART
  - Set up BAUD rate generator to provide 2400 BAUD rate clock to the UART module.
  - Turn on Tx, Rx. No interrupt here. Since the UART is only used for debugging purpose, the MCU will using polling method for UART communication.
- Init IO
  - Setup port direction and pull down all the output, make sure no actuactor is energized.
- Init ADC
- Init I2C
  - Setup I2C in slave mode.
- Init timer0
  - Setup prescaler and compare vale, working in CTC mode. The timer0 will be reset and raise a compare interrupt every 980 CPU cycle. Since the CPU is working at 1MHz, it will be 0.98ms.
  - This timer is used to provide software PWM signal to drive the valves. The period of the PWM should be 250ms, and the PWM resolution should be 255. Therefore, the timer interrupt should be raised every 250ms / 255 = 980us.

### Main task loop

__PWM routine__

There is an internal counter count from 0 to 254 and then starts from 0 again.

For each channel, there is a varibale records the duty of that channel. When the variable is larger than the counter, the channel output high; otherwise, this channel outputs low.

For example, the duty of a channel is 38. Then, the valve connected to this channel will be turned on when the counter is in the range of 0 to 37, and off if the counter is in the range of 38 to 254.

__I2C routine__

When a start condition is detected, the MCU will reset the Rx buffer.

Once the I2C receiver receive a word from the main controller, the data will be placed in the Rx buffer.

Once the I2C communication is terminated by a stop condition, the MCU will verify the data, both the packet length and checsum. If the data is verified, the command data will be applied to the output software PWM channels.
