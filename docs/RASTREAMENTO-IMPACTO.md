# Rastreamento de Impacto

Processo obrigatório antes de **corrigir, criar ou alterar** algo que já existe
no projeto. Objetivo: entender onde e como mudar algo com o menor raio de
efeito colateral possível — evitando quebrar outros scripts e evitando editar
mais arquivos do que o necessário.

## Quando aplicar

- Correção de bug em função/evento já existente.
- Alteração de comportamento de algo que outros resources podem consumir.
- Qualquer alteração em arquivo com mais de um resource dependente.

Criação de algo 100% novo, sem dependentes, não precisa do processo completo —
mas ainda exige atualizar `docs/MAPA-SCRIPTS.md` ao final.

## Passo a passo

1. **Identifique o alvo**: nome da função, evento, export ou caminho do arquivo.
2. **Rode a varredura**: `.claude/hooks/impact-scan.sh <alvo>` (ou peça ao
   assistente para rodar/simular manualmente via busca no repositório).
3. **Classifique os pontos de impacto encontrados**:
   - *Direto*: chama a função/evento/export diretamente.
   - *Indireto*: depende do resultado/efeito colateral (ex.: espera um evento
     disparado por quem você vai alterar).
   - *Configuração*: usa constantes/config do arquivo alvo.
4. **Escreva um mini relatório** (pode ser só no chat, não precisa de arquivo
   novo) no formato:

```
Alvo: esx_garage:server:storeVehicle
Arquivos que chamam diretamente: 
  - resources/esx_garage/client/main.lua (linha X)
  - resources/qb_dealership/server/sell.lua (linha Y)
Impacto indireto:
  - qb_dealership espera o evento ser concluído antes de remover o veículo da loja
Config usada:
  - shared/config.lua → Config.MaxVehiclesPerGarage
Plano mínimo de alteração:
  - Alterar apenas a validação dentro de storeVehicle, sem mudar assinatura
```

5. **Execute a menor alteração possível** que resolve o problema, evitando
   reescrever arquivos inteiros ou "aproveitar para refatorar" sem necessidade.
6. **Atualize a documentação**:
   - `docs/MAPA-SCRIPTS.md`, se dependências mudaram.
   - Histórico abaixo, com 3-5 linhas.

## Histórico de Alterações

> Cada entrada: data, alvo, resumo do que mudou e por quê. Mantenha curto.

- `2026-07-22` — `docs/MAPA-SCRIPTS.md` — Varredura inicial e preenchimento completo do mapa de scripts da base: mapeados 30+ resources (`[ox]`, `[dev]`, `[pe]`, terceiros), exports públicos, eventos de rede client/server e configurações compartilhadas.
- `2026-07-22` — `nv_garage` / `nv_orgs` — Adicionado envio de coordenadas (`coords`) nos veículos listados, botão "Marcar no Minimapa" na NUI e callback `track` no client para definir Waypoint no GPS.
- `2026-07-22` — `npwd` / `nv_garage` — Integração do App de Garagem do celular (NPWD) com `nv_garage`: renderização dinâmica dos veículos, exibição da garagem/localização e botão para marcar a garagem/veículo no minimapa.
- `2026-07-22` — `npwd` / `nv_garage` — Aprimorado o botão "Rastrear Veículo" na NUI do celular e estendido o cálculo de coordenadas para veículos em circulação ao vivo (`live.coords`), estacionados na rua (`parkedSpot`), guardados e no pátio.
- `2026-07-22` — `npwd` — Correção do problema de travamento em carregamento infinito: inclusão de `@ox_lib/init.lua` no `fxmanifest.lua`, `pcall` com callback NUI garantido em `client/garage.lua` e timeout com `AbortController` na NUI.
- `2026-07-22` — `npwd` — Simplificação visual do cartão de veículo no celular: removidos tipo/classe do carro, ícones extras de localização e grade de estatísticas.
- `2026-07-22` — `npwd` — Exibição exclusiva do nome limpo do local (ex.: "Pillbox Hill") na embed do cartão do veículo no celular, removendo prefixos de estacionamento.
- `2026-07-22` — `npwd` — Remoção do container embed de localização para veículos que estejam fora da garagem e alteração da etiqueta de status de "Fora" para "Na Rua".
- `2026-07-22` — `npwd` — Remoção total do container embed para todos os veículos: o nome limpo da garagem (ex.: "Pillbox Hill") é exibido diretamente na badge superior direita.
- `2026-07-22` — `npwd` / `nv_garage` — Sincronização em tempo real ao guardar/retirar veículos (cruzamento com `Ox.GetVehicles` na memória), atualização automática da lista ao abrir o celular/app e bloqueio da abertura do Menu de Pausa (ESC) do FiveM.
- `2026-07-22` — `npwd` / `nv_garage` — Implementado rastreamento visual no minimapa com Blip Sprite 161 (garagens) e Sprite 225 (carro na rua) em laranja (cor 47). Adicionada verificação de bloqueador de sinal ativo para impedir rastreamento de veículos jammeados.
- `2026-07-22` — `npwd` / `nv_garage` — Veículos apreendidos direcionam o rastreamento (Blip Sprite 161 laranja) para as coordenadas oficiais do Pátio de Apreensão (`Config.Garages['patio']`).
- `2026-07-22` — `npwd` / `nv_garage` — Adicionado temporizador automático de 30 segundos (`30000ms`) para a remoção automática do blip de rastreamento (Sprite 161/225) do minimapa.
- `2026-07-22` — `npwd` / `nv_garage` — Removidas as funções de geração de rota (`SetBlipRoute`) e waypoint do GPS (`SetNewWaypoint`). O rastreamento agora exibe exclusivamente o Blip Sprite 161 laranja no local por 30s.
