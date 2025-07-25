function [idxTrain, idxVal, idxTest] = trainingPartitions(numObservations, splits)
    % splits is e.g. [0.8 0.1 0.1]
    idxAll = randperm(numObservations);
    Ntrain = floor(splits(1)*numObservations);
    Nval   = floor(splits(2)*numObservations);
    Ntest  = numObservations - Ntrain - Nval;

    idxTrain = idxAll(1:Ntrain);
    idxVal   = idxAll(Ntrain+1:Ntrain+Nval);
    idxTest  = idxAll(Ntrain+Nval+1:end);
end