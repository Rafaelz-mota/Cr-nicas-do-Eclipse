# Servidor (reservado)

Fase futura: C# ASP.NET Core + PostgreSQL + ENet.

Nada foi implementado aqui ainda de propósito: o protótipo de cliente precisa validar o combate e a progressão antes de investir em infraestrutura. O ambiente de desenvolvimento atual também não possui o SDK .NET, então código aqui não poderia ser compilado nem testado.

Módulos previstos (separados): `Auth` (contas/login), `Persistence` (PostgreSQL), `World` (mundo/ENet), `Combat` (reexecuta `DamageCalc`/`RewardService` do cliente como autoridade).

Regra: nenhuma senha, token ou chave privada no repositório; use variáveis de ambiente/Secrets.
