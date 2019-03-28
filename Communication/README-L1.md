# Communication protocol tech document - Physical layer

## Introduction
In this document, the method used by the physical layer of the communication system will be discussed here.


## Purpose

There is full-duplex UART port on the ROV's controller (ATmeage328P) and the operator-side console (STC89C52RC). By connecting the UART port of this two MCUs, the two systems should be able to exchange data between each other directly.

The ROV is a remotely controlled device, which means, the deeper the ROV dives, the higher the ROV's capability will be. However, when the depth of the ROV increases, the distance between the ROV and the operator-side console increases as well.

Since wireless communication is impossible due to the technical limitation, a cable is applied to connect the ROV and the operator-side console. However, the wire communication still has some issue as well. The wire acts like an antenna so that it could gather noises. The longer the wire, the stronger the EMI noise will be gathered from the environment. Additionally, the faster the transmission speed, the stronger the wire will be created.

Additionally, the physical layer should provide real-time communication and the circuit delay should be in an acceptable range.

Furthermore, to minimize the cost of the system, the circuit should be as simple as possible.

The physical layer should be able to provide a reliable, real-time (with acceptable delay), and full-duplex transmission.


## Solutions

### Transmission speed

The higher the transmission speed, the worse the communication quality will be. Therefore, the transmission speed should be just higher than the required transmission speed of the application.

By analyzing of the software:
1. The ROV communicates with the operator-side console every 1/4 second, named as a frame.
2. Assume the ROV and operator-side console takes about 100ms to prepare data, encode and decode the package. As a result, the window for data transmission is 150ms.
2. In each frame, the ROV and the operator exchanges about 20 bytes (10 to 20) of data.
3. Each byte consider as 8 bits, plus a start bit and a stop byte.
(8 + 1 + 1) * 20 * (1/0.15) = 1333 BAUD

Ceiling to the lowest standard BAUD, the BAUD used by this system is 2400 BAUD.


### High-voltage differential signalling (RS-485 like)

The MCU on both operator-side and ROV comes with UART port. A typically TTL UART transmission is a single wire bus to connect a master (drive the wire) with several slaves (High-Z, listen to the wire). When the data on the line is 0, the master will drive the wire low (0V); otherwise, the master will drive the wire high (5V).

![TTL UART & Differential signaling](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/TTL%20UART%20vs%20RS-485.jpg "TTL UART & Differential signaling")

However, due to the length of the wire, strong noise could alternate the signal on the wire. As the graph (TTL UART) above, when the master drives the wire high, applying a -5V noise could alternate the signal on the wire from 1 to 0; when the master drives the wire low, applying a +5V noise could alternate the signal on the wire from low to high.

To deal with the noise issue, a differential signalling system is applied for the transmission. A differential signalling is a transmission method, that will send both the original signal and its negative signal. More specifically, when the transmitter sends X (1 or 0), the signal X will be placed on wire A, and the negative X will be placed on wire B. On the receiver side, by comparing the signal on wire A and B, the receiver could know the actual signal comes from the transmitter. Since the environment noise applies to both wire, the difference between the wires will not be alternated. 

For example, when the master drives the wire high, wire A will be high (5V), and wire B will be low (0V). Since the voltage on wire A is higher than the voltage on wire B, the receiver could know the signal on the wire is high:

Tx = 1; A = 5V; B = 0V; Rx = (A-B>0) ? 1 : 0 = 1

If applying a XV (X = negative infinity to positive infinity) noise:

Tx = 1; A' = 5V + X; B' = 0V + X; A' - B' = (5V + X) - (0V + X) = 5V - 0V = A - B;

By using the differential signalling, the noise is filtered.

Since the transmission cable and 12V power supply is built in one multi-core cable, the transmission signal could be amplified to 12 V instead of 5V. During this process, the transmission system could handle stronger EMI noise.


## Circuit

The differential signalling system circuit consist of 3 parts:
- Positive amplifier (Tx+): When it receives logic 1 (5V), the output will be 12V; when it receives logic 0 (0V), the output will be 0V.
- Negative amplifier (Tx-): When it receives logic 1 (5V), the output will be 0V; when it receives logic 0 (0V), the output will be 12V.
- Receiver (Rx): If Rx+ is greater than Rx-, the output will be logic 1 (5V); otherwise, the output will be logic 0 (0V).
Since the transmission system is full-duplex, there is a pair of differential signalling transmitter and receiver. One of them are responsible for sending signals from ROV to the operator-side console, another one for send signal from operator-side console to ROV.

There are two methods to design this system. One of them is using OpAmp, and the other one is using NMOS. The following shows the circuit and simulation result using LTSpice. According to the simulation, since the cable is very long, the cable comes with 50 ohms of resistance and 1nC capacitance between the positive and negative wire.

### Method 1 - OpAmp

![RS-485 using OpAmp](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/RS-485%20like%20OpAmp.JPG "RS-485 using OpAmp")

Bad: Delay, size, require OP27 and OP37 (more kinds of parts)


### Method 2 - NMOS

![RS-485 using NMOS](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/RS-485%20like%20NMOS.JPG "RS-485 using NMOS")

Bad: Power consumption

------

According to the simulation result, the NMOS solution comes with less delay and lower cost.

Notice: there is a 1V output offset. Using a diode to cut the offset.
