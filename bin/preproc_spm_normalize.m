function preproc_spm_normalize(varargin)

try
  % parse inputs
  p = inputParser;

  addParameter(p,'inFunc','');
  addParameter(p,'inStruct','');
  addParameter(p,'TPM','');
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

  mbatch{1}.spm.spatial.normalise.estwrite.subj.vol = {p.Results.inStruct};
  mbatch{1}.spm.spatial.normalise.estwrite.subj.resample = volumes;
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.biasreg = spmCfg.biasreg;
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.biasfwhm = spmCfg.biasfwhm;
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.tpm = {p.Results.TPM};
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.affreg = spmCfg.affreg;
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.reg = spmCfg.reg;
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.fwhm = spmCfg.fwhm;
  mbatch{1}.spm.spatial.normalise.estwrite.eoptions.samp = spmCfg.samp;
  mbatch{1}.spm.spatial.normalise.estwrite.woptions.bb = spmCfg.bb;
  mbatch{1}.spm.spatial.normalise.estwrite.woptions.vox = spmCfg.vox;
  mbatch{1}.spm.spatial.normalise.estwrite.woptions.interp = spmCfg.interp;
  mbatch{1}.spm.spatial.normalise.estwrite.woptions.prefix = spmCfg.prefix;
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
