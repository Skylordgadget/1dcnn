%% Load Files
clc; clf; close all; clear;

% set the path
recordings_path = '..\samples\recordings\piezo\trimmed\';

% get a list of all the files in the directory
files = readdir(recordings_path,'txt');
files = natsortfiles(files);

% load the contents of all the files into MATLAB (this takes some time)
recordings = loadrecordings(files);

percent_use = 0.1;

numPoints = 250; % 1 = no change

interpFactor = 1 / numPoints;

wornDataLength = floor(length(recordings{17}(:,2)) * percent_use);
xq = 1:interpFactor:wornDataLength;
vq = (interp1(recordings{17}(1:wornDataLength,2),xq))';

writematrix(vq,'worn_lerp_ch1.csv');

wornDataLength = floor(length(recordings{17}(:,4)) * percent_use);
xq = 1:interpFactor:wornDataLength;
vq = (interp1(recordings{17}(1:wornDataLength,4),xq))';

writematrix(vq,'worn_lerp_ch3.csv');

newDataLength = floor(length(recordings{1}(:,2)) * percent_use);
xq = 1:interpFactor:newDataLength;
vq = (interp1(recordings{1}(1:newDataLength,2),xq))';

writematrix(vq, 'new_lerp_ch1.csv');

newDataLength = floor(length(recordings{1}(:,4)) * percent_use);
xq = 1:interpFactor:newDataLength;
vq = (interp1(recordings{1}(1:newDataLength,4),xq))';

writematrix(vq, 'new_lerp_ch3.csv');