function [pdf, val] = genPDF_wn_v2(imSize, pa, pctg, pb, disp)

%[pdf,val] = genPDF(imSize,p,pctg [,distType,radius,disp])
%
%	generates a pdf for a 1d or 2d random sampling pattern
%	with polynomial variable density sampling
%
%	Input:
%		imSize - size of matrix or vector
%		p - power of polynomial
%		pctg - partial sampling factor e.g. 0.5 for half
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
% imSize=[256 256]; p=14; pctg=0.125; distType=2; radius=0; disp=1; 
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

% number of points we're going to sample, formerly was called PCTG
sample_points = floor(pctg*sx*sy);
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
% PCTG=floor(nnz(pdf)*val+sum(pdf(:)))
% PCTG-sum(pdf(:))=nnz(pdf)*val
% (PCTG-sum(pdf(:)))/nnz(pdf)=val
% this is REALLY close
% the floor operator is very hard to account for.
% could use these as updated minval and maxval
%
% I think used will always be numel, but i cant be certain, so this covers
% my bases. If you know better and it will alwys be, feel free to fix
% this.
used_points=nnz(f);
val_l=(sample_points-f_sum)/used_points;
val_h=(sample_points+1-f_sum)/used_points;
% but it appears simply repeating the val calc will work
% val=val_l/2+val_h/2;
val=mean([val_l,val_h]);
pdf = f + val; pdf(pdf>1) = 1;
N = floor(sum(pdf(:)));
if N ~= sample_points
    error('quick method failed');
end

%{ 
% begin bisection
its=0;
while(1)
    its=its+1;
    val = minval/2 + maxval/2;
    pdf = f + val; pdf(pdf>1) = 1;
    N = floor(sum(pdf(:)));
    if N > PCTG % infeasible
        maxval=val;
    end
    if N < PCTG % feasible, but not optimal
        minval=val;
    end
    if N==PCTG % optimal
        break;
    end
end
%}
%{
% same loop as above but with some time wasted collection.
over_trys=0;
under_trys=0;
minval=0;
maxval=1;
while(1)
    val = minval/2 + maxval/2;
    pdf = f + val;
    over_idx=pdf>1;
    pdf(over_idx) = 1;
    fprintf('%i over 1\n', nnz(over_idx));
    N = floor(sum(pdf(:)));
    if N > PCTG % infeasible
        maxval=val;
        over_trys=over_trys+1;
    end
    if N < PCTG % feasible, but not optimal
        minval=val;
        under_trys=under_trys+1;
    end
    if N==PCTG % optimal
        break;
    end
end
fprintf('scaling took %i tries, over target %i times, under target %i times\n', ...
    over_trys+under_trys, over_trys, under_trys);
%}

if disp
	figure,
	subplot(211), imshow(pdf)
	if sum(imSize==1)==0
		subplot(212), plot(pdf(end/2+1,:));
	else
		subplot(212), plot(pdf);
	end
end


% [mask,stat,actpctg] = genSampling(pdf,10,2);
%  size(find(mask==1))




