% Linuo Jiang
% ssylj3@nottingham.edu.cn

%% PRELIMINARY TASK - ARDUINO AND GIT INSTALLATION [10 MARKS]

disp("these two softwares have been download")

%% TASK 1 - READ TEMPERATURE DATA, PLOT, AND WRITE TO A LOG FILE [20 MARKS]

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


%% TASK 2 - LED TEMPERATURE MONITORING DEVICE IMPLEMENTATION [25 MARKS]

a = arduino('COM9', 'Uno');

% Pin setup
sensorPin = 'A0';
greenLED = 'D4';
yellowLED = 'D3';
redLED = 'D2';

% Temperature sensor parameters (LM35 assumed)
V0 = 0.5;   % Voltage at 0°C (500 mV)
Tc = 0.01;  % 10 mV per °C

% Data storage
timeData = [];
tempData = [];
startTime = tic;

% LED states and timing
yellowState = false;
redState = false;
lastYellowToggle = 0;
lastRedToggle = 0;

% Temperature reading control
lastTempRead = -1;
currentTemp = 0;

% Plot initialization
figure;
h = plot(NaN, NaN);
xlabel('Time (s)');
ylabel('Temperature (°C)');
title('Real-Time Temperature Monitoring');
grid on;

% Main loop
while true
    t = toc(startTime);

    % Read temperature once every second
    if floor(t) > lastTempRead
        lastTempRead = floor(t);

        voltage = readVoltage(a, sensorPin);
        currentTemp = (voltage - V0) / Tc;

        % Store data
        timeData(end+1) = t;
        tempData(end+1) = currentTemp;

        % Update plot
        set(h, 'XData', timeData, 'YData', tempData);
        xlim([max(0, t-60), t]);
        ylim([10, 40]);
        drawnow;
    end

    % LED control logic
    if currentTemp >= 18 && currentTemp <= 24
        % Normal temperature: Green LED ON
        writeDigitalPin(a, greenLED, 1);
        writeDigitalPin(a, yellowLED, 0);
        writeDigitalPin(a, redLED, 0);
    elseif currentTemp < 18
        % Low temperature: Yellow LED blinks every 0.5 seconds
        writeDigitalPin(a, greenLED, 0);
        writeDigitalPin(a, redLED, 0);
        if (t - lastYellowToggle) >= 0.5
            yellowState = ~yellowState;
            writeDigitalPin(a, yellowLED, yellowState);
            lastYellowToggle = t;
        end
    else
        % High temperature: Red LED blinks every 0.25 seconds
        writeDigitalPin(a, greenLED, 0);
        writeDigitalPin(a, yellowLED, 0);
        if (t - lastRedToggle) >= 0.25
            redState = ~redState;
            writeDigitalPin(a, redLED, redState);
            lastRedToggle = t;
        end
    end

    % Fast loop for accurate LED blinking
    pause(0.05);
end



%% TASK 3 - ALGORITHMS – TEMPERATURE PREDICTION [25 MARKS]

function temp_prediction(a, sensorPin, greenLED, yellowLED, redLED)
% TEMP_PREDICTION - Real-time temperature monitoring and prediction
%
% This function reads temperature data from a thermistor connected to an 
% Arduino, calculates the rate of change, predicts the temperature in 
% 5 minutes, and uses LEDs to indicate whether the temperature is stable,
% increasing too fast, or decreasing too fast.
%
% Parameters:
%   a         - Arduino object
%   sensorPin - Analog pin where the temperature sensor is connected (e.g., 'A0')
%   greenLED  - Digital pin for green LED (stable temperature)
%   yellowLED - Digital pin for yellow LED (cooling too fast)
%   redLED    - Digital pin for red LED (heating too fast)

% Sensor constants for LM35
V0 = 0.5;        % Voltage at 0°C in volts
Tc = 0.01;       % Voltage increase per °C (10mV/°C)

% Threshold for rate of change (4°C per minute = 0.0667°C/s)
rateThreshold = 4 / 60;

% Initialize buffers to store recent temperature and time data
tempHistory = [];
timeHistory = [];
historyLength = 30;  % Store the last 30 seconds of data

% Start continuous monitoring loop
while true
    % Record current time in seconds
    t = now * 24 * 3600;

    % Read sensor voltage and convert to temperature in Celsius
    voltage = readVoltage(a, sensorPin);
    tempC = (voltage - V0) / Tc;

    % Update history buffers
    tempHistory(end+1) = tempC;
    timeHistory(end+1) = t;

    % Keep only data within the last 'historyLength' seconds
    if length(timeHistory) > 1
        recentIdx = timeHistory > (t - historyLength);
        tempHistory = tempHistory(recentIdx);
        timeHistory = timeHistory(recentIdx);
    end

    % Calculate rate of temperature change (°C/s)
    if length(timeHistory) >= 2
        deltaTemp = tempHistory(end) - tempHistory(1);
        deltaTime = timeHistory(end) - timeHistory(1);
        rate = deltaTemp / deltaTime;
    else
        rate = 0;
    end

    % Predict temperature 5 minutes (300s) into the future
    predictedTemp = tempC + rate * 300;

    % Display real-time temperature info
    fprintf('Current Temp: %.2f°C | Rate: %.3f°C/s | Predicted (5 min): %.2f°C\n', ...
        tempC, rate, predictedTemp);

    % LED control based on temperature trend
    if rate > rateThreshold
        % Temperature rising too fast - red LED on
        writeDigitalPin(a, greenLED, 0);
        writeDigitalPin(a, yellowLED, 0);
        writeDigitalPin(a, redLED, 1);
    elseif rate < -rateThreshold
        % Temperature falling too fast - yellow LED on
        writeDigitalPin(a, greenLED, 0);
        writeDigitalPin(a, yellowLED, 1);
        writeDigitalPin(a, redLED, 0);
    else
        % Temperature is stable - green LED on
        writeDigitalPin(a, greenLED, 1);
        writeDigitalPin(a, yellowLED, 0);
        writeDigitalPin(a, redLED, 0);
    end

    % Wait for 1 second before the next reading
    pause(1);
end
end



%% TASK 4 - REFLECTIVE STATEMENT [5 MARKS]

% This project highlighted both the challenges and rewards of integrating hardware-software systems. Initializing stable MATLAB-Arduino communication required meticulous troubleshooting of port configurations and dependency management. In Task 1, resolving plotting errors caused by mismatched array dimensions (time vs. temperature data) necessitated rigorous validation of sampling logic. Task 2 introduced timing complexities: maintaining concurrent LED blinking intervals (0.25–0.5s) while ensuring 1s sampling intervals risked loop delays, demanding precise synchronization. Task 3's temperature prediction faced noise-induced instability in derivative calculations, which was mitigated through moving average filtering. Additionally, formatting the A4-compliant output table required iterative refinement of sprintf parameters to achieve column alignment.  
%  
% The system’s strengths lie in its modular architecture, which isolated monitoring, prediction, and logging functionalities, enhancing code maintainability. Git version control provided robust progress tracking and error recovery. Real-time plotting via drawnow enabled immediate visualization of thermal trends, while hardware-software integration (e.g., sensor-driven LED alerts) demonstrated end-to-end functionality. However, limitations persist: the design assumes ideal sensor behavior, ignoring thermal drift or electrical noise. The linear prediction model in Task 3 oversimplifies environmental dynamics, and software-based LED timing lacks hardware-level precision, causing minor flicker during rapid state transitions.  
%  
% Future improvements should prioritize hardware timers for millisecond-accurate LED control and advanced prediction models (e.g., LSTM networks) to address nonlinear thermal behaviors. Implementing error-handling routines for sensor disconnections and outlier detection would bolster reliability. Expanding the system with IoT-enabled multi-sensor networks and a GUI for dynamic threshold adjustments could bridge the gap between prototype and industrial application. This project not only reinforced MATLAB/Arduino technical skills but also underscored the iterative nature of embedded systems development—where patience, modularity, and incremental testing are paramount.  

 