# Operator-side console tech document - Software

## Introduction

The operator-side console is an interface for users to control the ROV. It was formed by four components: a set of keyboard, switches and joysticks, an LCD video monitor, two 1602 LCD displays, and an 8051-based microcontroller system.

There are two subsystems in the operator-side console: **ROV control system** and **Video monitor system**. The ROV control system combines with the keyboard, switches, joysticks, 8051-base MCU system and two 1602 LCD displays. The ROV control system includes two functions: encoding users’ input (command) and sending to ROV, decoding ROV data and displaying. The video monitor system is much simpler than the ROV control system, it receives PLA video signal, and then display it on the LCD video monitor.

This document will describe how the operator-side console work in the software's perspective. Since there is no manipulation on the video monitor system, this document is purely focus on the ROV control subsystem.


## Overview

This section will provide an abstraction-level description about how the control system works. Some of descriptions are not 100% correct, but they provide briefly ideas that help people to understand the mechanism of the system.

The chart below demonstrates a simple flow of the control system. Notice that, the main routine, the UART ISR (interrupt service routine) and the Timer0 ISR are logically simultaneous (these three routines are sharing the CPU).

![Operator Flow Chart](https://raw.githubusercontent.com/captdam/DD-40/master/Operator/Controller/Operator%20Flow%20Chart.jpg "Operator Flow Chart")

### Process flow
0. System initialization: Setup UART and LCD display refresh timer.
1. Waiting for SYNCH signal: The ROV will send a SYNCH signal to the operator-side console, that will synchronize the operator-side console with the ROV (the ROV is the master). This helps the operator-side console and the ROV be in the same phase.
2. Getting user input: Scanning the input matrix (keyboard, switches and joystick).
3. Packing the data (command): Encoding users’ input, calculating the checksum and then sending the package to the ROV. This starts the transmission process, which will take few milliseconds (about 50ms to 100ms).
4. Updating command UI: Displaying users’ input data on the LCD display.
5. Waiting for the RECEIVED signal: The ROV will send package to the operator-side console. The first byte of the package is the SYNCH signal, and it was followed by 10 to 15 bytes of data. The transmission process will take a while, and the package may not be fully received before this step. As result, the MCU will stall until the package is fully received.
6. Verifying the data: Checking the checksum.
7. Decoding the data.
8. Updating command UI: Displaying the ROV data on the LCD display.
9. Going back to step 1.


## Process design

### Main process
**[_S0]_** When the operator-side console was reset by turning on the power or pushing the reset key, the MCU initialize the system firstly. The initialization includes turning on UART transmitter/receiver, starting timer for LCD, and initializing LCD display. Furthermore, the MCU will begin to listen the ROV via the UART.

**_[S1]_** The ROV sends package to the Operator-side console every 250ms, and the first word in the package is always SYNCH. Once the operator-side console see a SYNCH signal from the ROV, **_[S2]_** it will scan users’ input (users’ command) from the keyboard, switches and joysticks. **_[S3]_** Furthermore, the MCU will encode (pack) users’ input into a package, calculate the checksum, and send the packet and checksum to ROV. Since the UART is a slow device (BAUD = 2400) compare to the MCU's CPU clock, the MCU cannot afford the time of waiting the UART to send all the data out before moving to next state. In this case, the MCU will write all data into Tx buffer (in XRAM of 8051) and start the UART transmitter.

**_[S4]_** The ROV is equipped with Auto-pilot function, and users are able to send command to the ROV, such as setting the ROV's direction to Bearing 270. To display the current auto-pilot settings, there is an LCD on the operator-side console called LCD0. The MCU will write the users’ inputs (auto-pilot settings) on LCD0. According to the datasheet of 1602 LCD, after sending instruction, the LCD module requires 100us processing time before receiving next instruction. Instead of stalling the MCU for 100 cycles to wait for the process finishing, it is better to let the MCU write the data into LCD0 buffer (XRAM).


**_[S5]_** At the same time, the MCU will listen the coming data from the ROV. **_[S6]_** Once the package from the ROV is fully decoded, **_[S7]_** the MCU will decode and check the package. **_[S8]_** If the package is verified (checksum OK), the MCU will display the data to user on LCD1. Simular to _S4_, the MCU will write the data to LCD1 buffer, instead of writing to LCD1 directly and stall.

Because the Operator console is on the user's side, the user can push the RESET button at any time they need. Hence, watchdog is not required on the Operator-side console.

### Send command to / Receive data from ROV
The 8051-based MCU has a combined UART ISR (Tx and Rx shares the same routine). In the UART ISR, the MCU first check the source of the interrupt.

If it comes from the Tx (transmitter), it means the previous word has been sent out. In this case, the MCU will check that how much word has been send out. If the package is fully sent, the MCU stops the transmitting processs; otherwiase, the MCU will fetch the next word from buffer and then send it out.

If it comes from the Rx (receiver), the MCU first check the content of the data. If it is 0xFF, it means the ROV wants the Operator-side console to synchronize with the ROV. In this case, the MCU will reset its step to _S2_ (scan user data) and reset Tx/Rx buffer pointer. Otherwise, the comming word will br write to the Rx buffer. Once the package is fully receiverd, it fires RECEIVED signal (actualy, in _S5_, the MCU will repeatly comparing PACKAGE_SIZE with RX_POINTER. If they are equal, the MCU will stop comparing and go to _S6_).

### Communication related issue
Any word in the package may be lost or corrupted. If:
- SYNCH word lost or corrupted: The operator-side console will not do anything before it receive the SYNCH signal. The console is stalled in _S1_ (Waiting for SYNCH)
- Data word lost: The package is not fully received. Once the next package comes, this package will be discard.
- Data word corrupted: The corrupted word will be write to buffer. After package fully received, because the checksum is not matched, the comming package will be discard.
- Data word corrupted and the value of the corrupted is 0xFF (SYNCH): The ROV's state will be reset to _S2_. The first half of the package will be discard when the corrupted word comes; the second half will be sidcard when next package comes. The operator-side console will stop the transmitter, re-scan user input and send the a new package to ROV. On the ROV side, the ROV will check the checksum and discard the package.
- Vary bad luck, lost/corrupted happens but checksum is still matched: Bad luck, something critical may be affected. But, once the next package comes and the next package has no lost nor corrupted, everyting will go back on track.

### LCD display
The LCD is a slow device (0.01MIPS) comparing to MCU's clock (1MIPS). The MCU will write data to buffer, and a timer ISR will constantly rise and move data to the LCD display with a specific speed. Using this method could prevent MCU stall and helps increase the MCU's performance.

To calculate the proper speed of the LCD subroutine:
- f_communication = 4Hz (consider this to be the signal needs to be sample)
- f_update > 2 * f_communication = 8Hz (sample rate needs to be greater than twice of the signal frequency)
- f_interrupt = (16 + 1) * 2 * f_update = 272Hz (16 character + 1 instruction set cursor, 2 lines)
- T_interrupt = 3.6ms (To have a safty factor, using 3ms)

Performance difference between Stall method and Buffer_Interrupt method:

Write to LCD take 20 cycles
- Stall method:
	34 writes: 34 * (20 cycles to write + 100 cycles stall) = 4080 cycles
- Buffer_Interrupt method:
	34 writes: 34 * 2 sample ratio * (20 cycles to write + 20 cycles of ISR init) = 2720 cycles
- Buffer_Interrupt method is better.

### Process window
As the chart shows, there is three process execute simultaneously: the main process, the UART interrupt process and the Timer0 interrupt process. The main process takes care of user input, package encode/decode/check; the UART process takes care of the communication between the operator-side console and the ROV; the Timer0 takes care of LCD display.

For the UART interrput process, becuase the UART on this MCU is full-duplex, the UART process could be consider as two sub-process: the transmitter process and the receiver process. In another word, there are 4 logic process executed on the MCU parallely, that are:
- MAIN
- UART Tx (transmitter)
- UART Tx (receiver)
- LCD

In the process loop:

**[_S1]_** At the beginning, the operator-side console is waiting package from the ROV. **[_S6]_** Before the operator could do any data processing, the package needs to be fully received. Hence, the window for Rx receiver is S2, S3 and S4.

In state 3 of the main process **[_S3]_** , the operator-side console will pack the package and send the first word. Before the loop ends **[_S8]_** , the package should be fully send out. Because the transmission takes a while, there should be extra time before the loop ends. Hence, the window for Tx transmitter includes part of S3, from S4 to S7, and the beginning of S8, shorter is better.

To update LCD display, the MCU writes to buffer, and a timer interrupt constantly rise and write the data to the LCD modules. Hence, the window for LCD writing covers the entire loop.

this means, the window of UART is limited, packages need to be send in the given time. To have long-distance tranmission, the BAUD rate of the UART is low. To have precise control, the loop needs to be short (so the frequency will be higher). In this design, the BAUD rate is 2400 and the loop time is 250ms. That been said:
- The transmission system cannot handle too much word, otherwise it will not be possible to transit the package in the give window. Hence, only critical data should be put on the line.
- When writing the code, try to provide more time for these two window. this means, making S6, S7 and S6 shorter.


## Code description

1 . Why assembly instead of C?
- On 8051, resources are limited. Using assembly helps precisely control resource usage.
- The MCU used here is a modified version of orginal Interl 8051. Althrough the MCU is compatible with the legacy C51 compiler, it cannot utilize all resource provided by the MCU, and it may utilize some resource exist on the legacy Intel 8051 but aviable on the MCU.
- Some tricky could be performed in assembly (e.g. frame buffer modification). Something could not be done if using C.
- Writing in assembly provides more control of the device than C (e.g. stack manipulation).
- Higher performance.
2. Design philosophy： (MIPS 4 disign principles)
- _Simplicity favors regularity._
- _Smaller is faster._
- _Good design demands compromise._
- _Make the common case fast._

In this section, each lines of the code will be reviewd. Inline commentis given in the code.

Code will be devided into blocks, comments are given to each blocks.

(WIP)
