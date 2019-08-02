# Operator-side console tech document - Software

## Introduction

The operator-side console is an interface for users to control the ROV. It was formed by four components: a set of keyboard, switches and joysticks, an LCD video monitor, two 1602 LCD displays, and an 8051-based microcontroller system.

There are two subsystems in the operator-side console: **ROV control system** and **Video monitor system**. The ROV control system combines with the keyboard, switches, joysticks, 8051-base MCU system and two 1602 LCD displays. The ROV control system includes two functions: encoding users’ input (command) and sending to ROV, decoding ROV data and displaying. The video monitor system is much simpler than the ROV control system, it receives PLA video signal, and then display it on the LCD video monitor.

This document will describe how the operator-side console work in the software's perspective. Since there is no manipulation on the video monitor system, this document is purely focus on the ROV control subsystem.

In this document, the following terms will be used:
- SFR: Special function register. A SFR is a special register that controls the behavior of a specific components of the MCU.
- ISR: Interrupt Service Routine. When an interrupt raised, the CPU will pause current job and process the task in the ISR. After the CPU finish the task in the ISR, the CPU return back to the previous job.



## Overview

This section will provide an abstraction-level description about how the control system works. Some of descriptions are not 100% correct, but they provide briefly ideas that help people to understand the mechanism of the system. For a fully detailed description, refer to the code.

The chart below demonstrates a simple flow of the control system. Notice that, the main routine, the UART ISR and the Timer0 ISR are logically simultaneous (these three routines are sharing the CPU).

![Operator Flow Chart](https://raw.githubusercontent.com/captdam/DD-40/master/Operator/Controller/Operator%20Flow%20Chart.jpg "Operator Flow Chart")

### Process flow
0. System initialization: Setup UART and LCD display refresh timer.
1. Waiting for SYNCH signal: The ROV will send a SYNCH signal to the operator-side console, that will synchronize the operator-side console with the ROV (the ROV is the master). This helps the operator-side console and the ROV be in the same phase.
2. Getting user input: Scanning the input matrix (keyboard, switches and joystick).
3. Packing the data (command): Encoding users’ input, calculating the checksum and then sending the package to the ROV. This starts the transmission process, which will take few milliseconds (about 50ms to 100ms).
4. Updating command UI: Displaying users’ input data on the LCD display.
5. Waiting for the RECEIVED signal: The ROV will send package to the operator-side console. The first byte of the package is the SYNCH signal, and it was followed by 16 bytes of data. The transmission process will take a while, and the package may not be fully received before this step. As result, the MCU will stall until the package is fully received.
6. Verifying the data: Checking the checksum.
7. Decoding the data.
8. Updating command UI: Displaying the ROV data on the LCD display.
9. Going back to step 1.


## Process design

### Main process
**_[S0]_** When the operator-side console was reset by turning on the power or pushing the reset key, the MCU initialize the system firstly. The initialization includes turning on UART transmitter/receiver, starting timer for LCD, and initializing LCD display. Furthermore, the MCU will begin to listen the ROV via the UART.

**_[S1]_** The ROV sends package to the Operator-side console every 250ms, and the first word in the package is always SYNCH. Once the operator-side console see a SYNCH signal from the ROV, **_[S2]_** it will scan users’ input (users’ command) from the keyboard, switches and joysticks. **_[S3]_** Furthermore, the MCU will encode (pack) users’ input into a package, calculate the checksum, and send the packet and checksum to ROV. Since the UART is a slow device (BAUD = 2400) compare to the MCU's CPU clock, the MCU cannot afford the time of waiting the UART to send all the data out before moving to next state. In this case, the MCU will write all data into Tx buffer (in XRAM of 8051) and start the UART transmitter.

**_[S4]_** The ROV is equipped with Auto-pilot function, and users are able to send command to the ROV, such as setting the ROV's direction to Bearing 270. To display the current auto-pilot settings, there is an LCD on the operator-side console called LCD0. The MCU will write the users’ inputs (auto-pilot settings) on LCD0. According to the datasheet of 1602 LCD, after sending instruction, the LCD module requires 100us processing time before receiving next instruction. Instead of stalling the MCU for 100 cycles to wait for the process finishing, it is better to let the MCU write the data into LCD0 buffer (XRAM).


**_[S5]_** At the same time, the MCU will listen the coming data from the ROV. **_[S6]_** Once the package from the ROV is fully decoded, **_[S7]_** the MCU will decode and check the package. **_[S8]_** If the package is verified by checking the checksum, the MCU will display the data to user on LCD1. The MCU will also write the data to LCD1 buffer, instead of writing the data to LCD1 directly and stalling.

Since the Operator console is on users’ side, the user can push the RESET button at any time. Therefore, watchdog is not required on the Operator-side console.

### Send command to / Receive data from ROV
The 8051-based MCU has a combined UART ISR, which means Tx and Rx sharing the same routine. In the UART ISR, the MCU first check the source of the interrupt.

If the interrupt comes from the Tx (transmitter), it will identify that the previous word has been sent out. In this case, the MCU will check that how much word has been send out. If the package is fully sent, the MCU will stop the transmission process; otherwise, the MCU will fetch the next word from buffer and then send it out.

However, If the interrupt comes from the Rx (receiver), the MCU will check that whether the data is the starting of a new packet or a data word of last packet. To do this, the MCU measures the time interval between this Rx interrupt and the last Rx interrupt. If the time interval longer than the time to send one word, that means it is a starting of a new packet. In this case, the ROV wants the Operator-side console to synchronize with the ROV, the MCU will reset its step to _S2_ (scan user data) and reset Tx/Rx buffer pointer.

If the time interval is about the time to send one word, that means it is a data word of the last packet. In this case, the data should be write to Rx buffer. Once the package is fully received, it will fire RECEIVED signal (in _S5_, the MCU will repeatedly comparing PACKAGE_SIZE with RX_POINTER. If they are equal, the MCU will stop comparing and go to _S6_).

For deatil about the communication process, refer to the Communication protocal tect document.

### LCD display
The LCD is a device with a slower clock speed(0.01MIPS) comparing to MCU's clock speed (1MIPS). The MCU will write data to buffer, and a timer ISR will be constantly raised to move data to the LCD display with a specific speed. Using this method could prevent MCU stalling and it helps to increase the MCU's performance.

__The proper speed of the LCD subroutine will be calculated by following steps:__
- f_communication = 4Hz (considering this is the signal needs to be sample)
- f_update > 2 * f_communication = 8Hz (sampling rate needs to be greater than twice of the signal frequency)
- f_interrupt = (16 + 1) * 2 * f_update = 272Hz (16 characters + 1 instruction set cursor, 2 lines)
- T_interrupt = 3.6ms  (using 3ms to have a safety factor)

__Performance difference between Stall method and Buffer_Interrupt method:__

Writing to LCD takes 20 cycles.
- Stall method:
	34 writes: 34 * (20 cycles to write + 100 cycles stall) = 4080 cycles
- Buffer_Interrupt method:
	34 writes: 34 * 2 sample ratio * (20 cycles to write + 20 cycles of ISR init) = 2720 cycles
- As the result, Buffer_Interrupt method is better.

### Process window
According to the FSM chart, there is three processes execute simultaneously, which are the main process, the UART interrupt process and the Timer0 interrupt process. The main process takes care of users’ input and package encode/decode/check; the UART process takes care of the communication between the operator-side console and the ROV; the Timer0 process takes care of LCD display.

For the UART interrupt process, since the UART on this MCU is full-duplex, the UART process could be considered as two sub-process: the transmitter process and the receiver process. In another word, there are 4 logic process executed on the MCU parallelly, which are:
- MAIN
- UART Tx (transmitter)
- UART Tx (receiver)
- LCD

In the process loop:

**_[S1]_** At the beginning, the operator-side console is waiting for package from the ROV. **_[S6]_** Before the operator could do any data processing, the package needs to be fully received. Therefore, the window for Rx receiver is S2, S3 and S4.

In the third state of the main process **_[S3]_** , the operator-side console will pack the package and send the first word and the package should be fully sent before the end of **_[S8]_** . Since the transmission takes time and the time of the whole frame(s1 to s8) can not be changed, the processing time before **_[S3]_** should be as short as possible in order to leave enough time for the transmission. Meanwhile, even though the window for the Tx transmitter includes a part of S3, S4, S5, S6, S7, and the beginning of S8, it is very necessary to make the transmission period as short as possible. There are two methods to reduce the time of UART processing. One is sending fewer words, and the other one is to send words faster. Since fast transmission speed is not reliable in the long-range environment, the only way to reduce the time is to reduce the length of the message. As a result, the UART will only send critical data.

In order to update LCD display, the MCU writes to buffer, and a timer interrupt constantly rise and write the data to the LCD modules. Hence, the window for LCD writing covers the entire loop.

As the result, the window of UART is limited, and packages need to be sent in a given period. In order reach the long-distance transmission, the BAUD rate of the UART is low. The loop needs to be short and the frequency needs to be higher to have precise control. In the design, the BAUD rate is 2400 and the loop time is 250ms, which means:
- The transmission system cannot handle too much word, otherwise it will not be possible to transit the package in the give window. Therefore, only critical data should be put on the line.
- During constructing the code, people should try to provide more time for these two windows to make S6, S7 and S6 shorter.


## Software design

### Using Assembly language instead of C
- On the 8051, resources are limited. Using assembly helps to control resource usage more precisely.
- This MCU is a modified version of original Intel 8051. Although the MCU is compatible with the legacy C51 compiler, it cannot utilize all resources which are provided by the MCU, and it may utilize some resource exist on the legacy Intel 8051 but available on the MCU.
- Some tricky could be applied in assembly language (e.g. frame buffer modification) only. 
- Writing in assembly language provides a better control of the device (e.g. stack manipulation).
- Higher performance.

### Memory allocation

There are 4 RAM space in the MCU:

__SRAM 0x00 - 0x7F__

There are 128 bytes of SRAM in this block, which can be addressed by both direct addressing (the address is in opcode) and indirect addressing (the address is saved in register). The first 32 bytes are register files, the following can be used for general purpose storage. It is recommanded to use this space for static global variables.

__SRAM 0x80 - 0xFF Direct__

There are 128 bytes of SRAM in this block, which can only be addressed by direct addressing. This block is designed for SFRs.

__SRAM 0x80 - 0xFF Indirect__

There are 128 bytes of SRAM in this block, which can only be addressed by indirect addressing. This block is designed for stack.

__XRAM 0x0000 - 0x00FF__

There are 256 bytes of external SRAM in this block. Logically speaking, this block is not in the MCU, and can only be access using ```XMOV``` instruction. Physically speaking, in this modified 8051 MCU, this block is build-in. The XRAM could be extended by adding a SRAM chip to the side of the MCU.

Since the XRAM can only be accessed by ```XMOV``` instruction, data access to this block is relatively slow than interal SRAM. However, the internal SRAM has limited space. therefore, commonly used data should be stored in SRAM, and less commonly used data should be stored in XRAM. In this system, the LCD and Tx/Rx buffer is stored in the XRAM.

### Register bank

One of the most critical overhead of ISR is housekeeping. Before enter ISR, all register should be push into stack; before quit ISR, all saved data in stack need to be pulled and restored. This comsumes a lot of CPU cycles. For 8051 MCU, there are 11 register need to be pushed into stack, that are ```ACC, B, SREG, R0, R1, R2, R3, R4, R5, R6, R7```.

To reduce the overhead of ISR housekeeping, it is possible to take an advantage of the 8051 archetecture, which is register bank swap. There are 4 register banks, modify SFR ```SREG``` could alternate the current working register bank. When executing the main process, the MCU uses register bank 0; when executing LCD ISR, the MCU uses register bank 2; when executing UART ISR, the MCU uses register bank 3. By doing this, only ```ACC, B, SREG``` need to be pushed into stack before executing ISR.

### Synch

In the Rx ISR, when the MCU detect a SYNCH signal, the operator-side console should halt all the current tasks, and go back to __State 2 **_[S2]_**__. To do this, the CPU need to modify the stack, at where the return address are stored.

The following code shows how this is down:

```Assembly
UART_ISR:
	PUSH	ACC
	PUSH	PSW
	MOV	A, SP					;Write return PC to MAIN
	ADD	A, #-3					;Stack = (H) PSW(Current pointer), ACC, PC_H, PC_L (L)
	MOV	R0, A
	MOV	@R0, #LOW MAIN
	INC	R0
	MOV	@R0, #HIGH MAIN
	RETI
```

When enter the ISR, the hardware will first push the current PC into stack, the lower portion first, then the higher portion.

The software will save ACC and PSW in stack. Since the stack pointer is always points to the last write byte; therefore, the pointer is now points to PSW. This means, Stack pointer - 3 pointes to the lower portion of the return address.

Since the stack is located in SRAM 0x80 - 0xFF Indirect, it requires indirect addressing using register. In this case, Stack pointer -3 will be stored in register R0.

Then, using the ```MOV @R0, #VALUE``` instruction to modify the return address. Once the CPU return from ISR, the modified address will be load into ```PC```. Therefore, the MCU return to desired location after executing the ISR
