# operator-side console tech document

## Introduction

The operator-side console is an interface for the user to control the ROV. There are several screens to show the status of the ROV and video recoded by the ROV, a set of joysticks, switches and keyboad to enter command to the ROV. Furthermore, the operator also includes a battery which is used to power the operator-side console and the ROV.

## Design parameters

When design the operator-side console, there is not too much requirment. As long as the components could be fit into the suitcase, and the part are set in a way that is easy to use for the user, the operator-side console's mechnical design meets the design requirment.

The following parts are included in the operator-side console:
- Battery
- Video monitor
- MCU and control circuit
- LCD display
- Joystick, switches and keyboard

## Implementation

![Operator-side console](https://raw.githubusercontent.com/captdam/DD-40/master/Operator/console.jpg "Operator-side console")

The photo above shows the operator-side console.

### Screen

There is a 7-inch screen on the operator-side console. This screen shows a real-time video recorded by the camera located at the haed of the ROV. This camera helps the user to see the surrunding of the ROV.

### Battary

The design use a 12 voltage battary for the power supply for the ROV and the operator-side console. The battery is connected using a XT-60 connector. When the system is not used, the battery should be disconnected and removed from the system; wehn chargin, connect the battery to a 12V battery charger with male XT-60 connector.

### Data display

Two LCD 1602 display are located at the top left of the board. The first screen is to show the actual status of the ROV. The ROV has several different sensor, and this board will show the battary voltage, tempeture of ROV, angle of elevation and depth on the board from left to right.

Another screen is for the auto-pilot mode. The user can use the 4 * 4 keyboard to config the auto pilot function. When the user config the auto pilot function, the user can use the display to monitor his/her input.

### Operation control board

Operation control board is at the bottom of the suitcase. There are joysticks, switches and keyboard.

The joysticks are used to directly control the ROV, shuch as moving forward, pitching up, and turning right.

The switches are used to turn on or off functions, includes light and auto pilot. For example, the user can toggle the headlight switch on the operator-side console to turn on or off headlight of the ROV.

The keyboard is used to enter auto pilot configuration. For example, if the user want to set the auto pilot function so the ROV will stay at 22.5 meters deep of water, the user will do te following:
- Enter "2", "2", "5" on the key board. After this, the LCD should display "225" in the input buffer.
- Hit the "Depth" key to applay "225" to depth. After this, the LCD should desplay "22.50m" as destnation depth.
- Engage the auto pilot depth control by turn on the switch. Then, the ROV will automatically move to the desired depth.
