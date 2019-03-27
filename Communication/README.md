# 3-Layers communication model

The ROV system contains two parts, the operator-side console and the ROV itself. During the operation, the user will use the operator-side console to send command to the ROV, such as direction; mean while, the ROV will send back data to the operator-console, including the battery voltage, depth and ect..

To establish a reliable and easy-to-implement communication between the ROV and the operator-side console, a communication sub-system is used in the ROV system. The communication system has 3 layers, the physical layer (real circuit and cable), the transport layer (provides a reliable data transmission), and the application layer (data exchange between the ROV and operator-side console).

## Application layer
- https://github.com/captdam/DD-40/blob/master/Communication/README-L3.md
- MCU data registers map (App SFR)
- Package data structure

## Transport layer
- https://github.com/captdam/DD-40/blob/master/Communication/README-L2.md
- Package regulation
- Error detection
- Master/slave synch

## Physical layer
- https://github.com/captdam/DD-40/blob/master/Communication/README-L1.md
- RS-485 like long-distance voltage-differential transmission
- Electrical schema
