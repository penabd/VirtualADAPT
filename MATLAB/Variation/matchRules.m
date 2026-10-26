function ruleIdx = matchRules(params, rules, exclude)
% MATCHRULES Index of the first rule matching each parameter.
%
%   ruleIdx(i) is the index into rules of the first rule whose path and
%   param regular expressions match params(i).relPath and params(i).param,
%   or 0 if none match, the path matches exclude, or the nominal value is
%   not numeric.

if nargin < 3
    exclude = '';
end

ruleIdx = zeros(size(params));
for i = 1:length(params)
    if isnan(params(i).nominal)
        continue;
    end
    if ~isempty(exclude) && ~isempty(regexp(params(i).relPath, exclude, 'once'))
        continue;
    end
    for r = 1:length(rules)
        if ~isempty(regexp(params(i).relPath, rules(r).path, 'once')) && ...
                ~isempty(regexp(params(i).param, rules(r).param, 'once'))
            ruleIdx(i) = r;
            break;
        end
    end
end
