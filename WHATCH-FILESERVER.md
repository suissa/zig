# WHATCH-FILESERVER

Este guia explica, de forma prática, como usar um file server simples para desenvolvimento.

## O que é

Um **file server** serve arquivos estáticos (HTML, CSS, JS, imagens, etc.) por HTTP para você testar no navegador.

## Pré-requisitos

- Ter o projeto localmente.
- Ter uma ferramenta para subir um servidor HTTP local (por exemplo: `python`, `node` ou outro utilitário).

## Como usar (rápido)

1. Entre na pasta que contém os arquivos estáticos:

```bash
cd caminho/do/projeto
```

2. Inicie o servidor.

### Opção A — Python 3

```bash
python3 -m http.server 8080
```

### Opção B — Node (npx)

```bash
npx serve . -l 8080
```

3. Abra no navegador:

- `http://localhost:8080`

4. Para parar, volte ao terminal e pressione `Ctrl + C`.

## Dicas úteis

- Se a porta `8080` estiver em uso, troque para outra (ex.: `3000`, `5173`, `9000`).
- Para testar em outro dispositivo da rede local, use o IP da máquina:
  - Ex.: `http://192.168.0.10:8080`
- Em produção, use um servidor apropriado (Nginx, Caddy, etc.) em vez de servidor de desenvolvimento.

## Problemas comuns

- **"Address already in use"**: a porta já está ocupada; mude a porta.
- **Arquivos não atualizam**: faça refresh completo no navegador (`Ctrl+Shift+R` / `Cmd+Shift+R`).
- **Erro 404**: confira se você iniciou o servidor na pasta correta.
