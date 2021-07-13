
Curve_WT = [0.835;0.536;0.442;0.422;0.912;0.858;0.898;0.679;0.927;0.908;0.808;1.000;
    0.760;0.599;0.470;0.516;0.564;0.647;0.838;0.948;0.819;0.919;0.970;0.900;]

Curve_PV = vcat(zeros(6),
    [0.07, 0.21, 0.44, 0.69, 0.83, 0.94, 0.96, 0.93, 0.83, 0.69, 0.31, 0.09],
    zeros(6))

Curve_elec = [0.64;0.60;0.58;0.56;0.56;0.58;
                0.64;0.72;0.78;0.84;0.87;0.86;
                0.83;0.78;0.76;0.79;0.87;0.96;
                0.98;0.93;0.92;0.93;0.87;0.72]

Curve_gas = [0.78, 0.71, 0.65, 0.71, 0.76, 0.8, 0.82, 0.89, 0.83,
     0.93, 0.90, 0.88, 0.85, 0.81, 0.76, 0.78, 0.86, 0.96,
     0.99, 1.2, 0.93, 0.91, 0.87, 0.81]


using PowerModels

elec_network_data = PowerModels.parse_file("case118.m");

const N_Hr = 8 ## Number of hours
const N_T = 12 ## number of time slots in each hour
const N_G = length(elec_network_data["gen"])
const N_U = 8 ## Number of thermal units
const N_B = length(elec_network_data["bus"]) ## Number of buses
const N_BR = length(elec_network_data["branch"]) ## Number of transmission lines
const N_J = 12 ## Number of natural gas nodes
const N_GS = 3 ## Number of natural gas suppliers
const N_P = 12 # 12 ## N pipes
const N_C = 2 ## N compressors
const N_L = length(elec_network_data["load"]) ## N elec loads

J = ["a","b","c","d","e","f","g","h","i","j","comp1","comp2",]

"base data";

    s_base = 100 ## MVA
    v_base = 138 ## kV
    z_base = v_base^2/s_base

"bus data";
    Bus = Dict()
    [Bus[i] = Dict() for i in Set_Bus]
    [(Bus[i]["pd"],Bus[i]["qd"]) = (0,0) for i in Set_Bus]
    [Bus[elec_network_data["load"]["$i"]["load_bus"]]["pd"] = elec_network_data["load"]["$i"]["pd"] for i in 1:N_L]
    [Bus[elec_network_data["load"]["$i"]["load_bus"]]["qd"] = elec_network_data["load"]["$i"]["qd"] for i in 1:N_L]
    sum(Bus[i]["pd"] for i in Set_Bus)
    sum(Bus[i]["qd"] for i in Set_Bus)

"generator data";

using XLSX
    cost_coef_gen = XLSX.readxlsx("Gen_cost.xlsx")["Sheet1!A1:C54"]

    Gen = Dict() ## Set of generating units
    [Gen[i] = Dict() for i in Set_Gen]
    [Gen[i]["bus"] = elec_network_data["gen"]["$i"]["gen_bus"] for i in Set_Gen]
    [Gen[i]["pmax"] = elec_network_data["gen"]["$i"]["pmax"] for i in Set_Gen]
    [Gen[i]["pmin"] = elec_network_data["gen"]["$i"]["pmin"] for i in Set_Gen]
    [Gen[i]["qmax"] = elec_network_data["gen"]["$i"]["qmax"] for i in Set_Gen]
    [Gen[i]["qmin"] = elec_network_data["gen"]["$i"]["qmin"] for i in Set_Gen]
    [Gen[i]["α"] = cost_coef_gen[i,3] for i in Set_Gen]
    [Gen[i]["β"] = cost_coef_gen[i,2] for i in Set_Gen]
    [Gen[i]["γ"] = cost_coef_gen[i,1] for i in Set_Gen]

    [Bus[Gen[i]["bus"]]["Gen"] = i for i in Set_Gen]

    sum(Gen[i]["pmax"] for i in Set_Gen)
    sum(Gen[i]["qmax"] for i in Set_Gen)

#####################################################################
"NATURAL GAS SIDE";

    Δt = 300 ## seconds
    Δx = 5000
    fr = 0.005 # friction factor
    c_s = 410 # speed of sound in m/s
    feet_cm = 30.48
    bar_atm = 0.986923
    bar_Pa = 1e5
    kcf_kg = 1000*(feet_cm/100)^3/bar_atm

"gas_supplier"
    v_max = [1250,2500,1750]
    v_min = [50,100,75] ## Max/min gas injection
    node_supplier = ["c" "a" "i"]
    cost_gs = [2, 1, 1.5]


"Pipe";

pip_length = [120/2, 120/2, 120, 120, 160, 160, 160, 160, 120/2, 120/2, 120, 120]*1e3

pip_diamater = 5*.6096*ones(N_P)

"Junction";

l_Gas = zeros(N_J)
    l_Gas[[4,5,7,10]] = [2000;3000;2000;1500]

comp_node = [11,12]
