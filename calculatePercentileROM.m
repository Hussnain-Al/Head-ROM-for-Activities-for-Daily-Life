function [ROM,lowerBound,upperBound] = calculatePercentileROM(x)
%CALCULATEPERCENTILEROM Return head ROM and its signed percentile bounds.
%   ROM is upperBound - lowerBound after omitting NaNs.

x = sort(x(~isnan(x)));
n = numel(x);
if n < 40
    ROM = NaN;
    lowerBound = NaN;
    upperBound = NaN;
    return
end

lowerIndex = max(1,round(0.025*n));
upperIndex = min(n,round(0.975*n));
lowerBound = x(lowerIndex);
upperBound = x(upperIndex);
ROM = upperBound-lowerBound;
end
