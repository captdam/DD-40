# Communication protocol tech document - Application layer



## Introduction

This document t is about the application layer of the ROV system, which defines the packet exchanged between the ROV and the Operator-side console. This includes the content of the packet and the data type of the packet.

In this document, the following terms will be used:
- Control packet: a string of bytes that sends from operator-side console to the ROV. The operator will send this packet to the ROV to control the ROV, or to set up the autopilot function of the ROV.
- Data packet: a string of bytes sends from ROV to the operator-side console. The ROV will gather data such as pitch angle, direction etc. and send them to the operator-side console. This packet helps the operator to understand the ROV's statue.
- Exchange event: an event rising every 250 mini seconds. This event will begin the data transfer process.


## Package regulations

### From lower layer

When defining the application layer, regulation from lower layers must be obeyed.

According to the specification of the lower layer, the ROV and the operator-side console will exchange packet __every 250 mini seconds__. The communication __BAUD rate is 2400__ bits pre second. Each packet contains __15 byte of data__, __appended with one byte of checksum__. Additionally, there will be an __SYNCH byte prepends to the packet send from ROV to operator-side console__.

Both the AVR and the 8051 architecture is __little-endian__. To take advantage of the little-endian architecture, multi-byte data should be sent by using little-endian format. In other word, __more significant portion of the data will be saved in higher address, a less significant portion of the data will be saved in lower address__. For example, if the data is 0x1234 and the data is saved in buffer address 0x01 and 0x00. In this case, data 0x12 will be placed in buffer address 0x01, and data 0x34 will be placed in address 0x00. Since the transport layer will first send the data with the lowest address, the least significant byte will be sent out before the most significant byte.

In fact, for the application layer, it does not matter if the application using little-endian or big-endian. The task of the transport layer is to copy the packet from one end to another end without modifying any bytes of the packet or the order of the packet. Therefore, as long as the ROV and the operator-side console follows the same endian format, there will not be any error during the packet exchange process. However, to avoid confusion when programing the higher and lower layer of the ROV system, all layers should follow the little-endian notation.

### From application layer

The data provided by some sensor is not linear, which means, the data must be translated by a lookup table before using it. The standard method is to translate the data into binary. Then, send it to the operator-side console. On the operator-side console, the data will be translated into BCD. Then, it will add 0x30 to get the ASCII coded data. However, if the lookup table directly translates the data into BCD, it could avoid redundancy steps and provide higher efficacy. Therefore, all integer data should be transmitted with BCD coded.


## How to send / receive the packet

### Tx/Rx Buffer

Before sending and receiving packets, two buffers need to be created. One 16-byte long buffer for sending (Tx buffer), another one 16-byte long buffer for receiving (Rx buffer).

For the ROV, it is an AVR architecture MCU with 2048 bytes of SRAM and 256 bytes of SFR memory space. For this architecture, the stack pointer is grown from top to bottom, which means that the stack will be located in the higher portion of the SRAM. Hence, static variables should be located in the lower portion of the SRAM. As a result, the Tx buffer is located in the SRAM from address 0x0100 to 0x010F and the Rx buffer is located in SRAM from address 0x0110 to 0x011F.

For the operator-side console, which is an 8051 architecture MCU with 128*2+128 bytes of RAM and 256 bytes of build-in XRAM. The XRAM stands for external RAM. Logically, it is external and should be accessed using XMOV instruction, but physically, it is inside of the MCU packet). Since the stack is located in RAM, the XRAM will not be modified by the MCU. Hence, the Tx buffer is located in XRAM from address 0xE0 to 0xEF and the Rx buffer is located in XRAM from address 0xF0 to 0xFF.

## Access the buffer

To send the data, the application should write the data into the Tx buffer, and in order to read the data, the application should read data from the Rx buffer.

The transport layer will exchange the packet every 250 mini seconds, which is called Exchange event.

When this event rising, the content of the packet should be written to the Tx buffer. Then, the transmitter will be started to send the packet. To send 16 bytes, it takes about 100 milliseconds. The UART is a dedicated communication hardware, which means it uses another thread. when the UART working on transmitting data, the CPU can process other tasks. 

To receive a packet, the application should request the transport layer by asking "Is the packet received". If the answer is “no”, the application should ask again later, before the next Exchange event. If the answer is “yes”, the application should fetch the data from Rx buffer as soon as possible. When the next Exchange event rises, the Rx buffer will be overwritten by the next packet.

In conclusion, the application needs to write to the Tx buffer at the beginning of the event as soon as possible. Additionally, the application should read from the Rx buffer after the packet received and before the next Exchange event.


## Data packet

The data packet contains the status of the ROV, the following table shows the content of the data packet:
![Data packet](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/communication-application-datapacket.jpeg "Data packet")


## Control packet

The control packet contains the command and auto-pilot configuration to the ROV, the following table shows the content of the data packet:
![Control packet](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/communication-application-controlpacket.jpeg "Control packet")
