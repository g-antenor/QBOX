-- Capacidade especifica de porta-malas por modelo: { slots, peso em gramas }.
-- Quando o modelo nao estiver aqui, o inventario usa a classe do veiculo.
local trunkModels = {
	[`xa21`] = {11, 10000},
	-- [`sultan`] = {30, 120000},
}

return {
	-- 0	vehicle has no storage
	-- 1	vehicle has no trunk storage
	-- 2	vehicle has no glovebox storage
	-- 3	vehicle has trunk in the hood
	Storage = {
		[`jester`] = 3,
		[`adder`] = 3,
		[`osiris`] = 1,
		[`pfister811`] = 1,
		[`penetrator`] = 1,
		[`autarch`] = 1,
		[`bullet`] = 1,
		[`cheetah`] = 1,
		[`cyclone`] = 1,
		[`voltic`] = 1,
		[`reaper`] = 3,
		[`entityxf`] = 1,
		[`t20`] = 1,
		[`taipan`] = 1,
		[`tezeract`] = 1,
		[`torero`] = 3,
		[`turismor`] = 1,
		[`fmj`] = 1,
		[`infernus`] = 1,
		[`italigtb`] = 3,
		[`italigtb2`] = 3,
		[`nero2`] = 1,
		[`vacca`] = 3,
		[`vagner`] = 1,
		[`visione`] = 1,
		[`prototipo`] = 1,
		[`zentorno`] = 1,
		[`trophytruck`] = 0,
		[`trophytruck2`] = 0,
	},

	-- Todos os porta-luvas: no maximo 5 slots e 5 kg.
	glovebox = {
		[0] = {5, 5000},		-- Compact
		[1] = {5, 5000},		-- Sedan
		[2] = {5, 5000},		-- SUV
		[3] = {5, 5000},		-- Coupe
		[4] = {5, 5000},		-- Muscle
		[5] = {5, 5000},		-- Sports Classic
		[6] = {5, 5000},		-- Sports
		[7] = {5, 5000},		-- Super
		[8] = {5, 5000},		-- Motorcycle
		[9] = {5, 5000},		-- Offroad
		[10] = {5, 5000},		-- Industrial
		[11] = {5, 5000},		-- Utility
		[12] = {5, 5000},		-- Van
		[14] = {5, 5000},		-- Boat
		[15] = {5, 5000},		-- Helicopter
		[16] = {5, 5000},		-- Plane
		[17] = {5, 5000},		-- Service
		[18] = {5, 5000},		-- Emergency
		[19] = {5, 5000},		-- Military
		[20] = {5, 5000},		-- Commercial (trucks)
		models = {
			[`xa21`] = {5, 5000}
		}
	},

	trunk = {
		[0] = {21, 168000},		-- Compact
		[1] = {41, 328000},		-- Sedan
		[2] = {51, 408000},		-- SUV
		[3] = {31, 248000},		-- Coupe
		[4] = {41, 328000},		-- Muscle
		[5] = {31, 248000},		-- Sports Classic
		[6] = {31, 248000},		-- Sports
		[7] = {21, 168000},		-- Super
		[8] = {5, 40000},		-- Motorcycle
		[9] = {51, 408000},		-- Offroad
		[10] = {51, 408000},	-- Industrial
		[11] = {41, 328000},	-- Utility
		[12] = {61, 488000},	-- Van
		-- [14] -- Boat
		-- [15] -- Helicopter
		-- [16] -- Plane
		[17] = {41, 328000},	-- Service
		[18] = {41, 328000},	-- Emergency
		[19] = {41, 328000},	-- Military
		[20] = {61, 488000},	-- Commercial
		models = trunkModels,
	}
}
