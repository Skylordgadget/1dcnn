%% Load Files
clc; clf; close all; clear;

% set the path
recordings_path = '..\samples\recordings\piezo\trimmed\';

% get a list of all the files in the directory
files = readdir(recordings_path,'txt');
files = natsortfiles(files);

% load the contents of all the files into MATLAB (this takes some time)
recordings = loadrecordings(files);

% variables
no_channels = 1;                    % number of channels
no_recordings = length(recordings); % number of recordings
worn_from = 14;                     % worn data starts from this recording

recordings_diff = {};

for i=1:no_recordings
    recordings_diff{i}(:,1) = recordings{i}(:,2) - recordings{i}(:,4);
    %recordings_diff{i}(:,2) = recordings{i}(:,3) - recordings{i}(:,5);
end



% adjustable stride
stride = 64; % you can change to 2, 4, 8, etc if memory is tight

%% Plot

figure();
for i=1:no_recordings
    for j=1:no_channels
        subplot(no_channels, no_recordings, ((j-1)*no_recordings)+i);
        plot(recordings_diff{i}(:,j));
        ylim([-2500 2000]);
    end
end

%% Create windows
windowSize = 512;

% collect windowed data and labels
X = {};
Y = strings(0);   % initialize empty string array

for i = 1:no_recordings
    rec = recordings_diff{i};  % all channels
    label = "New";
    if i >= worn_from
        label = "Worn";
    end

    % how many windows can we get
    numWindows = floor( (size(rec,1) - windowSize)/stride ) + 1;

    for w = 1:numWindows
        startIdx = (w-1)*stride + 1;
        endIdx = startIdx + windowSize - 1;
        window = rec(startIdx:endIdx, :); % window of size [256 x 4]
        X{end+1} = window;               % store as [4 x 256] for sequence
        Y(end+1) = label;                 % store label
    end
end

Y = categorical(Y(:));  % force column

numObservations = numel(Y);
idx = randperm(numObservations);

% shuffle once
X = X(idx);
Y = Y(idx);

% partition
nTrain = floor(0.8 * numObservations);
nVal   = floor(0.1 * numObservations);
nTest  = numObservations - nTrain - nVal;

idxTrain = 1:nTrain;
idxValidation = nTrain+1 : nTrain+nVal;
idxTest = nTrain+nVal+1 : numObservations;

XTrain = X(idxTrain);
TTrain = Y(idxTrain);

XValidation = X(idxValidation);
TValidation = Y(idxValidation);

XTest = X(idxTest);
TTest = Y(idxTest);

% sanity check
disp("Observations check:")
disp([length(XTrain) length(TTrain)])
disp([length(XValidation) length(TValidation)])
disp([length(XTest) length(TTest)])

%% Define CNN

filterSize = 5;
numFilters = 2; % increased filters for better representation
numClasses = numel(categories(Y));

layers = [ ...
    sequenceInputLayer(no_channels)
    convolution1dLayer(8,2,Padding="causal")
    reluLayer
    globalAveragePooling1dLayer
    fullyConnectedLayer(8)
    reluLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer];

options = trainingOptions("adam", ...
    MaxEpochs=1000, ...
    InitialLearnRate=0.001, ...
    SequencePaddingDirection="left", ...
    ValidationData={XValidation,TValidation}, ...
    Plots="training-progress", ...
    Metrics="accuracy", ...
    Verbose=false, ...
    ExecutionEnvironment="gpu");

net = dlnetwork(layers);

trainedNet = trainnet(XTrain,TTrain,net,"crossentropy",options);

save trainedNet;

%% Evaluate

load trainedNet.mat

scores = minibatchpredict(trainedNet,XTest,SequencePaddingDirection="left");
YTest = scores2label(scores, categories(Y));

TP = sum(TTest == "New" & YTest == "New");
FP = sum(TTest ~= "New" & YTest == "New");
FN = sum(TTest == "New" & YTest ~= "New");
TN = sum(TTest ~= "New" & YTest ~= "New");

accuracy  = (TP + TN) / (TP + TN + FP + FN);
precision = TP / (TP + FP);
recall    = TP / (TP + FN);
f1_score  = 2 * (precision * recall) / (precision + recall);

disp("Accuracy: " + accuracy)
disp("Precision: " + precision)
disp("Recall: " + recall)
disp("F1 Score: " + f1_score)

figure;
confusionchart(TTest,YTest)

%% Save weights

csvwrite("../weights/latest/conv1d_1_weights.csv", trainedNet.Learnables.Value{1,1})
csvwrite("../weights/latest/conv1d_1_biases.csv", trainedNet.Learnables.Value{2,1})

fc_parameters_1 = trainedNet.Learnables.Value{3,1};
fc_parameters_1 = [fc_parameters_1, trainedNet.Learnables.Value{4,1}]';
fc_parameters_1 = reshape(fc_parameters_1, [], 1);

fc_parameters_2 = trainedNet.Learnables.Value{5,1};
fc_parameters_2 = [fc_parameters_2, trainedNet.Learnables.Value{6,1}]';
fc_parameters_2 = reshape(fc_parameters_2, [], 1);

csvwrite("../weights/latest/fc_parameters_1.csv", fc_parameters_1);
csvwrite("../weights/latest/fc_parameters_2.csv", fc_parameters_2);
