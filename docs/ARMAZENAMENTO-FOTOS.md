# Armazenamento de Fotos — Câmera & Galeria (nv_phone)

Documento sobre **como as fotos tiradas pela câmera do celular são armazenadas**,
suas implicações e o caminho de evolução recomendado.

Relacionado: `docs/SISTEMA-DESIGN.md` (componentes `#cameraOverlay` / `#view-gallery`)
e `docs/RASTREAMENTO-IMPACTO.md` (entrada de implementação da Câmera + Galeria).

## Resumo

- Ao tirar uma foto, o frame do jogo é capturado via `screenshot-basic`
  (`requestScreenshot`, encoding **JPG**), recortado para a orientação escolhida
  (vertical/horizontal) num `<canvas>` na NUI e convertido em **data URL base64**.
- Essa string base64 é enviada ao servidor e **gravada diretamente no banco**
  (MySQL/oxmysql), na tabela `npwd_photos`, associada ao personagem.
- A galeria lê as fotos desse mesmo banco por personagem.

> **Em uma frase:** hoje a foto é guardada como base64 (LONGTEXT) no banco, não
> como arquivo/URL externa.

## Onde fica cada parte

| Camada | Arquivo | Papel |
|---|---|---|
| Captura + recorte | `resources/[pe]/npwd/dist/html/index.html` | `capturePhoto()` / `cropAndSavePhoto()` — screenshot, crop por orientação, gera base64 |
| Ponte NUI ↔ jogo | `resources/[pe]/npwd/dist/game/client/phone.lua` | callbacks `npwd:camera:*` e `npwd:savePhoto` / `npwd:getPhotos` / `npwd:deletePhoto` |
| Persistência | `resources/[pe]/npwd/dist/game/server/phone.lua` | tabela `npwd_photos`, callback `npwd:getPhotos`, eventos `npwd:serverSavePhoto` / `npwd:serverDeletePhoto` |

## Esquema da tabela

Criada automaticamente no boot do resource (`CREATE TABLE IF NOT EXISTS`):

```sql
CREATE TABLE IF NOT EXISTS `npwd_photos` (
    `id`          INT NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(64) NOT NULL,      -- charId/stateId do personagem
    `image`       LONGTEXT NOT NULL,         -- data URL base64 (data:image/jpeg;base64,...)
    `orientation` VARCHAR(12) NOT NULL DEFAULT 'portrait', -- 'portrait' | 'landscape'
    `createdAt`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_photos_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Parâmetros e limites atuais

- **Formato de captura:** JPG, `quality: 0.85` (no `screenshot-basic`).
- **Recorte por orientação:** `portrait` = 3:4 · `landscape` = 4:3 (centralizado).
- **Reamostragem:** maior lado limitado a **1080px**, reexportado como JPEG `0.82`
  para reduzir o tamanho do base64.
- **Limite defensivo no servidor:** fotos acima de **~8 MB** (tamanho da string)
  são descartadas em `npwd:serverSavePhoto`.
- **Histórico consultado:** as 60 fotos mais recentes por personagem
  (`ORDER BY id DESC LIMIT 60`).

## Implicações (por que isso importa)

**Prós**
- Zero infraestrutura externa: não precisa de host de imagens, webhook nem CDN.
- Simplicidade: uma única tabela, sem gerência de arquivos no disco.
- Privado por personagem: cada `identifier` só enxerga as próprias fotos.

**Contras / cuidados**
- **Peso no banco:** base64 é ~33% maior que o binário; cada foto ~200 KB–1 MB
  em LONGTEXT. Muitas fotos podem inflar a tabela e os backups.
- **Tráfego:** a imagem trafega client → server → banco (e volta na galeria) como
  texto grande; abrir a galeria carrega várias fotos de uma vez.
- **Não compartilhável fora do jogo:** por ser base64 no banco, não há URL pública
  (não dá para linkar no Discord, no chat como URL, etc. sem exportar antes).
- **Chat:** por isso, o envio de imagem no chat continua por **URL** (`§IMG§`),
  não por base64, para não inflar a tabela de mensagens.

## Manutenção sugerida

- **Retenção:** considerar limpar fotos antigas (ex.: manter só as N mais recentes
  por personagem, ou apagar após X dias) via cron/limpeza agendada.
- **Monitorar tamanho:** acompanhar o crescimento de `npwd_photos`
  (`SELECT COUNT(*), ROUND(SUM(LENGTH(image))/1048576,2) AS mb FROM npwd_photos;`).

## Evolução recomendada (migrar para host externo)

Quando o volume crescer, o ideal é **guardar só a URL** e subir o binário para um
host externo, mantendo o banco leve:

1. Trocar a captura para `exports['screenshot-basic']:requestScreenshotUpload(url, field, cb)`
   apontando para um endpoint de upload (ex.: webhook do Discord ou storage próprio).
2. Persistir na tabela apenas a **URL** retornada (trocar `image LONGTEXT` por
   `url VARCHAR(512)`), mantendo `identifier`, `orientation`, `createdAt`.
3. Ajustar `renderGallery()` / visualizador para usar a URL diretamente
   (a lógica de NUI muda pouco, pois já usa `<img src>`).

> Vantagem: banco enxuto, imagens compartilháveis por link e possibilidade de
> reaproveitar a mesma URL no chat e em outros apps.

## Histórico

- `2026-07-23` — Documento criado junto com a implementação inicial da Câmera +
  Galeria (armazenamento base64 em `npwd_photos`).
