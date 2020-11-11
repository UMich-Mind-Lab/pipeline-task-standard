function preproc_spm_smooth(varargin)

try
  % parse inputs
  p = inputParser;

  addParameter(p,'inFunc','');
  addParameter(p,'outFile','');
  addParameter(p,'spmConfig','config/spm_config.json');

  parse(p,varargin{:});

  %read spmConfig into workspace
  spmCfg = jsondecode(fileread(p.Results.spmConfig));
  spmCfg = spmCfg.(mfilename());

  %get number of volumes
  nVols = length(spm_vol(p.Results.inFunc));

  %create matrix of functional volumes (e.g., 'func.nii,1'; 'func.nii,2'; ...)
  volumes = cell(nVols,1);
  for i = 1:nVols
    volumes{i,1} = strcat(p.Results.inFunc,',',num2str(i));
  end

  mbatch{1}.spm.spatial.smooth.data = volumes;
  mbatch{1}.spm.spatial.smooth.fwhm = spmCfg.fwhm;
  mbatch{1}.spm.spatial.smooth.dtype = spmCfg.dtype;
  mbatch{1}.spm.spatial.smooth.im = spmCfg.im;
  mbatch{1}.spm.spatial.smooth.prefix = spmCfg.prefix;

  %save job to run in container
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
