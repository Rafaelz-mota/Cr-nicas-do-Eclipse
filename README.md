# Crônicas do Eclipse

MMORPG 3D anime, original, para **Android e PC**. Câmera superior inclinada (2.5D), nível máximo inicial 50, seis regiões, 30 clãs originais planejados.

> Estado atual: **Fase 1: fundação técnica e protótipo jogável**. Visual provisório (cápsulas coloridas), pronto para receber os modelos 3D anime definitivos.

## O que já funciona

- Cliente Godot 4.7 (GDScript) com cena de demonstração: clareira, NPC, 6 monstros, câmera 2.5D inclinada.
- Personagem controlável (teclado WASD/setas, ou joystick virtual na tela de toque).
- Combate com atributos, dano físico e mágico, defesa, resistências, mana, recargas, crítico, efeitos (dano contínuo, escudo, marcado).
- 4 classes e 3 clãs de demonstração; **qualquer classe combina com qualquer clã**.
- Monstros, NPCs, missões em cadeia, itens e raridades 100% orientados a dados (`client/data/*.json`).
- Inventário com pilhas, equipamento, durabilidade, reparo, amplificação +0 a +15 (falha nunca destrói o item), 7 raridades.
- **Salvamento local** do personagem (nível, XP, Gold, itens, equipamento, missões): autosave a cada 20 s, ao subir de nível, ao entregar missão e ao fechar/pausar o app. Botão "Continuar" na tela inicial.
- Testes automatizados e workflow de validação no GitHub Actions.

## Controles

| Ação | PC | Celular |
|---|---|---|
| Mover | WASD / setas | Joystick virtual |
| Habilidades | 1, 2, 3, 4 (ou J, K) | Botões na tela |
| Falar com NPC | E | Botão "Falar" |
| Mochila | I | Botão "Mochila" |

## Fluxo de trabalho 100% pelo celular

1. **Validar**: o workflow *Validar projeto* roda a cada alteração (testes + verificação jogável).
2. **Gerar APK**: GitHub → *Actions* → *Gerar APK Android (debug)* → *Run workflow*. O APK aparece em *Artifacts*. Veja [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md).

## Rodando localmente (opcional, exige computador)

```bash
godot --path client                                   # jogar
godot --headless --path client --import               # 1ª vez: importar
godot --headless --path client -s res://tests/run_tests.gd   # testes
godot --headless --path client -- --smoke             # verificação jogável
```

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md)
- [Gerar APK](docs/ANDROID_BUILD.md)
- [Relatório da Fase 1](docs/RELATORIO_FASE_1.md)

## Estrutura

```
client/      Projeto Godot (cliente)
  data/      Dados do jogo (JSON): classes, clãs, itens, monstros, missões...
  scripts/   core, combat, character, inventory, quests, actors, world, ui
  tests/     Testes automatizados
server/      Reservado: serviços ASP.NET Core + PostgreSQL (fase futura)
docs/        Documentação
assets/      Reservado: modelos 3D, texturas, áudio definitivos
.github/     Workflows de CI
```

Projeto independente. Não compartilha código nem dados com outros projetos.
