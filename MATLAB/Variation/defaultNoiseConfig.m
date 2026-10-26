function cfg = defaultNoiseConfig()
% DEFAULTNOISECONFIG Default settings for runVirtualADAPTMonteCarlo.
%
%   cfg = defaultNoiseConfig() returns a struct describing the three sources
%   of variation applied to the nominal VirtualADAPT model:
%
%     cfg.paramVariation  - per-run dispersion of component parameters and
%                           initial conditions (manufacturing tolerances,
%                           battery state of charge, ambient temperature).
%     cfg.processNoise    - time-varying disturbances inside the model
%                           (ambient drift, inverter regulation ripple, load
%                           fluctuation), modelled as first-order
%                           Gauss-Markov (Ornstein-Uhlenbeck) processes.
%     cfg.sensorNoise     - measurement noise, per-run calibration bias and
%                           gain error, and quantization on the logged sensors.
%
%   All values are starting points, not measured ADAPT statistics. Tune them
%   against nominal runs of the real testbed (e.g. the public DXC ADAPT data)
%   before treating generated datasets as representative.
%
%   Block paths in the rules are regular expressions matched against the
%   block path relative to cfg.root, e.g.
%   'PowerStorage/Battery1Subsystem/Battery1/CircuitEquivalent/C0'.
%   Parameter names are regular expressions matched against the mask
%   parameter name of the bond graph element ('R', 'C', 'I', 'GY', 'Se',
%   'Constant' or 'IC'). The first rule that matches a block/parameter pair
%   is used.

cfg.model = 'VirtualADAPT';
cfg.root = 'VirtualADAPT/VirtualADAPTv1/';

% master seed; run k uses substream k, so any run can be reproduced alone
cfg.seed = 0;

% simulation length in seconds (the model itself is set to run forever)
cfg.stopTime = 600;

% resample logged data onto a uniform grid with this period in seconds;
% [] keeps the variable-step solver time points
cfg.outputSampleTime = 1;

% if not empty, each run is saved to <outputDir>/run_NNNN.mat
cfg.outputDir = '';

% refuse to run if any fault profile in the model is not 'Nominal'
cfg.requireNominal = true;

% also return the noise-free sensor values for each run
cfg.keepClean = true;

%% component parameter and initial condition variation (per run)

cfg.paramVariation.enable = true;
% normal draws are truncated at this many standard deviations
cfg.paramVariation.truncate = 3;
% blocks never varied: sensor models and the battery charge integrator
cfg.paramVariation.exclude = 'Sensor|/Charge/';
% set the initial temperature of every thermal model to the drawn ambient
cfg.paramVariation.tieThermalICsToAmbient = true;
cfg.paramVariation.rules = [
    % batteries: capacity, RC network, self discharge, initial voltage
    paramRule('Battery\d/CircuitEquivalent/C0$',  '^C$',  0.02, 0)
    paramRule('Battery\d/CircuitEquivalent/C0$',  '^IC$', 0,    0.05)
    paramRule('Battery\d/CircuitEquivalent/',     '^(C|R)$', 0.05, 0)
    % thermal capacitance and resistance of batteries and light bulbs
    paramRule('TemperatureModel/',                '^(C|R)$', 0.05, 0)
    % loads: lamp, fan, pump and DC load resistances, motor constants
    paramRule('LoadBank',                         '^(R|C|I|GY)$', 0.02, 0)
    % inverter output voltage and frequency setpoints
    paramRule('Inverter\d/VoutSetpoint$',         '^Se$', 0.005, 0)
    paramRule('Inverter\d/NominalFreq$',          '^Se$', 0.0005, 0)
    % ambient temperature (deg C)
    paramRule('AmbientTemp/AmbientTemp$',         '^Constant$', 0, 1.5)
    ];

%% process noise (time varying, inserted into the model in memory)

cfg.processNoise.enable = true;
% sample time of the noise generators in seconds
cfg.processNoise.sampleTime = 1;
% blocks never given process noise: sensor models
cfg.processNoise.exclude = 'Sensor';
% mode 'rel' multiplies the parameter by (1 + n), 'abs' adds n;
% std is the stationary standard deviation of n, tau its correlation time (s)
cfg.processNoise.rules = [
    processRule('AmbientTemp/AmbientTemp$',               '^Constant$', 'abs', 0.2,   600)
    processRule('Inverter\d/VoutSetpoint$',               '^Se$',       'rel', 0.002, 2)
    processRule('LoadBank.*/(R|Resistance|R1|R2)$',       '^R$',        'rel', 0.005, 5)
    ];

%% sensor noise (applied to the logged outputs)

cfg.sensorNoise.enable = true;
% classes are matched against the sensor name in order; first match wins.
% Put rules for individual sensors (e.g. '^E165$') before the class rules.
%   whiteAbs/whiteRel - std of white noise, absolute and relative to reading
%   biasAbs           - std of a constant offset drawn once per run
%   gainRel           - std of a relative gain error drawn once per run
%   quantization      - resolution of the reading, 0 for none
cfg.sensorNoise.classes = [
    % relay position sensors are discrete
    sensorClass('^ESH', 0,    0,     0,    0,     0)
    % voltages (V)
    sensorClass('^E',   0.05, 0,     0.02, 0.002, 0)
    % currents (A)
    sensorClass('^(IT|ISH)', 0.05, 0, 0.02, 0.005, 0)
    % temperatures (deg C)
    sensorClass('^TE',  0.1,  0,     0.3,  0,     0)
    % speed, flow and light: units vary, so use relative noise
    sensorClass('^(ST|FT|LT)', 0, 0.005, 0, 0.01, 0)
    ];

end

function r = paramRule(path, param, relStd, absStd)
r = struct('path', path, 'param', param, 'relStd', relStd, 'absStd', absStd);
end

function r = processRule(path, param, mode, std, tau)
r = struct('path', path, 'param', param, 'mode', mode, 'std', std, 'tau', tau);
end

function c = sensorClass(pattern, whiteAbs, whiteRel, biasAbs, gainRel, quantization)
c = struct('pattern', pattern, 'whiteAbs', whiteAbs, 'whiteRel', whiteRel, ...
    'biasAbs', biasAbs, 'gainRel', gainRel, 'quantization', quantization);
end
