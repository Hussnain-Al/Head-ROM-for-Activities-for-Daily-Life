%% VALIDATE_GRAVITY_CUTOFF
% Reprocess head ROM at nearby gravity cutoffs to test parameter sensitivity.

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

tasks = {'Seated, laptop','Standing, laptop','Standing, phone','Eating','Walking'};
isWalkingTask = [false false false false true];
folders = { {'Sitting','Sitting_2','Sitting_3'}, ...
            {'Standing_working','Standing_working_2','Standing_Working_3'}, ...
            {'Scrolling_while_Standing','Scrolling_while_Standing_2','Scrolling_while_Standing_3'}, ...
            {'Eating','Eating_2','Eating_3'}, ...
            {'Walking','Walking_2','Walking_3'} };

gravityCutoffsHz = [0.3 0.5 1.0];
ROMMean = nan(numel(tasks),numel(gravityCutoffsHz));
CV = nan(numel(tasks),numel(gravityCutoffsHz));

for cutoffIndex = 1:numel(gravityCutoffsHz)
    testCfg = cfg;
    testCfg.gravityCutoffHz = gravityCutoffsHz(cutoffIndex);
    for taskIndex = 1:numel(tasks)
        trialROM = nan(3,1);
        for trialIndex = 1:3
            angles = readHeadTrial(fullfile(dataDir, ...
                folders{taskIndex}{trialIndex}),testCfg,isWalkingTask(taskIndex));
            trialROM(trialIndex) = calculatePercentileROM(angles(:,1));
        end
        ROMMean(taskIndex,cutoffIndex) = mean(trialROM);
        CV(taskIndex,cutoffIndex) = 100*std(trialROM)/mean(trialROM);
    end
end

TGravity = table(tasks',ROMMean(:,1),ROMMean(:,2),ROMMean(:,3), ...
    CV(:,1),CV(:,2),CV(:,3), ...
    'VariableNames',{'Task','ROMMean_0p3Hz_deg','ROMMean_0p5Hz_deg', ...
    'ROMMean_1p0Hz_deg','CV_0p3Hz_pct','CV_0p5Hz_pct','CV_1p0Hz_pct'});
writetable(TGravity,fullfile(repoDir,'TableIII_gravity_sensitivity.csv'))
disp(TGravity)
