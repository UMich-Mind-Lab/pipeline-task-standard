function L1_spm_modelest(varargin)

try
  % parse inputs
  p = inputParser;

  addParameter(p,'SPM','');
  addParameter(p,'outFile','');
  addParameter(p,'res',9)

  parse(p,varargin{:});

  %make batch job
  mbatch{1}.spm.stats.fmri_est.spmmat = {p.Results.SPM};
  mbatch{1}.spm.stats.fmri_est.write_residuals = p.Results.res;
  mbatch{1}.spm.stats.fmri_est.method.Classical = 1;

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
