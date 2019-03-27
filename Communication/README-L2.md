# Communication protocol tech document - Transport layer

## Introduction
In this document, the method used by the transport layer of the communication system will be discuesd here.

## Purpose

The communication protocol is a full-duplex asynchronous UART communication, which means, there is only two wire: one for sending, one fore receiving. That been said, the ROV and the operator-side console could send data to each others at the same time. The resaon of using the UART is because that, the UART is supported by the MCU.

However, the communication protocol also comes with issues:
- The communication data will be put into a package by the application, and then send to the transport layer. The UART has start bit and stop bit that indecates the start and end of a word (usually 8-bits), but there is no way to indecates the start and end of a package. Hence, the transport layer needs to identify the start and end of a package.
- The physical layer is not 100% reliable, hence, the transport layer should be able to detect error in the package.

## Solutions

### _Using TCP protocol?_

The TCP protocal is a good reliable transpoartation method, which is good for computer. However, it comsumes too much memory and computational power, it is not good for embedded system.

**Hence, the solution is to : Using custom protocol.**

### Send and Retry

1. Master sends package to the slave.
2. If the slave fully received the package, and the package is verified to be corrected, send ACK. If no package, or the package is incoorect, or the package is not fully, do not send ACK.
3. If the master did not receive ACK, re-send data.

- Issue 1: This method requires extra timer and timer interrupt.
- Issue 2: This method comsumes some computation power.
- Issue 3: This method is not friendly to full-duplex communication.

**This method is not used.**

### Boardcasting

1. The ROV is the master. The ROV has a timer which overflows every 1/4 second.
2. The ROV send the package to the operator-side console. All data in the package is BCD coded, and the first word in the package is always 0xFF, which means SYNCH. This means, the SYNCH signal is unique.
3. Once the operator-side console receives the SYNCH signal, the operator-side sonsole begins to send package to the ROV.

- Low overhead. This protocol does not requie ACK package.
- Easy to implement, low computation power comsupution. This protocol just keep sending data, no brain required. _(:3 _| <)__

- Issue? How to detect that if a package is loss or corrupt? Just keep send the most up-to-date data. Why re-send the out-of-date data?


## Overview of the boardcasting method

First of all, there is no identical clock on the world; simularly, there is no fully synchnonized MCU. Than means, there is time difference between the ROV and the operator-side console.

In this system, the ROV will server as the master clock. There is a timer on the ROV which overflow every 250ms. When the ROV's timer overflow, the ROV will measure data form its sensor, pack the data into a package, and then send the data to the operator-side cosnole.

The first word of the package is always 0xFF, and all the data is BCD coded. That means, the range of each byte in the data segment is 0x00 - 0xA0 (0xA0 represents decimal 100). The first word of the package is not in the range of data, hence, the value of the first word of the package is unique. The first word (0xFF) of the package is called SYNCH.

On the operator-side console, if the receiver see any 0xFF, it will terminate the current work, and then reset to the beginning. In another word, the SYNCH will synch the operator-side console with the ROV. After this, the operator-side console will scan the user input, pack the data into package, and then send the package to the ROV. Since the operator-side console is already synch with the ROV, the operator-side does not need to include a SYNCH word in its package.

Both package includes a checksum word. Furthermore, there is no package lenth encoded in the package, because both side knows how long is the package. (The length of the package is hard coded in program)

Once the package is fully received by the ROV or the operator-side console, the package will be decoded. For both side, if the package received is correct, the package will be depacked, and then send to the application layer.

The following figure shows how the communication protocol work:
===============================  WIP  ===============================

However, this protocol also comes with some limitations:
1. The package cannot be too large. Due to the physical issue, the longer the cabel, the worse the communication quality. To have a reliable transmissiion, the BAUD rate of the communication is set to 2400 BAUD. Since the operator-side console and the ROV exchange data every 1/4 second, the transmission line can only support up to 240 bits of data. Because the UART is using 10-bit encode (1-bit starting, 8-bit data, 1-bit ending), only 24 bytes are allowed to be packed. Since the system requires extra time to prepare the data, send SYNCH signal, send checksum; hence, the actrul support payload will be less than 24 bytes. Than means, the ROV and the operator-side console should only send critical data, not all the data. _good design demands good compromises_
2. The ROV should send BCD data only; otherwise, the data segment may confilc with the SYNCH segment.


## Edge cases

### Perfect consition


### One or more word lost



### One or more word corrput



### SYNCH word loss



### SYNCH word corrupt



### Data and checksum corrput at same time

Very very unsuccessfully, the incorrect checksum matches with the incorrect package.

OK, the system doomed. But, WHen the next package succefully arrive, everyting will go back on the track.
