# HANDOFF — teste do modo Turbo no Windows

Contexto pra uma sessão do Claude Code rodando **no PC Windows do Julio** (o de
jogo, GPU **GTX 1070 Ti**). A sessão original roda no Mac dele e cuida do
servidor. Sua missão aqui é **executar e medir os testes abaixo** e produzir um
relatório objetivo.

## O que é o projeto

Plataforma de compartilhamento de tela pra jogar com amigos (substituto do Go
Live do Discord), 100% grátis:

```
navegador do transmissor ──WHIP──► MediaMTX (Oracle free, São Paulo) ──WHEP──► espectadores
```

| recurso | endereço |
|---|---|
| App | https://compartilhartela.netlify.app |
| Diagnóstico de encoder | https://compartilhartela.netlify.app/diag.html |
| Servidor (WHIP/WHEP) | https://telajulio.duckdns.org |
| Streams ativos (JSON, só leitura) | https://telajulio.duckdns.org/api/paths |
| Repositório | github.com/juliorbaltazar/tela-compartilhada |

Deploy é automático: push na `main` → Netlify publica (~20 s). O `netlify.toml`
copia só `index.html`, `p2p.html`, `diag.html`, `tela-app.bat`.

## Estado atual (o que já foi feito)

- App com WHIP/WHEP, mosaicos arrastáveis, presets por **bits/pixel**
  (Nítida 1080p30 · Fluida 720p60 · Cheia 1080p60 · Leve 720p30), seletor de
  codec (auto/TURBO/H264/VP8), HUD com bitrate/fps/rtt/encoder, proteção
  automática (3 leituras de `qualityLimitationReason=cpu` → desce um preset),
  layout mobile, wake lock.
- **Modo Turbo**: passa a captura por um canvas relay
  (`requestVideoFrameCallback` + `captureStream(0)`) porque o Chromium recusa
  encoder de hardware pra tracks marcados como screencast; o track do canvas
  não carrega essa marca.
- Servidor: MediaMTX v1.20.0 + Caddy num E2.1.Micro (Oracle always-free).
  Capacidade medida: 16 espectadores = 2,5% CPU. Não é gargalo.

## Fatos já medidos nesta máquina (não re-descobrir)

Diagnóstico rodado pelo Julio neste PC:

- **Chrome (perfil normal): aceleração gráfica DESLIGADA de propósito** — ele
  precisa dela assim por causa de tela preta em sites de streaming.
  Resultado: `hw=false` em todos os codecs. **Não mexer nessa configuração.**
- **Edge**: `H.264 High hw=true` (NVENC visível via WebCodecs), captura limpa
  1920×1080@60 dpr=1, mas WebRTC clássico escolheu `libvpx` (software) — é a
  política anti-screencast do Chromium, motivo do Turbo existir.

## A questão em aberto — o que você vai testar

**O canvas relay do Turbo convence o Chromium a usar o NVENC?** Ninguém mediu
ainda. Testar em DOIS ambientes:

### Ambiente A — Chrome em modo app (perfil separado, aceleração ligada)

```
chrome --user-data-dir="%LocalAppData%\TelaCompartilhada" --app=https://compartilhartela.netlify.app
```

(o `tela-app.bat` na raiz do repo faz isso; o perfil novo tem aceleração ligada
por padrão — confirmar em chrome://gpu ANTES de medir: linha "Video Encode"
deve dizer Hardware accelerated)

### Ambiente B — Edge normal

### Roteiro em cada ambiente

1. `diag.html` → rodar → **copiar resultado** (agora inclui o passo 3:
   ms/quadro do encode de hardware real).
2. App → entrar → codec **"H.264 turbo (GPU) 🚀"** → compartilhar tela →
   anotar a linha `encoder` do HUD.
   - `MediaFoundation… · hardware ✓` = NVENC ativo (sucesso)
   - `OpenH264/libvpx · software` = o truque não bastou
3. Repetir com codec **VP8** (baseline de comparação).
4. Se houver um jogo aberto: anotar uso de CPU/GPU no Gerenciador de Tarefas
   em cada modo (turbo vs VP8), 1 minuto cada.
5. Conferir como espectador (aba normal em outro perfil): a imagem chega?
   fps do badge no tile?

### Interpretação

| resultado | conclusão |
|---|---|
| Turbo → hardware ✓ nos dois | objetivo alcançado; relatar ms/quadro e CPU |
| hardware só no ambiente A ou só no B | relatar qual; vira recomendação de uso |
| software em ambos | o canvas relay não basta → **plano B**: ponte WebCodecs (`prefer-hardware` é exigência, não sugestão; o diag já provou que funciona). A ponte precisa de peça nova no servidor — **não implementar daqui**, só relatar |

## Regras desta sessão Windows

- **Não tocar** na configuração do Chrome principal do Julio (aceleração fica OFF).
- **Sem acesso ao servidor**: a chave SSH está no Mac. Checagens só pelos
  endpoints públicos (`/api/paths`). Mudança de servidor = anotar no relatório
  pra sessão do Mac executar.
- Grátis somente. OBS é feature opcional, não é a solução (decisão do Julio).
- Push no repo: precisa do GitHub do Julio autenticado na máquina; se não
  houver, entregar o relatório como arquivo local/texto.
- Se editar o app: sintaxe já foi validada com `new Function(js)` — manter o
  hábito. Deploy é automático no push; cache do index é `max-age=0`.

## Formato do relatório

```
ambiente A (chrome app-mode):
  chrome://gpu Video Encode: ...
  diag: <colar saída>
  turbo HUD encoder: ...
  vp8 HUD encoder: ...
  CPU jogo+turbo: X% | jogo+vp8: Y%
ambiente B (edge): idem
veredito: ...
```

## Histórico condensado das decisões

P2P em malha (original) sofria com N encoders + upload N× → migrado pra SFU
próprio. Oracle A1 sem vaga (caçador ainda roda no Mac) → micro E2.1 deu conta
(medido). LiveKit/Cloudflare avaliados e descartados (pastas `alternativas/`).
Bitrate travado em 2 Mbps corrigido (priority:"low" + piso SDP). Imagem mole
corrigida com presets por bits/pixel. "CPU no limite" → causa raiz: encoder de
software; daí o Turbo.
