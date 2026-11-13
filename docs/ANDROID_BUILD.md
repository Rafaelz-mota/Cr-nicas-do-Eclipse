# Gerar o APK pelo celular

1. Abra o repositório no navegador do celular (github.com/Rafaelz-mota/Cr-nicas-do-Eclipse).
2. Toque em **Actions** → **Gerar APK Android (debug)** → **Run workflow** → **Run workflow**.
3. Aguarde terminar (cerca de 10 a 20 minutos).
4. Abra a execução concluída e baixe o arquivo em **Artifacts** (`cronicas-do-eclipse-apk-debug`). Vem dentro de um .zip; extraia e instale o `.apk`.
5. No Android, permita "instalar apps de fontes desconhecidas" para o navegador/gerenciador de arquivos.

## Estado honesto

O workflow `android-apk.yml` **foi escrito, mas ainda não foi executado**. Nenhum APK foi gerado até agora. O ambiente onde foi desenvolvido não tem Android SDK nem templates de exportação. Na primeira execução podem surgir ajustes (versão do build-tools/SDK exigida pelo Godot 4.7, caminhos). Se falhar, abra o log da execução e envie o erro para correção.

## Detalhes

- APK **debug**, assinado com uma keystore criada na hora pelo workflow (não fica no repositório).
- Arquitetura: arm64-v8a (celulares modernos).
- Exportação sem Gradle (`use_gradle_build=false`), o caminho mais simples.
- APK **release** assinado para a Play Store exigirá uma keystore própria guardada em *Secrets* do GitHub, tarefa de uma fase futura.
