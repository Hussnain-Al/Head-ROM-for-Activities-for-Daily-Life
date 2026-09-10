function ROM = calculatePercentileROM(x)
%CALCULATEPERCENTILEROM Return the 2.5th-to-97.5th percentile head ROM.

x = sort(x(~isnan(x)));
n = numel(x);
if n < 40
    ROM = NaN;
    return
end

lowerIndex = max(1,round(0.025*n));
upperIndex = min(n,round(0.975*n));
ROM = x(upperIndex)-x(lowerIndex);
end
