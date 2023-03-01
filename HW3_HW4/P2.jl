include("definitions.jl")
include("utils.jl")
include("matlab_utils.jl")
include("aircraft_eom.jl")

using LinearAlgebra
using Optim

function GetStateAndControl(trim_definition::TrimDefinition,trim_variables::TrimVariablesCT)

    #Parameters that don't matter
    x = y = ψ = 0.0

    #Parameters that matter
    ϕ = trim_variables.ϕ
    z = -trim_definition.h
    #=
    Since there is no wind, γ = γ_a.
    Also, this is constant altitude flight. So, flight path angle, γ=0.
    Thus, pitch θ = angle of attack α
    =#
    θ = trim_variables.α
    α = trim_variables.α
    β = trim_variables.β
    wind_angles = WindAngles(trim_definition.Va,β,α)
    Va_vector = WindAnglesToAirRelativeVelocityVector(wind_angles)
    u = Va_vector[1]
    v = Va_vector[2]
    w = Va_vector[3]
    #=
    Slides have defined the p,q,r terms using the rate of change of coarse angle χ. It is called chi
    χ_dot = (velocity_perpendicular_to_the_cirle)/R
    velocity_perpendicular_to_the_cirle = Va*cos(γ), where γ is the flight path angle.
    =#
    χ_dot = ( trim_definition.Va*cos(trim_definition.γ) )/ trim_definition.R
    p = -sin(θ)*χ_dot
    q = sin(ϕ)*cos(θ)*χ_dot
    r = cos(ϕ)*cos(θ)*χ_dot
    state = AircraftState(x,y,z,ϕ,θ,ψ,u,v,w,p,q,r)

    de = trim_variables.δe
    da = trim_variables.δa
    dr = trim_variables.δr
    dt = trim_variables.δt
    control = AircraftControl(de,da,dr,dt)

    return state,control
end


function GetCost(trim_definition::TrimDefinition,trim_variables::TrimVariablesCT,aircraft_parameters::AircraftParameters)

    state,control = GetStateAndControl(trim_definition,trim_variables)
    wind_inertial = [0.0,0.0,0.0]
    rho = stdatmo(-state.z)
    tangent_speed = trim_definition.Va*cos(trim_definition.γ)
    # current_R = (trim_definition.Va^2)/(aircraft_parameters.g*tan(state.roll))
    centripetal_acceleration = (tangent_speed*tangent_speed)/trim_definition.R
    a_desired_inertial_frame = [0.0, centripetal_acceleration, 0.0]
    euler_angles = EulerAngles(state.roll, state.pitch, state.yaw)
    a_desired_body_frame = TransformFromInertialToBody(a_desired_inertial_frame,euler_angles)
    desired_force = aircraft_parameters.m*a_desired_body_frame
    aero_force, aero_moment = AeroForcesAndMomentsBodyStateWindCoeffs(state, control, wind_inertial, rho, aircraft_parameters)
    total_force, total_moment = AircraftForcesAndMoments(state, control, wind_inertial, rho, aircraft_parameters)
    force = total_force - desired_force
    cost = norm(force,2)^2 + norm(total_moment,2)^2 + aero_force[2]^2

    return cost
end



function GetTrimConditionsCT(trim_definition::TrimDefinition,aircraft_parameters::AircraftParameters)
    lower = [-pi/4,-pi/4,0.0,-pi/4,-pi/4,-pi/4,-pi/4]
    upper = [pi/4,pi/4,1.0,pi/4,pi/4,pi/4,pi/4]
    initial_tv = [0.5,0.5,0.5,0.5,0.5,0.5,0.5]
    results = optimize(x->OptimizerCostFunction(x,trim_definition,aircraft_parameters), lower, upper, initial_tv)
    trim_variables_list = results.minimizer
    trim_variables = TrimVariablesCT(trim_variables_list...)
    state, control = GetStateAndControl(trim_definition, trim_variables)
    return state, control, results
end