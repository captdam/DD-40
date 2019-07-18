# Communication protocol tech document - Application layer



## Introduction

This documen t is about the application layer of the ROV system, which defines the packet exchanged between the ROV and the Operator-side console. This cincludes the content of the packet and the data type of the packet.

In this document, the following terms will be used:
- Control packet: a string of bytes that sends from operator-side console to the ROV. The operator will send this packet to the ROV to control the ROV, or to set up the autopilot function of the ROV.
- Data packet: a string of bytes sends from ROV to the operator-side console. The ROV will gather data such as pitch angle, direction etc. and send them to the operator-side console. This packet helps the operator to understand the ROV's statue.
- Exchange event: an event rising every 250 mini seconds. This event will begin the data transfer process.


## Package regulations

### From lower layer

When define the application layer, regulation from lower layers has to be obey.

According to the specifiction of the lower layer, the ROV and the operator-side console will exchange packet __every 250 mini seconds__. The communication __BAUD rate is 2400__ bits pre second. Each packet contains __15 byte of data__, __appended with one byte of checksum__. Addtionally, there will be an __SYNCH byte prepend to the packet send from ROV to operator-side console__.

Both the AVR and the 8051 architecture is __little-endian__. To take advantage of little-endian architecture, multi-byte data should be send using little-endian format. In another word, __more significant portion of the dta will be saved in higer address, less significant portion of the data will be saved in lower address__. For example, if the data is 0x1234 and the data is saved in buffer address 0x01 and 0x00. In this case, data 0x12 will be placed in buffer address 0x01, data 0x34 in address 0x00. Because the transport layer will first send the data with lowest address; therefore, least significant byte will be send out before the most significant byte.

In fact, for the application layer, it really does not matter if the application using little-endian or big-endian. The task of the transport layer is to copy the packet from one end to another end without modify any bytes of the packet or the order of the packet. Therefore, as long as the ROV and the operator-side console follows the same endian format, there will not be any error in the packet exchange process. However, to avoid confuse when program the higher and lower layer of the ROV system, all layers should follow the little-endian notation.

### From application layer

The data provided by some sensor is not linear, which means, the data has to be translate by a lookup table before use. The standard method is to translate the data into binary, then send it to the operator-side console. On the operator-side console, the data will be translated into BCD, then adds 0x30 to get the ASCII coded data. However, if the lookup table directly translate the data into BCD, it could avoid reduntance steps and provide higher effiency. Therefore, all integer data should be transmit using BCD coded.


## How to send / receive packet

### Tx/Rx Buffer

Before send and receive packet, two buffers needs to be created. One 16-byte long buffer for sending (Tx buffer), another one 16-byte long buffer for receiving (Rx buffer).

For the ROV, it is an AVR architecture MCU with 2048 bytes of SRAM and 256 bytes of SFR memory space. For this architecture, the stack pointer is grown from top to bottom. In another word, the stack will be located in the higher portion of the SRAM. Hence, static variables should be located in the lower portion of the SRAM. Therefore, the Tx buffer is located in the SRAM from address 0x0100 to 0x010F; the Rx buffer is located in SRAM from address 0x0110 to 0x011F.

For the operator-side console, which is an 8051 architecture MCU with 128*2+128 bytes of RAM and 256 bytes of build-in XRAM (stands for external RAM. Logically, it is external and should be access using XMOV instruction; physically, it is inside of the MCU packet). Because the stack is located in RAM, the XRAM will not be modified by the MCU. Hence, the Tx buffer is located in XRAM from address 0xE0 to 0xEF; the Rx buffer is located in XRAM from address 0xF0 to 0xFF.

## Access the buffer

To send data, the application should write the data into the Tx buffer; to read data, the application should read data from the Rx buffer.

The transport layer will exchange the packet every 250 mini seconds, which is called Exchange event.

When this event rising, the content of the packet should be write to the Tx buffer. Then, the transmitter will be start to snd the packet. To send 16 bytes, it takes about 100 miniseconds. Because the UART is a dedicated communication hardware, when the UART working on transmitting data, the CPU can process other tasks (Simplelly speaking, the UART uses another thread).

To receive packet, the application should request the transport layer by asking "Is the packet received". If not, the application should ask again later, but before the next Exchange event. In yes, the application should fetch the data from Rx buffer as soon as possible. When the next Exchange event rising, the Rx buffer will be overwritten by next packet.

In conclusion, the application need to write to the Tx buffer at the beginning of the event as soon as possible; the application should read from the Rx buffer after packet received and before the next Exchange event.


## Data packet

The data packet contains the status of the ROV, the following table shows the content of the data packet:
![Data packet](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/communication-application-datapacket.jpeg "Data packet")


## Control packet

The control packet contains the command and auto-pilot configuration to the ROV, the following table shows the content of the data packet:
![Control packet](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/communication-application-controlpacket.jpeg "Control packet")