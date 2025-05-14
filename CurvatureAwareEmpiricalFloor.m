% ==============================================================
% Chapter 4 — Curvature-Aware Ideal-Seconds Pilot
%
% Implements Chapter-3 scoring on three backward-walking trials:
%   1. Reads lumbar-IMU CSVs (FreeAcc_X, FreeAcc_Z at 60 Hz)
%   2. Removes first 7.0 s (P1) or 6.5 s (P2, P3) to match legacy trim
%   3. Computes 1-s sliding ML-SD; AP-SD kept only for table
%   4. Builds a continuous empirical mechanical floor as the frame-wise
%      minimum of all ML-SD traces, ignoring NaNs after a participant stops
%   5. Calculates per-frame reward  Q[k] = min(1 , floor/σ_ML[k])
%   6. Integrates Q to obtain Ideal-Second totals C
%   7. Generates dissertation figures:
%        • ML-SD traces + floor
%        • Reward Q[k] traces
%        • Ideal-Second score vs walking distance
%   8. Prints results table:
%        Distance, ML_SD, AP_SD, TrialTime, IdealSeconds, Ratio (=C/Time)
% ==============================================================

clear; clc; close all

participants = {
   'PARTICIPANT 1 STUMBLE 150cm D4-22-CD-00-A7-18_2025-04-08_20-07-40.csv', 150;
   'PARTICIPANT 2 STUMBLE 300cm D4-22-CD-00-A7-18_2025-04-08_20-11-06.csv', 300;
   'PARTICIPANT 3 STUMBLE 450cm D4-22-CD-00-A7-18_2025-04-08_20-20-09.csv', 450
};

Fs  = 60;                  % Hz
win = Fs;                  % 1-s sliding-SD window
nP  = size(participants,1);

MLsd  = cell(1,nP);  tCell = cell(1,nP);  len = zeros(1,nP);
ML_SD = zeros(1,nP); AP_SD = zeros(1,nP);
trialT = zeros(1,nP); IdealSec = zeros(1,nP);

% ----------------------  Load & preprocess  --------------------
for k = 1:nP
    file = participants{k,1};  dist_cm = participants{k,2};

    opts = detectImportOptions(file); opts.DataLines=2; opts.VariableNamesLine=2;
    T = readtable(file,opts);

    ML = T.FreeAcc_X;  AP = T.FreeAcc_Z;
    N  = min(numel(ML),numel(AP)); ML=ML(1:N); AP=AP(1:N);
    mask = abs(ML)<5 & abs(AP)<5 & ~isnan(ML) & ~isnan(AP);
    ML = ML(mask);  AP = AP(mask);

    t  = (0:numel(ML)-1)'/Fs;
    t0 = 7.0*(k==1) + 6.5*(k~=1);          % offsets for task start
    s0 = find(t>=t0,1);
    ML = ML(s0:end); AP = AP(s0:end); t = t(s0:end)-t0;

    ML_SD(k) = std(ML);  AP_SD(k) = std(AP);
    MLsd{k}  = movstd(ML,[win-1 0],1);
    tCell{k} = t;  len(k)=numel(MLsd{k});
    trialT(k)=t(end);

    % (Optional raw-signal plot can be kept or commented out)
end

% ------------------  Continuous empirical floor ----------------
Lmax = max(len);
MLmat = NaN(Lmax,nP);
for k=1:nP, MLmat(1:len(k),k)=MLsd{k}; end
ML_floor = nanmin(MLmat,[],2);    % ignore NaNs
tLong    = (0:Lmax-1)'/Fs;

% Figure 1: ML-SD traces with floor
figure('Name','ML-SD & Floor'); hold on
clr = lines(nP);
for k=1:nP, plot(tCell{k},MLsd{k},'Color',clr(k,:)); end
plot(tLong,ML_floor,'k--','LineWidth',2)
xlabel('Time (s)'), ylabel('ML SD (m/s^2)')
title('Sliding ML-SD and Empirical Floor'); grid on
legend('P1','P2','P3','Floor','Location','best')

% ------------------  Reward traces & ideal seconds -------------
epsFloor = 1e-6;            % guard against divide-by-zero
DeltaT   = 1 / Fs;
figure('Name','Reward Q[k]'); hold on
for k = 1:nP
    floor_k = ML_floor(1:len(k));
    Q       = min(1, floor_k ./ max(MLsd{k}, epsFloor));
    IdealSec(k) = sum(Q) * DeltaT;
    plot(tCell{k}, Q, 'Color', clr(k,:));
end
xlabel('Time (s)'); ylabel('Reward Q')
title('Instantaneous Reward per Frame'); grid on
legend('P1','P2','P3','Location','best')

% ------------------  Results table & performance plot ----------
ratio = IdealSec ./ trialT;               % IdealSeconds / trial time
tbl = table([participants{:,2}]', ML_SD', AP_SD', trialT', IdealSec', ratio', ...
    'VariableNames',{'Distance_cm','ML_SD','AP_SD','Time_s','IdealSeconds','Ratio'});
disp(tbl)

figure('Name','Ideal-Seconds vs Distance');
plot(tbl.Distance_cm, tbl.IdealSeconds,'o-','LineWidth',2)
xlabel('Distance Walked (cm)'), ylabel('Ideal-Second Score C')
title('Curvature-Aware Score vs Performance'); grid on
