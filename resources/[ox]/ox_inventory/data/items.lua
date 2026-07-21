return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	['bandage'] = {
		label = 'Bandage',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'You ate a delicious burger'
		},
	},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
		label = 'Lockpick',
		weight = 160,
		-- consume = 0: quem decide o desgaste e o nv_garage. Sem isso o
		-- ox_inventory comeria um lockpick a cada tentativa, inclusive nas
		-- bem-sucedidas.
		consume = 0,
		-- durability: um lockpick novo nasce com 100. NAO use `degrade` junto:
		-- com degrade o ox_inventory trata `metadata.durability` como um
		-- timestamp de validade, e nao como porcentagem.
		durability = true,
		-- decay: some do inventario quando a durabilidade chega a zero.
		decay = true,
		client = {
			export = 'nv_garage.useLockpick'
		}
	},

	-- ------------------------------------------------------ nv_garage --

	['vehiclekey'] = {
		label = 'Chave de Veiculo',
		weight = 25,
		stack = false,
		close = true,
		description = 'A placa gravada na chave diz em qual carro ela funciona.',
		-- Sem isto o ox_inventory procura por `vehiclekey.png`, que nao existe,
		-- e o item fica com o icone quebrado.
		client = {
			image = 'carkey.png'
		}
	},

	['alicate'] = {
		label = 'Alicate de Corte',
		weight = 800,
		close = true,
		consume = 0,
		durability = true,
		decay = true,
		description = 'Ferramenta para ligacao direta e retirada de bloqueadores.',
		client = {
			export = 'nv_garage.removeBlocker',
			-- O pacote de imagens do ox_inventory nao tem alicate. A chave
			-- inglesa e o que mais se aproxima de "ferramenta"; troque por um
			-- `alicate.png` proprio em web/images quando tiver um.
			image = 'WEAPON_WRENCH.png'
		}
	},

	-- -------------------------------------------------------- nv_orgs --

	['org_key'] = {
		label = 'Chave',
		weight = 20,
		-- stack = false: cada chave carrega o set da organizacao no metadata, e
		-- empilhar duas de organizacoes diferentes esconderia uma delas.
		stack = false,
		close = true,
		consume = 0,
		description = 'Uma chave. A gravacao diz de qual organizacao.',
		client = {
			export = 'nv_orgs.useKey',
			image = 'carkey.png'
		}
	},

	['org_contact'] = {
		label = 'Pedaco de Papel',
		weight = 1,
		-- stack = false: cada papel carrega um numero diferente no metadata, e
		-- empilhar dois esconderia um deles.
		stack = false,
		close = true,
		consume = 0,
		description = 'Um numero de telefone anotado a mao.',
		client = {
			image = 'card_id.png'
		}
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true,
		consume = 0,
		client = {
			export = 'nv_radio.useRadio'
		}
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

	['delivery_letter'] = {
		label = 'Caixa Pequena',
		weight = 100,
	},

	['delivery_small_box'] = {
		label = 'Caixa Média',
		weight = 5000,
	},

	['delivery_large_package'] = {
		label = 'Caixa Grande',
		weight = 15000,
	},

	['glass'] = {
		label = 'Vidro',
		weight = 10,
	},

	['plastic_bottle'] = {
		label = 'Garrafa Plástica Vazia',
		weight = 5,
	},

	['empty_can'] = {
		label = 'Latinha Vazia',
		weight = 5,
	},

	['chips_bag'] = {
		label = 'Saco de Salgadinho Vazio',
		weight = 2,
	},

	['coffee_cup'] = {
		label = 'Copo de Café Vazio',
		weight = 2,
	},

	['beer_bottle_empty'] = {
		label = 'Garrafa de Cerveja Vazia',
		weight = 15,
	},

	['wine_bottle_empty'] = {
		label = 'Garrafa de Vinho Vazia',
		weight = 20,
	},

	['whiskey_bottle_empty'] = {
		label = 'Garrafa de Uísque Vazia',
		weight = 25,
	},

	['wire_cable'] = {
		label = 'Cabo de Fio',
		weight = 30,
	},

	['broken_phone'] = {
		label = 'Celular Quebrado',
		weight = 50,
	},

	['trash_bag_black'] = {
		label = 'Saco de Lixo Preto',
		weight = 100,
		client = {
			image = 'trash_bag_black.png'
		},
		model = `prop_rub_binbag_01`
	},

	['trash_bag_white'] = {
		label = 'Saco de Lixo Branco',
		weight = 100,
		client = {
			image = 'trash_bag_white.png'
		},
		model = `prop_rub_binbag_03`
	},

	['recycled_material'] = {
		label = 'Material reciclável',
		weight = 50,
		client = {
			image = 'recycled_material.png'
		}
	},

	-- ======================================================================
	-- CAÇA (nv_hunting)
	-- Sem imagem por enquanto: o ox_inventory cai no ícone padrão sozinho.
	-- ======================================================================
	['meat_boar']        = { label = 'Carne de Javali',        weight = 800 },
	['hide_boar']        = { label = 'Couro de Javali',        weight = 600 },
	['meat_deer']        = { label = 'Carne de Cervo',         weight = 900 },
	['hide_deer']        = { label = 'Couro de Cervo',         weight = 700 },
	['meat_coyote']      = { label = 'Carne de Coiote',        weight = 500 },
	['hide_coyote']      = { label = 'Couro de Coiote',        weight = 400 },
	['meat_mtlion']      = { label = 'Carne de Leão da Montanha', weight = 1000 },
	['hide_mtlion']      = { label = 'Couro de Leão da Montanha', weight = 800 },
	['meat_rabbit']      = { label = 'Carne de Coelho',        weight = 200 },
	['hide_rabbit']      = { label = 'Couro de Coelho',        weight = 150 },
	['meat_rat']         = { label = 'Carne de Rato',          weight = 100 },
	['hide_rat']         = { label = 'Couro de Rato',          weight = 80 },
	['meat_crow']        = { label = 'Carne de Corvo',         weight = 120 },
	['meat_seagull']     = { label = 'Carne de Gaivota',       weight = 150 },
	['meat_cormorant']   = { label = 'Carne de Cormorão',      weight = 180 },
	['meat_chickenhawk'] = { label = 'Carne de Falcão',        weight = 160 },

	-- ======================================================================
	-- PESCA (nv_hunting)
	-- ======================================================================
	['fishingrod'] = {
		label = 'Vara de Pesca',
		weight = 1500,
		stack = false,
		consume = 0,
		client = {
			export = 'nv_hunting.useRod'
		}
	},
	['fishbait']      = { label = 'Isca de Pesca',    weight = 10 },

	-- Lixo
	['fishingtin']    = { label = 'Lata Enferrujada', weight = 100 },
	['fishingboot']   = { label = 'Bota Velha',       weight = 400 },

	-- Peixes pequenos
	['mackerel']      = { label = 'Cavala',           weight = 400 },
	['flounder']      = { label = 'Linguado',         weight = 500 },

	-- Peixes médios
	['bass']          = { label = 'Robalo',           weight = 900 },
	['codfish']       = { label = 'Bacalhau',         weight = 1100 },

	-- Peixes grandes
	['stingray']      = { label = 'Arraia',           weight = 2500 },

	-- Raros de mar aberto
	['sharkhammer']   = { label = 'Tubarão-martelo',  weight = 8000 },
	['sharktiger']    = { label = 'Tubarão-tigre',    weight = 9000 },
	['dolphin']       = { label = 'Golfinho',         weight = 7000 },
	['killerwhale']   = { label = 'Orca',             weight = 12000 },

	-- Baú de tesouro
	['fishinglootbig'] = { label = 'Baú Submerso',    weight = 3000, stack = false },
	-- Comprovante emitido pelas lojas (nv_shops). `stack = false` porque cada
	-- nota tem metadata propria: empilhar juntaria compras diferentes na mesma
	-- pilha e a descricao de uma sobreporia a da outra.
	['nota_fiscal']   = { label = 'Nota Fiscal',      weight = 5, stack = false },

	-- ------------------------------------------------------ nv_dispatch --

	-- Corta o rastreio que gera os chamados de roubo. NAO e invisibilidade: o
	-- servidor troca o chamado por um "perda de sinal" com a posicao borrada,
	-- entao a policia continua sabendo que ha algo acontecendo na regiao.
	--
	-- `consume = 0` porque quem remove o item e o nv_dispatch, que precisa
	-- O aparelho preserva a carga enquanto instalado no veiculo. A carga volta
	-- no metadata ao retirar; se chegar a zero, o modulo quebrado nao retorna.
	['bloqueador_sinal'] = {
		label = 'Bloqueador de Sinal',
		weight = 340,
		stack = false,
		consume = 0,
		durability = true,
		decay = true,
		description = 'Modulo persistente de bloqueio do rastreamento veicular.',
		client = {
			export = 'nv_garage.installBlocker'
		}
	},

	['dealership'] = {
		label = 'Painel da Concessionaria',
		weight = 350,
		stack = false,
		consume = 0,
		close = true,
		description = 'Painel de estoque, vendas e encomendas da concessionaria.',
		client = { export = 'nv_dealership.open' },
		image = 'dealership_tablet.png'
	},

	['dealership_invoice'] = {
		label = 'Nota Fiscal da Concessionaria',
		weight = 10,
		stack = false,
		consume = 0,
		close = false,
		description = 'Nota fiscal usada para retirar uma encomenda de veiculos.'
	},

	-- ------------------------------------------------------ nv_mechanic --

	['car_door'] = { label = 'Porta de Veiculo', weight = 18000, stack = true },
	['car_hood'] = { label = 'Capo de Veiculo', weight = 16000, stack = true },
	['car_trunk'] = { label = 'Porta-malas de Veiculo', weight = 15000, stack = true },
	['car_bumper'] = { label = 'Para-choque', weight = 9000, stack = true },
	['car_window'] = { label = 'Vidro Automotivo', weight = 4500, stack = true },
	['car_tyre'] = { label = 'Pneu', weight = 11000, stack = true },
	['reinforced_plastic'] = { label = 'Plastico Reforcado', weight = 2500, stack = true },
	['sheet_metal'] = { label = 'Chapa de Metal', weight = 5000, stack = true },
	['automotive_glass'] = { label = 'Vidro Automotivo', weight = 4000, stack = true },

	-- Componentes de armamento usados pelo crafting por formato.
	['pistol_slide'] = {
		label = 'Ferrolho de Pistola', weight = 420, stack = true,
		client = { image = 'pistol_slide.png' }
	},
	['pistol_barrel'] = {
		label = 'Cano de Pistola', weight = 260, stack = true,
		client = { image = 'pistol_barrel.png' }
	},
	['pistol_grip'] = {
		label = 'Armacao de Pistola', weight = 320, stack = true,
		client = { image = 'pistol_grip.png' }
	},
	['pistol_trigger'] = {
		label = 'Conjunto de Gatilho', weight = 110, stack = true,
		client = { image = 'pistol_trigger.png' }
	},
	['pistol_magazine'] = {
		label = 'Carregador de Pistola', weight = 180, stack = true,
		client = { image = 'pistol_magazine.png' }
	},
	['toolbox'] = {
		label = 'Caixa de Ferramentas', weight = 8000, stack = false,
		consume = 0, durability = true, decay = true,
		client = { export = 'nv_mechanic.useToolbox' }
	},
	['wheel_wrench'] = {
		label = 'Chave de Roda', weight = 2200, stack = false,
		consume = 0, durability = true, decay = true
	},
	['blowtorch'] = {
		label = 'Macarico', weight = 6500, stack = false,
		consume = 0, durability = true, decay = true
	},
	['fire_extinguisher'] = {
		label = 'Extintor', weight = 9000, stack = false,
		consume = 0, durability = true, decay = true,
		client = { export = 'nv_mechanic.useExtinguisher' }
	},
}
