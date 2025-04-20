% Task1.m
% Name: Linuo Jiang
% Email: ssylj3@nottingham.edu.cn
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
