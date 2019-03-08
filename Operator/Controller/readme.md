# Operator-side console

## About this document

The operator-side console is an interface for the user to control the ROV. It has 4 key components: a set of keyboard, switches and joystick, a LCD video monitor, two 1602 LCD display, and an 8051-based microcontroller system.

There is two subsystem in the operator-side console: **ROV controlling system** and **Video monitoering system**. The ROV controlling system combines the keyboard, switches, joystick, 8051-base MCU system and 2 1602 LCD display. The ROV controlling system has two job: Incode user input (command) and send to ROV, decode ROV data and display to user. The video monitoring system is way simpler than the ROV controlling, it receives PLA video signal, and then directly display it on the LCD video monitor.

This document will description how the operator-side console work in the software's perspective. Since there is no minipunation on the video minitoring system, this document is purely focus on the ROV controlling subsystem.


## Overview

This section will provide a abstraction-level description about how the controlling system work, some description is not 100% precent correct, but it provides an briefly idea that helps understanding the mechanism of the system.

The chart below shows a simnple flow of the controlling system. Notice that, the main routine, the UART interrupt routine and the Timer0 interrupt routine are logiclly simultaneously (these three routines are sharing the CPU).

![Operator Flow Chart](https://raw.githubusercontent.com/captdam/DD-40/master/Operator/Controller/Operator%20Flow%20Chart.jpg "Operator Flow Chart")

### Process flow
0. System initialization: Setup UART and LCD display refersh timer.
1. Wait for SYNCH signal: The ROV will send a SYNCH signal to the operator-side console, that will synchlize the operator-side console with the ROV (the ROV is the master). This helps the operator-side console and the ROV be in the same phase.
2. Get user input: Scan the input matrix (keyboard, switches and joystick).
3. Packing the data (command): Encode the user input, calculate the checksum and then send the package to the ROV. Notice, this starts the transmission process, this process will takes few miniseconds (about 50ms to 100ms).
4. Update command UI: Display the user input data on the LCD display.
5. Wait for RECEIVED signal: The ROV will send package to the operator-side console. The first byte of the package is the SYNCH signal, follow by 10 to 15 bytes of data. The transmission process will take a while, and the package my not be fully received before this step. In this step, the MCU will stall here, until the package is fully received.
6. Verify the data: Check the checksum.
7. Decode the data.
8. Update command UI: Display the ROV data on the LCD display.
9. Go back to step 1.

## Process design

### Main process
When the operator-side console reset (power on or push the reset key), the MCU will first initial the system. After this, the MCU will begin to listen the ROV vis the UART. Once the operator-side console see a SYNCH signal from the ROV, it will scan the user input (user command) from the keyboard, switches and joystick, and then encode (pack) the user input into package and send to ROV. At the same time, the MCU will listen the coming data from the ROV. Once the package from the ROV is fully decoded, the MCU will decode and check the package. If the package is verified to be correctly transmitted, the MCU will display the data to user.

### Send command to / Receive data from ROV
The 8051-based MCU has a combined UART interrupt routine (Tx and Rx shares the same routine). In the UART interrupt routine, the MCU first check the source of the interrupt.

If it comes from the Tx (transmitter), it means the last byte has been sent out. In this case, the MCU will check that how much byte has been send out. If the package is fully sent, the MCU stops the transmitting processs; otherwiase, the MCU will fetch the next byte and then send it out.

If it comes from the Rx (receiver), the MCU first check the content of the data. If it is 0xFF, it means the ROV wants the Operator-side console to synchronize with the ROV. In this case, the MCU will reset its step to S2 (scan user data)


## Details


## Code description
