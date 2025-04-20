clear
% Task1.m
% Name: Linuo Jiang
% Email: ssylj3@nottingham.edu.cn

% Initialize Arduino
a = arduino('COM9', 'Uno');

% Configuration parameters
duration = 600;           % 10 minutes in seconds
samplingInterval = 1;     % Sampling interval: 1 second
numSamples = duration / samplingInterval;

% Initialize time vector and data arrays
time = (0:numSamples-1) * samplingInterval; % Time array
voltageValues = zeros(1, numSamples);
temperatureValues = zeros(1, numSamples);

% Temperature sensor parameters (MCP9700A)
V0 = 0.5;     % Voltage at 0°C (V)
Tc = 0.01;    % Temperature coefficient (V/°C)

% Data acquisition
for i = 1:numSamples
    voltage = readVoltage(a, 'A0'); % Assuming the temperature sensor is connected to A0
    temperature = (voltage - V0) / Tc;
    voltageValues(i) = voltage;
    temperatureValues(i) = temperature;
    pause(samplingInterval); % Ensure proper time interval
end

% Calculate statistics
minTemp = min(temperatureValues);
maxTemp = max(temperatureValues);
avgTemp = mean(temperatureValues);

% Plot temperature curve
figure;
plot(time, temperatureValues);
xlabel('Time (seconds)');
ylabel('Temperature (°C)');
title('Cabin Temperature Variation');
grid on;

% ==== Generate formatted table string (A4 half-width, 42 chars) ====
tableWidth = 42; % Fixed total width: 42 characters
tableStr = '';

% Header (merge date and location)
headerLine = sprintf('%-42s', ['Data logging initiated - ', datestr(now, 'mm/dd/yyyy'), ' Location - Nottingham']);
tableStr = [tableStr, headerLine, newline, newline]; % Blank line after header

% Log data every 60 seconds (1 minute interval)
for i = 1:60:numSamples
    minute = floor((i-1)/60); % Minute starts from 0
    temp = temperatureValues(i);
    
    % Minute line: left-align label, right-align value
    minuteLine = sprintf('%-20s%23.2f ', 'Minute', minute);
    tableStr = [tableStr, minuteLine, newline];
    
    % Temperature line: left-align label, right-align value
    tempLine = sprintf('%-20s%18.2f C', 'Temperature', temp);
    tableStr = [tableStr, tempLine, newline, newline]; % Blank line after each group
end

% Statistics lines (aligned output)
statMax = sprintf('%-20s%20.2f C', 'Max temp', maxTemp);
statMin = sprintf('%-20s%20.2f C', 'Min temp', minTemp);
statAvg = sprintf('%-20s%17.2f C', 'Average temp', avgTemp);

% Termination line
endLine = sprintf('%-42s', 'Data logging terminated');

% Append statistics and termination line
tableStr = [tableStr, statMax, newline, statMin, newline, statAvg, newline, newline, endLine];

% Output to console
disp(tableStr);

% Write to log file
fileID = fopen('cabin_temperature.txt', 'w');
fprintf(fileID, '%s', tableStr);
fclose(fileID);
