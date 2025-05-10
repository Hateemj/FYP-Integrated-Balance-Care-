% === Combined Analysis and Visualization (Participants 1–3 Only) ===

% Participant file list and distances (Task Performance in cm)
participants = {
    'PARTICIPANT 1 STUMBLE 150cm D4-22-CD-00-A7-18_2025-04-08_20-07-40.csv', 150;
    'PARTICIPANT 2 STUMBLE 300cm D4-22-CD-00-A7-18_2025-04-08_20-11-06.csv', 300;
    'PARTICIPANT 3 STUMBLE 450cm D4-22-CD-00-A7-18_2025-04-08_20-20-09.csv', 450
};

scores = [];

for i = 1:size(participants, 1)
    filename = participants{i,1};
    TP = participants{i,2};

    % Read table, skip metadata
    opts = detectImportOptions(filename);
    opts.DataLines = 2;
    opts.VariableNamesLine = 2;
    T = readtable(filename, opts);

    % Identify FreeAcc_X and FreeAcc_Z columns
    colNames = T.Properties.VariableNames;
    mlCol = find(contains(colNames, 'FreeAcc_X', 'IgnoreCase', true), 1);
    apCol = find(contains(colNames, 'FreeAcc_Z', 'IgnoreCase', true), 1);

    if isempty(mlCol) || isempty(apCol)
        warning("Could not find expected acceleration columns in %s", filename);
        continue;
    end

    ML = T{:, mlCol};
    AP = T{:, apCol};

    % Ensure equal length for time and acceleration vectors
    N = min(length(ML), length(AP));
    ML = ML(1:N);
    AP = AP(1:N);

    % Remove NaNs
    ML = ML(~isnan(ML));
    AP = AP(~isnan(AP));
    N = min(length(ML), length(AP));
    ML = ML(1:N);
    AP = AP(1:N);

    % Remove extreme values (basic clip at ±5 m/s²)
    ML = ML(abs(ML) < 5);
    AP = AP(abs(AP) < 5);
    N = min(length(ML), length(AP));
    ML = ML(1:N);
    AP = AP(1:N);

    if length(ML) < 10 || length(AP) < 10
        warning("Insufficient valid data for participant %d", i);
        continue;
    end

    % Optional smoothing (5-point moving average)
    ML_smooth = movmean(ML, 5);

    % Feature extraction
    ML_SD = std(ML_smooth);
    AP_SD = std(AP);
    jerk = mean(abs(diff(ML_smooth,2)));

    % Entropy (histogram-based)
    [counts, ~] = histcounts(ML_smooth, 10, 'Normalization', 'probability');
    entropy_val = -sum(counts .* log(counts + eps));

    % Balance Score calculation
    w = [1, 1, 1, 1]; epsilon = 1e-5;
    balanceScore = TP / (w(1)*ML_SD + w(2)*AP_SD + w(3)*jerk + w(4)*entropy_val + epsilon);

    scores = [scores; TP, ML_SD, AP_SD, jerk, entropy_val, balanceScore];

    % Time vector assuming 50Hz
    time = (0:N-1)' / 50;

    % Define time thresholds
    if i == 1
        timeStart = 7.0;
    elseif i == 2 || i == 3
        timeStart = 6.5;
    else
        timeStart = 0;
    end

    idxStart = find(time >= timeStart, 1);
    time = time(idxStart:end) - time(idxStart); % Reset to start at 0s
    ML = ML(idxStart:end);
    AP = AP(idxStart:end);

    % Plot ML and AP on the same graph for each participant
    figure;
    plot(time, ML, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(time, AP, 'r-', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Acceleration (m/s^2)');
    title(sprintf('Participant %d: ML and AP Acceleration (Distance = %d cm)', i, TP));
    legend('ML (FreeAcc\_X)', 'AP (FreeAcc\_Z)', 'Location', 'best');
    xlim([0 15]);
    ylim([-5 5]);
    grid on;
end

% Display final results
results = array2table(scores, ...
    'VariableNames', {'TP_cm', 'ML_SD', 'AP_SD', 'Jerk', 'Entropy', 'BalanceScore'});
disp(results);

% Plot Balance Score vs Walking Distance
figure;
plot(scores(:,1), scores(:,6), 'o-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Distance Walked (cm)');
ylabel('Balance Score');
title('Balance Score vs Walking Performance');
grid on;