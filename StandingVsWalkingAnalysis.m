%%  Standing-vs-Walking  –  “No-Scaling” evaluation + plots     2025-04-xx
%  ▸ Clips walking (8–68 s) & standing (4–64 s)
%  ▸ Tries EMD, Wavelet, VMD reconstructions   (NO amplitude scaling)
%  ▸ Each candidate only gets a ±2-s lag search
%  ▸ Prints MSE & %-improvement vs. un-filtered raw walking
%  ▸ Generates 4 figures with all relevant plots
% -------------------------------------------------------------------------
clear;  clc;  close all

%% 0. user files ----------------------------------------------------------
fs   = 60;                                     % sampling rate (Hz)
file_stand = 'PARTICIPANT_STAND_STILL_2025-04-08_18-07-39.csv';
file_walk  = 'PARTICIPANT_FIGURE_OF_8_2025-04-08_18-19-01.csv';

%% 1. Load CSVs -----------------------------------------------------------
o = detectImportOptions(file_stand);  o.DataLines = 2;  o.VariableNamesLine = 2;
xStand = readtable(file_stand,o).FreeAcc_X;

o = detectImportOptions(file_walk );  o.DataLines = 2;  o.VariableNamesLine = 2;
xWalk  = readtable(file_walk ,o).FreeAcc_X;

% guarantee finite data
xStand = fillmissing(xStand,"nearest");  xStand(~isfinite(xStand)) = 0;
xWalk  = fillmissing(xWalk ,"nearest");  xWalk (~isfinite(xWalk )) = 0;

%% 2. Clip, detrend, equal length ----------------------------------------
xStand = detrend(xStand - mean(xStand));  tS = (0:numel(xStand)-1)/fs;
xWalk  = detrend(xWalk  - mean(xWalk ));  tW = (0:numel(xWalk )-1)/fs;

xStand = xStand( tS>=4 & tS<=64 );  tS = tS( tS>=4 & tS<=64 );
xWalk  = xWalk ( tW>=8 & tW<=68 );  tW = tW( tW>=8 & tW<=68 );

N      = min(numel(xStand),numel(xWalk));
xStand = xStand(1:N);   xWalk = xWalk(1:N);   tS = tS(1:N);

%% 3. feature helpers -----------------------------------------------------
metricSet = @(x) struct( ...
             "SD"  , std(x), ...
             "Shan", shannonE(x), ...
             "Spec", specE(x,fs), ...
             "DF"  , domF(x,fs) );

%% 4. reference row -------------------------------------------------------
R                 = struct();
R.Standing        = metricSet(xStand);
R.Standing.MSE    = 0;
R.Standing.sig    = xStand;
R.Standing.name   = "Standing";

%% 5. raw walking (lag only) ---------------------------------------------
[R.Raw.sig , R.Raw.MSE] = alignLag(xWalk,xStand,fs);
R.Raw                = copyfields(metricSet(R.Raw.sig),R.Raw,{'SD','Shan','Spec','DF'});
R.Raw.name           = "Raw Walking";

%% 6. EMD ---------------------------------------------------------------
imfs    = emd(xWalk);
bestEMD = struct('MSE',inf);
for s = 2:min(5,size(imfs,2)-1)
    cand        = sum(imfs(:,s:s+1),2);
    [sig,m]     = alignLag(cand,xStand,fs);
    if m < bestEMD.MSE
        bestEMD = metricSet(sig);
        bestEMD.MSE  = m;  bestEMD.sig = sig;
        bestEMD.name = sprintf("EMD (IMF %d-%d)",s,s+1);
    end
end
R.EMD = bestEMD;

%% 7. Wavelet ------------------------------------------------------------
[C,L] = wavedec(xWalk,4,'db4');
cands = { wrcoef('a',C,L,'db4',4) , "A4" ;
          wrcoef('a',C,L,'db4',3) , "A3" ;
          wrcoef('d',C,L,'db4',4)+wrcoef('d',C,L,'db4',3) , "D3+D4" };
bestW = struct('MSE',inf);
for k = 1:size(cands,1)
    [sig,m] = alignLag(cands{k,1},xStand,fs);
    if m < bestW.MSE
        bestW = metricSet(sig);
        bestW.MSE  = m;  bestW.sig = sig;
        bestW.name = "Wavelet (db4 " + cands{k,2} + ")";
    end
end
R.Wave = bestW;

%% 8. VMD ---------------------------------------------------------------
warning off
[u,~,~] = VMD(xWalk,2000,0,3,0,1,1e-7);     warning on
bestV = struct('MSE',inf);
for k = 1:size(u,1)
    [sig,m] = alignLag(u(k,:).',xStand,fs);
    if m < bestV.MSE
        bestV = metricSet(sig);
        bestV.MSE  = m;  bestV.sig = sig;
        bestV.name = sprintf("VMD (K=3, mode-%d)",k);
    end
end
R.VMD = bestV;

%% 9. Δ MSE (%) relative to raw -----------------------------------------
MSEraw   = R.Raw.MSE;
relGain  = @(m) 100*(MSEraw-m)/MSEraw;
keys     = ["Standing","Raw","EMD","Wave","VMD"];
for k = 1:numel(keys)
    R.(keys(k)).dMSE = relGain(R.(keys(k)).MSE);
end

%% 10. console table -----------------------------------------------------
fprintf('\n%-18s | %7s %9s %9s %14s %10s\n',...
       'Signal','SD','Shannon','Spectral','Dom-Freq (Hz)','MSE   ΔMSE %');
fprintf(repmat('-',1,84)); fprintf('\n');
for k = 1:numel(keys)
    r = R.(keys(k));
    fprintf('%-18s | %7.5f %9.5f %9.5f %14.2f %8.6f %7.2f\n',...
            r.name,r.SD,r.Shan,r.Spec,r.DF,r.MSE,r.dMSE);
end

%% 11. plots -------------------------------------------------------------
% figure 1 – all overlays
figure('Name','All candidates vs Standing','Position',[80 80 1200 700]);
plotN = numel(keys)-1;                         % exclude reference
for k = 1:plotN
    subplot(plotN,1,k);  hold on;  grid on
    plot(tS,xStand,'k','LineWidth',1.2)
    plot(tS,R.(keys(k+1)).sig,'r')
    title(R.(keys(k+1)).name + "  (MSE " + sprintf('%.4f',R.(keys(k+1)).MSE) + ")")
    if k==plotN, xlabel('Time (s)'); end,  ylabel('Acc')
end

% figure 2 – bar chart
figure('Name','MSE comparison');  clf
vals  = cellfun(@(f)R.(f).MSE, keys(2:end));
bar(categorical(keys(2:end)),vals);  ylabel('MSE')
title('Mean-square error (no scaling)');  grid on

% figure 3 – PSD of standing vs best
[~,ixBest] = min([R.EMD.MSE R.Wave.MSE R.VMD.MSE]);  candNames = ["EMD","Wave","VMD"];
bestKey    = candNames(ixBest);
figure('Name','PSD comparison');
pwelch(xStand,[],[],[],fs,'power');  hold on
pwelch(R.(bestKey).sig,[],[],[],fs,'power');
legend('Standing',bestKey,'Location','best');  grid on
title('Power-spectral density (no scaling)')

% figure 4 – overlay best (was already in original code)
figure('Name','Best-match overlay (no scaling)');
plot(tS,R.(bestKey).sig,'r--','LineWidth',1.4); hold on
plot(tS,xStand,'k','LineWidth',1.4)
xlabel('Time (s)'); ylabel('Acc (m/s²)')
title(sprintf('Best candidate → %s   MSE = %.5g',R.(bestKey).name,R.(bestKey).MSE))
legend('Reconstruction','Standing'); grid on

%% ------------- local functions -----------------------------------------
function [xA,MSE] = alignLag(x,y,fs)
    lagMax = round(2*fs);
    [xc,lgs] = xcorr(y,x,lagMax,'coeff');     [~,im] = max(xc);  lag = lgs(im);
    if lag>=0, xA = x(1+lag:end);  y = y(1:numel(xA));
    else       xA = x(1:end+lag);  y = y(1-lag:numel(x));
    end
    xA  = xA(:);
    MSE = mean((xA - y).^2);
    xA  = [zeros(max(0,lag),1); xA ; zeros(max(0,-lag),1)];
end
function H = shannonE(x)
    nb = ceil(sqrt(numel(x)));
    p  = histcounts(x,nb,'Normalization','probability');
    p  = p(p>0);  H = -sum(p.*log2(p))/log2(numel(p));
end
function H = specE(x,fs)
    [Pxx,~] = periodogram(x,[],[],fs);
    p = Pxx./sum(Pxx); p=p(p>0);
    H = -sum(p.*log2(p))/log2(numel(p));
end
function f = domF(x,fs)
    [Pxx,F] = pwelch(x,[],[],[],fs);
    Pxx(F<0.2 | F>3) = 0;   [~,ix] = max(Pxx);  f = F(ix);
end
function dst = copyfields(src,dst,flist)
    for i = 1:numel(flist), dst.(flist{i}) = src.(flist{i}); end
end
