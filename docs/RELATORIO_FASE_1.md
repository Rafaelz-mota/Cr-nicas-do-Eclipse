# Relatório da Fase 1: fundação e protótipo jogável

## Diagnóstico inicial do repositório

Repositório vazio: 1 commit ("Initial commit") e um `README.md` contendo só o título. Nada a preservar. Nenhuma dependência ou tecnologia pré-existente.

## Ambiente de verificação

Godot **4.7.2 estável** (a mais recente estável encontrada nas tags oficiais), executado em modo *headless* no ambiente de desenvolvimento. **Sem** .NET SDK, Android SDK, JDK, GPU ou templates de exportação.

## Testes realmente executados

| Verificação | Resultado |
|---|---|
| Testes unitários (`tests/run_tests.gd`) | **38 testes, 270 asserções, 0 falhas** |
| Verificação jogável `--smoke` (cena real, 6 monstros, mata um monstro com a habilidade básica, confere XP e Gold) | **Passou**, sem erros de script |
| Sintaxe YAML dos 2 workflows | Válida (apenas sintaxe) |
| Workflow `validate.yml` no GitHub | **Ainda não executado** (roda no primeiro push) |
| Workflow `android-apk.yml` | **Não executado. Nenhum APK foi gerado.** |

Um bug real foi encontrado e corrigido pelo smoke: a classe `VirtualJoystick` colidia com uma classe nativa do Godot 4.7; foi renomeada para `TouchJoystick`.

## O que foi criado (itens da Primeira Entrega)

1. Diagnóstico: acima.
2. Arquitetura: `docs/ARCHITECTURE.md`.
3. Estrutura de pastas: `client/`, `server/` (reservado), `docs/`, `assets/` (reservado), `.github/`.
4. Projeto Godot: `client/project.godot` (GL Compatibility, paisagem).
5. Cena do mundo: clareira com árvores/rochas provisórias, luz e sombras (`world/main.gd`).
6. Câmera 2.5D inclinada (`world/iso_camera.gd`).
7-8. Personagem controlável e movimentação: teclado e joystick virtual.
9. Combate: dano físico/mágico, defesa, resistências, crítico, mana, recarga, efeitos.
10. Atributos básicos: força, destreza, inteligência, vitalidade, espírito; pontos por nível.
11. Classes e clãs: 4 classes, 3 clãs, qualquer combinação (testado).
12. Monstros por dados com IA simples (perseguir, atacar, voltar), 2 tipos.
13. NPC e missões em cadeia (2 missões).
14-15. Inventário, equipamento, durabilidade/reparo, amplificação +0..+15, 7 raridades.
16. Testes automatizados.
17. Workflow de validação.
18. Preparação do APK: `export_presets.cfg` + `android-apk.yml` + guia.

## Limitações e pendências (sem maquiagem)

- **APK não gerado.** O workflow nunca rodou; pode precisar de ajustes de versão do SDK/build-tools na primeira execução.
- **Aparência não verificada visualmente.** O ambiente não tem GPU/tela: nenhum print foi tirado. A lógica foi testada; layout do HUD, câmera e toque no celular **nunca foram vistos** e podem precisar de ajustes.
- **Visual provisório**: cápsulas coloridas. Sem modelos anime, rostos, animações; efeitos de partículas mínimos.
- **Sem servidor, banco, login ou multiplayer.** Só a estrutura planejada. Salvamento permanente não existe ainda (há `ItemInstance.to_dict/from_dict` como base).
- **Conteúdo mínimo**: 4/N classes, 3/30 clãs, 2 habilidades por classe (meta 18), 1 técnica por clã (meta 10), 1 região de demonstração (meta 6), nível máximo configurado em 50 mas só testado por simulação de XP.
- Habilidades passivas, supremas, árvores evoluídas e despertar de clã ainda não existem como mecânica.
- Os 30 clãs originais, sua história e poderes ainda precisam ser criados (a originalidade foi respeitada: nomes e conceitos próprios).
- Balanceamento (XP, dano, amplificação) são valores iniciais não balanceados.
- Interface por código; sem tela de configuração, sem sons.

## Próxima etapa recomendada

1. Rodar `validate.yml` e `android-apk.yml` no GitHub e corrigir o que falhar; instalar o APK no seu celular e reportar o que vê (HUD, toque, desempenho).
2. Com base nisso, ajustar controles/HUD mobile.
3. Só então: esqueleto do servidor .NET + login + salvamento, e expandir catálogo (mais classes, clãs, habilidades).
