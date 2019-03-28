# Communication protocol tech document - Transport layer

## Introduction
In this document, the method used by the transport layer of the communication system will be discussed here.

## Purpose

The communication protocol is a full-duplex asynchronous UART communication, which means, there is only two wire for sending and receiving respectively, such that the ROV and the operator-side console could send data to each other simultaneously. 

However, the communication protocol also comes with some issues such as identification for packet and error detection. The communication data will be put into a package by applications, and then send to the transport layer. The UART has a start bit and a stop bit to indicate the start and end of a message (usually 8-bits), but there is no way to indicates the start and end of a package. As a result, the transport layer needs to identify the start and end of a package. Additionally, the physical layer is not 100% reliable, so that the transport layer should be able to detect errors in the package.

## Solutions

### _TCP protocol?_

The TCP protocol is a good reliable transportation method for computer and the high-end embedded system only because it consumes too much memory and computational power. Due to its power consumption, it is not good for the low-end embedded system.

**As a result, the solution is to use custom protocol.**

### _Send and Retry?_

1. Master sends a package to the slave.
2. If the slave fully receives the package and the package correctness is verified, it will send acknowledgement packet (ACK). If there is no package to be received or the received package is incorrect or not fully, do not send ACK.
3. If the master does not receive ACK, it will re-send the data.

- Issue 1: This method requires an extra timer and timer interrupt.
- Issue 2: This method consumes much computation power.
- Issue 3: This method is not friendly to full-duplex communication.

**Due to the issue above, this method has not been applied.**

### Broadcasting

1. The ROV is the master and it has a timer which overflows every 1/4 second.
2. When the ROV sends the package to the operator-side console, all the data in the package is BCD coded. The first word in the package is always 0xFF, which means SYNCH and the SYNCH signal is unique.
3. Once the operator-side console receives the SYNCH signal, the operator-side console begins to send a package to the ROV.

-Advantages:
- Low overhead. This protocol does not require ACK package.
- Easy implementation and low computation power consumption. This protocol just keeps sending data. _(:3 _| <)__

- Issue? How to detect that if a package is lost or corrupt? Just keep sending the most up-to-date data. Why re-send the out-of-date data?


## Overview of the broadcasting method

There is no identical clock on the world; similarly, there is no fully synchronized MCU such that there is a time difference between the ROV and the operator-side console.

In this system, the ROV will server as the master clock. The timer of the ROV will overflow every 250ms. When the ROV's timer overflow, the ROV will measure data from its sensor, pack the data into a package, and then send the data to the operator-side console.

The first word of the package is always 0xFF, and all the data is BCD coded. The range of each byte in the data segment is 0x00 - 0xA0 (0xA0 represents decimal 100). Since the first word of the package is not in the range of data, the value of the first word is unique. The first word (0xFF) of the package is called SYNCH.

On the operator-side console, if the receiver scans any 0xFF, it will terminate the current work, and reset to the beginning. Therefore, the SYNCH will synchronize the operator-side console with the ROV. Moreover, the operator-side console will scan the user input, pack the data into a package, and then send the package to the ROV. Since the operator-side console is already synchronized with the ROV, the operator-side does not need to include a SYNCH word in its package.

Both packages include a checksum word. Furthermore, there is no package length encoded in the package, because both of them know how long the package is. (The length of the package is hardcoded in the program)

Once the package is fully received by the ROV or the operator-side console, the package will be decoded. For both sides, if the received package is correct, the package will be de-packed, and then send it to the application layer.

The following figure shows how the communication protocol works:
![Communication flow](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/Communication%20flow.jpeg "Communication flow")

However, this protocol also has some limitations. Firstly, the package cannot be too large. Due to the physical limitation, the faster the transmission rate, the worse the communication quality will be. To have a reliable transmission, the BAUD rate of the communication is set to 2400 BAUD. Dueto the limitation of the physical layer, only 20 bytes can be packed. That means, the ROV and the operator-side console should only send critical data. _good design demands good compromises_ Additionally, The ROV should send BCD data only; otherwise, the data segment may conflict with the SYNCH segment.


## Edge cases

### Perfect condition
The data is successfully exchanged between the ROV and the operator-side console.

### One or more word lost
There will be not enough data in the receiver's bufffer, hence, the package will not be processed by the MCU. Once the next package arrive, this package will be discard.

### One or more word corrput
The checksum and the packga is not matched, hence, the opackage will be discard.

It is possible that, in the package from ROV to operator-side console, the value of the corrput byte becomes 0xFF, which triggers a SYNCH signal. In this case, the operator-side console will re-send command to ROV. However, 前半部分和后半部分长度都不够（same as one or more word lost）

### SYNCH word loss
This frame will not trigger SYNCH condition, hence, the current package will not be processed.

### SYNCH word corrupt
This frame will not trigger SYNCH condition, hence, the current package will not be processed.

### Data and checksum corrput at same time
Very very unsuccessfully, the incorrect checksum matches with the incorrect package. OK, the system doomed. But, When the next package succefully arrive, everyting will go back on the track.
