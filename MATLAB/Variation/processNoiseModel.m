function [A, B, C, D, P] = processNoiseModel(rule, Ts)
% PROCESSNOISEMODEL Discrete state-space form of a process noise source.
%
%   [A, B, C, D, P] = processNoiseModel(rule, Ts) returns the matrices of
%
%     x[k+1] = A x[k] + B w[k],   n[k] = C x[k] + D w[k],   w[k] ~ N(0, 1)
%
%   whose output n is stationary with standard deviation rule.std, and the
%   stationary covariance P of the state x. Drawing the initial state from
%   N(0, P) makes n stationary from the first sample.
%
%   rule.period == 0: first-order Gauss-Markov (Ornstein-Uhlenbeck) noise,
%   correlation time rule.tau, flat spectrum below 1/(2*pi*tau):
%
%     n[k] = a n[k-1] + std sqrt(1 - a^2) w[k],   a = exp(-Ts/tau)
%
%   rule.period > 0: second-order Gauss-Markov (randomly driven damped
%   oscillator) noise, with a spectral peak at rule.period seconds. tau is
%   the decay time of the oscillation envelope: tau of several periods gives
%   regular cycles, tau below one period gives an irregular wander.
%
%     n[k] = phi1 n[k-1] + phi2 n[k-2] + b w[k]
%     phi1 = 2 r cos(2 pi Ts/period),  phi2 = -r^2,  r = exp(-Ts/tau)
%     b^2  = std^2 (1 + phi2) ((1 - phi2)^2 - phi1^2) / (1 - phi2)
%
%   The state is x[k] = [n[k-1]; n[k-2]].

if rule.tau <= 0
    error('processNoiseModel:tau', 'tau must be positive.');
end
r = exp(-Ts / rule.tau);

if rule.period == 0
    A = r;
    B = rule.std * sqrt(1 - r^2);
    C = r;
    D = B;
    P = rule.std^2;
else
    if rule.period <= 2 * Ts
        error('processNoiseModel:period', ...
            'period (%g s) must be longer than twice the sample time (%g s).', rule.period, Ts);
    end
    phi1 = 2 * r * cos(2 * pi * Ts / rule.period);
    phi2 = -r^2;
    b = rule.std * sqrt((1 + phi2) * ((1 - phi2)^2 - phi1^2) / (1 - phi2));
    A = [phi1 phi2; 1 0];
    B = [b; 0];
    C = [phi1 phi2];
    D = b;
    rho = phi1 / (1 - phi2);
    P = rule.std^2 * [1 rho; rho 1];
end
