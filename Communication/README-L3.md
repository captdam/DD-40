# Communication protocol tech document - Application layer



## Introduction

This documen t is about the application layer of the ROV system, which defines the package exchanged between the ROV and the Operator-side console. This cincludes the content of the package and the data type of the package.

In this document, the following terms will be used:
- Control package: a string of bytes that sends from operator-side console to the ROV. The operator will send this package to the ROV to control the ROV, or to set up the autopilot function of the ROV.
- Data package: a string of bytes sends from ROV to the operator-side console. The ROV will gather data such as pitch angle, direction etc. and send them to the operator-side console. This package helps the operator to understand the ROV's statue.
- Exchange event: an event rising every 250 mini seconds. This event will begin the data transfer process.


## Package regulations

### From lower layer

When define the application layer, regulation from lower layers has to be obey.

According to the specifiction of the lower layer, the ROV and the operator-side console will exchange package __every 250 mini seconds__. The communication __BAUD rate is 2400__ bits pre second. Each package contains __15 byte of data__, __appended with one byte of checksum__. Addtionally, there will be an __SYNCH byte prepend to the package send from ROV to operator-side console__.

### From application layer

Both the AVR and the 8051 architecture is little-endian. To take advantage of little-endian architecture, data should be send using little-endian if the data is a multi-byte variabkle. For example, when sending 0x1234, 0x34 should be send first, then 0x12.

The task of the operator-sid econsole is to display data to the user using LCD module which accepts ASCII coded data. Furthermore, the data provided by some sensor is not linear, it has to be translated using lookup-table before processing. If transmit using binary, the data has to be transform from raw to binary, to BCD, then ASCII. If 

The data provided by some sensor is not linear, which means, the data has to be translate by a loopup table before use. The standard method is to translate the data into binary, then send it to the operator-side console. On the operator-side console, the data will be translated into BCD, then adds 0x30 to get the ASCII coded data. However, if the lookup table directly translate the data into BCD, it could avoid reduntance steps and provide higher effiency. Therefore, all integer data should be transmit using BCD coded.


## How to send / receive package

### Tx/Rx Buffer

Before send and receive package, two buffers needs to be created. One 16-byte long buffer for sending (Tx buffer), another one 16-byte long buffer for receiving (Rx buffer).

For the ROV, it is an AVR architecture MCU with 2048 bytes of SRAM and 256 bytes of SFR memory space. For this architecture, the stack pointer is grown from top to bottom. In another word, the stack will be located in the higher portion of the SRAM. Hence, static variables should be located in the lower portion of the SRAM. Therefore, the Tx buffer is located in the SRAM from address 0x0100 to 0x010F; the Rx buffer is located in SRAM from address 0x0110 to 0x011F.

For the operator-side console, which is an 8051 architecture MCU with 128*2+128 bytes of RAM and 256 bytes of build-in XRAM (stands for external RAM. Logically, it is external and should be access using XMOV instruction; physically, it is inside of the MCU package). Because the stack is located in RAM, the XRAM will not be modified by the MCU. Hence, the Tx buffer is located in XRAM from address 0xE0 to 0xEF; the Rx buffer is located in XRAM from address 0xF0 to 0xFF.

## Access the buffer

To send data, the application should write the data into the Tx buffer; to read data, the application should read data from the Rx buffer.

The transport layer will exchange the package every 250 mini seconds, which is called Exchange event.

When this event rising, the content of the package should be write to the Tx buffer. Then, the transmitter will be start to snd the package. To send 16 bytes, it takes about 100 miniseconds. Because the UART is a dedicated communication hardware, when the UART working on transmitting data, the CPU can process other tasks (Simplelly speaking, the UART uses another thread).

To receive package, the application should request the transport layer by asking "Is the package received". If not, the application should ask again later, but before the next Exchange event. In yes, the application should fetch the data from Rx buffer as soon as possible. When the next Exchange event rising, the Rx buffer will be overwritten by next package.

In conclusion, the application need to write to the Tx buffer at the beginning of the event as soon as possible; the application should read from the Rx buffer after package received and before the next Exchange event.


## Data package

The data package contains the status of the ROV, the following table shows the content of the data package:



## Control package

The control package contains the command and auto-pilot configuration to the ROV, the following table shows the content of the data package:
