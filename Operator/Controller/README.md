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


**_[S5]_** At the same time, the MCU will listen the coming data from the ROV. **_[S6]_** Once the package from the ROV is fully decoded, **_[S7]_** the MCU will decode and check the package. **_[S8]_** If the package is verified by checking the checksum, the MCU will display the data to user on LCD1. The MCU will also write the data to LCD1 buffer, instead of writing the data to LCD1 directly and stalling.

Since the Operator console is on users’ side, the user can push the RESET button at any time. Therefore, watchdog is not required on the Operator-side console.

### Send command to / Receive data from ROV
The 8051-based MCU has a combined UART ISR, which means Tx and Rx sharing the same routine. In the UART ISR, the MCU first check the source of the interrupt.

If the interrupt comes from the Tx (transmitter), it will identify that the previous word has been sent out. In this case, the MCU will check that how much word has been send out. If the package is fully sent, the MCU will stop the transmission process; otherwise, the MCU will fetch the next word from buffer and then send it out.

However, If the interrupt comes from the Rx (receiver), the MCU will check the content of the data first. If it is 0xFF, which means that the ROV wants the Operator-side console to synchronize with the ROV, the MCU will reset its step to _S2_ (scan user data) and reset Tx/Rx buffer pointer. Otherwise, the coming word will be written to the Rx buffer. Once the package is fully received, it will fire RECEIVED signal (in _S5_, the MCU will repeatedly comparing PACKAGE_SIZE with RX_POINTER. If they are equal, the MCU will stop comparing and go to _S6_).

### Communication related issue
Any word in the package may be lost or corrupted in the following cases:
- SYNCH word lost or corrupted: The operator-side console will not do anything before it receive the SYNCH signal. The console will be stalled in _S1_ (Waiting for SYNCH)
- Data word lost: The package is not fully received. Once the next package comes, this package will be discarded.
- Data word corrupted: The corrupted word is written to buffer. After package fully received, since the checksum is not matched, the coming package will be discarded.
- Data word corrupted and the value of the corrupted is 0xFF (SYNCH): The ROV's state will be reset to _S2_. The first half of the package will be discarded when the corrupted word comes; the second half will be discarded when next package comes. The operator-side console will stop the transmitter, re-scan users’ input and send a new package to the ROV. On the ROV side, it will check the checksum and discard the package.
- Lost/corrupted happens but checksum is still matched: It rarely happens and something critical may will be affected. However, once the next package comes and the next package is not lost or corrupted, everything will go back to the track.

### LCD display
The LCD is a device with a slower clock speed(0.01MIPS) comparing to MCU's clock speed (1MIPS). The MCU will write data to buffer, and a timer ISR will constantly rise and move data to the LCD display with a specific speed. Using this method could prevent MCU stalling and it helps to increase the MCU's performance.

The proper speed of the LCD subroutine will be calculated by following steps:
- f_communication = 4Hz (considering this is the signal needs to be sample)
- f_update > 2 * f_communication = 8Hz (sampling rate needs to be greater than twice of the signal frequency)
- f_interrupt = (16 + 1) * 2 * f_update = 272Hz (16 characters + 1 instruction set cursor, 2 lines)
- T_interrupt = 3.6ms  (using 3ms to have a safety factor)

Performance difference between Stall method and Buffer_Interrupt method:

Writing to LCD takes 20 cycles.
- Stall method:
	34 writes: 34 * (20 cycles to write + 100 cycles stall) = 4080 cycles
- Buffer_Interrupt method:
	34 writes: 34 * 2 sample ratio * (20 cycles to write + 20 cycles of ISR init) = 2720 cycles
- As the result, Buffer_Interrupt method is better.

### Process window
According to ?????the chart?????, there is three processes execute simultaneously, which are the main process, the UART interrupt process and the Timer0 interrupt process. The main process takes care of users’ input and package encode/decode/check; the UART process takes care of the communication between the operator-side console and the ROV; the Timer0 process takes care of LCD display.

For the UART interrupt process, since the UART on this MCU is full-duplex, the UART process could be considered as two sub-process: the transmitter process and the receiver process. In another word, there are 4 logic process executed on the MCU parallelly, which are:
- MAIN
- UART Tx (transmitter)
- UART Tx (receiver)
- LCD

In the process loop:

**[_S1]_** At the beginning, the operator-side console is waiting for package from the ROV. **[_S6]_** Before the operator could do any data processing, the package needs to be fully received. Therefore, the window for Rx receiver is S2, S3 and S4.

In state 3 of the main process **[_S3]_** , the operator-side console will pack the package and send the first word of it. Before the loop ends **[_S8]_** , the package should be fully sent. Since the transmission takes some time, there should be extra time before the loop ends. Hence, the window for Tx transmitter includes part of S3, from S4 to S7, and the beginning of S8. ?????Shorter is better?????.

In order to update LCD display, the MCU writes to buffer, and a timer interrupt constantly rise and write the data to the LCD modules. Hence, the window for LCD writing covers the entire loop.

As the result, the window of UART is limited, and packages need to be sent in a given period. In order reach the long-distance transmission, the BAUD rate of the UART is low. The loop needs to be short and the frequency needs to be higher to have precise control. In the design, the BAUD rate is 2400 and the loop time is 250ms, which means:
- The transmission system cannot handle too much word, otherwise it will not be possible to transit the package in the give window. Therefore, only critical data should be put on the line.
- During constructing the code, people should try to provide more time for these two windows to make S6, S7 and S6 shorter.


## Code description

1 . Why should we choose assembly language instead of C?
- On the 8051, resources are limited. Using assembly helps to control resource usage more precisely.
- This MCU is a modified version of original Intel 8051. Although the MCU is compatible with the legacy C51 compiler, it cannot utilize all resources which are provided by the MCU, and it may utilize some resource exist on the legacy Intel 8051 but available on the MCU.
- Some tricky could be applied in assembly language (e.g. frame buffer modification) only. 
- Writing in assembly language provides a better control of the device (e.g. stack manipulation).
- Higher performance.
2. Design philosophy： (MIPS 4 design principles)
- _Simplicity favors regularity._
- _Smaller is faster._
- _Good design demands compromise._
- _Making the common case fast._

In this section, each lines of the code will be reviewed. Inline comments are given by the code.

Code will be divided into blocks, and comments are given to each block.

### Note
When coding, following these:
1. There is 4 register banks, and each bank has 8 registers. 2 of the 8 registers has the ability of register addressing. The main routine uses regsiter bank 0; the timer 0 ISR uses register bank 2; and the UART ISR uses register bank 3. Register banks uses same instruction but different physical RAM address. Using different register banks help reduce house keeping overhead.
2. There is 4 RAM space:
	- SRAM 0x00 - 0x7F: Registers, custom static variables.
	- SRAM 0x80 - 0xFF (direct address): SFR of the MCU.
	- SRAM 0x80 - 0xFF (indirect addressing / register addressing): Stack.
	- XRAM 0x0000 - 0x00FF: External (used to be external, but now build-in, can be extended by adding external RAM chip): UART and LCD buffer.
3. When should use loop / loop unrolling, function / function inlining:
	- If only used once or few times: loop unrolling and function inlining. Using loop or functiin cannot reduce code size, plus it will increase house keeping overhead.
	- If timing is critical: loop unrolling and function inlining. Calling / return from function takes a few cycle; loop control takes some cycles.
	- If the function body / loop body is very small: loop unrolling and function inlining. Using function / loop reduce the ratio of function/cycle.
	- If used for more times: loop and function. It is worth to increase some overhead, because it save a great amount of ROM space.

### 

