# Arquitetura técnica

## Princípios

1. **Orientado a dados.** Classes, clãs, habilidades, itens, monstros, NPCs, missões e balanceamento vivem em `client/data/*.json`. Adicionar conteúdo não exige alterar lógica.
2. **Lógica separada da apresentação.** `Combatant`, `DamageCalc`, `CharacterData`, `Inventory`, `Equipment`, `QuestLog` são classes puras (sem nós, sem física). Os atores (`PlayerActor`, `MonsterActor`) só movem, mostram e chamam essa lógica.
3. **Servidor autoritativo (planejado).** O cliente nunca decide dano, XP, Gold, itens ou recompensas. As classes puras acima são exatamente o que o servidor assumirá.
4. **Sem complexidade antes da necessidade.** Nenhum microserviço, fila ou cache nesta fase.

## Pilha

| Camada | Tecnologia | Estado |
|---|---|---|
| Cliente 3D | Godot 4.7.2 (estável), GDScript, renderer GL Compatibility | Implementado (protótipo) |
| Contas/persistência | C# ASP.NET Core + PostgreSQL | Planejado (`server/`) |
| Tempo real | ENet (multiplayer do Godot) | Planejado |
| CI/CD | GitHub Actions | Validação implementada; APK escrito, ainda não executado |

O renderer **GL Compatibility** foi escolhido por ser o mais amplo em celulares Android e leve; pode ser reavaliado (Mobile/Vulkan) quando houver arte definitiva.

## Módulos do cliente (`client/scripts`)

| Pasta | Responsabilidade |
|---|---|
| `core/` | `GameDataStore` (carrega e valida JSON), `CombatStats` (atributos → estatísticas), `XpCurve`, `Rarity` |
| `combat/` | `Combatant` (vida, mana, recargas, efeitos, uso de habilidade), `DamageCalc`, `RewardService` |
| `character/` | `CharacterData`: XP, nível, Gold, pontos, classe+clã. **Único ponto de mutação** de XP/Gold/itens |
| `inventory/` | `Inventory`, `Equipment`, `ItemInstance` (uid único), `Enhancement` (+0..+15) |
| `quests/` | `QuestLog`: aceitar, progresso por eventos, cadeias, entrega |
| `actors/` | `PlayerActor`, `MonsterActor` (IA por dados), `NpcActor`, `VisualSlot`, `Fx` |
| `world/` | `main.gd` (cena de demonstração), `IsoCamera` |
| `ui/` | `Hud`, `TouchJoystick` |

## Substituição de modelos 3D

Todo ator tem um `VisualSlot`. Hoje chama `use_placeholder()`. Para usar um modelo anime real: `visual.set_model(preload("res://assets/...glb"))`. O campo `model_id` nos JSON de monstros/NPCs já identifica qual modelo usar. Combate, equipamentos e personagem não mudam.

## Classes × Clãs

Duas árvores independentes: habilidades da **classe** e técnicas do **clã** (`skills.json`, campo `owner_type`). `CharacterData.skill_ids()` combina as duas, então qualquer combinação funciona (há teste que percorre todas). Passivas hereditárias do clã entram em `CombatStats.derive`.

Metas de catálogo (18 habilidades por classe; 1+5+3+1 por clã; 30 clãs) são **conteúdo futuro**: hoje há 4 classes com 2 habilidades e 3 clãs com 1 técnica cada, só para provar a estrutura.

## Segurança e persistência (plano)

- Contas: ASP.NET Core Identity, senhas com hash (Argon2/PBKDF2), tokens de curta duração. **Nenhum segredo no repositório** (`.gitignore` cobre keystores e `.env`).
- Persistência: PostgreSQL; inventário com `uid` emitido apenas pelo servidor; operações de item/Gold em transações atômicas (anti-duplicação).
- Validação: o servidor reexecuta `DamageCalc`/`RewardService` com seu próprio RNG. O cliente apenas envia intenções ("usar habilidade X no alvo Y").
- Já aplicado no código: Gold não aceita valores negativos, XP/Gold só mudam por `CharacterData`, falha de amplificação nunca destrói item.

## Sistemas futuros e onde encaixam

| Sistema | Ponto de extensão |
|---|---|
| Guildas, grupos, raids | Novas classes em `scripts/social/`, ids de grupo no `CharacterData` |
| Masmorras, chefes | Novas entradas em `monsters.json` + cenas; `loot` já suporta itens exclusivos |
| Fabricação, profissões | `recipes.json` + serviço sobre `Inventory` |
| Leilão, comércio, banco | Serviço no servidor sobre `Inventory` (trocas atômicas) |
| Encantamentos, pedras | `ItemInstance.enchants` (reservado), limite por raridade em `rarities.json` |
| Conjuntos de equipamento | Campo `set` nos itens + bônus em `Equipment.bonus_stats` |
| Montarias, mascotes | Novos atores com `VisualSlot` |
| Missões secretas/dinâmicas/de clã/guilda | Campo `kind` e `consequences` já existem em `quests.json` |
| Novas regiões | Novas cenas + dados por região |

## Pendências técnicas conhecidas

Ver [RELATORIO_FASE_1.md](RELATORIO_FASE_1.md).
