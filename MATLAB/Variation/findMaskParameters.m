function params = findMaskParameters(root)
% FINDMASKPARAMETERS List the numeric mask parameters of the bond graph
% elements below root.
%
%   params = findMaskParameters('VirtualADAPT/VirtualADAPTv1/') returns a
%   struct array with one entry per block/parameter pair:
%     block      - full block path
%     relPath    - block path relative to root
%     param      - mask parameter name ('R', 'C', 'IC', 'Se', ...)
%     nominalStr - value string as saved in the model
%     nominal    - numeric value (NaN if the string is not a number)
%   The fault parameters FP, FT and FM are not included.

blocks = find_system(root, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Mask', 'on');

params = struct('block', {}, 'relPath', {}, 'param', {}, 'nominalStr', {}, 'nominal', {});
for i = 1:length(blocks)
    names = get_param(blocks{i}, 'MaskNames');
    values = get_param(blocks{i}, 'MaskValues');
    for j = 1:length(names)
        if any(strcmp(names{j}, {'FP' 'FT' 'FM'}))
            continue;
        end
        p.block = blocks{i};
        p.relPath = strrep(blocks{i}, root, '');
        p.param = names{j};
        p.nominalStr = values{j};
        p.nominal = str2double(values{j});
        params(end+1) = p; %#ok<AGROW>
    end
end
