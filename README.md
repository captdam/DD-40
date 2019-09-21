# [Deprecated]
This project is __deprecated__. Please see the DD-41 project: https://github.com/captdam/DD-41

# DD-40
University of Windsor Electrical and Computer Engineering Undergraduate Capstone Project 2019 - Remotely Operated Underwater Vehicle

# About this project

# Documents

## Operator-soide console

The operator-side console is an interface for the user to control the ROV. The operator-side console not only let the user directly control the ROV, display data and video returned by the ROV; but also allows the user to config the auto pilot function of the ROV.

__Mechanical structure__
A summary of the layout of the operator-side console.
- https://github.com/captdam/DD-40/blob/master/Operator/README-MECH.md
- Power
- Video monitor
- LCD displays
- User input

__Electrical circuit__
The circuit board in the operator-side console.
- https://github.com/captdam/DD-40/blob/master/Operator/README-ELEC.md
- MCU system
- LCD displays
- Matrix input

__Control software__
An abstruction level description of the software in operator-side console controller.
- https://github.com/captdam/DD-40/blob/master/Operator/README-SW.md
- UART for long-distance communication
- LCD display interface
- Input interface

## ROV

The ROV is a remotely operated underwater vehicle.

__Mechanical structure__
The design and assembly of structure of the ROV, and the actuator instalation.
- https://github.com/captdam/DD-40/blob/master/ROV/README-MECH.md
- ROV body assembly
- Actuator installation

__Electrical circuit__
The control circuit of the ROV, includes tail hub, main control circuit board and tail hub.
- https://github.com/captdam/DD-40/blob/master/ROV/README-ELEC.md
- Power supply
- MCU systems
- Gyro sensor
- Actuator drivers

__Control software__
An abstruction level description of the software in main controller and the AUX controller.
- https://github.com/captdam/DD-40/blob/master/ROV/README-SW.md
- Two AVR MCUs, ATmega328P
- Main Controller
  - UART for long-distance communication
  - I2C for local communication
  - ADC for analog sensor
- AUX controller
  - I2C for local communication
  - Software PWM

## Communication

The ROV system contains two parts, the operator-side console and the ROV itself. During the operation, the user will use the operator-side console to send command to the ROV, such as direction; mean while, the ROV will send back data to the operator-console, including the battery voltage, depth and ect..

To establish a reliable and easy-to-implement communication between the ROV and the operator-side console, a communication sub-system is used in the ROV system. The communication system has 3 layers:

__Physical layer__
Real circuit and cable, Rs-485 like transmitter and receiver.
- https://github.com/captdam/DD-40/blob/master/Communication/README-L1.md
- RS-485 like long-distance voltage-differential transmission
- Electrical schematic

__Transport layer__
Framework software, provides a reliable data transmission. Packet defination.
- https://github.com/captdam/DD-40/blob/master/Communication/README-L2.md
- Package regulation
- Error detection
- Master/slave synch

__Application layer__
Data exchange between the ROV and operator-side console.
- https://github.com/captdam/DD-40/blob/master/Communication/README-L3.md
- MCU data registers map (App SFR)
- Package data structure
