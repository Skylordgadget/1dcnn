classdef PiezoWindowDatastore < matlab.io.Datastore & ...
                                 matlab.io.datastore.MiniBatchable
    properties
        Recordings      % Cell array of recordings
        Labels          % String labels per recording
        WindowLength    % Size of each sliding window
        Stride          % Step between windows
    end

    properties (Access = private)
        FileIdx = 1
        SampleIdx = 1
    end

    methods
        function ds = PiezoWindowDatastore(recordings, worn_from, windowLength, stride)
            ds.Recordings = recordings;
            ds.WindowLength = windowLength;
            ds.Stride = stride;

            % Assign labels ("New" before worn_from, "Worn" after)
            ds.Labels = strings(length(recordings),1);
            ds.Labels(1:worn_from-1) = "New";
            ds.Labels(worn_from:end) = "Worn";
        end

        function tf = hasdata(ds)
            tf = ds.FileIdx <= numel(ds.Recordings);
        end

        function [data, label] = read(ds)
            batchData = {};
            batchLabels = {};
            maxBatchSize = 128;
            count = 0;

            while count < maxBatchSize && ds.FileIdx <= numel(ds.Recordings)
                rec = ds.Recordings{ds.FileIdx}(:, 2:end);  % drop time col
                totalSamples = size(rec, 1);

                while ds.SampleIdx + ds.WindowLength - 1 <= totalSamples && count < maxBatchSize
                    segment = rec(ds.SampleIdx:ds.SampleIdx+ds.WindowLength-1, :);
                    batchData{end+1} = segment';
                    batchLabels{end+1} = ds.Labels(ds.FileIdx);
                    ds.SampleIdx = ds.SampleIdx + ds.Stride;
                    count = count + 1;
                end

                if ds.SampleIdx + ds.WindowLength - 1 > totalSamples
                    ds.FileIdx = ds.FileIdx + 1;
                    ds.SampleIdx = 1;
                end
            end

            data = batchData';                  % cell array of [C x T] sequences
            label = categorical(batchLabels');  % categorical vector
        end

        function reset(ds)
            ds.FileIdx = 1;
            ds.SampleIdx = 1;
        end

        function n = numOutputs(ds)
            n = 2; % data and label
        end

        function dsNew = shuffle(ds)
            idx = randperm(numel(ds.Recordings));
            dsNew = PiezoWindowDatastore(ds.Recordings(idx), 1, ds.WindowLength, ds.Stride);
            dsNew.Labels = ds.Labels(idx);
        end

        function out = preview(ds)
            r = ds.Recordings{1}(:, 2:end);
            out = {r(1:ds.WindowLength, :)'};
        end
    end
end
