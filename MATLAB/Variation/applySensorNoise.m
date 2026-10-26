function [noisy, calibration] = applySensorNoise(clean, names, sn, stream)
% APPLYSENSORNOISE Corrupt noise-free sensor readings with measurement error.
%
%   [noisy, calibration] = applySensorNoise(clean, names, sn, stream) applies,
%   column by column, the first class in sn.classes whose pattern matches
%   names{j}:
%
%     y = (1 + g) * x + b + whiteAbs * w1 + whiteRel * |x| * w2
%
%   where g ~ N(0, gainRel^2) and b ~ N(0, biasAbs^2) are drawn once per
%   call (one sensor calibration per run) and w1, w2 are white N(0, 1)
%   sequences. y is then rounded to a multiple of quantization if it is
%   non-zero. Sensors that match no class are passed through unchanged.
%
%   calibration is a struct array (name, bias, gain) of the per-run errors.
%
%   The sensors only feed the model's outports, never its dynamics, so
%   adding this error to the logged data is equivalent to adding it inside
%   the model, and lets the same simulated run be re-noised cheaply.

noisy = clean;
calibration = struct('name', names, 'bias', 0, 'gain', 0);
n = size(clean, 1);

for j = 1:length(names)
    c = find(~cellfun(@isempty, regexp(names{j}, {sn.classes.pattern}, 'once')), 1);
    if isempty(c)
        continue;
    end
    cls = sn.classes(c);
    x = clean(:, j);

    calibration(j).gain = cls.gainRel * randn(stream);
    calibration(j).bias = cls.biasAbs * randn(stream);
    y = (1 + calibration(j).gain) * x + calibration(j).bias + ...
        cls.whiteAbs * randn(stream, n, 1) + cls.whiteRel * abs(x) .* randn(stream, n, 1);
    if cls.quantization > 0
        y = cls.quantization * round(y / cls.quantization);
    end
    noisy(:, j) = y;
end
