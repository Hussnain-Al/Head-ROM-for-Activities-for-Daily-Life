%% HEAD_ROM_ANALYSIS
% Head-orientation excursion during five activities of daily living.
% One subject, phone on a forehead strap, three recordings per task.
% MATLAB R2019b+ and Signal Processing Toolbox. Method and limits: README.md

clear; close all; clc

%% PART 1 - SETTINGS
% 1A signal tuning
cfg.sampleRateHz       = 50;
cfg.yawCutoffHz        = 5;
cfg.gravityCutoffHz    = 0.5;

% 1B time windows
cfg.window   = 180;
cfg.margin   = 2;
cfg.holdBand = [6 22];
cfg.holdLen  = 2;

% 1C axes and thresholds
cfg.turnRateDegPerSec = 25;
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
    r = nan(3,3); k = zeros(3,1); D = nan(cfg.window*cfg.sampleRateHz,3,3);

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
% trial-level flexion-extension excursion values. CV is descriptive only because
% each task has three trials.
flexExtMean = rom(:,1);
flexExtSD   = romSD(:,1);
flexExtVar  = flexExtSD.^2;
flexExtCV   = 100 * flexExtSD ./ flexExtMean;
T = table(tasks', round(flexExtMean,1), round(flexExtSD,1), ...
          round(flexExtVar,1), round(flexExtCV), ...
          round(rom(:,2),1), round(rom(:,3),1), ...
          round(100*rom(:,1)/sagRange), round(kept), ...
    'VariableNames',{'Task','FlexExt_Excursion_Mean_deg', ...
                     'FlexExt_Excursion_SD_deg', ...
                     'FlexExt_Excursion_Var_deg2','FlexExt_CV_pct', ...
                     'LatBend_Excursion_deg','AxialRot_Excursion_deg', ...
                     'PctSagCalibration','Kept_pct'});
disp(T); writetable(T,'TableI_results.csv')

fprintf('\nSampling rate  %.1f Hz measured, %g resampled\n', ...
        mean(diags(:,1)), cfg.sampleRateHz);
fprintf('Noise floor    %.2f deg while holding still\n', mean(diags(:,2)));
fprintf('Gyro drift     %.3f deg/s removed, worst %.3f\n', ...
        mean(abs(diags(:,3))), max(abs(diags(:,3))));
fprintf('Mount tilt     %.1f deg spread across refits\n', ...
        max(diags(:,4)) - min(diags(:,4)));
writematrix(diags,'TableII_checks.csv')

%% PART 3 - PARAMETER SENSITIVITY
% Re-run the same pipeline near the selected settings. These checks show
% whether the reported flexion-extension excursion depends strongly on one
% reasonable cutoff or walking-turn threshold.
gravityTests = [0.3 0.5 1.0];
gravityMean = nan(n,numel(gravityTests));
gravityCV = nan(n,numel(gravityTests));

for q = 1:numel(gravityTests)
    cfgTest = cfg;
    cfgTest.gravityCutoffHz = gravityTests(q);
    for i = 1:n
        trialExcursion = nan(3,1);
        for j = 1:3
            a = readTrial(fullfile(dataDir,folders{i}{j}),cfgTest,isWalk(i));
            trialExcursion(j) = pctRange(a(:,1));
        end
        gravityMean(i,q) = mean(trialExcursion);
        gravityCV(i,q) = 100*std(trialExcursion)/mean(trialExcursion);
    end
end

TGravity = table(tasks',gravityMean(:,1),gravityMean(:,2),gravityMean(:,3), ...
    gravityCV(:,1),gravityCV(:,2),gravityCV(:,3), ...
    'VariableNames',{'Task','Mean_0p3Hz_deg','Mean_0p5Hz_deg','Mean_1p0Hz_deg', ...
                     'CV_0p3Hz_pct','CV_0p5Hz_pct','CV_1p0Hz_pct'});
writetable(TGravity,'TableIII_gravity_sensitivity.csv')

turnTests = [20 25 30];
turnMean = nan(numel(turnTests),1);
turnKept = nan(numel(turnTests),1);
for q = 1:numel(turnTests)
    cfgTest = cfg;
    cfgTest.turnRateDegPerSec = turnTests(q);
    trialExcursion = nan(3,1);
    trialKept = nan(3,1);
    for j = 1:3
        [a,trialKept(j)] = readTrial( ...
            fullfile(dataDir,folders{end}{j}),cfgTest,true);
        trialExcursion(j) = pctRange(a(:,1));
    end
    turnMean(q) = mean(trialExcursion);
    turnKept(q) = mean(trialKept);
end

TTurn = table(turnTests',turnMean,turnKept, ...
    'VariableNames',{'TurnThreshold_deg_per_s', ...
                     'WalkingMeanFlexExt_deg','WalkingKept_pct'});
writetable(TTurn,'TableIV_turn_sensitivity.csv')

fprintf('Gravity sensitivity: maximum task-mean change from 0.5 Hz = %.2f deg\n', ...
        max(abs(gravityMean-gravityMean(:,2)),[],'all'));
fprintf('Turn sensitivity: walking mean = %.2f-%.2f deg across 20-30 deg/s\n', ...
        min(turnMean),max(turnMean));

%% PART 4 - TRACES FIGURE
% 4A timeline and canvas
t = (0:cfg.window*cfg.sampleRateHz-1)'/cfg.sampleRateHz;
planes = {'Flexion-extension','Lateral bending','Axial rotation'};
yLimits = [-35 35; -12 12; -35 35];
fig = figure('Color','w','Units','centimeters','Position',[1 1 26 24]);
tl  = tiledlayout(fig,n,3,'TileSpacing','compact','Padding','compact');

% 4B 5x3 grid
for i = 1:n
    for p = 1:3
        ax = nexttile; hold(ax,'on'); grid(ax,'on'); box(ax,'on')
        ax.Color = 'w';
        ax.XColor = 'k';
        ax.YColor = 'k';
        ax.FontName = 'Arial';
        ax.FontSize = 7.5;
        ax.LineWidth = 0.7;
        ax.GridAlpha = 0.18;
        colororder(ax,[0.00 0.45 0.74; 0.85 0.33 0.10; 0.93 0.69 0.13])

        % 4C each recording onto its own median
        X = squeeze(curves{i}(:,p,:) - median(curves{i}(:,p,:),1,'omitnan'));

        % 4D walking yaw is drawn but not reported
        if isWalk(i) && p == 3
            plot(ax, t, X, 'Color',[.72 .72 .72], 'LineWidth',0.8)
            lbl = 'excluded, turning';  col = [.45 .45 .45];
        else
            plot(ax, t, X, 'LineWidth',0.8)
            lbl = sprintf('%.1f \\pm %.1f deg', rom(i,p), romSD(i,p));  col = 'k';
        end

        if i == 1 && p == 1
            legend(ax,{'Trial 1','Trial 2','Trial 3'}, ...
                'Location','southwest','FontSize',6.5,'Box','off')
        end

        % 4E formatting
        if i == 1, title(ax,{planes{p},lbl},'FontWeight','normal','Color',col)
        else,      title(ax,lbl,'FontWeight','normal','Color',col)
        end
        ylim(ax,yLimits(p,:)); xlim(ax,[0 cfg.window])
        if p == 1, ylabel(ax,tasks{i}), end
        if i < n, xticklabels(ax,[]), end
    end
end

title(tl,'Head-orientation excursion during activities of daily living', ...
    'FontName','Arial','FontSize',11,'FontWeight','normal')
xlabel(tl,'Time (s)','FontName','Arial','FontSize',9)
ylabel(tl,'Angle relative to each trial median (deg)', ...
    'FontName','Arial','FontSize',9)

print(fig,'Fig1_traces.png','-dpng','-r300')

%% PART 5 - FLEXION-EXTENSION DESCRIPTIVE STATISTICS FIGURE
% One figure with two panels keeps unlike units on defensible axes.
% Left: mean excursion with +/- SD. Right: variance and CV.
figStats = figure('Color','w','Units','centimeters','Position',[2 2 29 13]);
tlStats = tiledlayout(figStats,1,2,'TileSpacing','loose','Padding','compact');
x = 1:n;

% 5A mean and standard deviation
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

% 5B variance and coefficient of variation
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





%% PART 6 - readTrial
function [ang, pctKept, d] = readTrial(folder, cfg, walking, window)
% Head orientation relative to this recording's neutral hold, in degrees.
% Columns: [flexion-extension, lateral bending, axial rotation].

    if nargin < 4, window = cfg.window; end
    [fs, yawCutoff, gravityCutoff, margin, holdBand, holdLen, ...
        turnRate, axFwd, sgnFlex] = deal( ...
        cfg.sampleRateHz, cfg.yawCutoffHz, cfg.gravityCutoffHz, ...
        cfg.margin, cfg.holdBand, cfg.holdLen, ...
        cfg.turnRateDegPerSec, cfg.axFwd, cfg.sgnFlex);

    % 6A load
    G = readtable(fullfile(folder,'Gyroscope.csv'));
    A = readtable(fullfile(folder,'TotalAcceleration.csv'));
    tRaw = G.seconds_elapsed;

    % 6B uniform clock, before any filtering
    d.fs = 1/median(diff(tRaw));
    assert(abs(d.fs - fs) < 0.2*fs, '%s logged at %.1f Hz.', folder, d.fs)
    t    = (tRaw(1) : 1/fs : tRaw(end))';
    gyro = interp1(tRaw, [G.x G.y G.z], t, 'linear');
    acc  = interp1(A.seconds_elapsed, [A.x A.y A.z], t, 'linear','extrap');

    % 6C gravity direction
    [bg,ag] = butter(2, gravityCutoff/(fs/2));
    g = filtfilt(bg,ag,acc); g = g ./ vecnorm(g,2,2);

    % 6D neutral hold
    quiet = movmean(vecnorm(gyro,2,2), holdLen*fs);
    rel = t - t(1);
    quiet(rel < holdBand(1) | rel > holdBand(2)) = Inf;
    [~,i0] = min(quiet);
    assert(isfinite(quiet(i0)), '%s: no neutral hold found.', folder)
    h = max(1,i0-holdLen/2*fs) : min(numel(t),i0+holdLen/2*fs);
    t = t - t(i0);
    assert(t(end) >= margin + window, '%s: only %.0f s after the hold.', folder, t(end))

    % 6E head frame from this recording's own neutral gravity vector
    zH = mean(g(h,:),1); zH = zH/norm(zH);
    e = zeros(1,3); e(axFwd) = 1;
    xH = e - (e*zH')*zH; xH = xH/norm(xH);
    R = [xH; cross(zH,xH); zH];
    d.tilt = 90 - acosd(max(-1,min(1, e*zH')));

    % 6F low-frequency pitch and roll from the gravity direction
    gh = g * R';
    pitch = sgnFlex * atan2d(gh(:,1), gh(:,3));
    roll  = atan2d(gh(:,2), gh(:,3));
    d.noise = std(pitch(abs(t) < holdLen/2));

    % 6G yaw rate: gyro bias removed at the hold, then filtered at 5 Hz
    [b,a] = butter(2, yawCutoff/(fs/2));
    yawRate = filtfilt(b,a, rad2deg((gyro - mean(gyro(h,:),1)) * zH'));
    yaw = cumtrapz(t, yawRate);

    % 6H window, then residual drift removed
    i1 = find(t >= margin, 1);
    sel = i1 : i1 + window*fs - 1;
    tw = (0:numel(sel)-1)'/fs;
    p = polyfit(tw, yaw(sel), 1);
    d.drift = p(1);
    ang = [pitch(sel), roll(sel), yaw(sel) - polyval(p,tw)];

    % 6I walking, drop the turns
    if walking
        turning = movmax(double(abs(yawRate(sel)) > turnRate), 2*fs) > 0;
        ang(turning,:) = NaN;
        pctKept = 100*mean(~turning);
    else
        pctKept = 100;
    end
end

%% PART 7 - pctRange
function r = pctRange(x)
% 2.5-97.5 percentile range, NaN ignored. Avoids the Statistics Toolbox.
    x = sort(x(~isnan(x))); m = numel(x);
    if m < 40, r = NaN; return, end
    r = x(min(m,round(0.975*m))) - x(max(1,round(0.025*m)));
end
