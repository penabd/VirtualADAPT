function results = runVirtualADAPTMonteCarlo(nRuns, cfg)
% RUNVIRTUALADAPTMONTECARLO Simulate the nominal VirtualADAPT model many
% times with physical variation and sensor noise.
%
%   results = runVirtualADAPTMonteCarlo(nRuns) runs the model nRuns times
%   with the settings of defaultNoiseConfig.
%
%   results = runVirtualADAPTMonteCarlo(nRuns, cfg) uses cfg, normally
%   obtained from defaultNoiseConfig and then edited.
%
%   Each run k:
%     1. draws component parameters and initial conditions
%        (cfg.paramVariation),
%     2. draws seeds and stationary initial states for the process noise
%        sources (cfg.processNoise),
%     3. simulates for cfg.stopTime seconds,
%     4. resamples the 73 sensors to cfg.outputSampleTime,
%     5. adds measurement error (cfg.sensorNoise).
%   All draws for run k come from substream k of an mrg32k3a stream seeded
%   with cfg.seed, so a single run can be reproduced on its own.
%
%   results(k) has fields
%     time              - N x 1 sample times (s)
%     data              - N x 73 noisy sensor readings
%     clean             - N x 73 readings before sensor noise (if cfg.keepClean)
%     sensorNames       - 1 x 73 column names
%     parameters        - parameter values used (relPath, param, nominal, value)
%     processNoise      - process noise sources (relPath, param, seed, x0)
%     calibration       - per-sensor bias and gain errors
%     seed, substream   - random stream used for the run
%
%   Relay and circuit breaker positions are whatever is set on the manual
%   switches of the saved model. The model is modified in memory only and
%   closed without saving when the function returns; it must not have
%   unsaved changes when the function is called.
%
%   Example
%     cfg = defaultNoiseConfig();
%     cfg.stopTime = 1200;
%     cfg.outputDir = 'nominal_runs';
%     results = runVirtualADAPTMonteCarlo(20, cfg);
%     plot(results(1).time, results(1).data(:, strcmp(results(1).sensorNames, 'E240')))

if nargin < 2 || isempty(cfg)
    cfg = defaultNoiseConfig();
end

model = cfg.model;
wasLoaded = bdIsLoaded(model);
if wasLoaded && strcmp(get_param(model, 'Dirty'), 'on')
    error('runVirtualADAPTMonteCarlo:dirtyModel', ...
        ['%s has unsaved changes. Save or close it first: this function modifies ' ...
        'the model in memory and closes it without saving.'], model);
end
load_system(model);
cleanup = onCleanup(@() closeModel(model, wasLoaded)); %#ok<NASGU>

if cfg.requireNominal
    checkNominal(cfg.root);
end

% log time together with the data
set_param([model '/To Workspace'], 'SaveFormat', 'StructureWithTime');

names = getSensorNames();
params = findMaskParameters(cfg.root);

if cfg.paramVariation.enable
    pvIdx = matchRules(params, cfg.paramVariation.rules, cfg.paramVariation.exclude);
else
    pvIdx = zeros(size(params));
end

generators = struct('relPath', {}, 'param', {}, 'rule', {}, 'noise', {}, 'state', {}, 'x0Factor', {});
if cfg.processNoise.enable
    % every matching rule applies, so insert one rule at a time
    for r = 1:length(cfg.processNoise.rules)
        pn = cfg.processNoise;
        pn.rules = pn.rules(r);
        pnIdx = matchRules(params, pn.rules, pn.exclude);
        generators = [generators insertProcessNoise(params, pnIdx, pn)]; %#ok<AGROW>
    end
end

fprintf('Varying %d parameters, %d process noise generators, %d sensors.\n', ...
    nnz(pvIdx), length(generators), length(names));

if ~isempty(cfg.outputDir) && ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

results = struct([]);
for k = 1:nRuns
    stream = RandStream('mrg32k3a', 'Seed', cfg.seed);
    stream.Substream = k;

    applied = applyParameterVariation(params, pvIdx, cfg.paramVariation, stream);

    processNoise = struct('relPath', {generators.relPath}, 'param', {generators.param}, ...
        'seed', 0, 'x0', []);
    for g = 1:length(generators)
        processNoise(g).seed = randi(stream, 2^31 - 2);
        processNoise(g).x0 = generators(g).x0Factor * randn(stream, size(generators(g).x0Factor, 1), 1);
        set_param(generators(g).noise, 'Seed', sprintf('%d', processNoise(g).seed));
        set_param(generators(g).state, 'X0', mat2str(processNoise(g).x0, 17));
    end

    fprintf('Run %d of %d...\n', k, nRuns);
    simOut = sim(model, 'StopTime', sprintf('%.17g', cfg.stopTime), 'ReturnWorkspaceOutputs', 'on');

    logged = simOut.get('simout');
    t = logged.time(:);
    x = logged.signals.values;
    if size(x, 2) ~= length(names)
        error('runVirtualADAPTMonteCarlo:sensorCount', ...
            'Logged %d signals but ''Sensors and Actuators.txt'' lists %d sensors.', ...
            size(x, 2), length(names));
    end

    if ~isempty(cfg.outputSampleTime)
        [t, x] = resampleUniform(t, x, cfg.outputSampleTime, strncmp(names, 'ESH', 3));
    end

    run = struct();
    run.time = t;
    if cfg.sensorNoise.enable
        [run.data, run.calibration] = applySensorNoise(x, names, cfg.sensorNoise, stream);
    else
        run.data = x;
        run.calibration = struct('name', names, 'bias', 0, 'gain', 0);
    end
    if cfg.keepClean
        run.clean = x;
    end
    run.sensorNames = names;
    run.parameters = applied;
    run.processNoise = processNoise;
    run.seed = cfg.seed;
    run.substream = k;

    if ~isempty(cfg.outputDir)
        save(fullfile(cfg.outputDir, sprintf('run_%04d.mat', k)), '-struct', 'run');
    end
    if isempty(results)
        results = run;
    else
        results(k) = run;
    end
end

end

function [tq, xq] = resampleUniform(t, x, dt, discrete)
% linear interpolation for analog signals, sample and hold for discrete ones
[t, last] = unique(t, 'last');
x = x(last, :);
tq = (0:dt:t(end))';
xq = zeros(length(tq), size(x, 2));
xq(:, ~discrete) = interp1(t, x(:, ~discrete), tq, 'linear');
xq(:, discrete) = interp1(t, x(:, discrete), tq, 'previous');
end

function checkNominal(root)
blocks = find_system(root, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Mask', 'on');
for i = 1:length(blocks)
    names = get_param(blocks{i}, 'MaskNames');
    fp = find(strcmp(names, 'FP'), 1);
    if ~isempty(fp)
        values = get_param(blocks{i}, 'MaskValues');
        if ~strcmp(values{fp}, 'Nominal')
            error('runVirtualADAPTMonteCarlo:faultActive', ...
                ['%s has fault profile ''%s''. Remove injected faults or set ' ...
                'cfg.requireNominal = false.'], blocks{i}, values{fp});
        end
    end
end
end

function closeModel(model, reopen)
close_system(model, 0);
if reopen
    open_system(model);
end
end
