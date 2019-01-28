Due to the lack of I/O pins on the main controller (ATmega328P), an addtional controller (STC89C52RC) is added into the ROV controller circuit.
This AUX controller will recive command from the main controller, and then send the command to actuators.
