extends Node2D

#=== CONSTANTES E VARIÁVEIS GLOBAIS ===
# Define o tamanho da matriz (60x60)
const TAMANHO = 60
# Número máximo de iterações para geração
const MAX_ITERACOES = 200
# Número máximo de correções no pós-processamento
const MAX_CORRECOES = 50
# Gerador de números aleatórios
var gerador_aleatorio = RandomNumberGenerator.new()
# Referência ao TileMap
@onready var mapa_de_tiles = $TileMapLayer

#=== REGRAS DE PROPAGAÇÃO ===
# Define as transições possíveis para cada tipo de pista
var regras = {
	1: [1.5],      # Pista vertical (baixo) pode virar curva especial
	1.5: [1.5, 13], # Curva especial pode continuar ou bifurcar
	2: [2.5],      # Pista horizontal (direita) pode virar curva especial
	2.5: [2.5, 15], # Curva especial pode continuar ou bifurcar
	3: [3.5],      # Pista vertical (cima) pode virar curva especial
	3.5: [3.5, 14], # Curva especial pode continuar ou bifurcar
	4: [4.5],      # Pista horizontal (esquerda) pode virar curva especial
	4.5: [4.5, 16], # Curva especial pode continuar ou bifurcar
	5: [1],        # Pistas de conexão específicas
	6: [1],
	7: [4],
	8: [2],
	9: [2],
	10: [4],
	11: [3],
	12: [3]
}

#=== DIREÇÕES DE PROPAGAÇÃO ===
# Define o vetor de direção para cada tipo de pista
var direcoes = {
	1: Vector2i(0, 1),   # Baixo
	1.5: Vector2i(0, 1), # Baixo
	5: Vector2i(0, 1),   # Baixo
	6: Vector2i(0, 1),   # Baixo

	2: Vector2i(1, 0),   # Direita
	2.5: Vector2i(1, 0), # Direita
	8: Vector2i(1, 0),   # Direita
	9: Vector2i(1, 0),   # Direita

	3: Vector2i(0, -1),  # Cima
	3.5: Vector2i(0, -1),# Cima
	11: Vector2i(0, -1), # Cima
	12: Vector2i(0, -1), # Cima

	4: Vector2i(-1, 0),  # Esquerda
	4.5: Vector2i(-1, 0),# Esquerda
	7: Vector2i(-1, 0),  # Esquerda
	10: Vector2i(-1, 0)  # Esquerda
}

#=== MAPEAMENTO DAS TILES ===
# Associa cada valor da matriz a uma coordenada no tileset
var tiles = {
	0.5: Vector2i(4,0), # Cruzamento especial
	0: Vector2i(6,5),   # Célula vazia
	1: Vector2i(0,0),   # Pista vertical
	2: Vector2i(1,0),   # Pista horizontal
	3: Vector2i(2,0),   # Pista vertical (cima)
	4: Vector2i(3,0),   # Pista horizontal (esquerda)
	5: Vector2i(0,1),   # Curvas e conexões
	6: Vector2i(1,1),
	7: Vector2i(2,1),
	8: Vector2i(3,1),
	9: Vector2i(0,2),
	10: Vector2i(1,2),
	11: Vector2i(2,2),
	12: Vector2i(3,2),
	13: Vector2i(0,3),  # Bifurcações
	14: Vector2i(1,3),
	15: Vector2i(2,3),
	16: Vector2i(3,3)
}

#=== CONVERSÃO VISUAL ===
# Converte valores especiais (.5) para inteiros na renderização
var mapeamento_visual = {
	1.5: 1,
	2.5: 2,
	3.5: 3,
	4.5: 4
}

#=== INICIALIZAÇÃO ===
func _ready():
	# Inicializa o gerador de números aleatórios
	gerador_aleatorio.randomize()
	# Gera e renderiza o mapa inicial
	gerar_e_renderizar()

#=== CONTROLE DE INPUT ===
func _unhandled_input(evento):
	# Regenera o mapa ao pressionar R ou ação "gerar"
	if evento.is_action_pressed("gerar") or (evento is InputEventKey and evento.pressed and evento.keycode == KEY_R):
		gerar_e_renderizar()

#=== FUNÇÃO PRINCIPAL DE GERAÇÃO ===
func gerar_e_renderizar():
	# Gera a matriz de pistas
	var matriz = gerar_matriz()
	# Aplica correções pós-geração
	matriz = pos_processamento(matriz)
	# Renderiza no TileMap
	renderizar_mapa_de_tiles(matriz)

#=== GERADOR DA MATRIZ ===
func gerar_matriz():
	# Inicializa matriz vazia
	var matriz = []
	for i in range(TAMANHO):
		matriz.append([])
		matriz[i].resize(TAMANHO)
		for j in range(TAMANHO):
			matriz[i][j] = 0

	var celulas_ativas = []

	#=== ESTRUTURA FIXA INICIAL ===
	var centro_x = TAMANHO / 2  # Centro X
	var centro_y = TAMANHO / 2  # Centro Y

	# Cria cruzamento central composto por:
	# - Duas pistas verticais (colunas centro_x e centro_x+1)
	# - Duas pistas horizontais (linhas centro_y e centro_y+1)
	for y in range(TAMANHO):
		if y < centro_y:
			matriz[y][centro_x] = 1   # Pista para baixo
			matriz[y][centro_x+1] = 3 # Pista para cima
		else:
			matriz[y][centro_x] = 1
			matriz[y][centro_x+1] = 3

	# Linha central horizontal
	for x in range(TAMANHO):
		if x < centro_x:
			matriz[centro_y][x] = 2   # Pista para direita
			matriz[centro_y+1][x] = 4 # Pista para esquerda
		else:
			matriz[centro_y][x] = 2
			matriz[centro_y+1][x] = 4

	# Centro do cruzamento (área especial)
	matriz[centro_y][centro_x] = 0.5
	matriz[centro_y][centro_x+1] = 0.5
	matriz[centro_y+1][centro_x] = 0.5
	matriz[centro_y+1][centro_x+1] = 0.5

	# Define as pontas das pistas centrais
	matriz[0][centro_x] = 1           # Topo da pista vertical esquerda
	matriz[TAMANHO-1][centro_x+1] = 3 # Base da pista vertical direita
	matriz[centro_y][0] = 2           # Início da pista horizontal superior
	matriz[centro_y+1][TAMANHO-1] = 4 # Fim da pista horizontal inferior

	# Inicia propagação a partir das pontas
	celulas_ativas.append(Vector2i(centro_x, 0))
	celulas_ativas.append(Vector2i(centro_x+1, TAMANHO-1))
	celulas_ativas.append(Vector2i(0, centro_y))
	celulas_ativas.append(Vector2i(TAMANHO-1, centro_y+1))

	#=== EXPANSÃO VIA L-SYSTEM ===
	for iteracao in range(MAX_ITERACOES):
		var novas_celulas_ativas = []
		for posicao in celulas_ativas:
			var valor = matriz[posicao.y][posicao.x]
			
			# Processa bifurcações primeiro
			if valor in [13,14,15,16]:
				novas_celulas_ativas += _processar_casos_especiais(matriz, posicao, valor)
				continue

			# Propaga pistas normais
			if regras.has(valor) and direcoes.has(valor):
				var direcao = direcoes[valor]
				var nova_posicao = posicao + direcao
				
				# Verifica limites do mapa
				if nova_posicao.x >= 0 and nova_posicao.x < TAMANHO and nova_posicao.y >= 0 and nova_posicao.y < TAMANHO:
					if matriz[nova_posicao.y][nova_posicao.x] == 0:
						# Verifica se pode gerar pista evitando mão dupla
						if _pode_gerar_pista(matriz, nova_posicao, direcao):
							var opcoes = regras[valor]
							var escolha = opcoes[gerador_aleatorio.randi_range(0, opcoes.size() - 1)]

							# Tratamento especial para bifurcações
							if escolha in [13, 14, 15, 16]:
								if _area_livre_de_bifurcacoes(matriz, nova_posicao):
									matriz[nova_posicao.y][nova_posicao.x] = escolha
								else:
									# Fallback para pista normal
									var substituto = int(valor)
									matriz[nova_posicao.y][nova_posicao.x] = substituto
									novas_celulas_ativas.append(nova_posicao)
							else:
								matriz[nova_posicao.y][nova_posicao.x] = escolha
								novas_celulas_ativas.append(nova_posicao)
		
		# Encerra se não houver novos pontos ativos
		if novas_celulas_ativas.is_empty():
			break
		celulas_ativas = novas_celulas_ativas

	#=== GERAÇÃO DE RUAS EXTRAS ===
	var celulas_ativas_extras = []
	
	# Define zona central protegida
	var zona_central_x_min = centro_x - 5
	var zona_central_x_max = centro_x + 6
	var zona_central_y_min = centro_y - 5
	var zona_central_y_max = centro_y + 6
	
	# Gera ruas nas bordas com espaçamento aleatório
	# Topo (y = 0)
	var x = 0
	while x < TAMANHO:
		if x < zona_central_x_min or x > zona_central_x_max:
			if matriz[0][x] == 0:
				matriz[0][x] = 1
				celulas_ativas_extras.append(Vector2i(x, 0))
		x += gerador_aleatorio.randi_range(2, 5)
	
	# Base (y = TAMANHO-1)
	x = 0
	while x < TAMANHO:
		if x < zona_central_x_min or x > zona_central_x_max:
			if matriz[TAMANHO-1][x] == 0:
				matriz[TAMANHO-1][x] = 3
				celulas_ativas_extras.append(Vector2i(x, TAMANHO-1))
		x += gerador_aleatorio.randi_range(2, 5)
	
	# Esquerda (x = 0)
	var y = 0
	while y < TAMANHO:
		if y < zona_central_y_min or y > zona_central_y_max:
			if matriz[y][0] == 0:
				matriz[y][0] = 2
				celulas_ativas_extras.append(Vector2i(0, y))
		y += gerador_aleatorio.randi_range(2, 5)
	
	# Direita (x = TAMANHO-1)
	y = 0
	while y < TAMANHO:
		if y < zona_central_y_min or y > zona_central_y_max:
			if matriz[y][TAMANHO-1] == 0:
				matriz[y][TAMANHO-1] = 4
				celulas_ativas_extras.append(Vector2i(TAMANHO-1, y))
		y += gerador_aleatorio.randi_range(2, 5)
	
	# Gera ruas paralelas às pistas centrais
	# Pista vertical esquerda
	y = 0
	while y < TAMANHO:
		if y < zona_central_y_min or y > zona_central_y_max:
			if matriz[y][centro_x] != 0:
				var novo_x = centro_x - 1
				if novo_x >= 0 and matriz[y][novo_x] == 0:
					if _pode_gerar_pista(matriz, Vector2i(novo_x, y), Vector2i(-1, 0)):
						matriz[y][novo_x] = 4
						celulas_ativas_extras.append(Vector2i(novo_x, y))
		y += gerador_aleatorio.randi_range(2, 5)
	
	# Pista vertical direita
	y = 0
	while y < TAMANHO:
		if y < zona_central_y_min or y > zona_central_y_max:
			if matriz[y][centro_x+1] != 0:
				var novo_x = centro_x + 2
				if novo_x < TAMANHO and matriz[y][novo_x] == 0:
					if _pode_gerar_pista(matriz, Vector2i(novo_x, y), Vector2i(1, 0)):
						matriz[y][novo_x] = 2
						celulas_ativas_extras.append(Vector2i(novo_x, y))
		y += gerador_aleatorio.randi_range(2, 5)
	
	# Pista horizontal superior
	x = 0
	while x < TAMANHO:
		if x < zona_central_x_min or x > zona_central_x_max:
			if matriz[centro_y][x] != 0:
				var novo_y = centro_y - 1
				if novo_y >= 0 and matriz[novo_y][x] == 0:
					if _pode_gerar_pista(matriz, Vector2i(x, novo_y), Vector2i(0, -1)):
						matriz[novo_y][x] = 3
						celulas_ativas_extras.append(Vector2i(x, novo_y))
		x += gerador_aleatorio.randi_range(2, 5)
	
	# Pista horizontal inferior
	x = 0
	while x < TAMANHO:
		if x < zona_central_x_min or x > zona_central_x_max:
			if matriz[centro_y+1][x] != 0:
				var novo_y = centro_y + 2
				if novo_y < TAMANHO and matriz[novo_y][x] == 0:
					if _pode_gerar_pista(matriz, Vector2i(x, novo_y), Vector2i(0, 1)):
						matriz[novo_y][x] = 1
						celulas_ativas_extras.append(Vector2i(x, novo_y))
		x += gerador_aleatorio.randi_range(2, 5)
	
	# Propaga as ruas extras geradas
	for posicao in celulas_ativas_extras:
		var valor = matriz[posicao.y][posicao.x]
		if regras.has(valor) and direcoes.has(valor):
			var direcao = direcoes[valor]
			var nova_posicao = posicao + direcao
			if nova_posicao.x >= 0 and nova_posicao.x < TAMANHO and nova_posicao.y >= 0 and nova_posicao.y < TAMANHO:
				if matriz[nova_posicao.y][nova_posicao.x] == 0:
					if _pode_gerar_pista(matriz, nova_posicao, direcao):
						var opcoes = regras[valor]
						var escolha = opcoes[gerador_aleatorio.randi_range(0, opcoes.size() - 1)]
						
						# Aplica mesma verificação de bifurcação
						if escolha in [13, 14, 15, 16]:
							if _area_livre_de_bifurcacoes(matriz, nova_posicao):
								matriz[nova_posicao.y][nova_posicao.x] = escolha
							else:
								var substituto = int(valor)
								matriz[nova_posicao.y][nova_posicao.x] = substituto
						else:
							matriz[nova_posicao.y][nova_posicao.x] = escolha

	return matriz

#=== VERIFICAÇÃO DE GERAÇÃO DE PISTA ===
func _pode_gerar_pista(matriz, posicao, direcao_geracao) -> bool:
	# Permite geração nas coordenadas centrais
	if posicao.x == 30 or posicao.x == 31 or posicao.y == 30 or posicao.y == 31:
		return true
	
	var direcao_oposta = -direcao_geracao
	
	# Lista de direções para verificar (excluindo direção atual e oposta)
	var direcoes_verificar = [
		Vector2i(0, -1),  # Cima
		Vector2i(1, 0),   # Direita  
		Vector2i(0, 1),   # Baixo
		Vector2i(-1, 0)   # Esquerda
	]
	
	direcoes_verificar.erase(direcao_geracao)
	direcoes_verificar.erase(direcao_oposta)
	
	# Verifica células adjacentes
	for direcao in direcoes_verificar:
		var adjacente_x = posicao.x + direcao.x
		var adjacente_y = posicao.y + direcao.y
		
		if adjacente_x < 0 or adjacente_x >= TAMANHO or adjacente_y < 0 or adjacente_y >= TAMANHO:
			continue
			
		var valor_adjacente = matriz[adjacente_y][adjacente_x]
		
		if valor_adjacente == 0:
			continue
		
		# Obtém direção da pista adjacente
		var direcao_adjacente = _obter_direcao_pista(valor_adjacente)
		
		# Bloqueia se houver pista paralela próxima
		if _sao_mesma_direcao_ou_oposta(direcao_adjacente, direcao_geracao):
			return false
	
	return true

#=== IDENTIFICA DIREÇÃO DA PISTA ===
func _obter_direcao_pista(valor):
	# Retorna o vetor direção baseado no tipo de pista
	match valor:
		1, 1.5, 5, 6, 13, 16:
			return Vector2i(0, 1)   # Baixo
		2, 2.5, 8, 9, 14, 15:
			return Vector2i(1, 0)   # Direita 
		3, 3.5, 11, 12:
			return Vector2i(0, -1)  # Cima
		4, 4.5, 7, 10:
			return Vector2i(-1, 0)  # Esquerda
		_:
			return Vector2i(0, 0)

#=== COMPARA DIREÇÕES ===
func _sao_mesma_direcao_ou_oposta(direcao1, direcao2):
	# Verifica se as direções são iguais ou opostas
	if direcao1 == direcao2:
		return true
	if direcao1 == -direcao2:
		return true
	return false

#=== PROCESSAMENTO DE BIFURCAÇÕES ===
func _processar_casos_especiais(matriz, posicao, valor):
	var novas_celulas_ativas = []

	match valor:
		13:  # Bifurcação que gera pistas horizontais
			# Tenta gerar à direita
			var posicao_direita = posicao + Vector2i(1, 0)
			if posicao_direita.x < TAMANHO and matriz[posicao_direita.y][posicao_direita.x] == 0:
				if _pode_gerar_pista(matriz, posicao_direita, Vector2i(1, 0)):
					matriz[posicao_direita.y][posicao_direita.x] = 2
					novas_celulas_ativas.append(posicao_direita)
			# Tenta gerar à esquerda
			var posicao_esquerda = posicao + Vector2i(-1, 0)
			if posicao_esquerda.x >= 0 and matriz[posicao_esquerda.y][posicao_esquerda.x] == 0:
				if _pode_gerar_pista(matriz, posicao_esquerda, Vector2i(-1, 0)):
					matriz[posicao_esquerda.y][posicao_esquerda.x] = 4
					novas_celulas_ativas.append(posicao_esquerda)

		14:  # Bifurcação que gera pistas horizontais (outro tipo)
			var posicao_direita = posicao + Vector2i(1, 0)
			if posicao_direita.x < TAMANHO and matriz[posicao_direita.y][posicao_direita.x] == 0:
				if _pode_gerar_pista(matriz, posicao_direita, Vector2i(1, 0)):
					matriz[posicao_direita.y][posicao_direita.x] = 2
					novas_celulas_ativas.append(posicao_direita)
			var posicao_esquerda = posicao + Vector2i(-1, 0)
			if posicao_esquerda.x >= 0 and matriz[posicao_esquerda.y][posicao_esquerda.x] == 0:
				if _pode_gerar_pista(matriz, posicao_esquerda, Vector2i(-1, 0)):
					matriz[posicao_esquerda.y][posicao_esquerda.x] = 4
					novas_celulas_ativas.append(posicao_esquerda)

		15:  # Bifurcação que gera pistas verticais
			# Tenta gerar para cima
			var posicao_cima = posicao + Vector2i(0, -1)
			if posicao_cima.y >= 0 and matriz[posicao_cima.y][posicao_cima.x] == 0:
				if _pode_gerar_pista(matriz, posicao_cima, Vector2i(0, -1)):
					matriz[posicao_cima.y][posicao_cima.x] = 3
					novas_celulas_ativas.append(posicao_cima)
			# Tenta gerar para baixo
			var posicao_baixo = posicao + Vector2i(0, 1)
			if posicao_baixo.y < TAMANHO and matriz[posicao_baixo.y][posicao_baixo.x] == 0:
				if _pode_gerar_pista(matriz, posicao_baixo, Vector2i(0, 1)):
					matriz[posicao_baixo.y][posicao_baixo.x] = 1
					novas_celulas_ativas.append(posicao_baixo)

		16:  # Bifurcação que gera pistas verticais (outro tipo)
			var posicao_cima = posicao + Vector2i(0, -1)
			if posicao_cima.y >= 0 and matriz[posicao_cima.y][posicao_cima.x] == 0:
				if _pode_gerar_pista(matriz, posicao_cima, Vector2i(0, -1)):
					matriz[posicao_cima.y][posicao_cima.x] = 3
					novas_celulas_ativas.append(posicao_cima)
			var posicao_baixo = posicao + Vector2i(0, 1)
			if posicao_baixo.y < TAMANHO and matriz[posicao_baixo.y][posicao_baixo.x] == 0:
				if _pode_gerar_pista(matriz, posicao_baixo, Vector2i(0, 1)):
					matriz[posicao_baixo.y][posicao_baixo.x] = 1
					novas_celulas_ativas.append(posicao_baixo)

	return novas_celulas_ativas

#=== VERIFICAÇÃO DE ÁREA PARA BIFURCAÇÕES ===
func _area_livre_de_bifurcacoes(matriz: Array, posicao: Vector2i) -> bool:
	# Verifica área 5x5 ao redor da posição
	for delta_y in range(-2, 3):
		for delta_x in range(-2, 3):
			var novo_x = posicao.x + delta_x
			var novo_y = posicao.y + delta_y
			# Ignora posições fora do mapa
			if novo_x < 0 or novo_y < 0 or novo_x >= TAMANHO or novo_y >= TAMANHO:
				continue
			# Se encontrar outra bifurcação, retorna falso
			var valor = matriz[novo_y][novo_x]
			if valor in [13, 14, 15, 16]:
				return false
	return true

#=== PÓS-PROCESSAMENTO ===
func pos_processamento(matriz):
	var correcoes = 0
	var fez_correcao = true
	
	# Loop de correções até não haver mais mudanças
	while fez_correcao and correcoes < MAX_CORRECOES:
		fez_correcao = false
		correcoes += 1
		
		# Percorre toda a matriz
		for y in range(TAMANHO):
			for x in range(TAMANHO):
				var valor = matriz[y][x]
				
				if valor == 0:
					continue
				
				# Verifica se célula precisa de correção
				if _precisa_correcao(matriz, x, y):
					if _corrigir_celula(matriz, x, y):
						fez_correcao = true
	
	return matriz

#=== DETECÇÃO DE CÉLULAS PROBLEMÁTICAS ===
func _precisa_correcao(matriz, x, y):
	var valor = matriz[y][x]
	
	# Lista de posições adjacentes
	var adjacentes = [
		Vector2i(x, y-1), # Cima
		Vector2i(x+1, y), # Direita
		Vector2i(x, y+1), # Baixo
		Vector2i(x-1, y)  # Esquerda
	]
	
	# Verifica cada adjacente
	for posicao_adjacente in adjacentes:
		if posicao_adjacente.x < 0 or posicao_adjacente.x >= TAMANHO or posicao_adjacente.y < 0 or posicao_adjacente.y >= TAMANHO:
			continue
		
		var valor_adjacente = matriz[posicao_adjacente.y][posicao_adjacente.x]
		
		# Se há célula vazia adjacente, precisa corrigir
		if valor_adjacente == 0:
			return true
		
		# Se as células são conectáveis mas não estão conectadas
		if _sao_conectaveis(valor, valor_adjacente) and not _estao_conectadas(Vector2i(x, y), Vector2i(posicao_adjacente.x, posicao_adjacente.y), valor, valor_adjacente):
			return true
	
	return false

#=== CORREÇÃO DE CÉLULAS ===
func _corrigir_celula(matriz, x, y):
	var valor = matriz[y][x]
	var corrigido = false
	
	# Propaga pistas normais
	if regras.has(valor) and direcoes.has(valor):
		var direcao = direcoes[valor]
		var nova_posicao = Vector2i(x, y) + direcao
		
		if nova_posicao.x >= 0 and nova_posicao.x < TAMANHO and nova_posicao.y >= 0 and nova_posicao.y < TAMANHO:
			if matriz[nova_posicao.y][nova_posicao.x] == 0:
				if _pode_gerar_pista(matriz, nova_posicao, direcao):
					var opcoes = regras[valor]
					var escolha = opcoes[gerador_aleatorio.randi_range(0, opcoes.size() - 1)]
					
					# Aplica verificação de bifurcação
					if escolha in [13, 14, 15, 16]:
						if _area_livre_de_bifurcacoes(matriz, nova_posicao):
							matriz[nova_posicao.y][nova_posicao.x] = escolha
						else:
							var substituto = int(valor)
							matriz[nova_posicao.y][nova_posicao.x] = substituto
					else:
						matriz[nova_posicao.y][nova_posicao.x] = escolha
					corrigido = true
	
	# Propaga bifurcações
	if valor in [13, 14, 15, 16]:
		var direcoes_a_verificar = []
		
		# Define direções baseadas no tipo de bifurcação
		match valor:
			13, 14:
				direcoes_a_verificar = [Vector2i(1, 0), Vector2i(-1, 0)] # Horizontal
			15, 16:
				direcoes_a_verificar = [Vector2i(0, 1), Vector2i(0, -1)] # Vertical
		
		# Tenta gerar em cada direção
		for direcao in direcoes_a_verificar:
			var nova_posicao = Vector2i(x, y) + direcao
			if nova_posicao.x >= 0 and nova_posicao.x < TAMANHO and nova_posicao.y >= 0 and nova_posicao.y < TAMANHO:
				if matriz[nova_posicao.y][nova_posicao.x] == 0:
					if _pode_gerar_pista(matriz, nova_posicao, direcao):
						var opcoes = []
						
						# Seleciona tipo de pista baseado na direção
						if valor == 13 or valor == 14:
							if direcao.x == 1:
								opcoes = [2] # Direita
							else:
								opcoes = [4] # Esquerda
						else:
							if direcao.y == 1:
								opcoes = [1] # Baixo
							else:
								opcoes = [3] # Cima
						
						if opcoes.size() > 0:
							var escolha = opcoes[gerador_aleatorio.randi_range(0, opcoes.size() - 1)]
							matriz[nova_posicao.y][nova_posicao.x] = escolha
							corrigido = true
	
	return corrigido

#=== VERIFICA CONECTIVIDADE ===
func _sao_conectaveis(valor1, valor2):
	# Duas células são conectáveis se ambas não são vazias
	return valor1 != 0 and valor2 != 0

func _estao_conectadas(posicao1, posicao2, valor1, valor2):
	# Calcula diferença entre posições
	var delta_x = posicao2.x - posicao1.x
	var delta_y = posicao2.y - posicao1.y
	
	# Verifica conexão direita-esquerda
	if delta_x == 1 and delta_y == 0:
		return valor1 in [2, 5, 8, 9, 12, 15] and valor2 in [4, 6, 7, 10, 11, 16]
	# Verifica conexão esquerda-direita
	elif delta_x == -1 and delta_y == 0:
		return valor1 in [4, 6, 7, 10, 11, 16] and valor2 in [2, 5, 8, 9, 12, 15]
	# Verifica conexão baixo-cima
	elif delta_x == 0 and delta_y == 1:
		return valor1 in [1, 5, 6, 9, 10, 13] and valor2 in [3, 7, 8, 11, 12, 14]
	# Verifica conexão cima-baixo
	elif delta_x == 0 and delta_y == -1:
		return valor1 in [3, 7, 8, 11, 12, 14] and valor2 in [1, 5, 6, 9, 10, 13]
	
	return false

#=== RENDERIZAÇÃO NO TILEMAP ===
func renderizar_mapa_de_tiles(matriz):
	# Limpa tilemap anterior
	mapa_de_tiles.clear()
	
	# Percorre toda a matriz
	for y in range(TAMANHO):
		for x in range(TAMANHO):
			var valor = matriz[y][x]
			# Converte valor especial para visualização
			if mapeamento_visual.has(valor):
				valor = mapeamento_visual[valor]
			# Renderiza célula se existir no tileset
			if tiles.has(valor):
				mapa_de_tiles.set_cell(Vector2i(x, y), 0, tiles[valor])
