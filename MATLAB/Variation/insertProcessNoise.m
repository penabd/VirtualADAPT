function generators = insertProcessNoise(params, ruleIdx, pn)
% INSERTPROCESSNOISE Add time-varying noise to bond graph element parameters.
%
%   generators = insertProcessNoise(params, ruleIdx, pn) modifies the loaded
%   model in memory. Each bond graph element feeds its parameter into the
%   simulation through a Constant block whose value is the mask parameter
%   name (e.g. Value 'R'). For every params(i) with ruleIdx(i) > 0 the output
%   of that Constant is rerouted through
%
%     'rel' mode:  P * (1 + n(t))
%     'abs' mode:  P + n(t)
%
%   where n(t) is a first-order Gauss-Markov process with stationary
%   standard deviation std and correlation time tau, built from a Random
%   Number block and a Discrete Filter at sample time pn.sampleTime:
%
%     n[k] = a * n[k-1] + std * sqrt(1 - a^2) * w[k],   a = exp(-Ts/tau)
%
%   generators is a struct array (relPath, param, block) where block is the
%   handle of the Random Number block; set its 'Seed' before each run.
%   The model must not be saved afterwards; close it with close_system(model, 0).

Ts = pn.sampleTime;
generators = struct('relPath', {}, 'param', {}, 'block', {});

for i = find(ruleIdx > 0)
    rule = pn.rules(ruleIdx(i));
    sys = params(i).block;
    const = find_system(sys, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'BlockType', 'Constant', 'Value', params(i).param);
    if length(const) ~= 1
        error('insertProcessNoise:noConstant', ...
            'Expected one Constant block with value ''%s'' in %s, found %d.', ...
            params(i).param, sys, length(const));
    end

    constPorts = get_param(const{1}, 'PortHandles');
    ln = get_param(constPorts.Outport, 'Line');
    dst = get_param(ln, 'DstPortHandle');
    dst = dst(dst > 0);
    delete_line(ln);

    % place the new blocks below the constant
    pos = get_param(const{1}, 'Position');
    at = @(dx, dy) [pos(1)+dx, pos(4)+dy, pos(1)+dx+30, pos(4)+dy+30];

    a = exp(-Ts / rule.tau);
    gen = add_block('simulink/Sources/Random Number', [sys '/ProcessNoise'], ...
        'MakeNameUnique', 'on', 'Mean', '0', 'Variance', '1', 'Seed', '0', ...
        'SampleTime', sprintf('%.17g', Ts), 'Position', at(0, 40));
    filt = add_block('simulink/Discrete/Discrete Filter', [sys '/ProcessNoiseFilter'], ...
        'MakeNameUnique', 'on', ...
        'Numerator', sprintf('[%.17g]', rule.std * sqrt(1 - a^2)), ...
        'Denominator', sprintf('[1 %.17g]', -a), ...
        'SampleTime', sprintf('%.17g', Ts), 'Position', at(60, 40));
    genPorts = get_param(gen, 'PortHandles');
    filtPorts = get_param(filt, 'PortHandles');
    add_line(sys, genPorts.Outport, filtPorts.Inport);

    switch rule.mode
        case 'rel'
            bias = add_block('simulink/Math Operations/Bias', [sys '/ProcessNoiseBias'], ...
                'MakeNameUnique', 'on', 'Bias', '1', 'Position', at(120, 40));
            comb = add_block('simulink/Math Operations/Product', [sys '/ProcessNoiseApply'], ...
                'MakeNameUnique', 'on', 'Inputs', '2', 'Position', at(180, 0));
            biasPorts = get_param(bias, 'PortHandles');
            add_line(sys, filtPorts.Outport, biasPorts.Inport);
            noiseOut = biasPorts.Outport;
        case 'abs'
            comb = add_block('simulink/Math Operations/Sum', [sys '/ProcessNoiseApply'], ...
                'MakeNameUnique', 'on', 'Inputs', '++', 'Position', at(180, 0));
            noiseOut = filtPorts.Outport;
        otherwise
            error('insertProcessNoise:mode', 'Unknown process noise mode ''%s''.', rule.mode);
    end

    combPorts = get_param(comb, 'PortHandles');
    add_line(sys, constPorts.Outport, combPorts.Inport(1));
    add_line(sys, noiseOut, combPorts.Inport(2));
    for d = 1:length(dst)
        add_line(sys, combPorts.Outport, dst(d));
    end

    generators(end+1) = struct('relPath', params(i).relPath, 'param', params(i).param, ...
        'block', gen); %#ok<AGROW>
end
