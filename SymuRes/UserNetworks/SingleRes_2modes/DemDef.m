%% DEMAND DEFINITION
%--------------------------------------------------------------------------

% All macro OD pairs
%--------------------------------------------------------------------------
for od = 1:
         NumODmacro
         i = 1;
ODmacro(od).Demand(i).Purpose = 'cartrip';
ODmacro(od).Demand(i).Time = 0;
% [s]
ODmacro(od).Demand(i).Data = 0;
% [veh/s]
end

addpath(['UserNetworks/' Simulation.Network '/scenarios/'])


%% Scenario 1:
low demand free flow scenario with 1 car and 1 bus route
%--------------------------------------------------------------------------
% Test scenario from Paipuri & Leclerq, TR Part B, 2020 - https://doi.org/10.1016/j.trb.2020.01.007

if strcmp(Simulation.Name(1:4),'SC11')
    Simulation.MergeModel = 'demprorata';
% 'demprorata', 'demfifo', 'equiproba' or 'endogenous'
Simulation.DivergeModel = 'maxdem';
% 'maxdem', 'decrdem' or 'queuedyn'
Simulation.TripbasedSimuFactor = 1.0;
% factor < 1 to scale down the demand level and increase the trip-based solver computation time
DemSC1
end

%% Scenario 2:
high demand congestion scenario with 1 car and 1 bus route
%--------------------------------------------------------------------------
% Test scenario from Paipuri & Leclerq, TR Part B, 2020 - https://doi.org/10.1016/j.trb.2020.01.007
% In the paper, only one 3D MFD is used to show the results of congested
% case. However, using two segregated 3D MFD approach results this case in
    % free flow as well. By default, two segregated 3D MFDs are used in this
    % simulator

    if strcmp(Simulation.Name(1:4),'SC21')
        Simulation.MergeModel = 'demprorata';
% 'demprorata', 'demfifo', 'equiproba' or 'endogenous'
Simulation.DivergeModel = 'maxdem';
% 'maxdem', 'decrdem' or 'queuedyn'
Simulation.TripbasedSimuFactor = 1.0;
% factor < 1 to scale down the demand level and increase the trip-based solver computation time
DemSC2
end


%% Scenario 3:
high demand congestion scenario with 1 car and 1 bus route
%--------------------------------------------------------------------------
% New test case to verify different entry functions

    if strcmp(Simulation.Name(1:4),'SC31')
        Simulation.MergeModel = 'demprorata';
% 'demprorata', 'demfifo', 'equiproba' or 'endogenous'
Simulation.DivergeModel = 'maxdem';
% 'maxdem', 'decrdem' or 'queuedyn'
Simulation.TripbasedSimuFactor = 1.0;
% factor < 1 to scale down the demand level and increase the trip-based solver computation time
DemSC3
end

if strcmp(Simulation.Name(1:4),'SC32')
    Simulation.MergeModel = 'endogenous';
% 'demprorata', 'demfifo', 'equiproba' or 'endogenous'
Simulation.DivergeModel = 'maxdem';
% 'maxdem', 'decrdem' or 'queuedyn'
Simulation.TripbasedSimuFactor = 1.0;
% factor < 1 to scale down the demand level and increase the trip-based solver computation time
DemSC3
end

if strcmp(Simulation.Name(1:4),'SC33')
    Simulation.MergeModel = 'demfifo';
% 'demprorata', 'demfifo', 'equiproba' or 'endogenous'
Simulation.DivergeModel = 'maxdem';
% 'maxdem', 'decrdem' or 'queuedyn'
Simulation.TripbasedSimuFactor = 1.0;
% factor < 1 to scale down the demand level and increase the trip-based solver computation time
DemSC3
end

rmpath(['UserNetworks/' Simulation.Network '/scenarios/'])

