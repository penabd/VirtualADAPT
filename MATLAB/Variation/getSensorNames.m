function names = getSensorNames()
% GETSENSORNAMES Sensor names in the column order of the logged simout data,
% read from 'Sensors and Actuators.txt'.

fname = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'Sensors and Actuators.txt');
txt = fileread(fname);
section = regexp(txt, 'Sensors \(\d+\):(.*?)Actuators', 'tokens', 'once');
tokens = regexp(section{1}, '"(\w+)"', 'tokens');
names = [tokens{:}];
