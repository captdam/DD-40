The main controller (call it master here) is an ATmega328P, it is a powerful MCU, but it has a limited pin number. Most of the master's pin is used for peripheral devices, such as SPI, USART, ADC...
There is a lot of actuators on this ROV; however, there is not enough pins on the master controller.
An AUX MCS-51 (8051) controller (call it slave) is attached to the master controller to solve this problem. The MSC-51 MCU is a cheap, slow MCU with very little peripheral. But! (Strong voice!) with lots of IO (32 programmerable).
Amoung the 32 pins on the slave:
  P0 to P2 (24 pins) will be connect to actuators
  P3.0, P3.1 (hardware UART) will be used for debuging (connect to PC, display all the intermedia data)
  P3.2, P3.3, P3.4, P3.5 will be used for SPI communication (the MCS-51 has no hardware SPI, hence a software SPI is writen)
  P3.6 will be used as IDEL LED indecator.
  P3.7 is not used.
The slave is normally idel (power down mode). When there is a falling edge on the SS pin, it triggers the slave. Then the slave will read data from the master (SPI mode 0, MSB first, P2 first). The data is 3 bytes long, if the master provides a shorter data (consider as fail), the entire package will be ignor; if longer, the exceed data will be ignored. If the SPI transcation is successed (data is 3 bytes or longer), the slave will then decode the data and update those data to its IO pins. After a successful transcation, if the master send a new package before the slave finish process the last package, the new package will be ignored.
To deal with the problem, there is two method:
  1. The IDEL LED indecator should be connect to the master to ensure the second package is sent after the slave finishing process the first package.
  2. The master should not send package to often. The slave takes 1167 cycles to process the package (that means, 1 ms).
Since most actuator is a logic device (only accept 1 or 0, not PWM or analog), this AUX controller will takes charge of them. IO on the master will be reserved for devices that requirs PWM signal.
