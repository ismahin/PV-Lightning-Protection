function energy_J = mov_energy_update(previousEnergy_J,voltage_V,current_A,dt)
%MOV_ENERGY_UPDATE Shared absolute dissipated-energy accumulation.
energy_J=previousEnergy_J+dt*abs(voltage_V.*current_A);
end
