# ROV tech document - Electrical circuit

## Introduction

This document will demostrate how the design group come up with the control circuit of the ROV.


__根据下面的System level design来写__


## System level design

Refer to the introduction, in conclusion, the control circuit of the ROV should be able to finish the following tasks:
- Communicate with the operator-side console
- Control the actuator
- Collect attitude data and depth of itself
- Temperature & voltage monitor
- Real-time video record
- Pilot by operator
- Pilot by auto-pilot function

To do such task, the following components are required:
- Power supply
- Microcontroller
  - With UART that can communicate with operator-side console
  - With local communication bus that can communicate with other components of the ROV
  - With ADC that can attach analog sensors
- Communication subsystem
- Motion sensor (6-axis or 9-axis) gyro sensor
  - With local communication bus that can communicate with other components of the ROV
- Actuator driver
- Pressure sensor
- Camera


### Camara

The camara is directly connected to the video monitor on the operator-side console.

An HD car back-up camara with BNC connector is used.

### Actuator driver

Logically speaking, the actuator is directlly drived by the MCU. When the MCU outputs high, the actuator will be energized; when the MCU outputs low, the actuator will be deenergized. However, the output strength of MCU is not high enough to drive an actuator. Generally speaking, the output current of MCU is typecally 1mA to 10mA; but the current required to drive an actuator will be at least 0.5A. In the ROV system, the current required to drive valves are 500mA.

To amplitify the output strength of the MCU, a driver is required to be connected between the MCU and the actuator like a buffer. Sine the driver is a NMOS, it only requires very small amount of current (uA level); therefore, the MCU can easily drive it. Then, the MOSFET will drive the actuator with high current.

In this system, a set of logical N-channel MOSFET 30N06 are used. This NMOS has a threshold voltage of 2.5V and continuous current of 32A. It can be drive by any 3V or 5V MCU, and it can easily drive the actuactors mounted on the ROV.

### Gyro sensor

In order to collect the attitude data of the ROV, a gyro sensor is required.

In this system, a MPU9250 9-axis sensor is used. This sensor comes with gyro, accelerometer and compass in x-axis, y-axis and z-axis, and a temperature sensor. By manipunate the above data, the attitude of the ROV such as pitch angle could be determined.

This sensor can be connect to MCU via SPI or I2C bus. In this design ,the I2C bus will be used. This sensor requires voltage in the range from 2.4V to 3.6V.

### Pressure/depth sensor

The deep the water, the higher the pressure. Every 10 meters of water bring 1 atm of pressure. By measure the pressure of the water, the depth of the ROV could be measures.
In this system, a 1.2MPa rated pressure is used. This pressure is a analog pressure sensor and requires 5V voltage.

### MCU
The microcontroller is the core of the ROV's control circuit. It not only control the ROV, but also communicate with the operator-side console. At the circuit level, the microcontroller will 

For the MCU, the following perfs is required:
- ADC: Measure the supply voltage and the pressure sensor.
- UART: Communicate with operator-side console.
- SPI or I2C: Communicate with the gyro sensor.
- PWM generator: Semi-analog output for pump motor control.

Any architecture is fine for the application; however, because the motion calculation involves floating point calculation, the MCU better comes with floating pointr ALU. Furthermore, the design should choose an architecture that the design team is familair to reduce development cost. by comparing 8051, 68HC00 and AVR architecture, ATmega328P is choosed as the controller of the ROV, the reasons are:
- This MCU comes with all the prefs that the system requires.
- This MCU is commonly used in Arduino. There is a large community, it is easier to find solution when encounter problem.
- This MCU is commonly used in Arduino. The chance of discontinue of this MCU is lower than other MCUs.

However, this MCU has limited amount of IO. For DIP28 package, there are 22 avriable IO, which is not enough for the ROV design. In order to expain the IO, an AUX controller is introduced. The main controller takes charge in communication, sensor data fetching and data processing; the AUX controller drives the actuactors. The main controller and the AUX controler are connected with I2C bus.

This MCU requires voltage in the range of 1.8V to 5.5V.

### Power supply

There is no battery on the ROV, instead, thhere is a 12V battery on the operator-side, and power will be provided through the communication cable. The 12V power supply is ideal for driving actuator; however, for microcontrollers and sensors, 12V is too high. Therefore, a voltage regulator is required.

### I2C vs SPI

In the system, the main controller, the AUX controller and the gyro sensor can be connect by both SPI or I2C sensor.

However, the SPI interface of the MCU is multiplexed with serial programming interfac of the MCU. In another word, the SPI interface will be used when programming the MCU. If the system is connected with SPI bus, the components is required to be disconnected when programming the MCU.

Disconnect and re-connect the wire may damage the solder joint and decrease the life cycle of the circuit board. Furthermore, there is change of wrong connection which may result in the system fail, short circuit or permeletely damage.


## Circuit board

### Main controller

The main controller circuit board comes with power supply, main controller MCU and communication module.

![Main circuit schematic](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/control-circuit.jpg "Main circuit schematic")
![Main circuit board](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/control-circuit-board.jpg "Main circuit board")

__Power supply__

The power provided to the ROV comes from a 12V car battery. Since the controller requires 5V power supply, a LM7805 linear voltage regulator is used. An LED is used for power indecator, and a 6.3V 1000uF high-volume capacitor is used to deal with low-frequency noise in the power supply. Socket J1 provides 5V power supply for other system which may be add on later.

The 7805 is a linear voltage regulator, it requires no external components. Furthermore, linear voltage regulator has better performance when the supply voltae varys comparing to switching voltage regulator. This is very important because the battery is used to drive motors and valves. The voltage of the battery may suddenly dropped by 1 or 2 volts when the motor is turned on.

This disadvantage is that, the effiency of linear voltage regulator is terrible. Assume the load is 1A 5V, and the supply voltage is 12V. In this case, the voltage regulator will comsume (12V - 5V) * 1A = 7W power. Therefore, heat sink is required. However, this also bring a benifit. When the circuit is shorted, the regulator heated up and the current output reduced due to heat resistance. This protects the circuit being burned.

Althrough the effiency is not good for linear voltage regulator, the current comsumed by the MCU is very low. Compare the effiency and the circuit complexity, it is worth to make the compermize. Furthermore, the actuactor comsumes much more power than the control circuit; therefore, the waste of power from the control circuit is ignorable.

__MCU core__

The MCU core combines the MCU, the reset button, supply voltage monitor and the programming socket J2 (or call it ICSP).

The timing requirement of the system is not critical. As long as the clock can provide a relatively BAUD rate for UART communication, the clock is good. Therefore, the fuse of the MCU is set in such way, the MCU will be powered by internal RC clock. Therefore, no crystal is required in this circuit. By dong so, pin PB6 and PB7 could be used as GPIO.

Pin1 is the reset of the MCU. It is weakly pulled up by a 10k resistor. When the RESET push button is pushed, or the RST pin of the ICSP is strongly pulled low, the MCU will be reset.

During the operation, it is important to monitor the supply voltage of the ROV. To do this, the power supply (12V) is connected to ADC channel 3 of the MCU. By doing an ADC convertion, the MCU can sample the battery voltage and give the user warning if voltage is too low. Since the MCU's ADC only accept 0V to 5V, a 30k:10k voltage divider is used. By doing so, the range and resolution of the ADC both increased by 3 times.

Socket J3 is the I2C bus of the ROV system. The AUX controller and the gyro sensor will be connected to the main controller through this socket.

Socket J4 is analog input of the MCU, with 5V supply. The pressure sensor and other analog sensor could be connect here.

Socket J5, J6 and J7 are bi-directional digital GPIO. For J5, it is connected to pin 15 and 16 of the ATmage328P MCU. This two pins are the output compare pin of 16-bit timer T1. In another word, these two pins support high-resolution PWM signal generation. These two pins will be connected to motor driver.

__Communication module__

This module is connected to the UART interface of the main controller. The purpose of this module is wo convert the TTL UART signal into a RS-485 like high-voltage differential-pair signal, which can be used for long distance communication. For detal of this module, refer to the Communication protocal tech document.


### Head hub

The head hub circuit board comes with camara, main light and navigation light.

![Head hub schematic](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/head-hub.jpg "Head hub schematic")
![Head hub board](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/head-hub-board.jpg "Head hub board")

__Camara__

The camara is located in the haed hub; however, since the video is untouched, the camara is not included in the schematic.

__Main light__

The main light is a very simple circuit. It is formed by a 5W 10 ohms resistor, two 3W white LED connected in series and a throttle NMOS. When the signal Main light is low, the throttle NMOS is off, hence no current; when the signal Main light is high, the throttle NMO turns on, and current pass through.

The voltage is 12V, the voltage drop for on LED is 3V, the resistor is 10 ohms and the resistance of the NMOS is almost zero. Current of the main ligh when turns on will be (12V - 2 * 3V) / 10 ohms = 0.6A. Since the current is high, the high-current NMOS 30N06 is used.

__Navigation light__

The purpose of having navigation light is to indecates other vechincle that the ROV is here. To build the navigation light, an astable multivirerator circuit is used. Notice that, the green LED is weaker than read LED. To counter the difference of light intensity, the resistor on the green LED side will be smaller to provide larger current.
The navigation light also comes with a throttle NMO. Because the current of the navigation light, a small 2N7000 NMOS could be used.


### Tail hub

The tail hub circuit board comes with second-stage power supply, AUX controller, gyro sensor and actuator driver bank.

The photo below shows both the tail hub circuit board and the main controller circuit board.

![Tail hub schematic](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/tail-hub.jpg "Tail hub schematic")
![Tail hub board](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/Circuit/tail-hub-board.jpg "Tail hub board")

__Second-stage power supply__

The main controller is working at 5V; however,the maximul voltage the gyro sensor could handle is 3.6V. Therfore, a circuit which can provide a lower voltage other than 5V supply is required.

By exameing the circuit, it is clear to say that, the current supplied to the gyro sensor and the AUX controller is very small and relatively constant. Instead of using a 3.3V voltage regulator, a simple way could be used. That is, using diodes to lower the voltage.

The second-stage power supply comes with three diodes and a resistor. The diodes are used to lower the voltage, and the resistor is used to make a certain current so the diode will provide the desired voltage drop. By doing some experiment and calculation, the resistor value should be 1k ohms to provide a 3V output voltage. If the resistor value is too small, the power supply circuit comsumes too much energy; if the resistor value is too large, the current will be not enough to make the diode has certain desired voltage drop.

__Gyro sensor__

The gyro sensor is used to collect attitude and temperature data of the ROV. The sensor is a highly integrated module; therefore, it just need to be connect to the power and I2C bus.

__AUX controller__

The AUX sensor is used to control the actuactors. Simular to the main controller, the AUX controller requires reset button and ICSP jacket. For information about these two components, refer to the main controller.

__Actuator & Driver bank__

All actuators are 12V rated and connected in the Power-Actuator-MOSFET-Groud way, where thw power is 12V car battery. Since the actuators are valves and pumps which requires 500mA and 4A of current, high-current logical N-channel MOSFET 30N06 is used. The gate of the MOSFETs are connected to the MCU.

When the MCU outputs high, the actuator will be energized. For the valve, the water path will be open; for the pump, the water will be pumped. When the MCU outputs low, the actuator will be deenergized. For the valve, the water path will be cut down; for the pump, the pump stoped.
