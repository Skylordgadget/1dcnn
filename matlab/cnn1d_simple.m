clear; clf;
wornData = readmatrix('../samples/original/worn_cutting_tool_samples.txt');
newData = readmatrix('../samples/original/new_cutting_tool_samples.txt');

samplesPerGroup = 256;
numChannels = 1;
filterSize = 5;
numFilters = 2;

dataCutOff = min([length(wornData);length(newData)]);
dataCutOff = dataCutOff - mod(dataCutOff, samplesPerGroup);

wornData = wornData(1:dataCutOff);
newData = newData(1:dataCutOff);

figure; 
subplot(2,2,1); plot(wornData); ca = gca; ylim = ca.YLim; ca.XLim = [1 dataCutOff];
title('Worn Tool Time Domain');
xlabel("Sample")
ylabel("Amplitude (mV)")
subplot(2,2,2); plot(newData); set(gca, "YLim", ylim, "XLim", [1 dataCutOff]);
title('New Tool Time Domain');
xlabel("Sample")
ylabel("Amplitude (mV)")
subplot(2,2,3); plot(wornData); ca = gca; ylim = ca.YLim; ca.XLim = [6800 7000];
title('Worn Tool Time Domain Exerpt');
xlabel("Sample")
ylabel("Amplitude (mV)")
subplot(2,2,4); plot(newData); set(gca, "YLim", ylim, "XLim", [6800 7000]);
title('New Tool Time Domain Exerpt');
xlabel("Sample")
ylabel("Amplitude (mV)")

figure; 
wDfft = fft(wornData);
P2 = abs(wDfft/dataCutOff);
P1 = P2(1:dataCutOff/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = 2500/dataCutOff*(0:(dataCutOff/2));

subplot(1,2,1); plot(f,P1);
title('Worn Tool Single-Sided Aplitude Spectrum');
xlabel("f (Hz)")
ylabel("|A|")

nDfft = fft(newData);
P2 = abs(nDfft/dataCutOff);
P1 = P2(1:dataCutOff/2+1);
P1(2:end-1) = 2*P1(2:end-1);

subplot(1,2,2); plot(f,P1);
title('New Tool Single-Sided Aplitude Spectrum');
xlabel("f (Hz)")
ylabel("|A|")


numGroups = dataCutOff/samplesPerGroup;

newData = reshape(newData,[samplesPerGroup,numGroups]);
wornData = reshape(wornData,[samplesPerGroup,numGroups]);

numObservations = numGroups/numChannels;

if (floor(numObservations)~=numObservations)
    error("numObservations (calculated: %f) must be an integer!", numObservations);
end

data = populateData(samplesPerGroup,numChannels,numGroups,newData);
data = [data;populateData(samplesPerGroup,numChannels,numGroups,wornData)];

labels = ones(numObservations,1);
labels = string([labels;zeros(numObservations,1)]);
labels(labels=="0") = "Worn";
labels(labels=="1") = "New";
labels = categorical(labels);

numObservations = numObservations*2;
[idxTrain,idxValidation,idxTest] = trainingPartitions(numObservations, [0.8 0.1 0.1]);
XTrain = data(idxTrain);
TTrain = labels(idxTrain);

XValidation = data(idxValidation);
TValidation = labels(idxValidation);

XTest = data(idxTest);
TTest = labels(idxTest);

classNames = categories(TTrain);
numClasses = numel(classNames);

layers = [ ...
    sequenceInputLayer(numChannels)
    convolution1dLayer(filterSize,numFilters,Padding="causal")
    reluLayer
    %layerNormalizationLayer
    % convolution1dLayer(filterSize,2*numFilters,Padding="causal")
    % reluLayer
    %layerNormalizationLayer
    globalAveragePooling1dLayer
    fullyConnectedLayer(numClasses)
    softmaxLayer];

options = trainingOptions("adam", ...
    MaxEpochs=60, ...
    InitialLearnRate=0.01, ...
    SequencePaddingDirection="left", ...
    ValidationData={XValidation,TValidation}, ...
    Plots="training-progress", ...
    Metrics="accuracy", ...
    Verbose=false);

net = dlnetwork(layers);

%figure;
%plot(net)

trainedNet = trainnet(XTrain,TTrain,net,"crossentropy",options);
save trainedNet;

scores = minibatchpredict(trainedNet,XTest,SequencePaddingDirection="left");
YTest = scores2label(scores, classNames);

acc = mean(YTest == TTest)

figure;
confusionchart(TTest,YTest)

csvwrite("../weights/latest/conv1d_weights.csv", trainedNet.Learnables.Value{1,1})
csvwrite("../weights/latest/conv1d_biases.csv", trainedNet.Learnables.Value{2,1})
csvwrite("../weights/latest/fc_weights.csv", trainedNet.Learnables.Value{3,1})
csvwrite("../weights/latest/fc_biases.csv", trainedNet.Learnables.Value{4,1})