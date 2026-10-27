# Motivation

The Advanced Diagnostic and Prognostic Testbed (ADAPT), developed at NASA Ames Research Center, is functionally representative of an electrical power system (EPS) on an exploration vehicle, and has been developed to:
* Serve as a technology-neutral basis for testing and evaluating software and hardware diagnostic systems,
* Allow accelerated testing of diagnostic algorithms by manually or algorithmically inserting faults,
* Provide a real-world physical system such that issues that might be disregarded in smaller-scale experiments and simulations are exposed,
* Act as a stepping stone between pure research and deployment in aerospace systems, thus creating a concrete path to maturing diagnostic technologies, and
* Develop analytical methods and software architectures in support of the above goals.

The ADAPT hardware includes components that can generate, store, distribute, and monitor electrical power. The EPS can deliver AC (Alternating Current) and DC (Direct Current) power to loads. A data acquisition and control system sends commands to and receives data from the EPS. The testbed operator stations are integrated into a software architecture that allows for nominal and faulty operations of the EPS, and includes a system for logging all relevant data to assess the performance of the health management applications.

# The ADAPT Hardware

The major system components of ADAPT include power generation, storage, and distribution components. Two power generation sources are connected to three sets of batteries, which in turn supply two load banks. Each load bank has provision for 6 AC loads and 2 DC loads. To be more specific, ADAPT consists of the following three classes of components – power generation, power storage, and power distribution.
* **Power Generation:** The two sources of power generation include two battery chargers. The battery chargers are connected to appropriate wall outlets through relays. The two power generation sources can be interchangeably connected to the three batteries. Hardware relay logic prevents connecting one charge source to more than one battery at the same time, and from connecting one charging circuit to another charging circuit.
* **Power Storage:** Three sets of batteries are used to store energy for operation of the loads. Each “battery” consists of two 12-volt sealed lead acid batteries connected in series to produce a 24-volt output. Two battery sets are rated at 100 Amp-hrs and the third set is rated at 50 Amp-hrs. The batteries and the main circuit breakers are placed in a ventilated cabinet that is physically separated from the equipment racks; however, the switches for connecting the batteries to the upstream chargers or downstream loads are located in the equipment racks.
* **Power Distribution:** Electromechanical relays are used to route the power from the sources to the batteries; and from the batteries to the AC and DC loads. All relays are of the normally-open type. An inverter converts the 24-volt DC battery input to a 120-volt r.m.s. AC output. Circuit breakers are located at various points in the distribution network to prevent overcurrents from causing unintended damage to the system components.


# Virtual ADAPT

VirtualADAPT is a high-fidelity, Matlab® Simulink®-based simulation testbed that emulates the ADAPT hardware for running offline health management experiments. This simulation testbed models all components of the ADAPT hardware within the power storage and power distribution subsystems. The physical components of the testbed, i.e., the batteries, relays, and the loads, are replaced by simulation modules that generate the same dynamic behaviors as the hardware test bed. 



## Installation

For the model to execute, the fault interface GUI functions must be on the Matlab path. To do this, run the script 
[installVirtualADAPT.m](https://github.com/nasa/VirtualADAPT/blob/master/MATLAB/installVirtualADAPT.m).

The script [uninstallVirtualADAPT.m](https://github.com/nasa/VirtualADAPT/blob/master/MATLAB/uninstallVirtualADAPT.m) will remove the directories from the Matlab path.


## Quick Start Guide

To generate data, load [VirtualADAPT.mdl](https://github.com/nasa/VirtualADAPT/blob/master/MATLAB/VirtualADAPT.mdl) in Simulink and hit the start button. The simulation is configured to run indefinitely and write data to the MATLAB workspace as a matrix of floating-point values. The 'Sensors' section of the file [Sensors And Actuators.txt](https://github.com/nasa/VirtualADAPT/blob/master/MATLAB/Sensors%20and%20Actuators.txt) contains the sensor names which correspond to the columns of this matrix.

To command a relay or circuit breaker, find the simulation input port for the desired actuator (eg. 'EY144_CL') and 
double-click the switch connected to it. Because the simulation is 'solved' as quickly as possible rather than running 
in real-time, it is easier to configure relays before starting the simulation.

To inject ADAPT faults, use the fault injection GUI which is opened (and closed) automatically when the Simulink model 
is opened (and closed). Fault modes are specific to components but are of the following general modes when referring to
parameter values:

* Nominal - Magnitude (M) unused. Nominal value (N) unaltered.
* Incipient - N + M\*T, where T is the number of seconds since injection.
* Abrupt - (N + 1)\*M
* Bias - N + M
* StuckAt - M

Faults are added/removed to/from the Simulink model when added/removed using the GUI.

A second method for injecting faults is to open the model in simulink, navigate to the desired block, and change the values 
manually. Alternately, the MATLAB functions get_param and set_param can be used to set these values from a script or the 
command line.


## Generating Nominal Datasets with Variation

The functions in [MATLAB/Variation](MATLAB/Variation) run the nominal model many times. Each run varies the physical system the way a real testbed varies, so the output can serve as a dataset. Three sources of variation are applied:

* **Component and initial-condition dispersion (per run):** battery capacity, RC network and initial voltage; thermal properties of batteries and lamps; load, fan and pump parameters; inverter setpoints; and ambient temperature. Each is drawn from a truncated normal distribution around its nominal value and written to the block's mask parameter before the run.
* **Process noise (within a run):** disturbances on ambient temperature, inverter output voltage and load resistances. Each source is either a first-order Gauss-Markov process (a slow wander with no preferred frequency) or a second-order one (quasi-periodic cycles at a chosen period, used by default for HVAC cycling of the ambient temperature). Several sources can act on the same parameter. Each run starts from a random state drawn from the noise's steady-state distribution, so the noise has its full size from the first sample. Noise generator blocks are inserted into the bond graph elements in memory, so the saved model is never changed.
* **Sensor noise:** white noise, a per-run calibration bias and gain error, and optional quantization, applied to the 73 logged sensors. Relay position sensors (ESH) are left noise-free. Because the sensors only feed the model's outputs, this is equivalent to adding the noise inside the model.

```matlab
cfg = defaultNoiseConfig();      % edit fields to change magnitudes or disable a source
cfg.stopTime = 1200;             % seconds
cfg.outputDir = 'nominal_runs';  % optional: save each run to run_NNNN.mat
results = runVirtualADAPTMonteCarlo(20, cfg);

e240 = strcmp(results(1).sensorNames, 'E240');
plot(results(1).time, results(1).data(:, e240), results(1).time, results(1).clean(:, e240))
```

Each run stores the noisy data, the noise-free data, the parameter values drawn, the process noise seeds and the sensor calibration errors. Runs are reproducible from `cfg.seed` and the run index. Relays are simulated in the positions set on the model's manual switches. The default magnitudes in `defaultNoiseConfig.m` are placeholders: calibrate them against nominal data from the real testbed before relying on the datasets.

## Extended Documentation

The document [VirtualADAPT.pdf](https://github.com/nasa/VirtualADAPT/blob/master/docs/VirtualADAPT.pdf) describes the Virtual ADAPT simulation model in more detail. Please refer to this document for instructions on running the simulation.

## License

This software is released under the [NASA Open Source Agreement Version 1.3](https://github.com/nasa/VirtualADAPT/blob/master/License.pdf).

## Notices

Copyright © 2017 United States Government as represented by the Administrator of the National Aeronautics and Space Administration.  All Rights Reserved.

### Disclaimers

No Warranty: THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF PRESENT IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS."

Waiver and Indemnity:  RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS AGAINST THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT SOFTWARE RESULTS IN ANY LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR LOSSES ARISING FROM SUCH USE, INCLUDING ANY DAMAGES FROM PRODUCTS BASED ON, OR RESULTING FROM, RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT SHALL INDEMNIFY AND HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE EXTENT PERMITTED BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER SHALL BE THE IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.
