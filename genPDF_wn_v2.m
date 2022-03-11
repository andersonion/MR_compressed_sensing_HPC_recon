function [pdf, val] = genPDF_wn_v2(imSize, pa, sample_fraction, pb, disp)
%[pdf,val] = genPDF_wn_v2(imSize,p,sample_fraction [,distType,radius,disp])
%
%	generates a pdf for a 1d or 2d random sampling pattern
%	with polynomial variable density sampling
%
%	Input:
%		imSize - size of matrix or vector
%		p - power of polynomial
%		sample_fraction - partial sampling factor e.g. 0.5 for half
%		distType - 1 or 2 for L1 or L2 distance measure
%		radius - radius of fully sampled center
%		disp - display output
%
%	Output:
%		pdf - the pdf
%		val - min sampling density
%
% 
%	Example:
%	[pdf,val] = genPDF([128,128],2,0.5,2,0,1);
%
%	(c) Michael Lustig 2007
% imSize=[256 256]; p=14; sample_points=0.125; distType=2; radius=0; disp=1; 
%{
val = 0.5;
if length(imSize)==1
	imSize = [imSize,1];
end
%}
if 3 < numel(imSize)
    % many values, assume it is an example file
    imSize=size(imSize);
end
if numel(imSize)<2
    imSize(2)=imSize(1);
end
if numel(imSize)<3
    imSize(3)=1;
end
sx = imSize(1);
sy = imSize(2);
sz = imSize(3);

% number of points we're going to sample, formerly was called sample_points
sample_points = floor(sample_fraction*sx*sy);
% % a=3;b=2.5;
%{
if sum(imSize==1)==0  % 2D
	[x,y] = meshgrid(linspace(-1,1,sy),linspace(-1,1,sx));
	switch distType
		case 1
			r = max(abs(x),abs(y));
		otherwise
			r = ((sqrt(x.^2+y.^2)).^2.1);
			r = r/max(abs(r(:)));			
	end
else %1d
	r = abs(linspace(-1,1,max(sx,sy)));
end
figure;imshow(r,[])
idx = find(r<radius);
pdf = (1-r).^p; pdf(idx) = 1;
%}
if sz == 1
    [y,x] = meshgrid(-sy/2:sy/2-1,  -sx/2:sx/2-1);
else
    % 3d case, which so far we never have
    % it may not matter to omit the third parameter because we were using a
    % size of 1, at least its more obvious this way.
    error('3D case NOT COMPLETE');
    [y,x,z] = meshgrid(-sy/2:sy/2-1,  -sx/2:sx/2-1,  -sz/2:sz/2-1);
end
% f1=exp(-((pb*sqrt(x.^2)/sx).^pa)); f2=exp(-((pb*sqrt(y.^2)/sy).^pa));
% f1=sqrt(exp(-((pb*sqrt(x.^2)/sx).^pa))); f2=sqrt(exp(-((pb*sqrt(y.^2)/sy).^pa)));
% for most cases we have x and y as the same value, so f1 and f2 will be
% identical.
f1=sqrt(exp(-((pb*sqrt(x.^2+y.^2)/sx).^pa)));
if sx==sy
    f2=f1;
else
    f2=sqrt(exp(-((pb*sqrt(y.^2+x.^2)/sy).^pa)));
end
f=f1.*f2;
% normalize f == 0-1
f=f/max(f(:));
% figure;imshow(f,[]); figure;plot(1:sx,f1)
f_sum=sum(f(:));
if floor(f_sum) > sample_points
	error('infeasible without undersampling dc, change pa or pb');
end

% It appears the bisection loop could be replaced with one line, solving
% for val
% sample_points=floor(nnz(pdf)*val+sum(pdf(:)))
% sample_points-sum(pdf(:))=nnz(pdf)*val
% (sample_points-sum(pdf(:)))/nnz(pdf)=val
% It is REALLY close
% the floor operator is very hard to account for.
% Its also hard to account for truncating the points because we dont
% know how many are going to be too high!
%
% I think used_points will always be numel, but i cant be certain, so this 
% % covers my bases. If you know better and it will alwys be, feel free to
% fix this.
used_points=nnz(f);
minval=(sample_points-f_sum)/used_points;
% this is not a valid maxval for bisection! it can be too low!
maxval=(sample_points+1-f_sum)/used_points;
% this could be used to initialize bisection
% maxval=(sample_points*1.01-f_sum)/used_points;
% this might be a closer bisection initializer
% maxval=(sample_points+10-f_sum)/used_points;
val=mean([minval,maxval]);
pdf = f + val;
pdf_truncate_idx=pdf>1;
pdf(pdf_truncate_idx) = 1;
pdf_sum=sum(pdf(:));
N = floor(pdf_sum);
% hos much did we not account for, maybe this could be used as the
% tollerance factor?
res=sample_points-pdf_sum;
if N ~= sample_points
    % this has failed me one time, HOWEVER when run a second time with the 
    % same input it didnt fail! .... no rational explaination available.
    % running a few more times and it failed consistently.
    %
    % the reason this fails is the truncation to 1, we dont know how many
    % points will be over 1 when we calculate.
    % 
    % we could adjust by counting number of points over 1, and remvoing them 
    % from the used points. We could loop that, but then we're back to
    % looping.
    %
    % we can provide a decent guess of maxval, and run the bisect loop, at 
    % this point its not clear if the bisect loop was really the problem
    % with long runtime in this function or not.
    warning('quick method failed! running bisect loop');
    truncated_pts=nnz(pdf_truncate_idx);
    maxval=(sample_points+1-f_sum)/(used_points-truncated_pts);
    [pdf,val]=bisect_pdf_loop(sample_points,f,minval,maxval);
end

if disp
	figure,
	subplot(211), imshow(pdf)
	if sum(imSize==1)==0
		subplot(212), plot(pdf(end/2+1,:));
	else
		subplot(212), plot(pdf);
	end
end

% [mask,stat,actsample_points] = genSampling(pdf,10,2);
%  size(find(mask==1))

end

function [pdf,val]=bisect_pdf_loop(sample_points,f,minval,maxval)
%{
% begin bisection
%%% minval=0;maxval=1;
its=0;
while(1)
    its=its+1;
    val = minval/2 + maxval/2;
    pdf = f + val; pdf(pdf>1) = 1;
    N = floor(sum(pdf(:)));
    if N > sample_points% infeasible
        maxval=val;
    end
    if N < sample_points % feasible, but not optimal
        minval=val;
    end
    if N==sample_points % optimal
        break;
    end
end
%}


% same loop as above but with some time wasted collection.
over_trys=0;
under_trys=0;
%minval=0;
%maxval=1;
limit=1000;
% if we're given bad min/max vals they could end up equal, trapping us in
% the loop.
while(limit && minval~=maxval)
    val = minval/2 + maxval/2;
    pdf = f + val;
    pdf_truncate_idx=pdf>1;
    pdf(pdf_truncate_idx) = 1;
    fprintf('%i over 1\n', nnz(pdf_truncate_idx));
    N = floor(sum(pdf(:)));
    if N > sample_points % infeasible
        maxval=val;
        over_trys=over_trys+1;
    end
    if N < sample_points % feasible, but not optimal
        minval=val;
        under_trys=under_trys+1;
    end
    if N==sample_points % optimal
        break;
    end
    limit=limit-1;
end
fprintf('scaling took %i tries, over target %i times, under target %i times\n', ...
    over_trys+under_trys, over_trys, under_trys);
if N~=sample_points
    error('failed to properly scale pdf to %i',sample_points);
end
end


