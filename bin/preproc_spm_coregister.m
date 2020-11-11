function preproc_spm_coregister(varargin)

try
    % parse inputs
    p = inputParser;

    addParameter(p,'srcImg','');
    addParameter(p,'refImg','');
    addParameter(p,'otherImg','');
    addParameter(p,'outFile','');
    addParameter(p,'spmConfig','config/spm_config.json');
    parse(p,varargin{:});

    %read spmConfig into workspace
    spmCfg = jsondecode(fileread(p.Results.spmConfig));
    spmCfg = spmCfg.(mfilename());

    %input files into SPM batch object
    mbatch{1}.spm.spatial.coreg.estimate.ref = {p.Results.refImg};
    mbatch{1}.spm.spatial.coreg.estimate.source = {p.Results.srcImg};
    mbatch{1}.spm.spatial.coreg.estimate.other = {p.Results.otherImg};
    mbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    mbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = spmCfg.sep;
    mbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = spmCfg.tol;
    mbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = spmCfg.fwhm;

    %save job to run in container
    save(p.Results.outFile,'mbatch');

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
