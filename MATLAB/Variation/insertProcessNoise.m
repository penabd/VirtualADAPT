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
%   where n(t) is the noise process of rule pn.rules(ruleIdx(i)) (see
%   processNoiseModel), built from a Random Number block and a Discrete
%   State-Space block at sample time pn.sampleTime. Calling this again on the
%   same parameter inserts another source between the Constant and the
%   previous one, so sources stack: P * (1 + n1) * (1 + n2), P + n1 + n2.
%
%   generators is a struct array with fields
%     relPath, param - the parameter the source acts on
%     rule           - the rule used
%     noise          - handle of the Random Number block; set its 'Seed'
%     state          - handle of the Discrete State-Space block; set its 'X0'
%     x0Factor       - lower Cholesky factor of the stationary state
%                      covariance; X0 = x0Factor * randn(n, 1)
%   The model must not be saved afterwards; close it with close_system(model, 0).

Ts = pn.sampleTime;
generators = struct('relPath', {}, 'param', {}, 'rule', {}, 'noise', {}, 'state', {}, 'x0Factor', {});

for i = find(ruleIdx > 0)
    rule = pn.rules(ruleIdx(i));
    [A, B, C, D, P] = processNoiseModel(rule, Ts);

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

    gen = add_block('simulink/Sources/Random Number', [sys '/ProcessNoise'], ...
        'MakeNameUnique', 'on', 'Mean', '0', 'Variance', '1', 'Seed', '0', ...
        'SampleTime', sprintf('%.17g', Ts), 'Position', at(0, 40));
    ss = add_block('simulink/Discrete/Discrete State-Space', [sys '/ProcessNoiseShape'], ...
        'MakeNameUnique', 'on', ...
        'A', mat2str(A, 17), 'B', mat2str(B, 17), 'C', mat2str(C, 17), 'D', mat2str(D, 17), ...
        'X0', mat2str(zeros(size(B)), 17), ...
        'SampleTime', sprintf('%.17g', Ts), 'Position', at(60, 40));
    genPorts = get_param(gen, 'PortHandles');
    ssPorts = get_param(ss, 'PortHandles');
    add_line(sys, genPorts.Outport, ssPorts.Inport);

    switch rule.mode
        case 'rel'
            bias = add_block('simulink/Math Operations/Bias', [sys '/ProcessNoiseBias'], ...
                'MakeNameUnique', 'on', 'Bias', '1', 'Position', at(120, 40));
            comb = add_block('simulink/Math Operations/Product', [sys '/ProcessNoiseApply'], ...
                'MakeNameUnique', 'on', 'Inputs', '2', 'Position', at(180, 0));
            biasPorts = get_param(bias, 'PortHandles');
            add_line(sys, ssPorts.Outport, biasPorts.Inport);
            noiseOut = biasPorts.Outport;
        case 'abs'
            comb = add_block('simulink/Math Operations/Sum', [sys '/ProcessNoiseApply'], ...
                'MakeNameUnique', 'on', 'Inputs', '++', 'Position', at(180, 0));
            noiseOut = ssPorts.Outport;
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
        'rule', rule, 'noise', gen, 'state', ss, 'x0Factor', chol(P, 'lower')); %#ok<AGROW>
end
