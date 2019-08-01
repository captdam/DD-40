# ROV tech document - Electrical circuit

## Introduction

This document will demonstrate how the design group come up with the control circuit of the ROV.


__根据下面的System level design来写__


## System-level design

Refer to the introduction, in conclusion, the control circuit of the ROV should be able to finish the following tasks:
- Communicate with the operator-side console
- Control the actuator
- Collect attitude data and depth of itself
- Temperature & voltage monitor
- Real-time video record
- Pilot by operator
- Pilot by auto-pilot function

To finish these tasks, the following components are required:
- Power supply
- Microcontroller includes:
  - UART that can communicate with the operator-side console
  - local communication bus that can communicate with other components of the ROV
  - ADC that can attach analog sensors
- Communication subsystem
- Motion sensor (6-axis or 9-axis) gyro sensor
  - With local communication bus that can communicate with other components of the ROV
- Actuator driver
- Pressure sensor
- Camera


### Camera

The camera is directly connected to the video monitor on the operator-side console.

An HD car back-up camera with BNC connector is used.

### Actuator driver

The actuator is directly driven by the MCU. When the MCU outputs high, the actuator will be energized. When the MCU outputs low, the actuator will be de-energized. However, the output strength of MCU is not high enough to drive an actuator. Generally, the output current of MCU is typically 1mA to 10mA but the current required to drive an actuator will be at least 0.5A. In the ROV system, the current required to drive valves is 500mA.

To amplify the output strength of the MCU, a driver is required to be connected between the MCU and the actuator, such as a buffer. Since the driver is an NMOS, it only requires a very small amount of current (uA level. As a result, the MCU can easily drive it and the MOSFET will drive the actuator with high current.

In this system, a set of logical N-channel MOSFET 30N06 is used. This NMOS has a threshold voltage of 2.5V and a continuous current of 32A. It can be driven by any 3V or 5V MCU, and it can easily drive the actuators mounted on the ROV.

### Gyro sensor

In order to collect the attitude data of the ROV, a gyro sensor is required.

In this system, an MPU9250 9-axis sensor is applied. This sensor comes with gyro, accelerometer and compass in the x-axis, y-axis and z-axis, and a temperature sensor. By manipulating the data above, the attitude of the ROV such as pitch angle could be determined.

This sensor can be connected to MCU via SPI or I2C bus. In this design, the I2C bus is chosen. Additionally, his sensor requires voltage in the range from 2.4V to 3.6V.

### Pressure/depth sensor

The deeper the water, the higher the pressure. Every 10 meters of water increases 1 atm of pressure. By measuring the pressure of the water, the depth of the ROV could be measured.
In this system, a 1.2MPa rated pressure is used. This pressure is an analog pressure sensor which requires 5V voltage.

### MCU
The microcontroller is the core of the ROV's control circuit. It not only is responsible for the ROV control, but also communicates with the operator-side console. At the circuit level, the microcontroller will 

For the MCU, the following components are required:
- ADC: Measuring the supply voltage and the pressure sensor.
- UART: Communicating with the operator-side console.
- SPI or I2C: Communicating with the gyro sensor.
- PWM generator: Semi-analog output for pump motor control.

Any architecture can be applied to the system. However, since the motion calculation involves floating-point calculation, the MCU better comes with floating-point ALU. Furthermore, the design should choose an architecture that the design team is more familiar with to reduce the development cost. by comparing 8051, 68HC00 and AVR architecture, ATmega328P is chosen as the controller of the ROV according to the following reasons:
- This MCU comes with all the prefs that the system requires.
- This MCU is commonly used in Arduino. There is a large community which will be easier to find solutions when encountering problems.
- This MCU is commonly used in Arduino. The chance of discontinuity of this MCU is lower than other MCUs.

However, this MCU has a limited amount of IO. For the DIP28 package, there are 22 available IOs, which is not enough for the ROV design. In order to expand the IO, an AUX controller is introduced. The main controller is responsible for communication, sensor data fetching, and data processing and the AUX controller drives the actuators. The main controller and the AUX controller are connected with I2C bus.

This MCU requires voltage in the range of 1.8V to 5.5V.

### Power supply

There is no battery on the ROV. Instead, there is a 12V battery on the operator-side, and the power will be provided through the communication cable. The 12V power supply is ideal for driving actuators. However, for microcontrollers and sensors, 12V is too high to work. Therefore, a voltage regulator is required.

### I2C vs SPI

In the system, the main controller, the AUX controller and the gyro sensor can be connected by both SPI or I2C sensor.

However, the SPI interface of the MCU is multiplexed with the serial programming interface of the MCU. More specifically, the SPI interface will be used when programming the MCU. If the system connects with the SPI bus, it is necessary to disconnect the system when programming the MCU.

Disconnecting and re-connecting the wire may damage the solder joint and decrease the life-time of the circuit board. Furthermore, the changing to the wrong connection may result in the system to fail and have a short circuit or permanent damage.


## Circuit board

### Main controller

The main controller circuit board comes with power supply, main controller MCU and communication module.

![Main circuit schematic](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/control-circuit.jpg "Main circuit schematic")
![Main circuit board](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/control-circuit-board.jpg "Main circuit board")

__Power supply__

The power provided to the ROV comes from a 12V car battery. Since the controller requires 5V power supply, an LM7805 linear voltage regulator is applied for the power regulation. Additionally, an LED is used for power indicator, and a 6.3V 1000uF high-volume capacitor is used to deal with low-frequency noise in the power supply. Socket J1 provides 5V power supply for other systems which may be added on later.

The 7805 is a linear voltage regulator which does not require any external components. Furthermore, when the supply voltage varies, the linear voltage regulator has better performance comparing to the switching voltage regulator. This is very important because the battery is used to drive motors and valves. The voltage of the battery may suddenly drop by 1 or 2 volts when the motor is turned on.

The disadvantage is that the efficiency of the linear voltage regulator is terrible. Assuming the load is 1A 5V, and the supply voltage is 12V, the voltage regulator will consume (12V - 5V) * 1A = 7W power. Therefore, the heat sink component is required. However, it still has some benefits. When the circuit is shorted, the regulator heated up and the current output reduced due to heat resistance. This can avoid the circuit being burned.

Although the linear voltage regulator does not have a good efficiency, the current consumed by the MCU is very low. By comparing the efficiency and the circuit complexity, it is worth to make the compromise. Furthermore, the actuator consumes much more power than the control circuit; therefore, the waste of power from the control circuit is ignorable.

__MCU core__

The MCU core combines the MCU, the reset button, supply-voltage monitor and the programming socket J2 (or call it ICSP).

The timing requirement of the system is not critical. As long as the clock can provide a relatively BAUD rate for UART communication, the clock is good. Therefore, the fuse of the MCU is set in such a way that the MCU will be powered by the internal RC clock. Therefore, no crystal is required in this circuit. By doing so, pin PB6 and PB7 could be used as GPIO.

Pin1 is the reset of the MCU. It is weakly pulled up by a 10k resistor. When the RESET push-button is pushed, or the RST pin of the ICSP is strongly pulled low, the MCU will be reset.

During the operation, it is important to monitor the supply voltage of the ROV. To do this, the power supply (12V) is connected to ADC channel 3 of the MCU. By doing an ADC converting, the MCU can sample the battery voltage and give the user warning if the voltage is too low. Since the MCU's ADC only accept 0V to 5V, a 30k to 10k voltage divider is used. By doing so, the range and resolution of the ADC both increased 3 times.

Socket J3 is the I2C bus of the ROV system. The AUX controller and the gyro sensor will be connected to the main controller through this socket.

Socket J4 is analog input of the MCU, with 5V supply. The pressure sensor and other analog sensors could be connected here.

Socket J5, J6 and J7 are bi-directional digital GPIO. For J5, it is connected to pin 15 and 16 of the ATmage328P MCU. These two pins are the output-comparing pin of 16-bit timer T1. In other word, these two pins support high-resolution PWM signal generation, and they will be connected to the motor driver.

__Communication module__

This module is connected to the UART interface of the main controller. The purpose of this module is to convert the TTL UART signal into an RS-485 like high-voltage differential-pair signal, which can be used for long-distance communication. For the details of this module, please refer to the Communication protocol tech document.


### Head hub

The head hub circuit board comes with a camera, main light and navigation light.

![Head hub schematic](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/head-hub.jpg "Head hub schematic")
![Head hub board](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/head-hub-board.jpg "Head hub board")

__Camera__

The camera is located in the head hub; however, since the video is untouched, the camera is not included in the schematic.

__Main light__

The main light is a very simple circuit. It is formed by a 5W 10 ohms resistor, and two 3W white LED connected in series with a throttle NMOS. When the signal Main light is low, the throttle NMOS is off, and no current will pass through it. When the signal Main light is high, the throttle NMO turns on, and the current will pass through it.

The voltage source is 12V, and the voltage drop for turning on LED is 3V. The resistor is 10 ohms and the resistance of the NMOS is almost zero. Current of the main light, when it turns on, will be (12V - 2 * 3V) / 10 ohms = 0.6A. Since the current is high, the high-current NMOS 30N06 is used.

__Navigation light__

The purpose of having navigation light is to indicate other underwater vehicles or humans that the ROV is here. To build the navigation light, an astable-multivariate circuit is used. Since the green LED is weaker than red LED, to counter the difference of light intensity, the resistor on the green LED side will be smaller to provide larger current.
The navigation light also comes with a throttle NMO. Due to the current of the navigation light, a small 2N7000 NMOS could be used.


### Tail hub

The tail hub circuit board comes with second-stage power supply, AUX controller, gyro sensor and actuator driver bank.

The photo below shows both the tail hub circuit board and the main controller circuit board.

![Tail hub schematic](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/tail-hub.jpg "Tail hub schematic")
![Tail hub board](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/tail-hub-board.jpg "Tail hub board")

__Second-stage power supply__

The main controller is working at 5V; however, the maximum voltage the gyro sensor could handle is 3.6V. As a result, a circuit which can provide a lower voltage other than 5V supply is required.

By examining the circuit, it is clear to say that the current supplied to the gyro sensor and the AUX controller is very small and relatively constant. Instead of using a 3.3V voltage regulator, using diodes to lower the voltage is a better choice.

The second-stage power supply comes with three diodes and a resistor. The diodes are used to lower the voltage, and the resistor is used to make a certain current so the diode will provide the desired voltage drop. By doing some experiment and calculation, the resistor value should be 1k ohms to provide a 3V output voltage. If the resistor value is too small, the power supply circuit will consume too much energy. If the resistor value is too large, the current will be not enough to make the diode has the certain desired voltage drop.

__Gyro sensor__

The gyro sensor is used to collect attitude and temperature data of the ROV. The sensor is a highly integrated module; therefore, it just needs to be connected to the power and I2C bus.

__AUX controller__

The AUX sensor is used to control the actuators. Similar to the main controller, the AUX controller requires a reset button and ICSP jacket. For information about these two components, please refer to the main controller.

__Actuator & Driver bank__

All actuators are 12V rated and connected in the Power-Actuator-MOSFET-Ground way, where the power is 12V car battery. Since the actuators are valves and pumps which requires 500mA and 4A of current, high-current logical N-channel MOSFET 30N06 is applied to the circuit. The gate of the MOSFETs is connected to the MCU.

When the MCU outputs high, the actuator will be energized, and the water path of the valves will be open with the opened water pump. When the MCU outputs low, the actuator will be de-energized, and the water path of the valve will be cut down. Additionally, the pump will be stopped.
