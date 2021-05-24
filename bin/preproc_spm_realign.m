function preproc_spm_realign(varargin)

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

  %get n Volumes for functional image
  nVols = length(spm_vol(p.Results.inFunc));

  %create matrix of functional volumes (e.g., 'func.nii,1'; 'func.nii,2'; ...)
  volumes = cell(nVols,1);
  for i = 1:nVols
    volumes{i,1} = strcat(p.Results.inFunc,',',num2str(i));
  end

  mbatch{1}.spm.spatial.realign.estwrite.data = {volumes};
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = spmCfg.quality;
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = spmCfg.sep;
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = spmCfg.fwhm;
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = spmCfg.rtm;
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = spmCfg.einterp;
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = spmCfg.ewrap;
  mbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = spmCfg.weight;
  mbatch{1}.spm.spatial.realign.estwrite.roptions.which = spmCfg.which;
  mbatch{1}.spm.spatial.realign.estwrite.roptions.interp = spmCfg.rinterp;
  mbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = spmCfg.rwrap;
  mbatch{1}.spm.spatial.realign.estwrite.roptions.mask = spmCfg.mask;
  mbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = spmCfg.prefix;

  %prep job to run through container
  save(p.Results.outFile,'mbatch')

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
