% % MFD SOLVER %
        -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- %
        Multi -
    reservoir MFD - based traffic flow solver % Accumulation -
    based model % % Nov 2019 -
    Guilhem Mariotte % Original version % % Feb 2020 -
    Mahendra Paipuri % Extension to multimodality with 3D -
    MFD functions % %
        References
    : %
      Mariotte et al.(TR part B, 2017) % Mariotte &Leclercq(TR part B, 2019) %
      Mariotte et al.(TR part B, 2020) % Paipuri &Leclercq(TR part B, 2020)

      %
      Simulation attributes SimulationDuration = Simulation.Duration;
TimeStep = Simulation.TimeStep;
SimulTime = Simulation.Time;
NumModes = Simulation.NumModes;
MFDfct = Simulation.MFDfct;
Entryfct = Simulation.Entryfct;
Exitfct = Simulation.Exitfct;

% Assignment period time window Temp_StartTimeID =
    floor(Assignment.CurrentTime / TimeStep) + 1;
Temp_EndTimeID =
    min([floor(Assignment.Periods(Assignment.CurrentPeriodID + 1) / TimeStep)
             NumTimes -
         1]);
Temp_numtimesperiod = Temp_EndTimeID - Temp_StartTimeID + 1;

if Assignment.CurrentPeriodID == 1

% Set variables
for r = 1:
            NumRes
            Temp_Nroutes = length(Reservoir(r).RoutesID);
% Variable initialization Reservoir(r).Acc = zeros(NumModes, NumTimes);
% accumulation per mode[veh] Reservoir(r).AccPerRoute = zeros(Temp_Nroutes,
                                                              NumTimes);
% accumulation per route crossing Rr[veh] Reservoir(r).AccCircuPerRoute =
    zeros(Temp_Nroutes, NumTimes);
% circulating accumulation per route[veh] Reservoir(r).AccQueuePerRoute =
    zeros(Temp_Nroutes, NumTimes);
% queuing accumulation per route[veh] Reservoir(r).MeanSpeed = zeros(NumModes,
                                                                     NumTimes);
% mean speed[m / s] Reservoir(r).InflowPerRoute = zeros(Temp_Nroutes, NumTimes);
% inflow per route[veh / s] Reservoir(r).OutflowPerRoute = zeros(Temp_Nroutes,
                                                                 NumTimes);
% outflow per route[veh / s] Reservoir(r).OutflowCircuPerRoute =
    zeros(Temp_Nroutes, NumTimes);
% outflow of circulating veh per route[veh / s] Reservoir(r).NinPerRoute =
    zeros(Temp_Nroutes, NumTimes);
% entry cumulative count per route[veh] Reservoir(r).NoutPerRoute =
    zeros(Temp_Nroutes, NumTimes);
% exit cumulative count per route[veh] Reservoir(r).NoutCircuPerRoute =
    zeros(Temp_Nroutes, NumTimes);
% exit cumulative count of circulating veh per route[veh]

    % Initial accumulation,
    mean speed and trip length Reservoir(r).Acc(
        :, 1) = zeros(NumModes, 1);
Reservoir(r).AccPerRoute( :, 1) = zeros(Temp_Nroutes, 1);
Reservoir(r).AccCircuPerRoute( :, 1) = zeros(Temp_Nroutes, 1);
Reservoir(r).MeanSpeed( :, 1) = Reservoir(r).FreeflowSpeed(1 : NumModes);
Reservoir(r).NinPerRoute( :, 1) = zeros(Temp_Nroutes, 1);

% Number of vehicles waiting to enter Rr when Rr is the begining of the route
        Reservoir(r)
            .NumWaitingVeh = zeros(1, Temp_Nroutes);

% Entry demand cumulative count for the FIFO merge
Reservoir(r).NinDemandPerRoute = zeros(Temp_Nroutes,NumTimes);
Reservoir(r).NinDemandPerRoute1 = zeros(Temp_Nroutes, NumTimes);

% Queue factor for the queuedyn exit model
Reservoir(r).QueueFactor = 1;
end
for iroute = 1:
             NumRoutes
             Route(iroute).TravelTime = zeros(1,NumTimes);
end

    else

    % Load from previous assignment period Reservoir = Snapshot.Reservoir;

end

% Macro node supply
for i = 1:
        NumMacroNodes
        Temp_times = MacroNode(i).Capacity.Time;
Temp_data = MacroNode(i).Capacity.Data;
[ Temp_times, Temp_data ] =
    stairfct(Temp_times, Temp_data, TimeStep, 0, SimulationDuration);
MacroNode(i).Supply = Temp_data;
end

    eps0 = 1e-3;
% criterion to determine if there are vehicles in the waiting list[veh] eps1 =
    1e-6;
% criterion to determine if there is a difference in flow[veh / s] eps2 = 10;

%% Simulation loop
%--------------------------------------------------------------------------

for itime = Temp_StartTimeID:
            Temp_EndTimeID % loop on all times

            % Mean speed and outflow demand calculation
            %------------------------------------------
            for r = 1:
                        NumRes % loop on all reservoirs

                        % Variable reset
                        Temp_Nroutes = length(Reservoir(r).RoutesID);
Reservoir(r).InflowDemandPerRoute = zeros(1, Temp_Nroutes);
Reservoir(r).InflowSupplyPerRoute = zeros(1, Temp_Nroutes);
Reservoir(r).MergeCoeffPerRoute = ones(1, Temp_Nroutes);
Reservoir(r).OutflowDemandPerRoute = zeros(1, Temp_Nroutes);
Reservoir(r).OutflowSupplyPerRoute = zeros(1, Temp_Nroutes);
Reservoir(r).InternalProd = 0;
Reservoir(r).ExitCoeffPerRoute = ones(1, Temp_Nroutes);

% Queue factor to adjust the MFD shape due to queuing accumulation %
    (= 1 in case of no queues) Temp_QF = 1 - sum(Reservoir(r).AccQueuePerRoute(
                                                 :, itime)) /
                                                 Reservoir(r).MaxAcc;
Reservoir(r).QueueFactor = Temp_QF;

% Reservoir Rr current accumulation and characteristics Temp_nr =
    zeros(NumModes, 1);
for
  i_m = 1 : NumModes Temp_modeindex = Reservoir(r).ModeIndex{i_m};
Temp_nr(i_m) = sum(Reservoir(r).AccCircuPerRoute(Temp_modeindex, itime));
end Temp_param = Reservoir(r).MFDfctParam;
Temp_Pc = Temp_QF * Reservoir(r).MaxProd;
Temp_Pr = MFDfct(Temp_nr, Temp_param);
Temp_Pr = Temp_QF * Temp_Pr(1 : NumModes);

% Reservoir Rr current mean speed if Temp_nr == 0 Temp_Vr =
    Reservoir(r).FreeflowSpeed;
else Temp_Vr = Temp_QF * MFDfct(Temp_nr, Temp_param)./ Temp_nr;
idx = find(isnan(Temp_Vr));
Temp_Vr(idx) = Reservoir(r).FreeflowSpeed(idx);
end Reservoir(r).MeanSpeed( :, itime) = Temp_Vr(1 : NumModes);

% Outflow demand production available per mode Temp_param =
    Reservoir(r).ExitfctParam;
Temp_proddemand = Exitfct(Temp_nr, Temp_param);

% Outflow demand per route in each mode
for i_m = 1:
          NumModes
          for i_r = Reservoir(r).ExitRoutesIndex{i_m} % loop on all routes exiting Rr
                            Temp_nrp = Reservoir(r).AccCircuPerRoute(i_r,itime);
Temp_Lrp = Reservoir(r).TripLengthPerRoute(i_r);
if strcmp (Simulation.DivergeModel, 'maxdem')
  % Maximum exit demand model if Temp_nr (i_m) == 0 Temp_Orp =
      Temp_nrp / Temp_Lrp * Temp_Vr(i_m);
else
  Temp_Orp = Temp_nrp / Temp_nr(i_m) * Temp_proddemand(i_m) / Temp_Lrp;
% maximum outflow % Temp_Orp =
    Temp_nrp / Temp_nr(i_m) * sum(Temp_proddemand) / Temp_Lrp;
% maximum outflow end elseif strcmp(Simulation.DivergeModel, 'queuedyn') %
    Boundary queue dynamics Reservoir(r).OutflowCircuPerRoute(i_r, itime) =
    Temp_nrp / Temp_Lrp * Temp_Vr;
if Reservoir (r)
  .AccQueuePerRoute(i_r, itime) < eps0 Temp_Orp =
      Reservoir(r).OutflowCircuPerRoute(i_r, itime);
% no queue else Temp_Orp =
    MacroNode(Reservoir(r).RoutesNodeID(2, i_r)).Supply(i_m, itime);
end elseif strcmp(Simulation.DivergeModel, 'decrdem') % Decreasing exit demand
    model(classic) Temp_Orp = Temp_nrp / Temp_Lrp * Temp_Vr(i_m);
end Reservoir(r).OutflowDemandPerRoute(i_r) = Temp_Orp;
end
end
for i_m = 1:
          NumModes
          for i_r = Reservoir(r).DestRoutesIndex{i_m} % loop on all routes ending in Rr
                            Temp_nrp = Reservoir(r).AccCircuPerRoute(i_r,itime);
Temp_Lrp = Reservoir(r).TripLengthPerRoute(i_r);
Temp_Orp = Temp_nrp / Temp_Lrp * Temp_Vr(i_m);
Reservoir(r).OutflowDemandPerRoute(i_r) = Temp_Orp;
Reservoir(r).OutflowCircuPerRoute(i_r, itime) = Temp_Orp;
end
end

end


% Inflow supply calculation
%--------------------------
for r = 1:
        NumRes % loop on all reservoirs

        % Queue factor
        Temp_QF = Reservoir(r).QueueFactor;

% Inflow demand for all routes
Temp_Nroutes = length(Reservoir(r).RoutesID);
Temp_dem = zeros(1, Temp_Nroutes);
i_r = 1;
for
  iroute = Reservoir(r).RoutesID % loop on all routes in Rr if r ==
           Route(iroute).ResOriginID % Rr origin of the route i_m =
               Reservoir(r).RouteMode(i_r);
if ismember (i_r, Reservoir(r).EntryRoutesIndex{i_m})
  % external origin if Reservoir (r).NumWaitingVeh(i_r) <
      eps0 Reservoir(r).InflowDemandPerRoute(i_r) = Route(iroute).Demand(itime);
else
    % In the case of queued vehicles, inflow demand
            % should be high enough to be able to use reservoir
            % capacity. Here the maximum route demand
            % is used. This minimises the oscillations in the
            % merge coefficients. However, if queues discharge
            % at different times, this approach still induces
            % oscillations in the merge coefficients.
            Reservoir(r).InflowDemandPerRoute(i_r) = max(Route(iroute).Demand);
end
Temp_dem(i_r) = Route(iroute).Demand(itime);
else % internal origin
    if Reservoir(r).NumWaitingVeh(i_r) < eps0
        Reservoir(r).InflowDemandPerRoute(i_r) = Route(iroute).Demand(itime);
    else
        Reservoir(r).InflowDemandPerRoute(i_r) = max(Route(iroute).Demand);
end
Temp_dem(i_r) = Route(iroute).Demand(itime);
end
else % Rr middle of the route
    r2 = Route(iroute).ResPath(Reservoir(r).RoutesPathIndex(i_r)-1);
% previous reservoir in the route
i_r2 = Route(iroute).ResRouteIndex(r2);
Reservoir(r).InflowDemandPerRoute(i_r) = Reservoir(r2).OutflowDemandPerRoute(i_r2);
Temp_dem(i_r) = Reservoir(r2).OutflowDemandPerRoute(i_r2);
end
i_r = i_r + 1;
end

% Entry demand cumulative count (for FIFO merge)
    Reservoir(r).NinDemandPerRoute(:,itime+1) = Reservoir(r).NinDemandPerRoute(:,itime) + Temp_dem'*TimeStep;

            % Effective inflow for internal origins (not restricted)
                Temp_inflowdemand = Reservoir(r).InflowDemandPerRoute;
      Reservoir(r).InternalProd = zeros(1, NumModes);
for i_m = 1:
NumModes
for i_n = Reservoir(r).OriNodesIndex{i_m} % loop on all origin nodes in Rr
              inode = Reservoir(r).MacroNodesID(i_n);
Temp_indexes = Reservoir(r).NodeRoutesIndex{i_m, i_n};
Temp_allindexes = [Reservoir(r).NodeRoutesIndex{ :, i_n}];
% all routes irrespective of mode for a given node
if ~isempty(Temp_indexes)
        Temp_dem = Reservoir(r).InflowDemandPerRoute(Temp_indexes);
Temp_demtot = sum(Temp_dem);
if Temp_demtot
  > 0 Temp_mergecoeff = Temp_dem./ Temp_demtot;
else
  Temp_mergecoeff = ones(1, length(Temp_indexes));
end Temp_modesupplycoeff = sum(Temp_inflowdemand(Temp_indexes)) /
                           sum(Temp_inflowdemand(Temp_allindexes));
% split the total supply between each mode Temp_flowsupply =
    Temp_modesupplycoeff * MacroNode(inode).Supply(itime);
Temp_inflow = mergeFair(Temp_dem, Temp_flowsupply, Temp_mergecoeff);
Reservoir(r).InflowPerRoute(Temp_indexes, itime) = Temp_inflow'; Temp_Ltrip =
    Reservoir(r).TripLengthPerRoute(Temp_indexes);
Reservoir(r).InternalProd(i_m) = Reservoir(r).InternalProd(i_m) +
                                 sum(Temp_Ltrip.*Temp_inflow);
end
end
end

% Entry merge coefficients for entering routes
if strcmp(Simulation.MergeModel,'endogenous')
        % Endogenous merge (for entering productions)
for i_m = 1:
                      NumModes
                      Temp_indexes = Reservoir(r).EntryRoutesIndex{i_m};
Temp_nrp = Reservoir(r).AccCircuPerRoute(Temp_indexes, itime)'; Temp_nr_entry =
    sum(Temp_nrp);
if Temp_nr_entry
  > 0 Reservoir(r).MergeCoeffPerRoute(Temp_indexes) =
      (Temp_nrp > 0).*Temp_nrp./ Temp_nr_entry + (Temp_nrp <= 0).*1;
end
end
elseif strcmp(Simulation.MergeModel,'demprorata')
% Demand pro-rata flow merge
for i_m = 1:
          NumModes
          Temp_indexes = Reservoir(r).EntryRoutesIndex{i_m};
Temp_dem = Reservoir(r).InflowDemandPerRoute(Temp_indexes);
Temp_demtot = sum(Temp_dem);
if Temp_demtot
  > 0 Reservoir(r).MergeCoeffPerRoute(Temp_indexes) = Temp_dem./ Temp_demtot;
end end elseif strcmp(Simulation.MergeModel, 'demfifo') % Demand FIFO flow merge
    Temp_dem = Reservoir(r).InflowDemandPerRoute;
Temp_demtot = sum(Temp_dem);
if Temp_demtot
  > 0 Reservoir(r).MergeCoeffPerRoute = Temp_dem./ Temp_demtot;
end
elseif strcmp(Simulation.MergeModel,'equiproba')
% Equi-probability for all transfer inflows
for i_m = 1:
              NumModes
              Temp_indexes = Reservoir(r).EntryRoutesIndex{i_m};
Temp_Nroutes = length(Temp_indexes);
if Temp_Nroutes
  > 0 Reservoir(r).MergeCoeffPerRoute(Temp_indexes) =
      ones(1, Temp_Nroutes)./ Temp_Nroutes;
end end end

    % Inflow limitation due to node supply at entry(border supply)
          Temp_inflowdemand = Reservoir(r).InflowDemandPerRoute;
for i_m = 1:
          NumModes
          for i_n = Reservoir(r).EntryNodesIndex{i_m} % loop on all entry border nodes in Rr
                            inode = Reservoir(r).MacroNodesID(i_n);
Temp_indexes = Reservoir(r).NodeRoutesIndex{i_m, i_n};
Temp_allindexes = [Reservoir(r).NodeRoutesIndex{ :, i_n}];
if
  ~isempty(Temp_indexes)
      Temp_flowdem = Reservoir(r).InflowDemandPerRoute(Temp_indexes);
Temp_modesupplycoeff = sum(Temp_inflowdemand(Temp_indexes)) /
                       sum(Temp_inflowdemand(Temp_allindexes));
% split the total supply between each mode Temp_flowsupply =
    Temp_modesupplycoeff * MacroNode(inode).Supply(itime);
Temp_mergecoeff = Reservoir(r).MergeCoeffPerRoute(Temp_indexes);
Temp_mergecoefftot = sum(Temp_mergecoeff);
Temp_newflowdem = mergeFair(Temp_flowdem, Temp_flowsupply,
                            Temp_mergecoeff./ Temp_mergecoefftot);
% Modify the original demands to account for node supply
Reservoir(r).InflowDemandPerRoute(Temp_indexes) = Temp_newflowdem;
end end end

    % Reservoir Rr current accumulation Temp_nr = zeros(NumModes, 1);
for
  i_m = 1 : NumModes Temp_modeindex = Reservoir(r).ModeIndex{i_m};
Temp_nr(i_m) = sum(Reservoir(r).AccCircuPerRoute(Temp_modeindex, itime));
end

% Effective inflow for entering routes
if strcmp(Simulation.MergeModel,'endogenous')
        % Endogenous merge (for entering productions)
            Temp_param = Reservoir(r).EntryfctParam;
Temp_totprodsupply = Temp_QF*(sum(Entryfct(Temp_nr,Temp_param)' - Reservoir(r).InternalProd));
                                  Temp_totflowdem = Reservoir(r).InflowDemandPerRoute;
                                  for i_m = 1:NumModes
                                          Temp_indexes = Reservoir(r).EntryRoutesIndex{i_m};
                                  Temp_Ltrip = Reservoir(r).TripLengthPerRoute(Temp_indexes);
                                  Temp_proddem = Temp_Ltrip.*Reservoir(r).InflowDemandPerRoute(Temp_indexes);
                                  Temp_flowdem = Reservoir(r).InflowDemandPerRoute(Temp_indexes);
                                  Temp_mergecoeff = Reservoir(r).MergeCoeffPerRoute(Temp_indexes);
                                  Temp_prodsupply = (sum(Temp_flowdem)/sum(Temp_totflowdem))*Temp_totprodsupply;

                                  Temp_prod = mergeFair(Temp_proddem,Temp_prodsupply,Temp_mergecoeff);
                                  Reservoir(r).InflowSupplyPerRoute(Temp_indexes) = Temp_prod./Temp_Ltrip;
                                  end
                                  elseif strcmp(Simulation.MergeModel,'demfifo')
                                  % FIFO discipline merge applied per external node
                                  Temp_param = Reservoir(r).EntryfctParam;
                                  Temp_prodsupply = Temp_QF*(sum(Entryfct(Temp_nr,Temp_param)) - sum(Reservoir(r).InternalProd));
                                  for i_e = 1:length(Reservoir(r).EntryRoutesIndexPerNode)
                                              Temp_indexes = Reservoir(r).EntryRoutesIndexPerNode{i_e};
                                      Temp_entryprodsupply = sum(Reservoir(r).MergeCoeffPerRoute(Temp_indexes))*Temp_prodsupply;
                                      Temp_Ltrip = Reservoir(r).TripLengthPerRoute(Temp_indexes);
                                      Temp_entryflowdem = Reservoir(r).InflowDemandPerRoute(Temp_indexes);
                                      if sum(Temp_entryflowdem) > 0
                                          Temp_Lr_entry = sum(Temp_entryflowdem)/sum(Temp_entryflowdem./Temp_Ltrip);
                                              else
                                                  Temp_Lr_entry = mean(Temp_Ltrip);
                                                  end
                                                  Temp_entryflowsupply = Temp_entryprodsupply/Temp_Lr_entry;
                                                  Temp_t = SimulTime;
                                                  Temp_Nincurrent = Reservoir(r).NinPerRoute(Temp_indexes,itime)';
                                                          Temp_Nindem = Reservoir(r).NinDemandPerRoute(Temp_indexes, :);
                                                  if sum(Temp_entryflowdem) > 0
                                                      Temp_inflow = mergeFIFO(itime,Temp_t,Temp_Nincurrent,Temp_Nindem,Temp_entryflowdem,Temp_entryflowsupply);
                                                      else
                                                          Temp_inflow = zeros(1,length(Temp_indexes));
                                                          end
                                                          Reservoir(r).InflowSupplyPerRoute(Temp_indexes) = Temp_inflow;
                                                          end
                                                          else
                                                              % Other merge models (for inflows)
                                                                  Temp_param = Reservoir(r).EntryfctParam;
                                                                  Temp_totprodsupply = Temp_QF*(sum(Entryfct(Temp_nr,Temp_param)' - Reservoir(r).InternalProd));
                                                                          Temp_totflowdem = Reservoir(r).InflowDemandPerRoute;
                                                                          for i_m = 1:NumModes
                                                                                      Temp_indexes = Reservoir(r).EntryRoutesIndex{i_m};
                                                                              Temp_Ltrip = Reservoir(r).TripLengthPerRoute(Temp_indexes);
                                                                              Temp_proddem = Temp_Ltrip.*Reservoir(r).InflowDemandPerRoute(Temp_indexes);
                                                                              Temp_flowdem = Reservoir(r).InflowDemandPerRoute(Temp_indexes);
                                                                              Temp_prodsupply = (sum(Temp_flowdem)/sum(Temp_totflowdem))*Temp_totprodsupply;
                                                                              Temp_nrp = Reservoir(r).AccCircuPerRoute(Temp_indexes,itime)';
                                                                                      Temp_nr_entry = sum(Temp_nrp);
                                                                              if Temp_nr_entry == 0
                                                                                  Temp_Lr_entry = mean(Temp_Ltrip);
                                                                                  else
                                                                                      Temp_Lr_entry = Temp_nr_entry/sum(Temp_nrp./Temp_Ltrip);
                                                                                      end
                                                                                      if sum(Temp_proddem) < Temp_prodsupply
                                                                                          Temp_flowsupply = Inf;
                                                                                          else
                                                                                              Temp_flowsupply = Temp_prodsupply/Temp_Lr_entry;
                                                                                              end

                                                                                              Temp_mergecoeff = Reservoir(r).MergeCoeffPerRoute(Temp_indexes);
                                                                                              Temp_inflow = mergeFair(Temp_flowdem,Temp_flowsupply,Temp_mergecoeff);
                                                                                              Reservoir(r).InflowSupplyPerRoute(Temp_indexes) = Temp_inflow;
                                                                                              end
                                                                                              end
                                                                                              end


                                                                                              % Effective outflow calculation
                                                                                              %------------------------------
                                                                                              for r = 1:NumRes % loop on all reservoirs

                                                                                                          % Exit merge coefficients (merge for several outflows ending in the same node)
                                                                                                              for i_m = 1:NumModes
                                                                                                                          Temp_indexes = Reservoir(r).ExitRoutesIndex{i_m};
                                                                                                          Temp_dem = Reservoir(r).OutflowDemandPerRoute(Temp_indexes);
                                                                                                          Temp_demtot = sum(Temp_dem);
                                                                                                          if Temp_demtot > 0
                                                                                                              Reservoir(r).ExitCoeffPerRoute(Temp_indexes) = Temp_dem./Temp_demtot;
                                                                                                              end
                                                                                                              end

                                                                                                              % Exit supply for internal destinations
                                                                                                                  Temp_outflowdemand = Reservoir(r).OutflowDemandPerRoute;
                                                                                                                  for i_m = 1:NumModes
                                                                                                                              for i_n = Reservoir(r).DestNodesIndex{i_m} % loop on all destination nodes in Rr
                                                                                                                                          inode = Reservoir(r).MacroNodesID(i_n);
                                                                                                                          Temp_indexes = Reservoir(r).NodeRoutesIndex{i_m,i_n};
                                                                                                                          Temp_allindexes = [Reservoir(r).NodeRoutesIndex{:,i_n}];
                                                                                                                          if ~isempty(Temp_indexes)
                                                                                                                              Temp_flowdem = Reservoir(r).OutflowDemandPerRoute(Temp_indexes);
                                                                                                                              Temp_mergecoeff = Reservoir(r).ExitCoeffPerRoute(Temp_indexes);
                                                                                                                              Temp_mergecoefftot = sum(Temp_mergecoeff);
                                                                                                                              Temp_modesupplycoeff = sum(Temp_outflowdemand(Temp_indexes))/sum(Temp_outflowdemand(Temp_allindexes)); % split the total supply between each mode
                                                                                                                              Temp_flowsupply = Temp_modesupplycoeff*MacroNode(inode).Supply(itime);
                                                                                                                              Temp_outflowsupply = mergeFair(Temp_flowdem,Temp_flowsupply,Temp_mergecoeff./Temp_mergecoefftot);
                                                                                                                              Reservoir(r).OutflowSupplyPerRoute(Temp_indexes) = Temp_outflowsupply;
                                                                                                                              end
                                                                                                                              end
                                                                                                                              end

                                                                                                                              % Exit supply for external destinations and transfer to another reservoir
                                                                                                                                  Temp_outflowdemand = Reservoir(r).OutflowDemandPerRoute;
                                                                                                                                  for i_m = 1:NumModes
                                                                                                                                              for i_n = Reservoir(r).ExitNodesIndex{i_m} % loop on all exit border nodes in Rr
                                                                                                                                                          inode = Reservoir(r).MacroNodesID(i_n);
                                                                                                                                          Temp_indexes = Reservoir(r).NodeRoutesIndex{i_m,i_n};
                                                                                                                                          Temp_allindexes = [Reservoir(r).NodeRoutesIndex{:,i_n}];
                                                                                                                                          if ~isempty(Temp_indexes)
                                                                                                                                              Temp_flowdem = Reservoir(r).OutflowDemandPerRoute(Temp_indexes);
                                                                                                                                              Temp_mergecoeff = Reservoir(r).ExitCoeffPerRoute(Temp_indexes);
                                                                                                                                              Temp_mergecoefftot = sum(Temp_mergecoeff);
                                                                                                                                              Temp_modesupplycoeff = sum(Temp_outflowdemand(Temp_indexes))/sum(Temp_outflowdemand(Temp_allindexes)); % split the total supply between each mode
                                                                                                                                              Temp_flowsupply = Temp_modesupplycoeff*MacroNode(inode).Supply(itime);
                                                                                                                                              Temp_outflowsupply = mergeFair(Temp_flowdem,Temp_flowsupply,Temp_mergecoeff./Temp_mergecoefftot);
                                                                                                                                              %Temp_outflowsupply = MacroNode(inode).Supply(itime)*Temp_mergecoeff./Temp_mergecoefftot;
                                                                                                                                              i = 1;
                                                                                                                                              for i_r = Temp_indexes
                                                                                                                                                          iroute = Reservoir(r).RoutesID(i_r);
                                                                                                                                                  if r == Route(iroute).ResDestinationID
                                                                                                                                                      Reservoir(r).OutflowSupplyPerRoute(i_r) = Temp_outflowsupply(i);
                                                                                                                                                      else
                                                                                                                                                          r2 = Route(iroute).ResPath(Reservoir(r).RoutesPathIndex(i_r)+1); % next reservoir in the route
                                                                                                                                                          i_r2 = Route(iroute).ResRouteIndex(r2);
                                                                                                                                                          Reservoir(r).OutflowSupplyPerRoute(i_r) = Reservoir(r2).InflowSupplyPerRoute(i_r2); % node supply already included in the inflow supply
                                                                                                                                                          end
                                                                                                                                                          i = i + 1;
                                                                                                                                                          end
                                                                                                                                                          end
                                                                                                                                                          end
                                                                                                                                                          end

                                                                                                                                                          % Effective outflow for all the routes
                                                                                                                                                              Temp_outflowdemand = Reservoir(r).OutflowDemandPerRoute;
                                                                                                                                                              Temp_outflowsupply = Reservoir(r).OutflowSupplyPerRoute;
                                                                                                                                                              if strcmp(Simulation.DivergeModel,'maxdem')
                                                                                                                                                                  % It is advisable to apply this maximum demand outflow per mode
                                                                                                                                                                  % as treating both cars and buses alike can pose stability
                                                                                                                                                                  % issues. By applying per mode, it is assumed that outflow
                                                                                                                                                                  % reduction in cars do not influence the outflow of buses. This
                                                                                                                                                                      % can be a reasonable assumption in the presence of bus lanes.
                                                                                                                                                                      for i_m = 1:NumModes
                                                                                                                                                                                  Temp_indexes = [Reservoir(r).ExitRoutesIndex{i_m} Reservoir(r).DestRoutesIndex{i_m}];
                                                                                                                                                                          Temp_exitlist = find(Temp_outflowdemand(Temp_indexes) > Temp_outflowsupply(Temp_indexes));
                                                                                                                                                                          if ~isempty(Temp_exitlist) % if there are outflow limitations
                                                                                                                                                                                  Temp_nrp = Reservoir(r).AccCircuPerRoute(Temp_indexes,itime)';
                                                                                                                                                                                          Temp_Ltrip = Reservoir(r).TripLengthPerRoute(Temp_indexes);
                                                                                                                                                                                  Temp_Vr = Reservoir(r).MeanSpeed(Reservoir(r).RouteMode(Temp_indexes),itime)';
                                                                                                                                                                                          Temp_Orp = Temp_Ltrip(Temp_exitlist).*Temp_outflowsupply(Temp_exitlist)./Temp_nrp(Temp_exitlist);
                                                                                                                                                                                  Temp_listmin = find(Temp_Orp == min(Temp_Orp));
                                                                                                                                                                                  imin = randi(length(Temp_listmin));
                                                                                                                                                                                  i_r2 = Temp_listmin(imin);
                                                                                                                                                                                  i_r_crit = Temp_exitlist(i_r2); % index of the critical exit (route)
                                                                                                                                                                                  Temp_outflow_crit = Temp_outflowsupply(Temp_indexes(i_r_crit)); % critical outflow
                                                                                                                                                                                  Reservoir(r).OutflowPerRoute(Temp_indexes,itime) = ((Temp_nrp'.*Temp_Vr')./Temp_Ltrip')...
                                                                                                                                                                                          .*(Temp_Ltrip(i_r_crit)./(Temp_Vr(i_r_crit).*Temp_nrp(i_r_crit))).*Temp_outflow_crit;
                                                                                                                                                                                          else
                                                                                                                                                                                              Reservoir(r).OutflowPerRoute(Temp_indexes,itime) = Temp_outflowdemand(Temp_indexes)';
                                                                                                                                                                                                      end
                                                                                                                                                                                                      end

                                                                                                                                                                                                      elseif strcmp(Simulation.DivergeModel,'decrdem') || strcmp(Simulation.DivergeModel,'queuedyn')
                                                                                                                                                                                                      Reservoir(r).OutflowPerRoute(:,itime) = min([Temp_outflowdemand; Temp_outflowsupply])';
                                                                                                                                                                                                              end
                                                                                                                                                                                                              end


                                                                                                                                                                                                              % Effective inflow update
                                                                                                                                                                                                              %------------------------
                                                                                                                                                                                                              for r = 1:NumRes % loop on all reservoirs

                                                                                                                                                                                                                          i_r = 1;
                                                                                                                                                                                                  for iroute = Reservoir(r).RoutesID % loop on all routes in Rr
                                                                                                                                                                                                              if r == Route(iroute).ResOriginID % Rr origin of the route
                                                                                                                                                                                                                  i_m = Reservoir(r).RouteMode(i_r);
                                                                                                                                                                                                          if ismember(i_r,Reservoir(r).EntryRoutesIndex{i_m}) % external origin
                                                                                                                                                                                                              Reservoir(r).InflowPerRoute(i_r,itime) = Reservoir(r).InflowSupplyPerRoute(i_r); % max. allowed inflow
                                                                                                                                                                                                              % Waiting lists at the route origins
                                                                                                                                                                                                              Temp_nwait = Reservoir(r).NumWaitingVeh(i_r);
                                                                                                                                                                                                              Temp_flowdem = Route(iroute).Demand(itime);
                                                                                                                                                                                                              Temp_inflow = Reservoir(r).InflowPerRoute(i_r,itime);
                                                                                                                                                                                                              if Temp_flowdem > Temp_inflow || Temp_nwait > eps0
                                                                                                                                                                                                                  Reservoir(r).NumWaitingVeh(i_r) = Temp_nwait + TimeStep*(Temp_flowdem - Temp_inflow);
                                                                                                                                                                                                                  end
                                                                                                                                                                                                                  else % internal origin
                                                                                                                                                                                                                      % Waiting lists at the route origins
                                                                                                                                                                                                                      Temp_nwait = Reservoir(r).NumWaitingVeh(i_r);
                                                                                                                                                                                                                      Temp_flowdem = Route(iroute).Demand(itime);
                                                                                                                                                                                                                      Temp_inflow = Reservoir(r).InflowPerRoute(i_r,itime); % not restricted, previously calculated
                                                                                                                                                                                                                      if Temp_flowdem > Temp_inflow || Temp_nwait > eps0
                                                                                                                                                                                                                          Reservoir(r).NumWaitingVeh(i_r) = Temp_nwait + TimeStep*(Temp_flowdem - Temp_inflow);
                                                                                                                                                                                                                          end
                                                                                                                                                                                                                          end
                                                                                                                                                                                                                          else % Rr middle of the route
                                                                                                                                                                                                                              r2 = Route(iroute).ResPath(Reservoir(r).RoutesPathIndex(i_r)-1); % previous reservoir in the route
                                                                                                                                                                                                                              i_r2 = Route(iroute).ResRouteIndex(r2);
                                                                                                                                                                                                                              Reservoir(r).InflowPerRoute(i_r,itime) = Reservoir(r2).OutflowPerRoute(i_r2,itime);
                                                                                                                                                                                                                              end
                                                                                                                                                                                                                              i_r = i_r + 1;
                                                                                                                                                                                                                              end
                                                                                                                                                                                                                              end


                                                                                                                                                                                                                              % Accumulation and trip length update
                                                                                                                                                                                                                              %------------------------------------
                                                                                                                                                                                                                              for r = 1:NumRes % loop on all reservoirs

                                                                                                                                                                                                                                          Temp_Nroutes = length(Reservoir(r).RoutesID);
                                                                                                                                                                                                                                  Temp_acc = Reservoir(r).AccPerRoute(:,itime)';
                                                                                                                                                                                                                                          Temp_acc_circu = Reservoir(r).AccCircuPerRoute(:,itime)';
                                                                                                                                                                                                                                                  Temp_acc_queue = Reservoir(r).AccQueuePerRoute(:,itime)';
                                                                                                                                                                                                                                                          Temp_in = Reservoir(r).InflowPerRoute(:,itime)';
                                                                                                                                                                                                                                                                  Temp_out = Reservoir(r).OutflowPerRoute(:,itime)';
                                                                                                                                                                                                                                                                          Temp_out_circu = Reservoir(r).OutflowCircuPerRoute(:,itime)';

                                                                                                                                                                                                                                                                                  % Accumulation update
                                                                                                                                                                                                                                                                                  if strcmp(Simulation.DivergeModel,'queuedyn')
                                                                                                                                                                                                                                                                                      Temp_acc_circu = Temp_acc_circu + TimeStep*(Temp_in - Temp_out_circu);
                                                                                                                                                                                                                                      Temp_acc_queue = Temp_acc_queue + TimeStep*(Temp_out_circu - Temp_out);
                                                                                                                                                                                                                                      else
                                                                                                                                                                                                                                          Temp_acc_circu = Temp_acc_circu + TimeStep*(Temp_in - Temp_out);
                                                                                                                                                                                                                                          Temp_acc_queue = zeros(1,Temp_Nroutes);
                                                                                                                                                                                                                                          end
                                                                                                                                                                                                                                          Reservoir(r).AccCircuPerRoute(:,itime+1) = max([Temp_acc_circu; zeros(1,Temp_Nroutes)])'; % to avoid negative values due to numerical errors
                                                                                                                                                                                                                                                  Reservoir(r).AccQueuePerRoute(:,itime+1) = max([Temp_acc_queue; zeros(1,Temp_Nroutes)])'; % to avoid negative values due to numerical errors
                                                                                                                                                                                                                                                          Reservoir(r).NinPerRoute(:,itime+1) = Reservoir(r).NinPerRoute(:,itime) + TimeStep*Temp_in';
                                                                                                                                                                                                                                                                  Reservoir(r).NoutPerRoute(:,itime+1) = Reservoir(r).NoutPerRoute(:,itime) + TimeStep*Temp_out';
                                                                                                                                                                                                                                                                          Reservoir(r).NoutCircuPerRoute(:,itime+1) = Reservoir(r).NoutCircuPerRoute(:,itime) + TimeStep*Temp_out_circu';
                                                                                                                                                                                                                                                                                  Reservoir(r).AccPerRoute(:,itime+1) = Reservoir(r).AccCircuPerRoute(:,itime+1) + Reservoir(r).AccQueuePerRoute(:,itime+1);
                                                                                                                                                                                                                                          % It is critical to correct the "actual inflow demand" for FIFO
                                                                                                                                                                                                                                              % entry. Since the real outflow for the preceding reservoir is
                                                                                                                                                                                                                                                  % corrected after FIFO computations, the new corrected outflow will
                                                                                                                                                                                                                                                  % be the actual inflow demand. Without this setp, flow conservation
                                                                                                                                                                                                                                                  % will be lost.
                                                                                                                                                                                                                                                  Reservoir(r).NinDemandPerRoute(:,itime+1) = Reservoir(r).NinDemandPerRoute(:,itime) + TimeStep*Temp_in';

                                                                                                                                                                                                                                                          for i_m = 1:NumModes
                                                                                                                                                                                                                                                                      i_r = Reservoir(r).ModeIndex{i_m};
                                                                                                                                                                                                                                                      Reservoir(r).Acc(i_m,itime+1) = sum(Reservoir(r).AccPerRoute(i_r,itime+1));

                                                                                                                                                                                                                                                      % Average trip length update
                                                                                                                                                                                                                                                      if Reservoir(r).Acc(i_m,itime+1) > 0
                                                                                                                                                                                                                                                          Temp_nr = Reservoir(r).AccPerRoute(i_r,itime+1)';
                                                                                                                                                                                                                                                                  Temp_Lr = Reservoir(r).TripLengthPerRoute(i_r);
                                                                                                                                                                                                                                                          Reservoir(r).AvgTripLength(i_m,itime+1) = Reservoir(r).Acc(i_m,itime+1)/sum(Temp_nr./Temp_Lr);
                                                                                                                                                                                                                                                          else
                                                                                                                                                                                                                                                              Reservoir(r).AvgTripLength(i_m,itime+1) = Reservoir(r).AvgTripLength(i_m,itime);
                                                                                                                                                                                                                                                              end
                                                                                                                                                                                                                                                              end
                                                                                                                                                                                                                                                              end

                                                                                                                                                                                                                                                              end



                                                                                                                                                                                                                                                              %% Deriving N-curves and travel time per route
                                                                                                                                                                                                                                                              %--------------------------------------------------------------------------

                                                                                                                                                                                                                                                              % Flow for the last time step (simplification, useful for the last assignment period only)
                                                                                                                                                                                                                                                                      for r = 1:NumRes
                                                                                                                                                                                                                                                                                  Reservoir(r).InflowPerRoute(:,NumTimes) = Reservoir(r).InflowPerRoute(:,NumTimes-1);
                                                                                                                                                                                                                                                                          Reservoir(r).OutflowPerRoute(:,NumTimes) = Reservoir(r).OutflowPerRoute(:,NumTimes-1);
                                                                                                                                                                                                                                                                          Reservoir(r).MeanSpeed(:,NumTimes) = Reservoir(r).MeanSpeed(:,NumTimes-1);
                                                                                                                                                                                                                                                                          end

                                                                                                                                                                                                                                                                          % Travel time evolution per route
                                                                                                                                                                                                                                                                          for iroute = 1:NumRoutes
                                                                                                                                                                                                                                                                                      if Route(iroute).AssignCoeff > 0
                                                                                                                                                                                                                                                                                          o = Route(iroute).ResOriginID;
                                                                                                                                                                                                                                                                                  d = Route(iroute).ResDestinationID;
                                                                                                                                                                                                                                                                                  i_o = Route(iroute).ResRouteIndex(o);
                                                                                                                                                                                                                                                                                  i_d = Route(iroute).ResRouteIndex(d);

                                                                                                                                                                                                                                                                                  Temp_nin = Reservoir(o).NinPerRoute(i_o,1:Temp_EndTimeID);
                                                                                                                                                                                                                                                                                  Temp_nout = Reservoir(d).NoutPerRoute(i_d,1:Temp_EndTimeID);
                                                                                                                                                                                                                                                                                  Temp_TT = ExperiencedTravelTime(SimulTime(1:Temp_EndTimeID),Temp_nin,Temp_nout);
                                                                                                                                                                                                                                                                                  Route(iroute).TravelTime(Temp_StartTimeID:Temp_EndTimeID) = Temp_TT(Temp_StartTimeID:Temp_EndTimeID);

                                                                                                                                                                                                                                                                                  else
                                                                                                                                                                                                                                                                                      % If the route is not used, default is the free-flow travel time
                                                                                                                                                                                                                                                                                      Route(iroute).TravelTime(Temp_StartTimeID:Temp_EndTimeID) = Route(iroute).FreeFlowTravelTime*ones(1,Temp_numtimesperiod);
                                                                                                                                                                                                                                                                                      end

                                                                                                                                                                                                                                                                                      % TT for the last time step (simplification, useful for the last assignment period only)
                                                                                                                                                                                                                                                                                              Route(iroute).TravelTime(NumTimes) = Route(iroute).TravelTime(NumTimes-1);
                                                                                                                                                                                                                                                                                              end
