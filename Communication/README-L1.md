# Communication protocol tech document - Physical layer

## Introduction
In this document, the method used by the physical layer of the communication system will be discuesd here.


## Purpose

There is full-duplex UART port on the ROV's controller (ATmeage328P) and the operator-side console (STC89C52RC). By connecting the UART port of this two MCUs, the two system should be able to exchange data between each others directly.

The ROV is a remotely controlled device; that means, the deeper the ROV dives, the higher the ROV's capability is. However, when the depth of the ROV increases, the distance between the ROV and the operator-side console increases as well.

Due to the physical propertity, wireless communication is impossible; hence, a cable is used to connect the ROV and the operator-side console. However, the wire communication comes with some issue as well. The wire is an antenna, that been said, the wire gathers noise:
- The longer the wire, the stronger the EMI noise gathered from the environment.
- The faster the tranmission speed, the stronger the wire creates.

Addtionally, the physical layer should provide real-time communication. In another word, the circuit delay should be in an acceptable range.

Furthermore, to keep the system low cost, the circuit should be simple.

The physical layer should be able to provide a reliable, real-time (with acceptable delay), full-duplex transmission.


## Solutions

### Transmission speed

The higher the transmission speed, the worse the communication quality. Hence, the communication speed should be as slow as possible. In anothe word, the transmission speed should be just higher than the required transmission speed of the application.

By analysis the software:
1. The ROV communicate with the operator-side console every 1/4 second, call it a frame.
2. Assume the ROV and operator-side console takes about 100ms to prepare data, encode and decode the package. Which means, the window for data transmission is 150ms
2. In each frame, the ROV and the operator exchanges about 20 bytes (10 to 20) of data.
3. Each byte consider as 8 bits, plus 1 start bit and one stop byte.
(8 + 1 + 1) * 20 * (1/0.15) = 1333 BAUD

Ceiling to the loweset standard BAUD, the BAUD used by this system is 2400 BAUD.


### High-voltage differential signaling (RS-485 like)

The MCU on both of the operator-side and ROV comes with UART port. A typically UART transmission is a single wire, with one master (drive the wire), one ore more slave (High-Z, listen the wire). When the data on the line is 0, the master will drive the wire low (0V); otherwise, the master will drive the wire high (5V).

![TTL UART & Differential signaling](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/TTL%20UART%20vs%20RS-485.jpg "TTL UART & Differential signaling")

However, due to the length of the wire, strong noise could alter the signal on the wire, as the above graph (TTL UART) shows, when the master drives the wire high, applying a -5V noise could alternate the signal on the wire from 1 to 0; when the master drives the wire low, applying a +5V noise could alternate the signal on the wire from low to high.

To deal with the noise issue, a differential signaling system is used for the transmission. A differential signaling is a transmission method, that will send both the orginal signal and its negative signal. That means, when the transmitter sends X (1 or 0), the signal X will be placed on wire A, and the nagative X will be placed on wire B. On the receiver side, by comparing the signal on wire A and B, the receiver could know the actural signal comes from the transmitter. This is because the envoronment noise applys to both wire, hence the difference between the wires will not be alternated. See the above figure (differential signaling):

For example, when the master drives the wire high, the wire A will be high (5V), and the wire B will be low (0V). Because voltage on wire A is higher than voltage on wire B, hence the receiver could know the signal on the wire is high:

Tx = 1; A = 5V; B = 0V; Rx = (A-B>0) ? 1 : 0 = 1

If applying a XV (X = negative infinate to positive ) noise:

Tx = 1; A' = 5V + X; B' = 0V + X; A' - B' = (5V + X) - (0V + X) = 5V - 0V = A - B;

By using the differential signaling, the noise is filtered.

Beause the transmission cable and 12V power supply is build in one multi-core cable, the transmission signal could be amplifiled to 12 V instead of 5V. By doing this, the transmission system could handle stronger EMI noise.


## Circuit

The differential signaling system circuit consist 3 parts:
- Positive amplifier (Tx+): When receive logic 1 (5V), output 12V; when receive logic 0 (0V), output 0V.
- Negative amplifier (Tx-): When receive logic 1 (5V), output 0V; when receive logic 0 (0V), output 12V.
- Receiver (Rx): If Rx+ is greater than Rx-, output logic 1 (5V); otherwise, output logic 0 (0V).
Since the transmission system is full-duplex, there is a pair of differential signaling transmitter and receiver. One for sending signal from ROV to operator-side console, another one for send signal from opeartor-side console to ROV.

There is two designs developed, one using OpAmp, another one using NMOS. The following shows the circuit and simulation result using LTSpice. When doing the simulation, because the cable is very long, hence the cable comes with 50 ohms of resistance and 1nC capacitance between the positive and negative wire.

### Method 1 - OpAmp

![RS-485 using OpAmp](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/RS-485%20like%20OpAmp.JPG "RS-485 using OpAmp")

Bad: Delay, size, require OP27 and OP37 (more kinds of parts)


### Method 2 - NMOS

![RS-485 using NMOS](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/RS-485%20like%20NMOS.JPG "RS-485 using NMOS")

Bad: Power comsuption

------

As the simulation result shows, the NMOS solution comes with less delay. Plus, the NMOS solution is cheaper.

Notice: there is a 1V output offset. Using a diode to cut the offset.
