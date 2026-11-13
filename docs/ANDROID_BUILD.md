# Gerar o APK pelo celular

1. Abra o repositório no navegador do celular (github.com/Rafaelz-mota/Cr-nicas-do-Eclipse).
2. Toque em **Actions** → **Gerar APK Android (debug)** → **Run workflow** → **Run workflow**.
3. Aguarde terminar (cerca de 10 a 20 minutos).
4. Abra a execução concluída e baixe o arquivo em **Artifacts** (`cronicas-do-eclipse-apk-debug`). Vem dentro de um .zip; extraia e instale o `.apk`.
5. No Android, permita "instalar apps de fontes desconhecidas" para o navegador/gerenciador de arquivos.

## Estado honesto

O workflow `android-apk.yml` **foi executado no GitHub e gerou um APK debug** (~28 MB, assinado, artefato `cronicas-do-eclipse-apk-debug`). A primeira tentativa falhou por causa de uma ação auxiliar do Android SDK; foi corrigida usando o SDK que já vem no runner, e a segunda execução passou.

**O que NÃO foi verificado:** o APK nunca foi instalado nem aberto em um aparelho. Não se sabe ainda se abre, como ficam HUD/joystick no toque, nem o desempenho. Se algo falhar ao instalar ou abrir, envie o erro ou uma descrição/captura de tela.

## Detalhes

- APK **debug**, assinado com uma keystore criada na hora pelo workflow (não fica no repositório).
- Arquitetura: arm64-v8a (celulares modernos).
- Exportação sem Gradle (`use_gradle_build=false`), o caminho mais simples.
- APK **release** assinado para a Play Store exigirá uma keystore própria guardada em *Secrets* do GitHub, tarefa de uma fase futura.
