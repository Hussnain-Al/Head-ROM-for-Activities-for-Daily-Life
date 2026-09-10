%% VALIDATE_TURN_THRESHOLD
% Reprocess walking head ROM at nearby turn thresholds.

repoDir = fileparts(fileparts(mfilename('fullpath')));
addpath(repoDir)
dataDir = fullfile(repoDir,'data','raw');
if ~isfolder(dataDir)
    unzip(fullfile(repoDir,'data','raw_data.zip'),repoDir);
end

cfg.sampleRateHz = 50;
cfg.yawCutoffHz = 5;
cfg.gravityCutoffHz = 0.5;
cfg.window = 180;
cfg.margin = 2;
cfg.neutralSearchEnd = 30;
cfg.neutralDuration = 10;
cfg.turnRateDegPerSec = 25;
cfg.phoneForwardAxis = 3;
cfg.flexionSign = -1;

walkingFolders = {'Walking','Walking_2','Walking_3'};
turnThresholdsDegPerSec = [20 25 30];
ROMMean = nan(numel(turnThresholdsDegPerSec),1);
keptPct = nan(numel(turnThresholdsDegPerSec),1);

for thresholdIndex = 1:numel(turnThresholdsDegPerSec)
    testCfg = cfg;
    testCfg.turnRateDegPerSec = turnThresholdsDegPerSec(thresholdIndex);
    trialROM = nan(3,1);
    trialKeptPct = nan(3,1);
    for trialIndex = 1:3
        [angles,trialKeptPct(trialIndex)] = readHeadTrial(fullfile(dataDir, ...
            walkingFolders{trialIndex}),testCfg,true);
        trialROM(trialIndex) = calculatePercentileROM(angles(:,1));
    end
    ROMMean(thresholdIndex) = mean(trialROM);
    keptPct(thresholdIndex) = mean(trialKeptPct);
end

TTurn = table(turnThresholdsDegPerSec',ROMMean,keptPct, ...
    'VariableNames',{'TurnThreshold_deg_per_s','WalkingFlexExt_ROM_Mean_deg', ...
    'WalkingKept_pct'});
writetable(TTurn,fullfile(repoDir,'TableIV_turn_sensitivity.csv'))
disp(TTurn)
