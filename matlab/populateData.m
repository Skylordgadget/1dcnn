function data = populateData(samplesPerGroup,numChannels,numGroups,dataIn)

tmp = ones(samplesPerGroup,numChannels);
k=1;
for i=1:numGroups
    j = mod(i,numChannels);

    if (j==0)
        tmp(:,numChannels) = dataIn(:,i);
        if (i==numChannels) 
            data = {tmp};
        else 
            data = [data;tmp];
        end
        k=k+1;
    else 
        tmp(:,j) = dataIn(:,i);
    end
end

end