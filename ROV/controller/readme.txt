Controller.asm:
  ROV main controller, an ATmega328P.

AUX Controller 0:
  Due to lack of I/O pins on main controller (24 includes SPI, USART ADC ...), the AUX controller 0 is used to expand the I/O of the main controller.
  The AUX controller 0 is a MSC-51 MCU, it is cheap, slow with very little peripheral, but with lots of IO (32 programmerable).
  The AUX controller 0 works as a SPI slave. It will listen command from the main controller, decode the command, and then update its (AUX controller 0's) IO.
  This AUX controller controls most of the main actuators of the ROV.
