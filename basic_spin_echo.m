

sliceThickness = 0.005;    % slice thickness [m]
phaseFov = 0.2;            % phase encoding field of view [m]
readoutFov = 0.2;          % frequency encoding field of view [m] 
phaseMatrix = 128;         % phase encoding matrix size 
readoutMatrix = 128;       % frequency encoding matrix size
readoutBandwidth = 125000; % frequency encoding bandwidth [Hz] -- Please do not change this. 
te = 0.04;                % echo time [s]
tr = 0.1;                  % repetition time [s] 
dummyPulses = 4;           % number of dummy RF pulses to establish steady state 
numAutoPrescanLines = 1;   % number of lines of k-space used to calculate receive gains -- Please do not change this.
seqName = 'spinEcho_v1.seq'; 

% define hardware limits for scanner
system = mr.opts('MaxGrad', 40.0, ...
        'GradUnit', 'mT/m', ...
        'MaxSlew', 100.0, ...
        'SlewUnit', 'T/m/s', ...
        'rfRingdownTime', 0.00006, ...
        'rfDeadTime', 0.0001, ...
        'rfRasterTime', 0.000002,...
        'adcDeadTime', 0.00004,...
        'adcRasterTime', 0.000002,...
        'gradRasterTime', 0.000004,...
        'blockDurationRaster', 0.000004);

% create a pulseq sequence object 
seq = mr.Sequence(system);

% prepare excitation pulse and slice-select gradient 
[rfexc,gzexc] = mr.makeSincPulse(pi/2, ...     % flip angle [radians]
        'timeBwProduct', 6.4, ...              % time-bandwidth product
        'phaseOffset', pi/2, ...               % pulse phase--apply along +y axis
        'sliceThickness', sliceThickness, ...  % slice thickness [m]
        'duration', 0.0032, ...                % pulse duration [s]
        'system', system);                     % system object defined above

% non-selective 180-degree refocusing pulse applied along +x
% since this is a single-slice pulse sequence, we don't need to worry about
% what effects this pulse has outside of our 2D slice excited with rfexc
rfref = mr.makeBlockPulse(pi, 'duration', 0.001, 'system', system);

% calculate area of crusher gradient to eliminate FID after refocusing pulse
ph = 8*pi;                                                 % desired phase across the 2D slice
crusherArea = ph / (2*pi*system.gamma * sliceThickness);   % crusher area [T*s/m]
crusherArea = system.gamma * crusherArea;                  % crusher area [1/m]

% prepare the crusher gradient to be played out after the refocusing pulse
% along the z (slice) axis 
gzCrushPost = mr.makeTrapezoid('z', 'area', crusherArea, 'system', system);

% prepare the crusher gradient to be played out between the excitation
% pulse and the refocusing pulse. **Note that this area is different than 
% gzCrushPost because the phase accumulated during the second half of the 
% excitation pulse needs to be rewound. 
gzCrushPre = mr.makeTrapezoid('z', 'area', crusherArea - 0.5*gzexc.area, 'system', system);

% phase encoding gradients played out along 'y' axis 
% gy is prepared with the largest-necessary area, and its amplitude is
% scaled for each phase encoding line 
deltaky = 1/phaseFov;  % step size in k-space along phase encoding dimension [1/m]
gy = mr.makeTrapezoid('y', 'area', phaseMatrix * deltaky / 2, 'system', system);
ny = phaseMatrix;
ysteps = ((0:ny-1)-ny/2)/ny*2; % these are the scaling factors 
kyindsmatlab = 1:ny;           % indices saved for use during reconstruction
ycenter = ny/2 + 1;            % center k-space line index

% prepare frequency encoding gradient along x dimension
samplingTime = readoutMatrix / readoutBandwidth; % duration of frequency encoding readout 
deltakx = 1/readoutFov;                          % step size in k-space [1/m]
gxampl = readoutMatrix*deltakx/samplingTime;     % readout gradient amplitude [Hz/m]
gx = mr.makeTrapezoid('x', system, 'amplitude', gxampl, 'flatTime', samplingTime);

% ADC object
% note the delay so the data collection begins on the plateau of the
% frequency encoding gradient 
adc = mr.makeAdc(readoutMatrix, system, 'duration', samplingTime, 'delay', gx.riseTime);

% frequency encoding pre-phaser gradient
gxpre = mr.makeTrapezoid('x', system, 'area', gx.area/2);

% spoiler gradient to kill magnetization after readout
% (same calculations as for crusher gradient)
ph = 16*pi; 
area = ph / (2*pi*system.gamma*sliceThickness); % T*s/m
spoilerArea = system.gamma * area; % [1/m]
gspoil = mr.makeTrapezoid('z', 'area', spoilerArea, 'system', system);

% time between end of slice-select gradient and start of refocusing pulse 
teDelay1 = mr.makeDelay(te/2 - mr.calcDuration(gzexc)/2 - mr.calcDuration(rfref)/2);

% time between end of refocusing pulse and start of frequency encoding grad
teDelay2 = mr.makeDelay(te/2 - mr.calcDuration(rfref)/2 - mr.calcDuration(gx)/2);

% time between end of frequency encoding gradient and start of next TR 
trDelay = mr.makeDelay(tr - mr.calcDuration(gzexc)/2 - te - mr.calcDuration(gx)/2);


% dummy pulses to establish a steady state **without** playing out ADC
for p = 1:dummyPulses

    % play out excitation pulse and slice-select gradient 
    seq.addBlock(rfexc, gzexc, mr.makeLabel('SET', 'LIN', 1));

    % play out pre-refocusing crusher, readout prephaser, phase encoding,
    % and delay block bringing us to start of the refocusing pulse
    seq.addBlock(gzCrushPre, gxpre, mr.scaleGrad(gy, -ysteps(ycenter)), teDelay1);

    % play out refocusing pulse 
    seq.addBlock(rfref);

    % play out post-refocusing pulse crusher, and wait until start of
    % frequency encoding gradient 
    seq.addBlock(gzCrushPost, teDelay2);

    % play out frequency encoding gradient (WITHOUT ADC)
    seq.addBlock(gx);

    % play out spoiler gradient, phase encoding rewinder, and wait until the next TR 
    seq.addBlock(gspoil, mr.scaleGrad(gy, ysteps(ycenter)), trDelay);

end


% acquired lines without phase encoding for auto-prescan
% same as the above loop except ADC is turned on 
for p = 1:numAutoPrescanLines
    seq.addBlock(rfexc, gzexc, mr.makeLabel('SET', 'LIN', 2));
    seq.addBlock(gzCrushPre, gxpre, mr.scaleGrad(gy, -ysteps(ycenter)), teDelay1);
    seq.addBlock(rfref);
    seq.addBlock(gzCrushPost, teDelay2);
    seq.addBlock(gx, adc); % NOTE THE USE OF ADC HERE VS ABOVE
    seq.addBlock(gspoil, mr.scaleGrad(gy, ysteps(ycenter)), trDelay);
end

% step through and acquire all phase encoding lines 
for p = 1:length(ysteps)
    seq.addBlock(rfexc, gzexc, mr.makeLabel('SET', 'LIN', 2));
    seq.addBlock(gzCrushPre, gxpre, mr.scaleGrad(gy, -ysteps(p)), teDelay1);
    seq.addBlock(rfref);
    seq.addBlock(gzCrushPost, teDelay2);
    seq.addBlock(gx, adc);
    seq.addBlock(gspoil, mr.scaleGrad(gy, ysteps(p)), trDelay);
end

seq.plot();

seq.write(seqName);

% save this file for use during conversion to scanner-ready pulse sequence
% and during image reconstruction 
kyinds = kyindsmatlab - 1;
maxView = max([readoutMatrix, phaseMatrix, 256]);
[~,prefix,~] = fileparts(seqName);
seqInfoFile = sprintf('%s_info.mat', prefix);
save(seqInfoFile, 'maxView', 'seqName', 'kyinds', 'kyindsmatlab');
