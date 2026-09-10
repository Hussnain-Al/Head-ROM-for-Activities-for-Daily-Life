function [angles,pctKept,quality] = readHeadTrial(folder,cfg,walking,window)
%READHEADTRIAL Process one phone recording into three head-angle channels.
% Columns of ANGLES: flexion-extension, lateral bending, axial rotation.

if nargin < 4
    window = cfg.window;
end

gyroTable = readtable(fullfile(folder,'Gyroscope.csv'));
accTable = readtable(fullfile(folder,'TotalAcceleration.csv'));
gyroTime = gyroTable.seconds_elapsed;
accTime = accTable.seconds_elapsed;

quality.measuredRateHz = 1/median(diff(gyroTime));
assert(abs(quality.measuredRateHz-cfg.sampleRateHz) < 0.2*cfg.sampleRateHz, ...
    '%s logged at %.1f Hz.',folder,quality.measuredRateHz)

% Use only the time span recorded by both sensors, then create a uniform clock.
commonStart = max(gyroTime(1),accTime(1));
commonEnd = min(gyroTime(end),accTime(end));
t = (commonStart:1/cfg.sampleRateHz:commonEnd)';
gyro = interp1(gyroTime,[gyroTable.x gyroTable.y gyroTable.z],t,'linear');
acc = interp1(accTime,[accTable.x accTable.y accTable.z],t,'linear');

% Estimate the slowly varying gravity direction.
[gravityB,gravityA] = butter(2,cfg.gravityCutoffHz/(cfg.sampleRateHz/2));
gravity = filtfilt(gravityB,gravityA,acc);
gravity = gravity./vecnorm(gravity,2,2);

% Find the quietest complete 10 s neutral hold within the first 30 s.
neutralSamples = round(cfg.neutralDuration*cfg.sampleRateHz);
relativeTime = t-t(1);
gyroMagnitude = vecnorm(gyro,2,2);
quietScore = movmean(gyroMagnitude,[0 neutralSamples-1]);
sampleNumber = (1:numel(t))';
candidateStarts = find(relativeTime <= ...
    cfg.neutralSearchEnd-cfg.neutralDuration & ...
    sampleNumber+neutralSamples-1 <= numel(t) & ...
    t(min(sampleNumber+neutralSamples-1,numel(t)))+cfg.margin+window <= t(end));
assert(~isempty(candidateStarts),'%s: no complete neutral hold found.',folder)
[~,bestCandidate] = min(quietScore(candidateStarts));
neutralStart = candidateStarts(bestCandidate);
neutralRows = neutralStart:neutralStart+neutralSamples-1;

% Build a trial-specific head frame from the neutral gravity direction.
headVertical = mean(gravity(neutralRows,:),1);
headVertical = headVertical/norm(headVertical);
phoneForward = zeros(1,3);
phoneForward(cfg.phoneForwardAxis) = 1;
headForward = phoneForward-(phoneForward*headVertical')*headVertical;
headForward = headForward/norm(headForward);
headFrame = [headForward; cross(headVertical,headForward); headVertical];
quality.neutralPhoneInclinationDeg = 90-acosd(max(-1,min(1, ...
    phoneForward*headVertical')));

% Convert gravity direction into head flexion-extension and lateral bending.
headGravity = gravity*headFrame';
pitch = cfg.flexionSign*atan2d(headGravity(:,1),headGravity(:,3));
roll = atan2d(headGravity(:,2),headGravity(:,3));
quality.neutralHoldSDDeg = std(pitch(neutralRows));

% Convert filtered, bias-corrected yaw rate into axial head angle.
[yawB,yawA] = butter(2,cfg.yawCutoffHz/(cfg.sampleRateHz/2));
neutralGyroBias = mean(gyro(neutralRows,:),1);
yawRate = rad2deg((gyro-neutralGyroBias)*headVertical');
yawRate = filtfilt(yawB,yawA,yawRate);
yaw = cumtrapz(t,yawRate);

% Start after the neutral hold and margin, then select the fixed window.
analysisStartTime = t(neutralRows(end))+cfg.margin;
firstRow = find(t >= analysisStartTime,1);
lastRow = firstRow+window*cfg.sampleRateHz-1;
assert(lastRow <= numel(t),'%s: insufficient data after the neutral hold.',folder)
selectedRows = firstRow:lastRow;
windowTime = (0:numel(selectedRows)-1)'/cfg.sampleRateHz;

% Remove the residual linear trend from integrated yaw.
yawLine = polyfit(windowTime,yaw(selectedRows),1);
quality.yawTrendDegPerSec = yawLine(1);
angles = [pitch(selectedRows),roll(selectedRows), ...
          yaw(selectedRows)-polyval(yawLine,windowTime)];

% Remove lap turns only from the walking task.
if walking
    turning = movmax(double(abs(yawRate(selectedRows)) > ...
        cfg.turnRateDegPerSec),2*cfg.sampleRateHz) > 0;
    angles(turning,:) = NaN;
    pctKept = 100*mean(~turning);
else
    pctKept = 100;
end
end
