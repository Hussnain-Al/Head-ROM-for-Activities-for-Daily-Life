%% HEAD_ROM_ANALYSIS
% Head ROM during five activities of daily living.
% One participant, phone on a forehead strap, three recordings per task.
% MATLAB R2019b+ and Signal Processing Toolbox. Method and limits: README.md

clear; close all; clc

%% PART 1 - SETTINGS
cfg.sampleRateHz       = 50;
cfg.yawCutoffHz        = 5;
cfg.gravityCutoffHz    = 0.5;
cfg.window             = 180;
cfg.margin             = 2;
cfg.neutralSearchEnd   = 30;
cfg.neutralDuration    = 10;
cfg.turnRateDegPerSec  = 25;
cfg.phoneForwardAxis   = 3;
cfg.flexionSign        = -1;

dataDir = fullfile('data','raw');
if ~isfolder(dataDir)
    unzip(fullfile('data','raw_data.zip'), '.');
end

tasks = {'Seated, laptop','Standing, laptop','Standing, phone','Eating','Walking'};
isWalkingTask = [false false false false true];
folders = { {'Sitting','Sitting_2','Sitting_3'}, ...
            {'Standing_working','Standing_working_2','Standing_Working_3'}, ...
            {'Scrolling_while_Standing','Scrolling_while_Standing_2','Scrolling_while_Standing_3'}, ...
            {'Eating','Eating_2','Eating_3'}, ...
            {'Walking','Walking_2','Walking_3'} };

%% PART 2 - CALIBRATION
calibrationAngles = readHeadTrial(fullfile(dataDir,'Calibration'),cfg,false,60);
flexion = max(calibrationAngles(:,1));
extension = min(calibrationAngles(:,1));
sagittalCalibrationROM = flexion - extension;

if sagittalCalibrationROM <= 30
    warning('Calibration ROM was %.1f deg; inspect the recording and axis mapping.', ...
            sagittalCalibrationROM)
end

fprintf('Sagittal calibration ROM: %.1f deg (%.1f flexion, %.1f extension)\n\n', ...
        sagittalCalibrationROM,flexion,extension);

%% PART 3 - TASK ANALYSIS
nTasks = numel(tasks);
ROMMean = zeros(nTasks,3);
ROMSD = zeros(nTasks,3);
keptPct = zeros(nTasks,1);
curves = cell(nTasks,1);
qualityChecks = zeros(3*nTasks,4);

for taskIndex = 1:nTasks
    trialROM = nan(3,3);
    trialKeptPct = zeros(3,1);
    taskCurves = nan(cfg.window*cfg.sampleRateHz,3,3);

    for trialIndex = 1:3
        [angles,trialKeptPct(trialIndex),quality] = readHeadTrial( ...
            fullfile(dataDir,folders{taskIndex}{trialIndex}),cfg, ...
            isWalkingTask(taskIndex));
        taskCurves(:,:,trialIndex) = angles;

        for planeIndex = 1:3
            trialROM(trialIndex,planeIndex) = ...
                calculatePercentileROM(angles(:,planeIndex));
        end

        if isWalkingTask(taskIndex)
            trialROM(trialIndex,3) = NaN;
        end

        row = 3*(taskIndex-1) + trialIndex;
        qualityChecks(row,:) = [quality.measuredRateHz, ...
            quality.neutralHoldSDDeg,quality.yawTrendDegPerSec, ...
            quality.neutralPhoneInclinationDeg];
    end

    ROMMean(taskIndex,:) = mean(trialROM,1);
    ROMSD(taskIndex,:) = std(trialROM,0,1);
    keptPct(taskIndex) = mean(trialKeptPct);
    curves{taskIndex} = taskCurves;
end

%% PART 4 - RESULTS TABLES
flexExtMean = ROMMean(:,1);
flexExtSD = ROMSD(:,1);
flexExtVar = flexExtSD.^2;
flexExtCV = 100*flexExtSD./flexExtMean;

T = table(tasks',round(flexExtMean,1),round(flexExtSD,1), ...
    round(flexExtVar,1),round(flexExtCV), ...
    round(ROMMean(:,2),1),round(ROMSD(:,2),1), ...
    round(ROMMean(:,3),1),round(ROMSD(:,3),1), ...
    round(100*ROMMean(:,1)/sagittalCalibrationROM),round(keptPct), ...
    'VariableNames',{'Task','FlexExt_ROM_Mean_deg','FlexExt_ROM_SD_deg', ...
    'FlexExt_ROM_Var_deg2','FlexExt_CV_pct', ...
    'LatBend_ROM_Mean_deg','LatBend_ROM_SD_deg', ...
    'AxialRot_ROM_Mean_deg','AxialRot_ROM_SD_deg', ...
    'PctSagCalibration','Kept_pct'});
disp(T)
writetable(T,'TableI_results.csv')

qualityTask = repelem(tasks',3);
qualityTrial = repmat((1:3)',nTasks,1);
TChecks = table(qualityTask,qualityTrial,qualityChecks(:,1),qualityChecks(:,2), ...
    qualityChecks(:,3),qualityChecks(:,4), ...
    'VariableNames',{'Task','Trial','MeasuredSampleRate_Hz','NeutralHoldSD_deg', ...
    'YawTrend_deg_per_s','NeutralPhoneInclination_deg'});
writetable(TChecks,'TableII_checks.csv')

fprintf('\nSampling rate  %.2f Hz measured, %g Hz resampled\n', ...
        mean(qualityChecks(:,1)),cfg.sampleRateHz);
fprintf('Neutral hold   %.2f deg mean SD\n',mean(qualityChecks(:,2)));
nonWalkingRows = 1:3*(nTasks-1);
fprintf('Yaw trend      %.3f deg/s mean absolute in non-walking trials\n', ...
        mean(abs(qualityChecks(nonWalkingRows,3))));
fprintf('Phone angle    %.1f deg spread across neutral holds\n', ...
        max(qualityChecks(:,4))-min(qualityChecks(:,4)));

%% PART 5 - HEAD ROM TRACES
t = (0:cfg.window*cfg.sampleRateHz-1)'/cfg.sampleRateHz;
planes = {'Flexion-extension','Lateral bending','Axial rotation'};
yLimits = [-35 35; -12 12; -35 35];
fig = figure('Color','w','Units','centimeters','Position',[1 1 26 24]);
traceLayout = tiledlayout(fig,nTasks,3,'TileSpacing','compact','Padding','compact');

for taskIndex = 1:nTasks
    for planeIndex = 1:3
        ax = nexttile;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on')
        ax.Color = 'w';
        ax.XColor = 'k';
        ax.YColor = 'k';
        ax.FontName = 'Arial';
        ax.FontSize = 7.5;
        ax.LineWidth = 0.7;
        ax.GridAlpha = 0.18;
        colororder(ax,[0.00 0.45 0.74; 0.85 0.33 0.10; 0.93 0.69 0.13])

        X = squeeze(curves{taskIndex}(:,planeIndex,:));
        if isWalkingTask(taskIndex) && planeIndex == 3
            plot(ax,t,X,'Color',[.72 .72 .72],'LineWidth',0.8)
            resultLabel = 'not reported';
            titleColor = [.45 .45 .45];
        else
            plot(ax,t,X,'LineWidth',0.8)
            resultLabel = sprintf('%.1f \\pm %.1f deg', ...
                ROMMean(taskIndex,planeIndex),ROMSD(taskIndex,planeIndex));
            titleColor = 'k';
        end

        if taskIndex == 1 && planeIndex == 1
            legend(ax,{'Trial 1','Trial 2','Trial 3'}, ...
                'Location','southwest','FontSize',6.5,'Box','off')
        end

        if taskIndex == 1
            title(ax,{planes{planeIndex},resultLabel}, ...
                'FontWeight','normal','Color',titleColor)
        else
            title(ax,resultLabel,'FontWeight','normal','Color',titleColor)
        end
        ylim(ax,yLimits(planeIndex,:));
        xlim(ax,[0 cfg.window]);
        if planeIndex == 1, ylabel(ax,tasks{taskIndex}), end
        if taskIndex < nTasks, xticklabels(ax,[]), end
    end
end

title(traceLayout,'Head ROM during activities of daily living', ...
    'FontName','Arial','FontSize',11,'FontWeight','normal')
xlabel(traceLayout,'Time (s)','FontName','Arial','FontSize',9)
ylabel(traceLayout,'Head angle (deg; axial detrended)', ...
    'FontName','Arial','FontSize',9)
print(fig,'Fig1_traces.png','-dpng','-r300')
print(fig,'Fig1_traces_updated.svg','-dsvg')

%% PART 6 - FLEXION-EXTENSION STATISTICS
figStats = figure('Color','w','Units','centimeters','Position',[2 2 29 13]);
statsLayout = tiledlayout(figStats,1,2,'TileSpacing','loose','Padding','compact');
x = 1:nTasks;

axMean = nexttile(statsLayout);
meanBars = bar(axMean,x,flexExtMean,0.62,'FaceColor',[0.20 0.45 0.70], ...
    'EdgeColor','none','DisplayName','Mean');
hold(axMean,'on')
sdWhiskers = errorbar(axMean,x,flexExtMean,flexExtSD,'k', ...
    'LineStyle','none','LineWidth',1.2,'CapSize',9,'DisplayName','+/- SD');
ylim(axMean,[0 1.18*max(flexExtMean+flexExtSD)])
ylabel(axMean,'ROM (deg)')
title(axMean,'Mean and standard deviation','FontWeight','normal')
legend(axMean,[meanBars sdWhiskers],{'Mean','+/- SD'}, ...
    'Location','northeast','Orientation','horizontal', ...
    'NumColumns',2,'FontSize',8,'Box','off')

axRepeat = nexttile(statsLayout);
yyaxis(axRepeat,'left')
varianceBars = bar(axRepeat,x,flexExtVar,0.62,'FaceColor',[0.85 0.55 0.12], ...
    'EdgeColor','none','DisplayName','Variance');
ylim(axRepeat,[0 1.18*max(flexExtVar)])
ylabel(axRepeat,'Variance (deg^2)')
yyaxis(axRepeat,'right')
CVPoints = scatter(axRepeat,x,flexExtCV,32,'kd','filled','DisplayName','CV');
ylim(axRepeat,[0 max(50,1.18*max(flexExtCV))])
ylabel(axRepeat,'CV (%)')
title(axRepeat,'Repeatability','FontWeight','normal')
legend(axRepeat,[varianceBars CVPoints],{'Variance','CV'}, ...
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

sgtitle(statsLayout,'Flexion-extension ROM across three trials per task', ...
    'FontName','Arial','FontSize',11,'FontWeight','normal')
print(figStats,'Fig2_flexext_statistics.png','-dpng','-r300')
