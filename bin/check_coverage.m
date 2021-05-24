function coverage = check_coverage(niiFile,maskFile,outFile)
%% FUNCTION NOTES

% For use with SPM99 and SPM99-formatted Analyze images
%                ----OR----
%         with SPM2 and SPM2-formatted Analyze images!
%
% Special treatment is made in the masking and sphere cases
% (regionType 'r', 's') so that voxels in the mask for which
% the image has value NaN (not a number) are ignored
% (i.e., not used for either the sum or the number of
% voxels when computing the mean over the region)
%
% Version history:
% @(#)sjf_get_vals.m	1.13 01/12/07

% Development notes
%
% Nearest neighbor setting for spm_sample_vol simply return 0
% for voxel coordinates outside of volume (good).
%
% SPM99 code where dim, orientation/position are verified as
% same:  spm_spm.m, line 416
%
% SPM99 code where masking is done:  spm_spm.m, about line 700
%
% For regionType == 'r', tested once
%
% 2005-07-21
%   - Added ability to handle masks that are translated wrt data
% 2005-07-25
%   - Added ability to handle masks and images such that mask
%     includes NaN regions of image.
% 2005-07-27
%   - Completed handling of single voxels
% 2005-10-18
%   - Merged spm_get_vals.m (for SPM2) with
%     spm_get_vals_99.m (for SPM99).  Almost exactly same as
%     version 1.7 08/04/05 of spm_get_vals_99.m, except for
%     name and beginning stuff forking SPM99 or SPM2.
% 2005-11-23
%   - Merged code for computation of value for sphere, region
%     + NaNs in spheres now treated like NaNs in region (a mean
%       is computed over the finite values, with number of
%       such voxels listed)
% 2007-01-06
%   - Moved shear checking into a function (minor)
%   - Added code to more fully emulate ez_measure_roi_vals
%     (using a conjunction mask); see also sjf_measure_roi_vals
% 2019-09-18 Jared
%   - Reformatted script to work within MiND lab batch system steps
%   - Primarily includes removing interactive elements and specifying as
%     variables instead
% Testing notes
% 2005-07-25
%   - Verified for one example that translating the mask (using
%     the "origin" field of *.hdr (under the SPM version of the
%     Analyze format) makes no difference to the answer.
%     + Was able to do this easily because Linda has older version
%       of Pine's groups masks.  And the new versions have left/right
%       centered origins, unlike the older ones, but give the same
%       answers.
%   - Verified for one example that the new code allowing NaN values
%     in the image within the mask works.
% 2005-10-18
%   - New version joining SPM99 and SPM2 versions tested once, using
%     's' option.
% 2005-11-23
%   - Tested new version on voxel, sphere, region, comparing it to
%     old version.  Tests passed.  Didn't actually compare to result
%     of doing computation manually.
% 2007-01-07
%   - Ran program a few times using region and sphere, and conjunction
%     mask.  Seemed fine.
%   - Ran after adding capability for multiple ROIs.  Did case of using
%     a conjunction mask (this function called from
%     sjf_measure_roi_vals), with multiple ROI masks, as well as multiple
%     spheres.



%% %%%%%%%%%% SET VARIABLES %%%%%%%%%%%%%%%%%
try
  %get this directory for lib/masks
  roi = {maskFile};

  %specify con image for roi
  t_images = {niiFile};

  isfiniteFlag = 1;
  useConjMask = 0;
  regionType = 'r'; %specifying roi (other options 'v' or 's' for voxes/spheres)
  fileListType = 't'; %t = text file; ('g' = use the gui [boo!])

  %% %%%%%%%%%% GET COVERAGE %%%%%%%%%%%%%%%%%
  if regionType=='r' % region
  %   Get mask
    if useConjMask
      maskName = cellstr(spm_select(Inf,filterName,{'ROI mask(s)'}));
    else
      maskName = cellstr(strcat(roi, ',1'));
    end
    numROIs = length(maskName);
  elseif regionType == 's' || regionType == 'v'
    fprintf(1,'For each ');
    if regionType == 's'
      fprintf(1,'sphere, ');
    elseif regionType == 'v'
      fprintf(1,'voxel, ');
    end
    fprintf(1, 'enter 3 coordinates in mm.\n');
    fprintf(1, 'These are MNI or Talairach coordinates, ');
    fprintf(1, 'not voxel coordinates.\n\n');

    fprintf(1, 'You may enter each set of three coordinates either \n');
    fprintf(1, '*i*nputting here on the screen, or by using a ');
    fprintf(1, '*t*ext file.\n');
    choiceIT = input('Please type i or t:  ','s');
    if isequal(choiceIT,'i')
      % NOT DONE
      allCoords = [];
      while 1
        coordsTmp = input('Coordinates:  ','s');
        coordsTmp = sscanf(coordsTmp,'%f');
        if ~isequal(size(coordsTmp),[3 1])
          error('You must enter 3 coordinates.')
        end
        allCoords = [allCoords, coordsTmp];
        moreCoords = input(['Do you want to enter another set of ' ...
                        'coordinates (y/n)?:  '], 's');
        if isequal(moreCoords,'n')
          break;
        elseif ~isequal(moreCoords,'y')
          error('You need to enter y/n.  Quitting.')
        end
      end
    elseif isequal(choiceIT,'t')
      % Get filename
      coordsList = spm_select(1,'','Coordinates file');
      [a,b,c] = textread(coordsList,'%n %n %n');
      allCoords = [a';b';c'];     % Make sure you force column vector
    else
      error('You must enter either i or t.  Quitting...');
    end

    numROIs = size(allCoords,2);

    % LATER:  Allow multiple radii
    % Postponing this for now because control flow below
    % assumes one list of regions, and to do that with
    % spheres we'd have to change two dimensions
    % (center, radius) into one dimension (since list is
    % one dimension)

    if regionType == 's'
      r = input('Enter radius in mm:  ');
      if ~isequal(size(r),[1 1]) | r <= 0
        error('You must enter a legitimate radius');
      end
    end

  else
    disp('You must answer ''v'', ''s'', or ''r''.');
    error('Program exiting.');
  end

  % Get images
  switch fileListType
    case 'g'
      images = spm_select(Inf,filterName,'Images');
    case 't'
      files = strcat(t_images, ',1');
      images = char(files);
    otherwise
      disp('You must answer ''g'' or ''t''.');
      error('Program exiting.');
  end % switch fileListType

  numImages = size(images,1);

  % Verify data images have same dimensions, orientation, position
  fprintf(1,'Memory mapping images...');
  for i=1:numImages
    v{i} = spm_vol(images(i,:));
    % Verify images are in same space
    if ~isequal(v{i}.dim(1:3),v{1}.dim(1:3))
      error('Images must have same dimensions.')
    end
    % Verify orientation/position are the same
    if ~isequal(v{i}.mat,v{1}.mat)
      error('Images must have same orientation/position.')
    end
  end
  fprintf(1,'done.\n');

  % Verify no shears (images)
  check_shears(v{1},'Image mat files have shears.')
  mat = v{1}.mat;
  mat3d = mat(1:3,1:3);

  % Conjunction mask
  if useConjMask
    % get mask
    conjMaskName = spm_get(1,'conj_mask.img','conjunction mask');
    conjMask = spm_vol(conjMaskName);

    % Check to see if conjunction mask "consistent" with images.
    % I.e., should be in same space, as conj mask should have been
    % generated from these images, or a superset of them.  Note that don't
    % need to check conj mask for shears, as have already checked images
    % in same space
    if ~isequal(conjMask.dim(1:3),v{1}.dim(1:3))
      error(['Conjunction mask, data images don''t have same ' ...
             'dimensions.  Quitting.']);
    end
    % Verify conj mask, data images have same orientation/position
    if ~isequal(conjMask.mat,v{1}.mat)
      error(['Conjunction mask, data images don''t have same ' ...
            'orientation/position.  Quitting.']);
    end
  end

  % Split image file pathnames into common first part, differing
  % remainder, in order to make output more user-friendly
  if numImages > 1
    loc = ones(1,size(images,2));
    for i=2:numImages
      loc = loc.*(images(1,:)==images(i,:));
    end % for i=2:numImages
    ind1 = min(find(loc==0)) - 1;
    % What if everything is in common? (E.g., repeated filename)
    % find returns empty, so does min(...) and min(...)-1
    if(isempty(ind1))
      ind1 = size(loc,2);
    end
    % If there's nothing in common, ind1==0.  Resulting behavior OK:
    %   - common1 is empty
    %   - ind2 is empty
    common1 = images(1,1:ind1);
    ind2 = max(findstr('/',common1));
  end % if numImages > 1

  if numImages==1 || isempty(ind2)
    commonDir = '';
    truncImgNames = images;
  else
    commonDir = images(1,1:ind2);
    truncImgNames = images(:,(ind2+1):size(images,2));
  end

  %print to file
  fidOut = fopen(outFile,'a');

  fprintf(fidOut,'Base directory:  %s\n\n',commonDir);

  if useConjMask
    fprintf(fidOut,'Conjunction mask:  %s\n\n',conjMaskName);
  end

  % Get voxel coords; get voxel values; print
  for idxROI=1:numROIs

    if regionType == 's'

      coords = allCoords(:,idxROI);

      % Take world coords ==> vox coords

      vox_coords = inv(mat)*[coords;1];

      % - Find integer locations within each radius
      %   + ceil(x0 - r/s_x):  floor(x0 + r/s_x)

      % Don't worry about which direction ellipsoid is largest in
      rvox = r/min(svd(mat3d));
      for i=1:3
        voxCoordList{i} = 1:v{1}.dim(i);
        voxCoordCan{i} = find(abs(voxCoordList{i} - vox_coords(i)) <= rvox);
      end

      voxCand = [];

      for i=voxCoordCan{1}
        for j=voxCoordCan{2}
          for k=voxCoordCan{3}
            voxCand = [voxCand, [i, j, k, 1]'];
          end
        end
      end

      % - Include if dist < r
      % - Convert back to mm, stick into spm_samp_vol, select NN
      mmCand = mat*voxCand;
      tmp = mmCand - [coords; 1]*ones(1,size(mmCand,2));
      mmWinners = mmCand(:,find(sum(tmp.*tmp) <= r^2));
      vROIdata = inv(mat)*mmWinners;

      fprintf(fidOut, '\n\n---------------------------------------------');
      fprintf(fidOut, '--------------------------\n\n');

      fprintf(fidOut, ...
       '\n\nSphere:  center = (%.1f,%.1f,%.1f), radius = %.1f\n\n', ...
       coords(1), coords(2), coords(3), r);

      fprintf(fidOut,'Number of voxels in the sphere:  ');
      fprintf(fidOut,'%d\n\n',size(vROIdata,2));

    elseif regionType == 'v'
      coords = allCoords(:,idxROI);

      % Take world coords ==> vox coords
      vROIdata = inv(mat)*[coords;1];

      fprintf(fidOut, ...
       'Voxel:  coords = (%.1f,%.1f,%.1f)\n\n', ...
       coords(1), coords(2), coords(3));

    elseif regionType == 'r'

      % If using ROI/mask, verify mask, data images have same dimensions,
      % orientation, position
      mask = spm_vol(maskName{idxROI});
      % Verify mask, data images are in same space
      if ~isequal(mask.dim(1:3),v{1}.dim(1:3))
        fprintf(1, '\nMask\n    %s\n', maskName{idxROI});
        fprintf(1, 'and data images don''t have same dimensions.\n');
        fprintf(1, 'Use with caution.\n\n');
      end
      % Verify mask, data images have same orientation/position
      if ~isequal(mask.mat,v{1}.mat)
        fprintf(1, '\nMask\n    %s\n', maskName{idxROI});
        fprintf(1, 'and data images don''t have same orientation/position.\n');
        fprintf(1, 'Use with caution.\n\n');
      end

      % Verify no shears (region)
      check_shears(mask,'Mask mat file has shears.');

      % Got rid of triple for loop:  too slow
      fprintf(1,'Creating voxel coord matrix...');

      vx = subfunc1(mask.dim(1),mask.dim(2),mask.dim(3));
      vy = subfunc1(mask.dim(2),mask.dim(1),mask.dim(3));
      vy = permute(vy,[2 1 3]);
      vz = subfunc1(mask.dim(3),mask.dim(2),mask.dim(1));
      vz = permute(vz,[3 2 1]);

      fprintf(1,'done.\n');

      % Force to be row vectors
      vx = vx(:)';
      vy = vy(:)';
      vz = vz(:)';

      fprintf(1,'Sampling mask...');
      indexMask = find(spm_sample_vol(mask,vx,vy,vz,0)>0);
      fprintf(1,'done.\n');

      vxROI = vx(indexMask);
      vyROI = vy(indexMask);
      vzROI = vz(indexMask);
      sizeMask = length(indexMask);

      vROI = [vxROI; vyROI; vzROI; ones(1,sizeMask)];

      % Go from voxel coords mask to voxel coords data
      m2v = inv(mat)*mask.mat;

      % For now, allow translations but not rotations or different voxel
      % sizes (which would show up as dilations)
      if(norm(abs(m2v(1:3,1:3)) - eye(3),'fro') > 1e-8)
        error(['Mask and data have different voxel sizes or ', ...
               'different orientations.  This script is not ', ...
               'equipped to handle that.  Quitting.']);
      end

      % For now at least, insist only on grid-preserving translations
      if(max(abs(m2v(1:3,4) - round(m2v(1:3,4)))) > 1e-8)
        error('Not equipped to handle non-grid-preserving translations.');
      end

      vROIdata = m2v*vROI;

      fprintf(fidOut, '\n\n---------------------------------------------');
      fprintf(fidOut, '--------------------------\n\n');

      fprintf(fidOut, '\n\nRegion (mask):  %s\n', maskName{idxROI});

      fprintf(fidOut,'Number of voxels in the region:  ');
      fprintf(fidOut,'%d\n\n',sizeMask);

    end % END if regionType == 's', ...

    if useConjMask
      % Look at intersection of mask, conjunction mask
      valsConjMask = spm_sample_vol(v{i},vROIdata(1,:),vROIdata(2,:), ...
                            vROIdata(3,:),0);  % 0 means nearest neighbor
      % Language note:  "Inf > 0" is true, so used:
      intersectionIndex = isfinite(valsConjMask) & (valsConjMask > 0);

      if isequal(regionType,'s')
        regionName = 'sphere';
      elseif isequal(regionType,'r')
        regionName = 'region';
      elseif isequal(regionType,'v')
        regionName = 'voxel';
      end

      if isempty(intersectionIndex)
        msg = ['Conjunction mask and ' regionName];
        msg = [msg 'you selected don''t intersect.  Quitting.'];
        error(msg);
      end

      if length(intersectionIndex) ~= size(vROIdata,2)
        vROIdata = vROIdata(:,intersectionIndex);
        fprintf(fidOut,'Fraction of values in %s', regionName);
        fprintf(fidOut,'that are also conjunction mask:  %f\n\n',...
                length(intersectionIndex)/size(vROIdata,2));
      end
    end

    for i=1:numImages

      % Language note:  syntax vROIdata(1,:) is OK even in case
      % of sphere where vROIdata is a col vector not a matrix
      vals = spm_sample_vol(v{i},vROIdata(1,:),vROIdata(2,:), ...
                            vROIdata(3,:),0);  % 0 means nearest neighbor
      val = mean(vals);
      if isfinite(val)
        fprintf(fidOut,'%s\t%f\n',truncImgNames(i,:),val);
      else
        isfiniteFlag = 0;
        valsFinite = vals(isfinite(vals));
        numVox = length(valsFinite);
        if numVox==0
          fprintf(fidOut,'%s\t"No voxels"\t0\n',truncImgNames(i,:));
        else
          val = mean(vals(isfinite(vals)));
          fprintf(fidOut,'%s\t%f\t%d\n',truncImgNames(i,:),val,numVox);
        end
      end
    end

  end % END for i=1:numROIs

  %% Calculate coverage and close out
  %numVox doesn't get set if all voxels are present, so we'll set it here
  %to be all voxels if that's the case
  if ~exist('numVox','var')
      numVox = sizeMask;
  end

  coverage = numVox / sizeMask; %percent coverage
  fprintf(fidOut,'%f\n',coverage);
  fclose(fidOut);
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

function m = subfunc1(x,y,z)
m = (1:x)'*ones(1,y*z);
m = reshape(m,x,y,z);

% Verify no shears
function check_shears(v,text)

mat3d = v.mat(1:3,1:3);
m = mat3d'*mat3d;
m = m - diag(diag(m));
if norm(m,'fro') > 1e-8
  error([text '  Quitting.']);
end
