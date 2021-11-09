s_base = 100 ## 100 MVA
    v_base = 33 ##kV
    z_base = v_base^2/s_base

Curve_PV = vcat(zeros(6),
    [0.07, 0.21, 0.44, 0.69, 0.83, 0.94, 0.96, 0.93, 0.83, 0.69, 0.31, 0.09],
    zeros(6))

Curve_Demand_E = [0.64;0.60;0.58;0.56;0.56;0.58;
                0.64;0.72;0.78;0.84;0.87;0.86;
                0.83;0.78;0.76;0.79;0.87;0.96;
                0.98;0.93;0.92;0.93;0.87;0.72]

tou_base = vcat(.20*ones(6), .25*ones(4), .20*ones(4), .25*ones(2), .45*ones(5), .25*ones(3))*1e3/s_base
# plot(tou_base)

elec_network_data = PowerModels.parse_file("case30.m");
N_T = 24
    N_G = length(elec_network_data["gen"])
    N_S = 4 #solar
    N_B = length(elec_network_data["bus"]) ## Number of buses
    N_L = length(elec_network_data["branch"]) ## Number of transmission lines
    N_D = length(elec_network_data["load"]) ## N elec loads
    N_F = 10 # set of ev fleets
    N_K = 3 # segments of generator
    N_M = 3 # segments of bidding cost function
    N_C = 3 # set of EVSEs


"bus data";
    Bus = Dict()
    [Bus[b] = Dict() for b in B]
    [Bus[b]["angmax"] = pi/6 for b in B]
    [Bus[b]["angmin"] = -pi/6 for b in B]
    # [Bus[b]["vmax"] = 1.1 for b in B]
    # [Bus[b]["vmin"] = 0.9 for b in B]

c_g_seg =  [20 20.1 20.2
       17.5  17.6 17.7
       10 10.3 10.6
       32.5 32.55 32.6
       30 30.1 30.2
       28 28.1 28.2]/s_base


"PV"
    Demand_bus = [Demand[d]["bus"] for d in D]
    PV_bus_demand = [3,8,11,17]

    PV = Dict() ## Set of PV units
    [PV[s] = Dict() for s in S]
    [PV[s]["bus"] = Demand_bus[PV_bus_demand[s]] for s in S]
    [PV[s]["pmax"] = .4 for s in S]
    [PV[s]["p_forecast"] = zeros(N_T) for s in S]
    [PV[s]["p_forecast"][t] = Curve_PV[t]*PV[s]["pmax"] for s in S, t in T]
    [Bus[PV[s]["bus"]]["PV"] = s for s in S]
    sum(PV[s]["pmax"] for s in S)


"EV"

penetration_level = 0.1

    Pmax_ev_ch = 30/1e3/s_base
    Pmax_ev_dc = 10/1e3/s_base
    Emax_ev = Pmax_ev_ch*2
    Emin_ev = 0
    (η_dc,η_ch)=(0.98,0.98)

    trip_flag = [2, 1, 1, 2, 4, 7, 8,
                14, 13, 11, 10, 8, 9, 7, 8, 10,
                    15, 14, 10, 8, 7, 3, 3, 2]/36

    connected_flag = vcat(.2*ones(6), [.25,.3,.35,.4,.45,.5,.5,.5,.45,.4,.4,.4,.35,.3,.25,.2], .2*ones(2))
Fleet = Dict()
    [Fleet[f] = Dict() for f in F]
    Fleet_bus_demand = collect(1:2:19)
    [Fleet[f]["bus"] = Demand_bus[Fleet_bus_demand[f]] for f in F]
    [Bus[Fleet[f]["bus"]]["Fleet"] = f for f in F]
    [Fleet[f]["trip_flag"] = trip_flag for f in F]
    [Fleet[f]["connected_flag"] = connected_flag for f in F]

# connected_flag
# plot(connected_flag)
Demand_bus[Fleet_bus_demand]

daily_dem_bus_fleet = [sum(Demand[Bus[Fleet[f]["bus"]]["Demand"]]["pd"][t] for t in T) for f in F]
N_EV = zeros(N_F)
ev_per_mwh = 6/1.8 # 10% penetration
[N_EV[f] = round(daily_dem_bus_fleet[f]*s_base*ev_per_mwh) for f in F]

[Fleet[f]["p_trip"] = zeros(N_T) for f in F]
    [Fleet[f]["p_trip"][t] = Fleet[f]["trip_flag"][t]*N_EV[f]*Pmax_ev_dc for f in F, t in T]
    [Fleet[f]["p_ch_cap"] = zeros(N_T) for f in F]
    [Fleet[f]["p_ch_cap"][t] = Fleet[f]["connected_flag"][t]*N_EV[f]*Pmax_ev_ch for f in F, t in T]
    [Fleet[f]["p_home_cap"] = 0.1*N_EV[f]*Pmax_ev_ch for f in F, t in T]
    [Fleet[f]["emax"] = N_EV[f]*Emax_ev for f in F]
    [Fleet[f]["emin"] = N_EV[f]*Emin_ev for f in F]

τ_c_range =  [1.4 .4
              1.6 .5
              1.8 .6]

π_c_seg_range =  [.32 .24 .16 .08
                  .37 .28 .19 .10
                  .31 .23 .15 .07]
