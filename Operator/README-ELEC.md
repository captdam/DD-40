# Operator-side console tech document - Electrical circuit

## Introduction

The operator-side console is an interface for the user to control the ROV. The user is able to directly control the ROV using joysticks and switches, or enter auto pilot configuration on the keyboard to program the auto pilot function of the ROV. Furthermore, the operato-side sonsole needs to display the auto-pilot configuration and the ROV's status to the user using LCD displays.

This document will demonstrate how the design group come up with the control circuit of the operator-side console.

## System-level design

Refer to the introduction, in conclusion, the control circuit of the operator-side should be able to finish the following tasks:
- Power the MCU system
- Collect user input
- Send /receive data to/from ROV
- Display data on LCD displays

To finish these tasks, the following components are required:
- Power supply
- Microcontroller includes:
  - UART that can communicate with the operator-side console
  - Large amount of IO to connect inputs and LCd displays
- Communication subsystem
- Input, such as switch and joystick
- LCD displays


### Input matrix

The inputs is a set of switches which connect the input port of the MCU to power supply or ground. If the switch connects the MCU input port with ground, a logic 0 will be provided to MCU; if the switch connects the MCU input port with power, a logic 1 will be provided to MCU.

In this system, there are 32 inputs. If directly connect each input to a pin, it requires 32 GPIO. Instead, input keyboard matrix is used. In this way, 2 8-bit port could form a 8*8 matrix that support up to 64 inputs.

In this design, a 6*8 matrix is used. 14 pins are required.

### LCD display

Althrough other types of display can proform the same task; however, the 1602 LCD has the simplest interface and lowest cost. Directly connect the LCD display to the MCU, and supply the LCD display control signal and ASCII encoded charcode, the LCD will print the desired character on the screen.

In fact, the 1602 LCD is orginally designed for 8051 MCU. Both the 8051 MCU and 1602 LCD use 5V TTL voltage, 8-bit palleral data interface, 1MHz clock and ect..

The LCD has 8 pins for data IO and 4 pins for control IO.

### MCU
The microcontroller is the core of the ROV's control circuit. The LCD and the input matrix are connected to the MCU.

Any architecture can be applied to the system. However, since the design requires a lot of IO, the MCU should be IO rich MCU.By comparing 8051, 68HC00 and AVR architecture, STC89C52RC is chosen as the controller of the ROV according to the following reasons:
- This MCU has 32 GPIO.
- This MCU is exteremely cheap.
- This MCU is commonly used in China as education kit. The chance of discontinuity of this MCU is lower than other MCUs.

### Power supply

There is a 12V battery power supply. However, for microcontrollers and LCD displays, 12V is too high to work. Therefore, a voltage regulator is required.


## Circuit board

![Circuit](https://raw.githubusercontent.com/captdam/DD-40/master/Operator/Circuit/circuit.jpg "Circuit schematic")

### Power supply

The power provided to the ROV comes from a 12V car battery. Since the controller requires 5V power supply, an LM7805 linear voltage regulator is applied for the power regulation. Additionally, an LED is used for power indicator, and a 6.3V 1000uF high-volume capacitor is used to deal with low-frequency noise in the power supply. Socket J1 provides 5V power supply for other systems which may be added on later.

The 7805 is a linear voltage regulator which does not require any external components. Furthermore, when the supply voltage varies, the linear voltage regulator has better performance comparing to the switching voltage regulator. This is very important because the battery is used to drive motors and valves. The voltage of the battery may suddenly drop by 1 or 2 volts when the motor is turned on.

The disadvantage is that the efficiency of the linear voltage regulator is terrible. Assuming the load is 1A 5V, and the supply voltage is 12V, the voltage regulator will consume (12V - 5V) * 1A = 7W power. Therefore, the heat sink component is required. However, it still has some benefits. When the circuit is shorted, the regulator heated up and the current output reduced due to heat resistance. This can avoid the circuit being burned.

Although the linear voltage regulator does not have a good efficiency, the current consumed by the MCU is very low. By comparing the efficiency and the circuit complexity, it is worth to make the compromise. Furthermore, the actuator consumes much more power than the control circuit; therefore, the waste of power from the control circuit is ignorable.

### MCU minimul system

The MCU minimul system combines the MCU, the reset button and crystal.

Pin8 is the reset of the MCU. Bu default, this pin is pulled low by a 10k resistor. When the RESET button is press, the reset pin will be stringly pull up to reset the MCU.

The STC89C52RC can only be clocked by crystal. A 12MHz crystal is used in this system.

### LCD displays

There are two LCD displays in the system, one is used to display the status of the ROV, another one is used to display the auto pilot configuration.

Bothe LCD shares the same data bus and control wire, except the enable wire. For example, when the MCU write data to LCD1, both LCD0 and LCD1 receives the data. However, the MCU will set the enable of LCD1 to high and that of LCD0 to low. in this case, LCD0 is disabled, only LCD1 will react with the data.

### Communication module

This module is connected to the UART interface of the MCU The purpose of this module is to convert the TTL UART signal into an RS-485 like high-voltage differential-pair signal, which can be used for long-distance communication. For the details of this module, please refer to the Communication protocol tech document.

### User input matrix

The user input matrix is 6*8 matrix. The column wires are used for scan, they are connected to P0 of the MCU, and pulled up through 8 10k resistors. The row wires are for drive, they are connected to P1 of the MCU.

By default, all row wire are high. When scan, the MCU will set each wire of the row to low in sequence. Then, the MCU will scan the colume wire to determine which switch is closed.

For example, in a 4*8 matrix, the switch at row 1 colume 2 is closed:
- Scan row 0: Drive row 0 low, Read 0b11111111. Result: No key pressed on the row.
- Scan row 1: Drive row 1 low, Read 0b11111011. Resukt: Key at column 2 pressed on this row.
- Scan row 0: Drive row 2 low, Read 0b11111111. Result: No key pressed on the row.
- Scan row 0: Drive row 3 low, Read 0b11111111. Result: No key pressed on the row.

The reason is that: When there is no switch closed, the column wires are pulled by by resistors. However, when there is a switch closed, and the MCU is scanning that row. The MCU will drive the row wire low. Then, the row wire will drive the specific column wire low. After thism the MCU can read a low on the column, this tells the MCU a key at the specific location is pressed.

Notice that, all switches are connected with a diode in series. This is used to prevent ghost key when more than two switches are closed in the matrix.


