function hCorr(vol_path,outPath)

% -----------------------------------------------------------
%	to correct for image nonuniformity
%	first fills in holes, then generates a low frequency
%	background image and makes correction factor
%	input image is stored in img, output is Iout
%
%	homocor.m  rev 0    4/8/00                Gary Glover
%	-----------------------------------------------------
%
%   Modified to deal with SPM99 analize format image files.
%   Produces a 'homocor.img' volume in the working directory.
%
%   Works with volumes acquired in any orientation, The inplane
%   is taken to be the plane where two of the volume dimensions
%   match. If all dimensions match, it will default to axial.
% -----------------------------------------------------------
%   @(#)vol_homocor.m    1.10  Kalina Christoff    2000-05-29
%
% this is a modification by LHG @ UM so that it can run without
% SPM mexfiles

% get the path
% ------------
%vol_path=spm_get(1, 'img', 'Please select image to correct');

%{
% load the volume
% ---------------
if ischar(vol_path)
  vol = spm_vol(vol_path);
end

% make a guess as to what orientation are the slices
% eg. vol.dim=[256 256 124 4] probably axial, etc
% --------------------------------------------------

if	 vol.dim(1)==vol.xdim % probably axial
            inpl_crd=[1 2]; thrpl_crd=3;
            orientation='axial';

 elseif  vol.xdim==vol.ydim % probably sagittal
            inpl_crd=[2 3]; thrpl_crd=1;
            orientation='sagittal';

 elseif  vol.dim(1)==vol.ydim % probably coronal
            inpl_crd=[1 3]; thrpl_crd=2;
            orientation='coronal';
end
%}

% $Id: myvol_homocor.m,v 1.1 2014/07/30 17:36:19 xsense Exp $
% -----------------------------------------------------------
% $Id: hCorr.m,v 1.2 Jared Burton 2020/05/13
%
% Edited file for compatibility with snakemake. Added input
% "outPath" so that the output file location can be specified
% by snakemake output, instead of adding prefix 'h' and saving
% in input directory.

try
  [p filename ext]= fileparts(vol_path);

  if strcmpi(ext,'.nii')
    [Y,h] = read_nii_img_reshape(vol_path);
    xdim = h.dim(2);
    ydim = h.dim(3);
    zdim = h.dim(4);
  else
    [data h] = read_img(vol_path);
    xdim = h.xdim;
    ydim = h.ydim;
    zdim = h.zdim;

    Y = reshape(data, h.xdim, h.ydim, h.zdim);
  end

  if xdim==ydim % probably axial
    inpl_crd=[1 2]; thrpl_crd=3;
    orientation='axial';

  elseif ydim==zdim % probably sagittal
    inpl_crd=[2 3]; thrpl_crd=1;
    orientation='sagittal';

  elseif xdim==zdim % probably coronal
    inpl_crd=[1 3]; thrpl_crd=2;
    orientation='coronal';
  end

  %foo = vol.dim(inpl_crd);
  %npix = foo(1);
  npix = xdim;
  np2 = npix/2;

  %thres = input('gimme threshold % [5] =');
  %if(isempty(thres))
  thres = 5;
  %end;
  thres = thres*.01;

  % Y = spm_read_vols(vol,0);

  orientation='axial';
  thrpl_crd=3;

  fprintf('\nAssuming the planes were acquired in ');
  fprintf(orientation); fprintf( ' orientation.\n\n');


  % initialize the corrected output volume Yc
  % Yc=zeros(vol.dim(1:3));
  Yc = zeros(size(Y));

  fprintf('Please wait - now working on plane    ');

  % begin looping through slices
  % ----------------------------
  %for slice = 1:vol.dim(thrpl_crd);
  % for slice = 1:h.zdim;
  for slice = 1:zdim
    if slice<10; fprintf('\b%d',slice);
    elseif slice<100,  fprintf('\b\b%d',slice);
    elseif slice<1000, fprintf('\b\b\b%d',slice);
    end

    % surprisingly, Y needs to be squeezed to remove the singleton
    % dimensions for coronal or sagittal... interesting command.
    % ---------------------------------------------------------------

    if thrpl_crd==1; img=squeeze(Y(slice,:,:)); end;
    if thrpl_crd==2; img=squeeze(Y(:,slice,:)); end;
    if thrpl_crd==3; img=squeeze(Y(:,:,slice)); end; % though no need here


    Imax = max(max(img));
    Ithr = Imax*thres;

    %  fill in holes

    mask = (img>Ithr);
    Imask = img.*mask;
    Iave = sum(sum(Imask))/sum(sum(mask));
    Ifill = Imask + (1-mask).*Iave;

    %  make low freq image

    z = fftshift(fft2(Ifill));

    %ndef = 3;
    ndef = np2/8;
    n = ndef;

    y2 = (1:np2).^2;  % use 15 as default win for guassian
    a2 = 1/n;
    for x=1:np2
      r2 = y2 +x*x;
      win1(x,:) = exp(-a2*r2);
    end

    win(np2+1:npix,np2+1:npix) = win1;
    win(np2+1:npix,np2:-1:1) = win1;
    win(1:np2,:) = win(npix:-1:np2+1,:);
    zl = win.*z;

    Ilow = abs(ifft2(fftshift(zl)));

    %corrected image

    Ilave = sum(sum(Ilow.*mask))/sum(sum(mask));
    Icorf = (Ilave./Ilow).*mask;  % correction factor
    Iout = img.*Icorf;

    % update the volume with the corrected values
    % -------------------------------------------
    if thrpl_crd==1; Yc(slice,:,:) = Iout; end
    if thrpl_crd==2; Yc(:,slice,:) = Iout; end
    if thrpl_crd==3; Yc(:,:,slice) = Iout; end

    Yc(:,:,slice) = Iout;
    clear img;

    % end looping through slices
    % ---------------------------
  end

  fprintf('\n\nDone.\n\n')

  % write corrected image (homocor.img)
  % ==================================

  %Yc_vol = vol;
  %Yc_vol.fname   ='homocor';
  %Yc_vol.descrip ='homocor';

  % Write out image.
  if strcmpi(ext,'.nii')
     write_nii([outPath], Yc, h,0);
  else
     write_img([outPath], Yc, h);
  end
catch ME
  %print error messages
  fprintf('MATLAB code threw an exception:\n')
  fprintf('%s\n',ME.message);
  if length(ME.stack) ~= 0
    for i = 1:length(ME.stack)
      fprintf('File:%s\nName:%s\nLine:%d\n',ME.stack(i).file,...
        ME.stack(i).name,ME.stack(i).line);
    end
  end
end

end
