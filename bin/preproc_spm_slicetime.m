function preproc_spm_slicetime(varargin)


try
  % parse inputs
  p = inputParser;

  addParameter(p,'inFunc','');
  addParameter(p,'outFile','');
  addParameter(p,'RepetitionTime','');
  addParameter(p,'bidsConfig','')
  addParameter(p,'spmConfig','config/spm_config.json');
  parse(p,varargin{:});

  %get functional dimensions from spm_vol function
  S = spm_vol(p.Results.inFunc);
  nSlices = S(1).dim(3);
  nVols = length(S);

  %read bidsConfig into workspace
  bidsCfg = jsondecode(fileread(p.Results.bidsConfig));

  %read spmConfig into workspace
  spmCfg = jsondecode(fileread(p.Results.spmConfig));
  spmCfg = spmCfg.(mfilename());

  %set ref slice to be middle real time point of TR
  refSlice = unique(bidsCfg.SliceTiming);
  refSlice = refSlice(floor(length(refSlice)/2)+1);

  %convert sliceTiming array from bids format to SPM
  sliceTiming = transpose(bidsCfg.SliceTiming) / 1000;
  
  %create matrix of func volumes (e.g., 'func.nii,1'; 'func.nii,2'; ...)
  volumes = cell(nVols,1);
  for i = 1:nVols
    volumes{i,1} = strcat(p.Results.inFunc,',',num2str(i));
  end

  mbatch{1}.spm.temporal.st.scans = {volumes};
  mbatch{1}.spm.temporal.st.nslices = nSlices;
  mbatch{1}.spm.temporal.st.tr = bidsCfg.RepetitionTime;
  %specify aquisition as 0 so we can use slice times instead of orders
  mbatch{1}.spm.temporal.st.ta = 0;
  %for multiband, slice order is specified as the time each slice acquired in msec.
  mbatch{1}.spm.temporal.st.so = sliceTiming;
  mbatch{1}.spm.temporal.st.refslice = refSlice;
  mbatch{1}.spm.temporal.st.prefix = spmCfg.prefix;

  %save job file
  save(p.Results.outFile,'mbatch');

catch ME
  fprintf('MATLAB code threw an exception:\n')
  fprintf('%s\n',ME.message);
  if length(ME.stack) ~= 0
    for i = 1:length(ME.stack)
      fprintf('File:%s\nName:%s\nLine:%d\n',ME.stack(i).file,...
        ME.stack(i).name,ME.stack(i).line);
    end
  end
end
