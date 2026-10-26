function applied = applyParameterVariation(params, ruleIdx, pv, stream)
% APPLYPARAMETERVARIATION Draw and set one realization of the component
% parameters and initial conditions.
%
%   applied = applyParameterVariation(params, ruleIdx, pv, stream) draws a
%   value for every params(i) with ruleIdx(i) > 0 from the rule
%   pv.rules(ruleIdx(i)), using random stream stream, and writes it to the
%   block with set_param. Draws are normal, truncated at pv.truncate
%   standard deviations:
%       value = nominal * (1 + relStd * z1) + absStd * z2
%   If pv.tieThermalICsToAmbient is set, the initial condition of every
%   TemperatureModel/Ctheta is set to the drawn ambient temperature.
%
%   applied is a struct array (relPath, param, nominal, value) recording
%   what was set. Parameters without a matching rule are left as they are.

applied = struct('relPath', {}, 'param', {}, 'nominal', {}, 'value', {});
values = [params.nominal];
changed = false(size(params));

for i = find(ruleIdx > 0)
    rule = pv.rules(ruleIdx(i));
    values(i) = params(i).nominal * (1 + rule.relStd * truncatedRandn(stream, pv.truncate)) + ...
        rule.absStd * truncatedRandn(stream, pv.truncate);
    changed(i) = true;
end

if pv.tieThermalICsToAmbient
    amb = find(~cellfun(@isempty, regexp({params.relPath}, 'AmbientTemp/AmbientTemp$', 'once')) & ...
        strcmp({params.param}, 'Constant'), 1);
    if ~isempty(amb)
        thermal = ~cellfun(@isempty, regexp({params.relPath}, 'TemperatureModel/Ctheta$', 'once')) & ...
            strcmp({params.param}, 'IC');
        values(thermal) = values(amb);
        changed(thermal) = true;
    end
end

for i = find(changed)
    set_param(params(i).block, params(i).param, sprintf('%.17g', values(i)));
    applied(end+1) = struct('relPath', params(i).relPath, 'param', params(i).param, ...
        'nominal', params(i).nominal, 'value', values(i)); %#ok<AGROW>
end

end

function z = truncatedRandn(stream, limit)
z = randn(stream);
while abs(z) > limit
    z = randn(stream);
end
end
