function preproc_spm_realignunwarp(varargin)

try
  % parse inputs
  p = inputParser;

  addParameter(p,'inFunc','');
  addParameter(p,'inVDM','')
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

  mbatch{1}.spm.spatial.realignunwarp.data.scans = volumes;
  mbatch{1}.spm.spatial.realignunwarp.data.pmscan = {strcat(p.Results.inVDM,',1')};
  mbatch{1}.spm.spatial.realignunwarp.eoptions.quality = spmCfg.quality;
  mbatch{1}.spm.spatial.realignunwarp.eoptions.sep = spmCfg.sep;
  mbatch{1}.spm.spatial.realignunwarp.eoptions.fwhm = spmCfg.fwhm;
  mbatch{1}.spm.spatial.realignunwarp.eoptions.rtm = spmCfg.rtm;
  mbatch{1}.spm.spatial.realignunwarp.eoptions.einterp = spmCfg.einterp;
  mbatch{1}.spm.spatial.realignunwarp.eoptions.ewrap = spmCfg.ewrap;
  mbatch{1}.spm.spatial.realignunwarp.eoptions.weight = spmCfg.weight;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.basfcn = spmCfg.basfcn;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.regorder = spmCfg.regorder;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.lambda = spmCfg.lambda;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.jm = spmCfg.jm;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.fot = spmCfg.fot;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.sot = spmCfg.sot;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.uwfwhm = spmCfg.uwfwhm;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.rem = spmCfg.rem;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.noi = spmCfg.noi;
  mbatch{1}.spm.spatial.realignunwarp.uweoptions.expround = spmCfg.expround;
  mbatch{1}.spm.spatial.realignunwarp.uwroptions.uwwhich = spmCfg.uwwhich;
  mbatch{1}.spm.spatial.realignunwarp.uwroptions.rinterp = spmCfg.rinterp;
  mbatch{1}.spm.spatial.realignunwarp.uwroptions.wrap = spmCfg.wrap;
  mbatch{1}.spm.spatial.realignunwarp.uwroptions.mask = spmCfg.mask;
  mbatch{1}.spm.spatial.realignunwarp.uwroptions.prefix = spmCfg.prefix;

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
