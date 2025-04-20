clear;
% Task1.m
% Name: Linuo Jiang
% Email: ssylj3@nottingham.edu.cn
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
