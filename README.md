# DD-40
University of Windsor Electrical and Computer Engineering Undergraduate Capstone Project 2019 - Remotely Operated Underwater Vehicle

# About this project

# Documents
## Operator-soide console
- Software: https://github.com/captdam/DD-40/blob/master/Operator/Controller/README.md
- Hardware: WIP
## ROV
- Software: WIP
- Hardware: WIP

## Communication

The ROV system contains two parts, the operator-side console and the ROV itself. During the operation, the user will use the operator-side console to send command to the ROV, such as direction; mean while, the ROV will send back data to the operator-console, including the battery voltage, depth and ect..

To establish a reliable and easy-to-implement communication between the ROV and the operator-side console, a communication sub-system is used in the ROV system. The communication system has 3 layers:
- Physical layer: real circuit and cable, Rs-485 like transmitter and receiver.
- Transport layer: Framework software, provides a reliable data transmission. Packet defination.
- Application layer: data exchange between the ROV and operator-side console.

__Application layer__
- https://github.com/captdam/DD-40/blob/master/Communication/README-L3.md
- MCU data registers map (App SFR)
- Package data structure

__Transport layer__
- https://github.com/captdam/DD-40/blob/master/Communication/README-L2.md
- Package regulation
- Error detection
- Master/slave synch

__Physical layer__
- https://github.com/captdam/DD-40/blob/master/Communication/README-L1.md
- RS-485 like long-distance voltage-differential transmission
- Electrical schema
