%% Search all VSC block by looking for the MaskType
model2update = bdroot;
VSC_idx = find_system(model2update,'MaskType','VSC');

%% Search All Voltage Source with Inertia by looking for the Masktype
Inertia_idx = find_system(model2update,'MaskType','Inertial_Voltage_source');

%% Search All Generic Voltage Source by looking for the Masktype
GenVSource_idx = find_system(model2update,'MaskType','GenericVoltageSource');
GenVSource_Sb = 0;
GenVSource_Ub = 0;
GenVSource_fb = 0;


%% Enable All Fake Voltage Source for LF computation and reset the parameters of voltage sources blocks
for i=1:length(VSC_idx)
    set_param(VSC_idx{i}, 'LinkStatus', 'inactive');
    set_param([VSC_idx{i} '/Source_For_LF'],'Commented','off','Frequency','fb','PhaseAngle','0','Voltage','Un2');
    set_param([VSC_idx{i} '/Output_Transformer'],'Commented','on');
    set_param([VSC_idx{i} '/Mean_model'],'Commented','on');
    set_param([VSC_idx{i} '/Mean_model/Three-Phase Source'],'Voltage','Vvsc0*Un1','PhaseAngle','Theta_vsc0','Frequency','fb');
end

for i=1:length(Inertia_idx)
    set_param([Inertia_idx{i} '/Source_For_LF'],'Commented','off');
    set_param([Inertia_idx{i} '/Mean_model'],'Commented','on');
end

for i=1:length(GenVSource_idx)
    set_param([GenVSource_idx{i} '/Source_For_LF'],'Commented','off');
    set_param([GenVSource_idx{i} '/Source_For_OP'],'Commented','on');
    GenVSource_Sb=max(GenVSource_Sb,str2num(get_param([GenVSource_idx{i}],'Sn')));
    GenVSource_fb=max(GenVSource_fb,str2num(get_param([GenVSource_idx{i}],'fn')));
    GenVSource_Ub=max(GenVSource_Ub,str2num(get_param([GenVSource_idx{i}],'Un')));
end

%% Compute Loadflow

% Configure powergui as function of Generic Voltage Sources configuration:
powerguiHandle = find_system(gcs,'SearchDepth','1','Name','powergui');
try
    powerguiHandle = get_param(powerguiHandle{1},'Handle');
catch
    disp('Please name your powergui block: powergui')
end
if(GenVSource_Sb~=0)
    set_param(powerguiHandle,'Pbase',num2str(GenVSource_Sb));
end
if(GenVSource_fb~=0)
    set_param(powerguiHandle,'frequencyindice',num2str(GenVSource_fb));
end


LF = power_loadflow('-v2',model2update,'solve');

LF_Pbase = LF.basePower;

%% Update all VSC with a Masktype equal to 'VSC'
for i=1:length(VSC_idx)
    block_name = get_param(VSC_idx{i},'Name');
    test=find(strcmp({LF.bus.ID},block_name));
    Pb_VSC = eval(get_param(VSC_idx{i},'Sn'));
    
    if (isempty(test)==0)
        %set_param(VSC_idx{i},'V_mag_0',num2str(LF.bus(test).vbase * abs(LF.bus(test).Vbus) / sqrt(3)),'Theta0',num2str(angle(LF.bus(test).Vbus) * 180/pi));
        set_param(VSC_idx{i},'V0',num2str(abs(LF.bus(test).Vbus)),'Theta0',num2str(angle(LF.bus(test).Vbus) * 180/pi));
        set_param(VSC_idx{i},'P0',num2str(real(LF.bus(test).Sbus)*LF_Pbase/Pb_VSC),'Q0',num2str(imag(LF.bus(test).Sbus)*LF_Pbase/Pb_VSC));
        
        %p.setParameters('V_mag_0') = LF.bus(test).vbase * LF.bus(test).vref / sqrt(3);
        %p.setParameters('Theta0') = LF.bus(test).angle;        
    end
    
    set_param([VSC_idx{i} '/Source_For_LF'],'Commented','on');
    set_param([VSC_idx{i} '/Output_Transformer'],'Commented','off');
    set_param([VSC_idx{i} '/Mean_model'],'Commented','off');
    set_param(VSC_idx{i}, 'LinkStatus', 'restore');
end

%% Disable All fake voltage source in Voltage Source with Inertia blocks
for i=1:length(Inertia_idx)
    block_name = get_param(Inertia_idx{i},'Name');
    test=find(strcmp({LF.bus.ID},block_name));
    % Pb_VSC = eval(get_param(Inertia_idx{i},'Sc'));
    
    if (isempty(test)==0)
        %set_param(VSC_idx{i},'V_mag_0',num2str(LF.bus(test).vbase * abs(LF.bus(test).Vbus) / sqrt(3)),'Theta0',num2str(angle(LF.bus(test).Vbus) * 180/pi));
        %set_param(VSC_idx{i},'V0',num2str(abs(LF.bus(test).Vbus)),'Theta0',num2str(angle(LF.bus(test).Vbus) * 180/pi));
        set_param(Inertia_idx{i},'P0',num2str(real(LF.bus(test).Sbus)*LF_Pbase/Pb_VSC)); %,'Q0',num2str(imag(LF.bus(test).Sbus)*Pb_LF/Pb_VSC));
        
        %p.setParameters('V_mag_0') = LF.bus(test).vbase * LF.bus(test).vref / sqrt(3);
        %p.setParameters('Theta0') = LF.bus(test).angle;        
    end
    
    set_param([Inertia_idx{i} '/Source_For_LF'],'Commented','on');
    set_param([Inertia_idx{i} '/Mean_model'],'Commented','off');
end

%% Update all Generic Voltage Sources 
for i=1:length(GenVSource_idx)
    block_name = get_param(GenVSource_idx{i},'Name');
    test=find(strcmp({LF.bus.ID},block_name));
    GenVSource_Sb = eval(get_param(GenVSource_idx{i},'Sn'));
    GenVSource_Vb = eval(get_param(GenVSource_idx{i},'Un'))/sqrt(3);
    
    if (isempty(test)==0) % if a loadflow bus with the same name as the block name exists, then execute the following configuration of the block: 
        
        set_param(GenVSource_idx{i},'V0_pu',num2str(abs(LF.bus(test).Vbus)),'Theta0_deg',num2str(angle(LF.bus(test).Vbus)*180/pi));
        set_param(GenVSource_idx{i},'P0',num2str(real(LF.bus(test).Sbus)*LF_Pbase),'Q0',num2str(imag(LF.bus(test).Sbus)*LF_Pbase));  
        
    end
       
    set_param([GenVSource_idx{i} '/Source_For_LF'],'Commented','on');
    set_param([GenVSource_idx{i} '/Source_For_OP'],'Commented','off');
end