# Communication protocol tech document - Physical layer

## Introduction

In this document, the method used by the physical layer of the communication system will be discussed here. In the first part of this document, it will discuss the design of the circuit; in the second part of this document, the physical implementation will be discussed.

There is full-duplex UART port on the ROV's controller (ATmeage328P) and the operator-side console (STC89C52RC). By connecting the UART port of this two MCUs, the two systems should be able to exchange data between each other directly. Plus, to give the operator a directly and clearly view of the surrending of the ROV, there is a camera mounted on the ROv. Which means, there will be an adtional wire carring video signal other than the data wires.

In this document, the following terms will be used:
- Control signal: Digital signal send from operator-side console to ROV. The operator will send this signal to the ROV to control the ROV, or to setup the autopilot function on the ROV.
- Data signal: Digital signal send from ROV to operator-side console. The ROV will gather data such as pitch angle, direction and ect. and send them to the operator-side console. This signal helps the operator to understant the ROV's statue.
- Video signal: Analog video signal send from camara on the ROV to screen on the operator-side console.

Note: The highest frequency that a digital signal could generated is 0.5 * BAUD (one low bit and one high bit together forms a compelete square wave). In this document, the frequency will be calculated by formula "1 * BAUD " instead of "0.5 * BAUD". This will provide a safety factor of 2.

## Design scope

The ROV is a remotely controlled device, which means, the deeper the ROV dives, the higher the ROV's capability will be. However, when the depth of the ROV increases, the distance between the ROV and the operator-side console increases as well.

Since wireless communication is impossible due to the physical limitation, a cable is applied to connect the ROV and the operator-side console. However, the wire communication still has some issue as well. The wire acts like an antenna so that it could gather noises. The longer the wire, the stronger the EMI noise will be gathered from the environment. Additionally, the faster the transmission speed, the stronger the noise will be created.

Additionally, the physical layer should provide real-time communication and the circuit delay should be in an acceptable range.

Furthermore, to minimize the cost of the system, the circuit should be as simple as possible.

The physical layer should be able to provide a reliable, real-time (with acceptable delay), and full-duplex transmission.


## Design

### Transmission speed

The higher the transmission speed, the worse the communication quality will be. Therefore, the transmission speed should be just higher than the required transmission speed of the application.

By analyzing of the software:
1. The ROV communicates with the operator-side console every 1/4 second.
2. Assume the ROV and operator-side console takes about 100ms to prepare data, encode and decode the package. As a result, the window for data transmission is 150ms.
2. Each time, the ROV and the operator exchanges about 20 bytes (10 to 20) of data.
3. Each byte consider as 8 bits, plus a start bit and two stop byte.

(8 + 1 + 2) * 20 * (1/0.15) = 1466.67 BAUD

Ceiling to the lowest standard BAUD, the BAUD used by this system is 2400 BAUD.


### High-voltage differential signalling (RS-485 like)

The MCU on both operator-side and ROV comes with UART port. A typically TTL UART transmission is a single-wire bus to connect a master (drive the wire) with several slaves (High-Z, listen to the wire). When the data is 0, the master will drive the wire low (0V); otherwise, the master will drive the wire high (5V).

However, due to the length of the wire, strong noise could alternate the signal on the wire. When the master drives the wire high, applying a -5V noise could alternate the signal on the wire from 1 to 0; when the master drives the wire low, applying a +5V noise could alternate the signal on the wire from low to high.

<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/DiffSignaling.png/2560px-DiffSignaling.png" width="50%" alt="TTL UART & Differential signaling" />

_Source: Wikipedia user upload image (by: Linear77, CC BY 3.0)_

To deal with the noise issue, a differential signalling system is applied for the transmission. A differential signalling is a transmission method, that will send both the original signal and its negative signal. More specifically, when the transmitter sends X (1 or 0), the signal X will be placed on wire A, and the negative X will be placed on wire B. On the receiver side, by comparing the signal on wire A and B, the receiver could know the actual signal comes from the transmitter. Since the environment noise applies to both wire, the difference between the wires will not be alternated. 

For example, when the master drives the wire high, wire A will be high (5V), and wire B will be low (0V). Since the voltage on wire A is higher than the voltage on wire B, the receiver could know the signal on the wire is high:

Tx = 1;

A = 5V; B = 0V;

Rx = (A-B>0) ? 1 : 0 = 1

If applying a XV (X = negative infinity to positive infinity) noise:

Tx = 1;

A' = 5V + X; B' = 0V + X;

A' - B' = (5V + X) - (0V + X) = 5V - 0V = A - B;

By using the differential signalling, the noise is filtered.

Since the transmission cable and 12V power supply is built in one multi-core cable, the transmission signal could be amplified to 12 V instead of 5V. During this process, the transmission system could handle stronger EMI noise.


## Circuit design

The differential signalling system circuit consist of 3 parts:
- Positive amplifier (Tx+): When it receives logic 1 (5V), the output will be 12V; when it receives logic 0 (0V), the output will be 0V.
- Negative amplifier (Tx-): When it receives logic 1 (5V), the output will be 0V; when it receives logic 0 (0V), the output will be 12V.
- Receiver (Rx): If Rx+ is greater than Rx-, the output will be logic 1 (5V); otherwise, the output will be logic 0 (0V).
Since the transmission system is full-duplex, there is a pair of differential signalling transmitter and receiver. One of them are responsible for sending signals from ROV to the operator-side console, another one for send signal from operator-side console to ROV.

There are two methods to design this system. One of them is using OpAmp, and the other one is using NMOS. The following shows the circuit and simulation result using LTSpice. According to the simulation, since the cable is very long, the cable comes with 50 ohms of resistance and 1nC capacitance between the positive-side and negative-side of the wire.

### Method 1 - OpAmp

![RS-485 using OpAmp](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/RS485_like_OpAmp.jpg "RS-485 using OpAmp")

In this circuit, on the transmitter side, one OP27 is used for negative amplifier, and one OP37 is used for positive amplifier; on the receiver side, another OP27 is used for comparing the voltage on both wires.

As the simulation result shows, this solution comes with about 5 microsecond delay.

### Method 2 - NMOS

![RS-485 using NMOS](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/RS485_like_NMOS.jpg "RS-485 using NMOS")

Like the OpAmp method, the method uses an OP27 as the comparing circuit on the receiver side. However, on the transmitter side, a 2N7002 NMOS is used for negative amplifier; two 2N7002 NMOS are cascade to form a positive amplifier.

As the simulation shows, the NMOS method has less delay than the OpAmp method (1.5 microsecond delay). Furthermore, the NMOS requires less components. However, for this method, there will always be one NMOS turns on, which means higher power consumption. By increasing the value of resistors, the power consumption could be reduced, but circuit delay may increase.

By comparing both methods, the NMOS design is choose for the communication circuit.


## Circuit implementation

![Test scheme](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scheme-test.jpg "Test scheme")

The above scheme is used to test the communication system. To preform the test, a test signal (an adjustable square wave) will be send to the transmitter, this simulates the operator-side sending control signal to the ROV. The control wire and the data wire is shorted on the ROV side, this simulates the ROV returning the same signal to the operator-side. The distance from the operator-side console to the ROV is 10 meters (for one direction).

### Digital signals (controll signal and data signal)

![Test wave](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-wave.jpg "Test wave")

The above graph shows the typical case. The yellow signal shows the input signal on the Tx, and the green signal shows the output signal on the Rx.

Because of the inner resistance of the transmitter of the MCU, the test signal is 2.5V+/-2V instead of 2.5V +/2.5V. This critical to ensure the on/off voltage of the actual MCU is compatible with the MOSFET. For example, a TTL MCU may only provides 4.5V when it is logic high. If the Vth (threshold voltage) MOSFET is 4.8V, the 5V test signal will be able to open the MOSFET, but the actual MCU cannot.

![Test wave zoom in](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-io.jpg "Test wave zoom in")

In ideal case, there should be no phase difference between the input and output signal; however, due to the natural property of the components, there will always be a delay. The communication system should provide a reasonable small delay.

Due to supply issue, three 2N7000 is used to replac those 2N7002 on the transmitter side; a LM386 is used to replac the OP27 on the receiver-side. Furthermore, the actural impedence of the transmission cord is different from the simulation. Therefore, the value of the pull-up resistors needs to be re-sellected, in order to have an acceptable compromise between the circut delay and power comsuption.

In fact, finding the suitable values of the resistors by calculation is extermelly difficult. Therefore, the "buret-force" method is used to determine the value.

First, assume the pull-up resistor should be 6k ohms:

![Test scheme - 6k pull-up](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-6k-zo.jpg "Test scheme - 6k pull-up")

The above figure shows the test signal (yellow) and the wave observed on probe1 (green). It is clear to say that, there is a delay when the signal changing from 0 to 1. This is because the wire is too long, it becomes a capacitor. The pull-up resistor will limit the current flow into the capacitor, which slows down the charging procedure. The result is a slow rising-edge on the wire. For the falling edge, there is no delay, because there is no resistor between the wire and the ground (resistance of MOS is neglectable).

In this case, the delay of the transmitter amplifier on rising-edge takes 5 microsecond:

![Test scheme - 6k pull-up](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-6k.jpg "Test scheme - 6k pull-up")

Decreasing the pull-up resistance could decrease the rising time. Decreasing the pull-up resistor to 2k will decrease the delay of the transmitter amplifier on rising-edge to 3.8 microsecond:

![Test scheme - 2k pull-up](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-2k.jpg "Test scheme - 2k pull-up")

Decreasing the pull-up resistor to 1k will decrease the rising time to 3.1 microsecond, but increasing the power comsuption. Compare to the 2k version, the 1k version has a minor performance increasing, but a significant power comsuption increasing:

![Test scheme - 1k pull-up](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-1k.jpg "Test scheme - 1k pull-up")

By analysis the aboving attempts, the 2k version is choosed. The following graph shows the delay between the Tx (test signal) and Rx (probe3). The delay between the Tx and Rx is smaller than the delay between the Tx and the wire, this is because of the gain of the OpAmp:

![Test scheme - 2k pull-up](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scope-delay.jpg "Test scheme - 2k pull-up")

This circuit provides a delay (rising time and falling time) less than 5us with average power comsuption of 120mA, which is an acceptable compromise. The final scheme is shown below:

![Test scheme](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/scheme-final.jpg "Test scheme")

The delay is 5 microseconds, it may seem to be long; however, the communication spped is 2400 BAUD. Assume the data/command wires carry 2400Hz square wave, the period of the square wave is 417 microseconds, which is about 80 times of the delay.


### Video signal

The above experiments shows that, the communication system is able to handle digital communication. The following experiments will determine wheather the system could handle digital communication plus analog video communication together.

Do notice that, on one hand, althrough the video signal is an analog signal, it still generates EMI on the data wrie and control wire. Thanks to the differential signalling, the EMI is neglectable. On the other hand, the data signal and control will generate EMI on the video. Because the video signal is not differential signalling, the effect will be significant.

It is clear to say that, the quality of the video will be significantly affected by the control signal and the data signal. However, even the video will be affected, user (human) should be able to watch the video with minor image defect. In fact, when the ROV is working underwater, the surrending will be very dark, hence the user may not be able to notice the effect on the video signal due to EMI. Furthermore, the camera mounted on the ROV is design for observation, not moving making (which means, the image quality is not important). That means, the video image defect is neglectable.

![Video signal test](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/video.jpg "Video signal test")

The above pictures show the experimental result. The top-left picture shows the test object.

The top-right picture shows the image coming from the camera via the 10-meter-long communication cord, when there is no control signal or data signal (by powering the control wire and data wire with DC). The image loses some color accuracy due to noise and wire impedance.

The software will exchanging data at 2400 BAUD. To simulate this, powering the control wire and data wire with 12V 2400Hz square wave. Like the picture shows, in this case, some dot could be observed on the image. This is bacuase the switching of the data signal and control signal generate EMI on the video signal. However, the user is still able to see the video with this much image defect.

Althrouth the software will not use high frequency data exchange rate, it is good to test the system in extreme case. If the data exchanging rate keep increasing, when the data rate reaches 10k BAUD (simulated by using 12V 10kHz square wave). There will be significant defect on the image, like the above picture shows. When the data rate reaches 1M BAUD, the video signal will be significantly affected.

In conclusion, this system is capable with the design specification.


## Cable implementation

Obviously, the first concern when design the cable of the ROV is that: the cable, particularly the connector, should be waterproof, even under certain pressure.

The second concern is that, in some case, the ROV may malfunction. In this case, the ROV will lose its proplusion; hence, the operator will need to use the cable to pull the ROV back. In exterme case, the ROV may be trapped by something like seaweeds. Therefore, the cable must be able to handle certain force.

Furthermore, bacause the cable carries power of the ROV and the data/control/video signal, the cable needs to be multi-core, comes with at least 2 power grids, and at least 5 (2 for differential-signalling control signal, 2 for data signal, 1 for video signal) shielded signal wires. Furthermore, because of the differential signalling, it is better to have the control signal and the data signal go through twisted pairs with diffenent twist length.

To satisfy the above requirements, IP68 rated waterproof aviation plug is used. Like the below picture shows, the aviation plug used in this system has 7 pins, each can handle up to 15A of current.

![Aviation connector](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/connector.jpg "Aviation connector")

The cable used in this system is orginal designed for elevator, which is specially designed for using with high tensile force. Like the below picture shows, the cable has 3 components. The first component is a pair of high strength steel cable, which is used to handle the tensile force. The second component is a pair of 1-square-minimeter power wire, which is designed for power supply. The third component is four pairs of double shield twisted wire with different twist length, which is used to carry signals.
![Cable](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/cable-1.jpg "Cable")

This system requires a pair of power cable, two pairs of twisted wire for data and control signals, and one wire for video signal. The following table shows the connection of wires and the plug. Notice that, the orange pair and the brown pair has the longest and shortest twist length, using them for control signal and data signal respectively could provide lowest EMI between them.

![Connection](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/connection.jpg "Connection")

The challenge here is to implement the cable system, especially that the aviation accepts round cable, but the elevator cable is flat.

To deal with this issue, the following method is used:

1 - Removing the outer rubber of the cable. Then, wraping the wires with electrical tape to form a round shape.

![Cable implementation](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/cable-2.jpg "Cable implementation")

2 - Using shrinking tube to tight the cable.

![Cable implementation](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/cable-3.jpg "Cable implementation")

3 - Soldering the wires onto the aviation plug, according to the table.

![Cable implementation](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/cable-4.jpg "Cable implementation")

4 - Securing the aviation plug. The rubber ring located in the tail of the aviation plug's body should now tightly attached to the cable's outer layer to prevent water inleaking. To prevent water inleaking from the end of the shriking tube, applying a piece of aluminum foil tape to seal the cable.

![Cable implementation](https://raw.githubusercontent.com/captdam/DD-40/master/Communication/PhysicalLayer/cable-5.jpg "Cable implementation")

5 - For a better waterproofing profermance, filling the aviation plug with silicon glue. After doing this, it is no longer possible to open the plug to modify the connection. However, it seems like the wire connection in the plug will never be modified in the furture.
