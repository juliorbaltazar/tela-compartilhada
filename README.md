# Tela Compartilhada

Compartilhamento de tela pra jogar junto no Discord, com servidor próprio.

**No ar:** https://telajulio.duckdns.org (servidor) · o app é publicado no Netlify/Pages

## O problema que isso resolve

A primeira versão era malha P2P: quem transmitia abria **um encoder por espectador**
e subia N cópias do vídeo. Com 4 amigos, o upload saturava e o ping do jogo explodia.

Agora tem servidor no meio. Você codifica **uma vez** e manda **uma cópia**; o
servidor distribui. O custo na sua máquina para de crescer com o número de amigos.

```
navegador ─┐
           ├─WHIP─► MediaMTX (Oracle) ─WHEP─► navegadores
OBS       ─┘
```

## Como usar

**Pelo navegador:** abra o site, digite seu nome, clique em compartilhar tela.

**Pelo OBS** (não precisa abrir o site depois da primeira vez):

| campo | valor |
|---|---|
| Serviço | WHIP |
| Servidor | `https://telajulio.duckdns.org/SEUNOME-obs/whip` |
| Chave | vazio |

Em *Saída → Avançado*, pra jogo: **NVENC H.264**, **CBR 4000–6000 Kbps**, keyframe **1s**.

## Arquivos

| | |
|---|---|
| `index.html` | o app (servidor/SFU) |
| `p2p.html` | versão em malha, plano B se o servidor cair |
| `servidor/` | a configuração real que está rodando |
| `alternativas/` | caminhos avaliados e não usados (LiveKit, Cloudflare) |

## O servidor

Oracle Cloud Always Free, região São Paulo — `VM.Standard.E2.1.Micro`,
1 GB de RAM, x86. Roda **MediaMTX** (binário único em Go) atrás do **Caddy**,
que cuida do certificado.

### Capacidade medida

Teste com espectadores WebRTC reais:

| espectadores | saída | CPU | RAM |
|---|---|---|---|
| 0 | 0 | 0,8% | 38 MB |
| 8 | 17 Mbps | 1,6% | 73 MB |
| 16 | 30 Mbps | 2,5% | 108 MB |

Escala linear: ~0,1% de CPU e ~4 MB por espectador. O limite prático é a placa
de rede (480 Mbps), o que dá umas 80 pessoas.

Parece pouco 1 GB de RAM, mas o servidor **não recodifica vídeo** — só copia
pacotes. O trabalho pesado fica na máquina de quem joga, onde o NVENC resolve.

### Portas

| porta | protocolo | pra quê |
|---|---|---|
| 80, 443 | TCP | site e certificado |
| 8189 | UDP | WebRTC (ICE) |

> A imagem Ubuntu da Oracle traz iptables fechado. Abrir na Security List **não
> basta** — tem que liberar dentro da VM também. É o erro nº 1 ao remontar isso.

### Remontar do zero

```bash
# 1. MediaMTX
curl -sL -o mtx.tar.gz https://github.com/bluenviron/mediamtx/releases/download/v1.20.0/mediamtx_v1.20.0_linux_amd64.tar.gz
tar xzf mtx.tar.gz && sudo mv mediamtx /usr/local/bin/
sudo cp servidor/mediamtx.yml /etc/mediamtx.yml   # já tem o IP público no ICE

# 2. serviço
sudo systemctl enable --now mediamtx

# 3. Caddy (TLS automático)
sudo cp servidor/Caddyfile /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

Dois pontos que quebram silenciosamente se esquecidos:

- **`webrtcAdditionalHosts`** no `mediamtx.yml` precisa ter o IP público. A VM só
  enxerga o IP privado, e sem isso o navegador tenta conectar num endereço que
  não existe pra ele — a conexão morre com *deadline exceeded*.
- **`/api/paths`** no Caddy expõe só a listagem. A API completa do MediaMTX
  permite derrubar sessão e trocar config; não pode ficar aberta.

## Detalhes que custaram caro

**Bitrate travado em 2 Mbps.** Duas causas: `priority:"low"` no encoding (fazia
sentido na malha, onde havia N streams competindo; com um stream só, o alocador
do Chrome segurava banda à toa) e o controle de congestionamento não subindo —
contra o servidor o retorno de rede é mais fraco que entre dois navegadores.
Resolvido removendo o priority e fixando `x-google-min/start-bitrate` na oferta SDP.

**Preview local desligado por padrão.** Desenhar a própria tela num `<video>`
gasta GPU que o jogo quer. Tem botão pra ligar quando precisar conferir.

**`selfBrowserSurface: "exclude"`** evita o espelho infinito ao capturar a
própria aba, que queima CPU sem servir pra nada.
