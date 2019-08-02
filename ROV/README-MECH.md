# ROV tech document - Mechanical structure


## Introduction

In the design, a 40-centimeter-long ROV which can operate at 10-meter depth will be designed. A high-power pump will be applied to move the ROV and a 10-meter-long cable will be applied to connect the tail of the ROV and control board to make it to work at around 10-meter depth.


## Design

### Design parameters

As mentioned above, the ROV should be able to operate under 10 meters depth of water. In order to satisfy the requirement, the Schedule 40 PVC pipe is applied for the body of the ROV. The pipe can hold up to 2MPa pressure, which is equivalent to the water pressure under 200 meters depth of water. The cross section of ROV should be big enough to contain the control boards.

To maneuver the ROV under water, valve-controlled nozzles are applied to change its direction and position. For example, if the ROV need to float, the head and tail nozzles at the bottom will spray the water downward to give the ROV a reacting force upward. Additionally, for pitching up the ROV, the tail nozzle at the top and the head nozzle at the bottom will spray the water upward and downward respectively to pitch the ROV up.

## Implementation

![ROV](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/rov.jpg "ROV")

### Head-hub

At the head of the ROV, a camera is connected to the display on the operator-side console to provide a real-time vison of the ROV. A headlight and two navigation LED at the head of the ROV can be controlled by the switches on the console. The headlight with white light will illuminate the front which can help camera have better image.

Once the head of the ROV is built, it will not be opened in the future. Therefore, the head of ROV was sealed by resin and silicon glue. Even though the silicon glue by itself is enough for sealing, resin still need to be applied to resist the water pressure.

### Body

A high-power pump is applied to move the whole ROV. The pump is connected to 10 valves, which are connect to the main controller board, through a water splitter. Only eight valves are used and connected to eight nozzles on the vehicle. Four of them is stuck at the head of the vehicle and the other four nozzles is stuck at the tail of the vehicle. The nozzles must exactly stay on the 90, 180,270,360 degrees, because the accuracy of the movement of the vehicle is depend on the accurate position of nozzles. Since the size and shape of nozzles and the splitter have to be customized, the Solidwork was used to design it to make it can be printed by the 3D printer. After the 3D printing, nozzles were stuck to its designed position by using the Gorilla Glue. Meanwhile, straps were applied to attach all the valves to the body of the ROV, and some hose were applied to connect the valves and nozzles. When the valve is opened, the water pump will deliver pressurized water to the nozzles through those valves. 

### Tail hub

The tail hub comes with control circuit board, communication cable and depth sensor. The control circuit board is located inside the vehicle, the depth sensor and the communication cable are located outside of the vehicle.

For the tail sealing, cap with O-ring is used to prevent water leakage and the ROV could be open easily for modifications. 
 
### Trim

After connecting all the parts, the center of buoyancy and the center of the gravity should be measured. To provide a nature buoyancy for the vehicle, the center of gravity should be a little lower than the center of the buoyancy and both of them should around the center of ROV. By putting the vehicle in to the water, the center of gravity and the center of buoyancy was adjusted by adjusting the location of valves and water pump. Although it is possible to using calculation to find out the proper installation position of valves and pump, it is very hard to find out the correct volume of the vehicle due to the irregular shape of the valves and water pump. The test-retry method is more efficient to get the result. As a result, the ROV not only can immerse in the water, but also stay in a proper depth in the water. Once the power turns on, vehicle can use nozzles to adjust its position. 




## Experiment

### Sealing
A good sealing function is very necessary to isolate the circuit board with water. Firstly, the sealing of the vehicle was tested in the bathtub which has 20-centimeter depth without the circuit board. As the result, the vehicle has no water leaking issue.

### Actuators

To test the dynamic system of the vehicle, a 12 V battery was directly connected to the water pump and valves.
As a result, the water pump and valves worked as expected and the vehicle can move to every direction successful with appropriate speed. 

### Stage 1 test

The stage 1 test is running in the bathtub. After testing all the system individually, all the components of the vehicle were constructed to test in the bathtub. In this test, the ROV works well. It can dive 20-centimeter depth and make some movement. Additionally, when the auto-pilot mode turns on, the vehicle was able to adjust its position automatically according to the input data.

### Stage 2 test

The stage 2 test is running in the water tank at the university lab.

The water tank has 3 meters depth of water. The electric part is still working well. However, the difference between the water tank and the bathtub is that the connect cable is too heavy when they use the long cable. The heavy cable change the center of the gravity of our ROV and let it dive fast before they open our power. Then the design group use some foam to increase the buoyancy of our ROV.

They try several times with different amounts of foam and finally the ROV can stay in the 1 meter depth. However, due to pressure issue and inporper installation of the tail cap, the ROV facing leaking issue. In the stage 2 test, the ROV fails due to mechnical issue.

## Improvement

The hydrodynamic and the dynamic system of the vehicle still need to be improved.

Although the electrical system performed the , they still have some problems in the mechanical system. When the design group tested their design in the bathtub, all the function was working. However, when they test in the water tank, their ROV have leaking issue due to the pressure. As a result, their sealing method is something can be improved, such as using wax to seal the cap.

Additionally, they have a lot of surface mounted valves, which brings up the wiring issue. For improvement, the design group could use a quick-connect jacket to help us disconnect and reconnect the actuators easier when they need to modify the ROV. Furthermore, the design group’s pump is not powerful enough through the test. The pump worked well by itself; however, after they connect the pump with hose and valves, the resistance of the hose reduces the output pressure of our direction control nozzles.
