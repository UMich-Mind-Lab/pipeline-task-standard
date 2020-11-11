try
  fmap = inputs{1};
  eFmapMag = inputs{2};
  tFunc = inputs{3};

  %Fieldmap settings
  IP = FieldMap('Initialise');
  IP.pP = spm_vol(fmap);
  IP.fm.fpm = spm_read_vols(IP.pP);
  IP.fm.jac = pm_diff(IP.fm.fpm,2);
  IP.blipdir = +1;
  IP.tert = 48.24;

  %create vdm file
  [IP.vdm, IP.vdmP] = FieldMap('FM2VDM',IP);

  %apply to nifti image
  epiP = spm_vol(tFunc);
  IP.epiP = epiP(10) %10th volume is reference
  IP.fmagP = spm_vol(eFmapMag);
  IP.vdmP = FieldMap('MatchVDM',IP);
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
