# Communication protocol tech document - Transport layer



## Introduction

In this document, the method was applied in the transport layer of the communication system will be discussed. In the communication system model, the transport layer is a layer between the physical layer and the application layer. On the one hand, the transport layer will pack the application data, then send the package using UART hardware byte by byte; on the other hand, the transport layer will fetch the data from the UART hardware, re-assemble the data into the package, and then provide the data to the application for further application.

The physical layer is capable to provide a reliable full-duplex asynchronous communication hardware by using high-voltage differential-signalling; however, there is a possibility (although very small) that the physical layer fails. In this case, the transport layer should be able to detect the error and prevent the effect from the error.

The physical layer uses UART for the communication. It is a word-orientation communication hardware. Unlike SPI or I2C, which comes with start signal and stop signal at the beginning and the end of the entire package; the UART only provides start bit and stop bit at the beginning and end of each word. As a result, the transport layer should be able to identify the beginning and the ending of a package.

In the application software’s prospect of view, a transport layer is a framework software. By using the transport layer, the application layer can focus on the functionality of the application without dealing with the hardware. For illustration, the hardware can only send one byte at a time, but the application generates the entire package in one instant. Without the transport layer, the application has to send the package byte by byte, which is inefficiencies. With the transport layer, the application could send the entire package to the transport layer and focus on the application task.

In fact, in the hardware's prospect of view, the transport layer does not increase the efficacy of the system at all. It decreases the performance of the system due to layer overhead. However, adding a transport layer between the application layer and the physical layer do provide separation of concerns, which helps define the communication system and coding the application for the developer.

In this document, the following terms will be used:
- Control package: a string of bytes that sends from operator-side console to the ROV. The operator will send this package to the ROV to control it, or to set up the autopilot function of the ROV.
- Data package: a string of bytes sends from ROV to the operator-side console. The ROV will gather data such as pitch angle, direction etc. and send them to the operator-side console. This package helps the operator to understand the ROV's statue.
- SYNCH: A word send by the ROV to wake up the operator-side console. Because this signal will synchronize the ROV's and the operator-side console's statue, it is called SYNCH.
- Tx buffer / Rx buffer: Two blocks of memory used by the transport layer framework software. The buffer is applied for saving the intermedia data.

Notice:
The following terms may be misunderstood by readers:
- Word: A word is a unit that the hardware/software processing. For example, ATmega328P's word length is 8-bit, because the ATmega328P's general purpose register width is 8-bit (the ATmega328P's flash/program memory's word length is 16-bit); the UART's word length is 4 to 9 bits because the UART send 1 start bit and  followed by 4 to 9 data bits and 1 to 2 stop bits (in this system, the UART's word length is fixed to 8-bit); the Intel Core i7's word length is 64-bit because its main accumulator is 64-bit; an FPGA has a word length of 1234-bit because someone wrote "std_logic_vector (1233 down to 0)".
- Byte: A byte is always 8-bit. A word can be any byte long. It also can be 1-byte, 2-byte, 4-byte or even half-byte.


## Solutions

### _TCP protocol?_

The TCP protocol is a reliable communication method for computer and the high-end embedded system; however, it consumes too much memory and computational power. Due to its resource consumption, it is not good for the low-end embedded system.

**As a result, the solution is to use custom protocol.**


### _Send and Retry?_

1. Master sends a package to the slave.
2. If the slave fully receives the package and the package correctness is verified, it will send acknowledgement packet (ACK) back to master. If there is no package to be received or the received package is incorrect or not fully, it will not send the ACK packet.
3. If the master does not receive the ACK packet, it will re-send the package.

- Issue 1: This method requires an extra timer to measure the ACK timeout.
- Issue 2: This method consumes much more computation power.
- Issue 3: This method is not friendly to full-duplex communication.

**Due to the issue above, this method has not been applied.**


### Broadcasting

1. The ROV will send data packages to the operator-side console every 1/4 second.
2. After the operator-side console receives the first word of the data package, the operator-side console sends control package to ROV.

-Advantages:
- Eliminating the timer synchronize issue between the ROV and the operator-side console. 
- Easy implementation and low computation power consumption. This protocol just keeps sending data. _(:3 _| <)__

- Issue 1: How to detect that if a package is lost or corrupt? How to notice the sender? What is the further response if the package is lost or corrupt?
- Issue 2: How to identify the start and the end of the package?


## Broadcasting method

### Package structure

The ROV and the operator-side console need to exchange data every 250 milliseconds, the data is in a package format (in C language, called struct) in the application's prospect of view.

A package is a string of word, which contains 15 words of data, plus a checksum at the end of the package. If adding all the word together (using unsigned int type, no carry), the result should be 0. In other word, the checksum is the negative of the sum of all data words. If the checksum does not match with the data, it means the package is corrupt.

For the data package (sends from ROV to operator-side console), there is an additional word called SYNCH, which is used to wake up the operator-side console and synchronize the operator-side console with the ROV, prepend to the package. The SYNCH can be any value and it does not count toward the package length nor the checksum.

The length (16 words) of the package is fixed and hard coded in the transport layer framework software. If the received package length is less than the desired length, the package is considered to be uncompleted and the package will be dropped. If the received package length is greater than the desired length (although it rarely happens), the extra word will overwrite the last word in the buffer.

The application software should fit its data into 15 bytes (120 bits). Since the package length is fixed, the application should fill the gap with arbitrary values or zeros when the data is less than 15-byte.

The communication speed (BAUD rate) should be 2400, which is a stander given by the physical layer. In other word, the ROV and the operator-side console exchanges data at the speed of 2400 bits pre-second. Because the ROV and the operator-side console exchange data every 1/4 second, and each word contains 1 start bit, 8 data bits and 1 stop bit (10 bits in total), there is maximumly 60 bytes exchanged every 250 milliseconds.

Since the ROV and the operator-side console need time to prepare and execute data, the actual data, which could be exchanged, will be less than 60 bytes. The reason for choosing 16 is because 16 is a power of 2. 16 bytes of data could be fit into a block of SRAM in the MCU, which provides an easier implementation. 8 bytes can fit into a block, but not enough to carry the amount of data required by the application software; 32 bytes could be fit into a block as well, but it takes too much memory space. Hence, the compromise is to use 16-bit as the size of each package.

The UART hardware is a word-orientation communication device; therefore, the transport layer needs to identify the beginning and the end of each package.

On the ROV side, the identification algorithm for the control package is quite straight forward. The first received word after firing SYNCH is the beginning of the control package; and the 16th one after firing SYNCH is the end of the control package.

On the operator-side console, the identification algorithm for the data package is much more complex. The ROV will send the data words in series at the BAUD rate, then waiting for the next 250ms to send the next package. For example, the ROV send 10 words to the operator-side console every package, sending one word will consume 10 milliseconds. In this case, the ROV will send
- Package 1 word 1 at t = 0ms
- Package 1 word 2 at t = 10ms
- ...
- Package 1 word 9 at t = 80ms
- package 1 word 10 at t = 90ms
- Idle
- Package 2 word 1 at t = 250ms
- Package 2 word 2 at t = 260ms
It is clear to say that, there is a 150ms gap between each package. Therefore, the operator-side could measure the time interval between the current word and the last word. If the interval is larger than 20ms (the time to send 5 bytes at 2400 BAUD), it means the current word is the beginning of a package. Like the ROV, the 16th word of the package is the end of the package.


### No ACK
This protocol does not provide ACK feedback. Therefore, the sender has no acknowledgement whether the receiver received the correct package or not. Hence, the package should be stateless. Although it is possible to implement state-oriented communication on the application layer, it is too complicated to be recommended.

Furthermore, since the sender has no acknowledgement whether the receiver received the correct package or not, the sender will not re-send the package to the receiver if there is any communication error. In fact, re-sending the package really does not have any advantages in this system. Since the ROV and the operator-side exchange the most up-to-date data every 250ms, it is unnecessary to waste time to send some out-of-date data.

## Implementation

### About the UART
The UART (Universal Asynchronous Receiver/Transmitter) is dedicated hardware which is applied to send and receive data between MCUs. The UART comes with its own clock and logic circuits, which means, the UART could process signal (such as sampling signal on IO port, byte error / parity error detection) while the CPU is working on other tasks. Once a byte is received or send, the UART controller will fire an interrupt request to the CPU.

For the transmitter, the UART controller starts the transmitter when the CPU writes to UART Tx buffer. The UART controller will send the word, which is stored in the UART Tx buffer, in a bit stream. Firstly, it sends start bit, then data bits followed by a stop bit. After that, the controller fires interrupt request to notice the CPU that the word has been fully sent out. The CPU can either send the next word to the UART or terminated the transmission process (by not writing the UART buffer).

For the receiver, there are two stages of the buffer. Stage one is the working buffer, which is directly connected to the IO port. After all bits of a word shifted into the working buffer and a stop bit is presented on the IO port, the UART controller moves the word from the working buffer to the intermedia buffer. Then, the UART controller fires interrupt request to notice the CPU that a word has been received, while the working buffer continuously listens on the IO port. The CPU needs to fetch that word from the intermedia buffer as soon as possible before the next word arrived; otherwise, the word will be overwritten by the next word.

Although the UART could process signal while the CPU working on other tasks, the UART only working with word-format data. For the STC80C52RC MCU and ATmega328P MCU in this project, the UART's buffer size is one byte, which means, when the transmission is happening, the CPU needs to provide a byte of data to the UART. After that byte is sent out, the UART controller fires interrupt request. Then, the CPU provides the next byte to the UART. For the receiver, the UART controller fires interrupt request once the byte is received. Then, the CPU needs to fetch the data from the UART buffer. After a while, when the next byte arrives, the UART controller fires another interrupt request.

The UART is a word-orientation device, but the application is a package-orientation software. To have the application interact with the UART hardware, the transport layer is required to transform data between byte-stream format and package format.


### Transport layer framework

To accomplish this, the transport layer needs two memory blocks to save intermedia data. One of them is called Tx buffer, and another one is called Rx buffer. Since the UART is word-orientated, the transport layer needs another two memory-spaces to save the pointers. One of them is called Tx pointer, and another one is called Rx pointer.

To send a package, the application layer software needs to write the package to the Tx buffer. Then, the physical layer will calculate the checksum, and save the checksum at the end of the Tx buffer. Furthermore, the physical layer begins to send data using UART. After the first word is sent out, the UART controller fires interrupt request. Then, the transport layer will send the second word in the buffer. After all words in the Tx buffer have been sent out, the physical layer terminates the transmitting process.

To receive a package, once the word arrives, the UART controller fires interrupt request. Then, the transport layer will copy the data from the UART buffer to the Rx buffer. If the buffer overflows, the last word in the buffer will be overwritten.

For the operator-side console's transport layer, there is an additional function. The transport layer will measure the time interval between the current interrupt and the last interrupt. If the interval is greater than 20 milliseconds, the transport layer will terminate the current process. This can synchronize the operator-side console with the ROV.

The following pseudocode shows the algorithm of the transport layer:
```c
uint8_t txBuffer[16], rxBuffer[16]; //16 bytes of Tx and Rx buffer on both side
unsigned int txc, rxc; //Pointer on both side

//ROV side
ISR_timer() { //Fires every 250ms
	txBuffer[] = applicationOutputData; //Save application data in Rx buffer
	txBuffer[15] = getChecksum(txBuffer); //Get checksum
	txBuffer[15] = getChecksum(txBuffer); //Get checksum
	UART = 0x00; //This will turn on Tx
	
	if (rxp == 16 && rxBuffer[15] == getChecksum(rxBuffer)) //Package length OK, checksum OK
		applicationInputData = rxBuffer[]; //Apply control
	
	rxp = 0;
}

ISR_tx() {
	if (txp < 16) //Send all data in the buffer
		UART = txBuffer[txp++]; //If no data provided to Tx, Tx will be turned off
}

ISR_rx() {
	if (rxp >= 16) //Check buffer overflow
		rxp--; //In this case, the last byte of the rx buffer will be overwritten
		
	rxBuffer[rxp++] = UART; //Write data to buffer
}


//Operator-side console
some_miniseconds > time_to_send_one_byte && some_miniseconds < 250ms - time_to_send_a_package

ISR_tx() {
	if (txp < 16) //Send all data in the buffer
		UART = txBuffer[txp++]; //If no data provided to Tx, Tx will be turned off
}

ISR_rx() {
	if (currentTime() - lastTime > 20000) //Check time interval, 20'000us = 20'000 cycles @ 12MHz, 12T
		__SYSTEM_RESET_PHASE__ //Synch with ROV, terminate current work
	
	lastTime = currentTime();
	
	if (rxp >= 16) //Check buffer overflow
		rxp--; //In this case, the last byte of the rx buffer will be overwritten
		
	rxBuffer[rxp++] = UART; //Write data to buffer
}
```


## Edge cases analysis

There are two types of error may occur during the communication process.

### One or more words lost
In this case, there will be not enough data in the receiver's buffer; hence, the package will not be processed by the MCU. Once the next package arrives, the current package will be discarded.

It is possible that several continuous words lost. In this case, there will be an interval greater than 20 milliseconds. On the one hand, the operator-side console will assume a new package is arriving. However, since the length of both packages is less than the desired length, both packages will be dropped. When the next package comes from the ROV, the operator-side will get up-to-date data. On the other hand, the operator-side console will send a new control package to the ROV. On the ROV's side, those extra words will cause ROV Rx buffer overflow (but there is protection). When the ROV read the buffer, the checksum will show the error.

### One or more words corrupt
In this case, the checksum and the package will not match; hence, the package will be discarded.

It is possible that several words corrupt, but the checksum is matched with the corrupted package. In this case, the ROV will receive wrong control, the operator-side console will receive wrong data. This issue will present for 250ms. When the next package arrives, the next package with correct data can fix the error.
