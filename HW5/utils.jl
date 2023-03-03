#=
Author: Himanshu Gupta
=#

#Function to get rotation matrix that rotates around the z axis
function GetRotationMatrixFromInertialToV1(yaw)
    rotation_matrix = [
                        cos(yaw) sin(yaw) 0;
                        -sin(yaw) cos(yaw) 0;
                        0 0 1
                        ]
    return rotation_matrix
end

#Function to get rotation matrix that rotates around the y axis
function GetRotationMatrixFromV1ToV2(pitch)
    rotation_matrix = [
                        cos(pitch) 0 -sin(pitch);
                        0 1 0;
                        sin(pitch) 0 cos(pitch)
                        ]
    return rotation_matrix
end

#Function to get rotation matrix that rotates around the x axis
function GetRotationMatrixFromV2ToBody(roll)
    rotation_matrix = [
                        1 0 0;
                        0 cos(roll) sin(roll);
                        0 -sin(roll) cos(roll)
                        ]
    return rotation_matrix
end

#Function to get rotation matrix that rotates around z,y and then x axis
function RotationMatrix321(euler_angles::EulerAngles)

    roll = euler_angles.roll
    pitch = euler_angles.pitch
    yaw = euler_angles.yaw
    RMFromIntertialToV1 = GetRotationMatrixFromInertialToV1(yaw)
    RMFromV1ToV2 = GetRotationMatrixFromV1ToV2(pitch)
    RMFromV2ToBody = GetRotationMatrixFromV2ToBody(roll)
    #GetRotationMatrixToTransformFromInertialToBody
    RM = RMFromV2ToBody*RMFromV1ToV2*RMFromIntertialToV1
    return RM
end

#Function to transform vector from body frame to inertial frame
function TransformFromBodyToInertial(VectorBody, euler_angles::EulerAngles)
    rotation_matrix = RotationMatrix321(euler_angles)
    v = transpose(rotation_matrix)*VectorBody
    return v
end

#Function to transform vector from inertial frame to body frame
function TransformFromInertialToBody(VectorBody, euler_angles::EulerAngles)
    rotation_matrix = RotationMatrix321(euler_angles)
    v = rotation_matrix*VectorBody
    return v
end

#Function to get Air Relative Vehcile Velocity Vector in Body Frame from Wind Angles
function WindAnglesToAirRelativeVelocityVector(wind_angles::WindAngles)
    Va = wind_angles.Va
    beta = wind_angles.beta
    alpha = wind_angles.alpha
    u = Va*cos(alpha)*cos(beta)
    v = Va*sin(beta)
    w = Va*sin(alpha)*cos(beta)
    AirSpeedInBodyFrame = [u,v,w]  #This is the VelocityBody vector
    return AirSpeedInBodyFrame
end

#Function to get Wind Angles from Air Relative Vehcile Velocity Vector in Body Frame
function AirRelativeVelocityVectorToWindAngles(VelocityBody)
    u = VelocityBody[1]
    v = VelocityBody[2]
    w = VelocityBody[3]
    Va = sqrt( (u*u) + (v*v) + (w*w) )
    beta = asin(v/Va)
    alpha = atan(w/u)
    wind_angles = WindAngles(Va, beta, alpha)
    return wind_angles
end

#Function to get the multiplication matrix for rotational kinematics in ODEs
function GetRotationalKinematicsMatrix(euler_angles::EulerAngles)

    roll = euler_angles.roll #phi
    pitch = euler_angles.pitch #theta
    yaw = euler_angles.yaw #psi
    multiplication_matrix = [
                        1 sin(roll)*tan(pitch) cos(roll)*tan(pitch);
                        0 cos(roll) -sin(roll);
                        0 sin(roll)*sec(pitch) cos(roll)*sec(pitch)
                        ]
    return multiplication_matrix
end


#Function to get all the gamma values for rotational dynamics
function GetGammaValues(aircraft_parameters::AircraftParameters)
    Ix = aircraft_parameters.Ix
    Iy = aircraft_parameters.Iy
    Iz = aircraft_parameters.Iz
    Ixz = aircraft_parameters.Ixz

    Gamma = (Ix*Iz) - (Ixz^2)
    Gamma1 = (Ixz * (Ix-Iy+Iz))/Gamma
    Gamma2 = ( (Ixz^2) + (Iz*(Iz-Iy)) )/Gamma
    Gamma3 = Iz/Gamma
    Gamma4 = Ixz/Gamma
    Gamma5 = (Iz - Ix)/Iy
    Gamma6 = Ixz/Iy
    Gamma7 = ( (Ixz^2) + (Ix*(Ix-Iy)) )/Gamma
    Gamma8 = Ix/Gamma

    GammaArray = [Gamma1,Gamma2,Gamma3,Gamma4,Gamma5,Gamma6,Gamma7,Gamma8,Gamma]
    return GammaArray
end


function GetCoefficients(aircraft_state::AircraftState, aircraft_surfaces::AircraftControl, wind_angles::WindAngles, aircraft_parameters::AircraftParameters)

    Va = wind_angles.Va
    beta = wind_angles.beta
    alpha = wind_angles.alpha
    p_hat = 0.5*aircraft_state.p*aircraft_parameters.b/Va
    q_hat = 0.5*aircraft_state.q*aircraft_parameters.c/Va
    r_hat = 0.5*aircraft_state.r*aircraft_parameters.b/Va
    delta_e = aircraft_surfaces.de
    delta_a = aircraft_surfaces.da
    delta_r = aircraft_surfaces.dr
    delta_t = aircraft_surfaces.dt

    CL = aircraft_parameters.CL0 + (aircraft_parameters.CLalpha*alpha) + (aircraft_parameters.CLq*q_hat) +
                            (aircraft_parameters.CLde*delta_e)
    CD = aircraft_parameters.CDmin + (aircraft_parameters.K * (CL - aircraft_parameters.CLmin)^2)
    CT = 2*(aircraft_parameters.Sprop/aircraft_parameters.S)*aircraft_parameters.Cprop*(delta_t/(Va^2))
    CT = CT * ( Va + delta_t*(aircraft_parameters.kmotor-Va) ) * (aircraft_parameters.kmotor - Va)
    CY = (aircraft_parameters.CYbeta*beta) + (aircraft_parameters.CYp*p_hat) + (aircraft_parameters.CYr*r_hat) +
                            (aircraft_parameters.CYda*delta_a) + (aircraft_parameters.CYdr*delta_r)
    Cl = (aircraft_parameters.Clbeta*beta) + (aircraft_parameters.Clp*p_hat) + (aircraft_parameters.Clr*r_hat) +
                            (aircraft_parameters.Clda*delta_a) + (aircraft_parameters.Cldr*delta_r)
    Cm = aircraft_parameters.Cm0 + (aircraft_parameters.Cmalpha*alpha) + (aircraft_parameters.Cmq*q_hat) +
                            (aircraft_parameters.Cmde*delta_e)
    Cn = (aircraft_parameters.Cnbeta*beta) + (aircraft_parameters.Cnp*p_hat) + (aircraft_parameters.Cnr*r_hat) +
                            (aircraft_parameters.Cnda*delta_a) + (aircraft_parameters.Cndr*delta_r)
    CX = ( CL*sin(alpha) ) - ( CD*cos(alpha) )
    CZ = ( -CL*cos(alpha) ) - ( CD*sin(alpha) )

    CoefficientsDict = Dict(
                            "CL" => CL,
                            "CD" => CD,
                            "CT" => CT,
                            "CY" => CY,
                            "Cl" => Cl,
                            "Cm" => Cm,
                            "Cn" => Cn,
                            "CX" => CX,
                            "CZ" => CZ
                        )

    return CoefficientsDict
end

function GetLateralEOMCoefficients(Γ::Array{Float64},ap::AircraftParameters)
    #For roll rate p
    Cp0 = Γ[3]*ap.Cl0 + Γ[4]*ap.Cn0
    Cpβ = Γ[3]*ap.Clbeta + Γ[4]*ap.Cnbeta
    Cpp = Γ[3]*ap.Clp + Γ[4]*ap.Cnp
    Cpr = Γ[3]*ap.Clr + Γ[4]*ap.Cnr
    Cpδa = Γ[3]*ap.Clda + Γ[4]*ap.Cnda
    Cpδr = Γ[3]*ap.Cldr + Γ[4]*ap.Cndr

    #For yaw rate r
    Cr0 = Γ[4]*ap.Cl0 + Γ[8]*ap.Cn0
    Crβ = Γ[4]*ap.Clbeta + Γ[8]*ap.Cnbeta
    Crp = Γ[4]*ap.Clp + Γ[8]*ap.Cnp
    Crr = Γ[4]*ap.Clr + Γ[8]*ap.Cnr
    Crδa = Γ[4]*ap.Clda + Γ[8]*ap.Cnda
    Crδr = Γ[4]*ap.Cldr + Γ[8]*ap.Cndr

    CoefficientsDict = Dict(
                            "Cp0" => Cp0,
                            "Cpβ" => Cpβ,
                            "Cpp" => Cpp,
                            "Cpr" => Cpr,
                            "Cpδa" => Cpδa,
                            "Cpδr" => Cpδr,
                            "Cr0" => Cr0,
                            "Crβ" => Crβ,
                            "Crp" => Crp,
                            "Crr" => Crr,
                            "Crδa" => Crδa,
                            "Crδr" => Crδr
                        )

    return CoefficientsDict
end

function wrap_between_negative_pi_to_pi(theta)
    if(theta>pi)
        return theta-2*pi
    else
        return theta
    end
end

function wrap_between_0_and_2Pi(theta)
   return mod(theta,2*pi)
end
