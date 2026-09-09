%% HEAD_ROM_ANALYSIS
% Head range of motion during five activities of daily living.
% One subject, phone on a forehead strap, three recordings per task.
% MATLAB R2019b+ and Signal Processing Toolbox. Method and limits: README.md

clear; close all; clc

%% PART 1 - SETTINGS
% 1A signal tuning
cfg.fs       = 50;
cfg.fc       = 5;
cfg.fg       = 0.5;

% 1B time windows
cfg.window   = 180;
cfg.margin   = 2;
cfg.holdBand = [6 22];
cfg.holdLen  = 2;

% 1C axes and thresholds
cfg.turnRate = 25;
cfg.axFwd    = 3;
cfg.sgnFlex  = -1;

% 1D files
dataDir = fullfile('data','raw');
if ~isfolder(dataDir)
    unzip(fullfile('data','raw_data.zip'), '.');
end
tasks   = {'Seated, laptop','Standing, laptop','Standing, phone','Eating','Walking'};
isWalk  = [0 0 0 0 1];
folders = { {'Sitting','Sitting_2','Sitting_3'}, ...
            {'Standing_working','Standing_working_2','Standing_Working_3'}, ...
            {'Scrolling_while_Standing','Scrolling_while_Standing_2','Scrolling_while_Standing_3'}, ...
            {'Eating','Eating_2','Eating_3'}, ...
            {'Walking','Walking_2','Walking_3'} };

%% PART 2 - PIPELINE
% 2A calibration sets the scale
cal = readTrial(fullfile(dataDir,'Calibration'), cfg, false, 60);
flexion = max(cal(:,1)); extension = min(cal(:,1));
sagRange = flexion - extension;
assert(sagRange > 30, 'Calibration range only %.1f deg - check axFwd and sgnFlex.', sagRange)
fprintf('Sagittal range: %.1f deg (%.1f flexion, %.1f extension)\n\n', ...
        sagRange, flexion, extension);

% 2B preallocate
n = numel(tasks);
rom = zeros(n,3); romSD = zeros(n,3); kept = zeros(n,1);
curves = cell(n,1); diags = zeros(3*n,4);

% 2C task and trial loops
for i = 1:n
    r = nan(3,3); k = zeros(3,1); D = nan(cfg.window*cfg.fs,3,3);

    for j = 1:3
        [a, k(j), d] = readTrial(fullfile(dataDir,folders{i}{j}), cfg, isWalk(i));
        D(:,:,j) = a;

        % 2D range per plane
        for p = 1:3, r(j,p) = pctRange(a(:,p)); end
        if isWalk(i), r(j,3) = NaN; end
        diags(3*(i-1)+j,:) = [d.fs d.noise d.drift d.tilt];
    end

    % 2E across the three recordings
    rom(i,:) = mean(r,1); romSD(i,:) = std(r,0,1);
    kept(i) = mean(k); curves{i} = D;
end

% 2F results and checks
% Mean, sample SD, sample variance, and CV are calculated across the three
% trial-level flexion-extension ROM values. CV is descriptive only because
% each task has three trials.
flexExtMean = rom(:,1);
flexExtSD   = romSD(:,1);
flexExtVar  = flexExtSD.^2;
flexExtCV   = 100 * flexExtSD ./ flexExtMean;
T = table(tasks', round(flexExtMean,1), round(flexExtSD,1), ...
          round(flexExtVar,1), round(flexExtCV), ...
          round(rom(:,2),1), round(rom(:,3),1), ...
          round(100*rom(:,1)/sagRange), round(kept), ...
    'VariableNames',{'Task','FlexExt_Mean_deg','FlexExt_SD_deg', ...
                     'FlexExt_Var_deg2','FlexExt_CV_pct', ...
                     'LatBend_deg','AxialRot_deg','PctSagRange','Kept_pct'});
disp(T); writetable(T,'TableI_results.csv')

fprintf('\nSampling rate  %.1f Hz measured, %g assumed\n', mean(diags(:,1)), cfg.fs);
fprintf('Noise floor    %.2f deg while holding still\n', mean(diags(:,2)));
fprintf('Gyro drift     %.3f deg/s removed, worst %.3f\n', ...
        mean(abs(diags(:,3))), max(abs(diags(:,3))));
fprintf('Mount tilt     %.1f deg spread across refits\n', ...
        max(diags(:,4)) - min(diags(:,4)));
writematrix(diags,'TableII_checks.csv')

%% PART 3 - FIGURE
% 3A timeline and canvas
t = (0:cfg.window*cfg.fs-1)'/cfg.fs;
planes = {'Flexion-extension','Lateral bending','Axial rotation'};
fig = figure('Color','w','Units','centimeters','Position',[1 1 26 24]);
tl  = tiledlayout(fig,n,3,'TileSpacing','compact','Padding','compact');

% 3B 5x3 grid
for i = 1:n
    for p = 1:3
        ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on')

        % 3D each recording onto its own median
        X = squeeze(curves{i}(:,p,:) - median(curves{i}(:,p,:),1,'omitnan'));

        % 3C walking yaw is drawn but not reported
        if isWalk(i) && p == 3
            plot(ax, t, X, 'Color',[.72 .72 .72], 'LineWidth',0.8)
            lbl = 'excluded, turning';  col = [.45 .45 .45];
        else
            plot(ax, t, X, 'LineWidth',0.8)
            lbl = sprintf('%.1f \\pm %.1f deg', rom(i,p), romSD(i,p));  col = 'k';
        end

        % 3E formatting
        if i == 1, title(ax,{planes{p},lbl},'FontWeight','normal','Color',col)
        else,      title(ax,lbl,'FontWeight','normal','Color',col)
        end
        ylim(ax,[-16 16]); xlim(ax,[0 cfg.window])
        if p == 1, ylabel(ax,tasks{i}), else, yticklabels(ax,[]), end
        if i < n, xticklabels(ax,[]), else, xlabel(ax,'Time (s)'), end
    end
end

print(fig,'Fig1_traces.png','-dpng','-r300')

%% PART 4 - FLEXION-EXTENSION DESCRIPTIVE STATISTICS FIGURE
% One figure with two panels keeps unlike units on defensible axes.
% Left: mean excursion with +/- SD. Right: variance and CV.
figStats = figure('Color','w','Units','centimeters','Position',[2 2 29 13]);
tlStats = tiledlayout(figStats,1,2,'TileSpacing','loose','Padding','compact');
x = 1:n;

% 4A mean and standard deviation
axMean = nexttile(tlStats);
meanBars = bar(axMean,x,flexExtMean,0.62, ...
    'FaceColor',[0.20 0.45 0.70], ...
    'EdgeColor','none', ...
    'DisplayName','Mean');
hold(axMean,'on')
sdWhiskers = errorbar(axMean,x,flexExtMean,flexExtSD,'k', ...
    'LineStyle','none','LineWidth',1.2,'CapSize',9);
sdWhiskers.DisplayName = '+/- SD';
ylim(axMean,[0 1.18*max(flexExtMean + flexExtSD)])
ylabel(axMean,'Excursion (deg)')
title(axMean,'Mean and standard deviation','FontWeight','normal')
legend(axMean,[meanBars sdWhiskers],{'Mean','+/- SD'}, ...
    'Location','northeast','Orientation','horizontal', ...
    'NumColumns',2,'FontSize',8,'Box','off')

% 4B variance and coefficient of variation
axRepeat = nexttile(tlStats);
yyaxis(axRepeat,'left')
varBars = bar(axRepeat,x,flexExtVar,0.62, ...
    'FaceColor',[0.85 0.55 0.12], ...
    'EdgeColor','none', ...
    'DisplayName','Variance');
ylim(axRepeat,[0 1.18*max(flexExtVar)])
ylabel(axRepeat,'Variance (deg^2)')

yyaxis(axRepeat,'right')
cvPoints = scatter(axRepeat,x,flexExtCV,32,'kd','filled', ...
    'DisplayName','CV');
ylim(axRepeat,[0 max(50,1.18*max(flexExtCV))])
ylabel(axRepeat,'CV (%)')
title(axRepeat,'Repeatability','FontWeight','normal')
legend(axRepeat,[varBars cvPoints],{'Variance','CV'}, ...
    'Location','northeast','Orientation','horizontal', ...
    'NumColumns',2,'FontSize',8,'Box','off')

for ax = [axMean axRepeat]
    ax.Color = 'w';
    ax.XColor = 'k';
    ax.FontName = 'Arial';
    ax.FontSize = 8.5;
    ax.LineWidth = 0.8;
    ax.XTick = x;
    ax.XTickLabel = tasks;
    ax.XTickLabelRotation = 18;
    ax.YGrid = 'on';
    ax.GridAlpha = 0.18;
    box(ax,'on')
end
axRepeat.YAxis(1).Color = 'k';
axRepeat.YAxis(2).Color = 'k';

sgtitle(tlStats,'Flexion-extension excursion across three trials per task', ...
    'FontName','Arial','FontSize',11,'FontWeight','normal')
print(figStats,'Fig2_flexext_statistics.png','-dpng','-r300')





%% PART 5 - readTrial
function [ang, pctKept, d] = readTrial(folder, cfg, walking, window)
% Angle relative to this recording's neutral hold, in degrees.
% Columns: [flexion-extension, lateral bending, axial rotation].

    if nargin < 4, window = cfg.window; end
    [fs, fc, fg, margin, holdBand, holdLen, turnRate, axFwd, sgnFlex] = deal( ...
        cfg.fs, cfg.fc, cfg.fg, cfg.margin, cfg.holdBand, cfg.holdLen, ...
        cfg.turnRate, cfg.axFwd, cfg.sgnFlex);

    % 5A load
    G = readtable(fullfile(folder,'Gyroscope.csv'));
    A = readtable(fullfile(folder,'TotalAcceleration.csv'));
    tRaw = G.seconds_elapsed;

    % 5B uniform clock, before any filtering
    d.fs = 1/median(diff(tRaw));
    assert(abs(d.fs - fs) < 0.2*fs, '%s logged at %.1f Hz.', folder, d.fs)
    t    = (tRaw(1) : 1/fs : tRaw(end))';
    gyro = interp1(tRaw, [G.x G.y G.z], t, 'linear');
    acc  = interp1(A.seconds_elapsed, [A.x A.y A.z], t, 'linear','extrap');

    % 5C gravity direction
    [bg,ag] = butter(2, fg/(fs/2));
    g = filtfilt(bg,ag,acc); g = g ./ vecnorm(g,2,2);

    % 5D neutral hold
    quiet = movmean(vecnorm(gyro,2,2), holdLen*fs);
    rel = t - t(1);
    quiet(rel < holdBand(1) | rel > holdBand(2)) = Inf;
    [~,i0] = min(quiet);
    assert(isfinite(quiet(i0)), '%s: no neutral hold found.', folder)
    h = max(1,i0-holdLen/2*fs) : min(numel(t),i0+holdLen/2*fs);
    t = t - t(i0);
    assert(t(end) >= margin + window, '%s: only %.0f s after the hold.', folder, t(end))

    % 5E head frame from this recording's own neutral gravity vector
    zH = mean(g(h,:),1); zH = zH/norm(zH);
    e = zeros(1,3); e(axFwd) = 1;
    xH = e - (e*zH')*zH; xH = xH/norm(xH);
    R = [xH; cross(zH,xH); zH];
    d.tilt = 90 - acosd(max(-1,min(1, e*zH')));

    % 5F pitch and roll
    gh = g * R';
    [b,a] = butter(2, fc/(fs/2));
    pitch = filtfilt(b,a, sgnFlex * atan2d(gh(:,1), gh(:,3)));
    roll  = filtfilt(b,a, atan2d(gh(:,2), gh(:,3)));
    d.noise = std(pitch(abs(t) < holdLen/2));

    % 5G yaw, gyro bias removed at the hold
    yawRate = filtfilt(b,a, rad2deg((gyro - mean(gyro(h,:),1)) * zH'));
    yaw = cumtrapz(t, yawRate);

    % 5H window, then residual drift removed
    i1 = find(t >= margin, 1);
    sel = i1 : i1 + window*fs - 1;
    tw = (0:numel(sel)-1)'/fs;
    p = polyfit(tw, yaw(sel), 1);
    d.drift = p(1);
    ang = [pitch(sel), roll(sel), yaw(sel) - polyval(p,tw)];

    % 5I walking, drop the turns
    if walking
        turning = movmax(double(abs(yawRate(sel)) > turnRate), 2*fs) > 0;
        ang(turning,:) = NaN;
        pctKept = 100*mean(~turning);
    else
        pctKept = 100;
    end
end

%% PART 6 - pctRange
function r = pctRange(x)
% 2.5-97.5 percentile range, NaN ignored. Avoids the Statistics Toolbox.
    x = sort(x(~isnan(x))); m = numel(x);
    if m < 40, r = NaN; return, end
    r = x(min(m,round(0.975*m))) - x(max(1,round(0.025*m)));
end
