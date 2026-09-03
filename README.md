# 🎯 Foco DS

<div align="center">

![GitHub repo size](https://img.shields.io/github/repo-size/Douglock/foco-ds?style=for-the-badge&color=10b981)
![GitHub stars](https://img.shields.io/github/stars/Douglock/foco-ds?style=for-the-badge&color=eab308)
![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)
![Status](https://img.shields.io/badge/status-ativo%20%26%20minimalista-emerald?style=for-the-badge)

**HUD Minimalista Flutuante para Super Productivity no macOS.**  
*Barra de progresso, tarefa em foco em tempo real, notas minimalistas na lateral e alerta com som e flash de tela ao finalizar.*

[Visão Geral](#-visão-geral) •
[Funcionalidades](#-funcionalidades) •
[Instalação](#-instalação-rápida) •
[Como Funciona](#-como-funciona) •
[Arquitetura](#-arquitetura-do-projeto) •
[Autor](#-autor)

</div>

---

## 💡 Visão Geral

O **Foco DS** foi projetado para quem busca foco ininterrupto com o menor atrito visual possível:
- **100% Passivo (Read-Only)**: Todo o gerenciamento de tarefas, cronômetro e pausas continua sendo feito dentro do Super Productivity.
- **Display Flutuante em Dark Glassmorphism**: Exibe o título da tarefa, tempo decorrido/restante e a barra de progresso.
- **Clique Direto**: Clicar na pílula traz imediatamente o **Super Productivity para primeiro plano** focado na tarefa ativa.
- **Arraste Livre**: Mova a pílula livremente para qualquer área da tela com aceleração nativa.

---

## ✨ Funcionalidades Principais

1. 📊 **Barra de Progresso Integrada**:
   - Preenchimento gradiente dinâmico no fundo da pílula proporcional ao tempo decorrido ou estimativa da tarefa.
   - Linha fina e nítida na base da pílula com visualização imediata do progresso.
2. 🎯 **Tarefa em Foco em Destaque**:
   - Ícone com pulso de respiração quando o foco está ativo.
   - Nome da tarefa legível em alta definição, com truncamento suave e status em tempo real.
3. 📝 **Notas Minimalistas na Lateral (Side Notes)**:
   - Gaveta lateral integrada acionável pelo botão `📝` ou pelo menu.
   - Bloco de anotações sem distrações com salvamento automático local no macOS para descarregar pensamentos rápidos sem trocar de janela.
   - Ações de copiar e limpar com um toque.
4. 🔔 **Alerta de Finalização (Som + Flash na Tela)**:
   - Ao término do ciclo de foco ou pomodoro, o app emite um chime sonoro suave (`Hero`/`Glass`) e dispara um flash translúcido na tela inteira (`Screen Flash`), garantindo que você perceba o fim da sessão mesmo se estiver imerso.
   - A borda da pílula pisca em tom âmbar/dourado.

---

## ⚡ Instalação Rápida

### 1. Instalar o Plugin no Super Productivity
1. No Super Productivity, acesse **Configurações → Plugins → Escolher arquivo de plugin**.
2. Selecione o arquivo [`release/foco-ds-super-productivity.zip`](release/foco-ds-super-productivity.zip).

### 2. Abrir o App no macOS
1. O app já pode ser aberto a partir de [`release/Foco-DS-macOS.zip`](release/Foco-DS-macOS.zip) (ou copiado para a pasta **Aplicativos**).
2. Abra o **Foco DS.app**.
3. A pílula minimalista surgirá suavemente no topo da sua tela, conectando-se automaticamente ao Super Productivity!

---

## 🔍 Como Funciona

```text
┌─────────────────────────────────────────────────────────────┐
│  Super Productivity                                         │
│  (Você gerencia tarefas, pomodoros e projetos aqui)         │
└──────────────────────────────┬──────────────────────────────┘
                               │ POST /state (127.0.0.1:28475)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│  Foco DS (macOS SwiftUI HUD)                                │
│  • 📊 Barra de progresso integrada                          │
│  • 🎯 Tarefa ativa em destaque                              │
│  • 📝 Notas minimalistas na lateral (Side Notes)            │
│  • 🔔 Chime sonoro + Flash na tela ao finalizar o foco      │
│  • 👆 Clique: Traz o Super Productivity para primeiro plano │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Arquitetura do Projeto

```text
foco-ds/
├── macos/                             # App nativo Swift para macOS (SwiftUI + AppKit)
│   ├── Package.swift                  # Manifesto do Swift Package Manager
│   └── Sources/FocoDS/
│       ├── FocoDSApp.swift            # Janela flutuante transparente (.floating) e Menu Bar
│       ├── FocoDSModel.swift          # Modelo de estado observável (@ObservableObject)
│       ├── FocoDSPillView.swift       # Visual Glassmorphism da pílula com barra de progresso
│       ├── SideNotesView.swift        # Painel lateral de notas minimalistas com auto-save
│       ├── ScreenFlashController.swift # Controlador de som e flash translúcido na tela
│       ├── FocoDSBridge.swift         # Servidor local ultra leve (Network.framework NWListener)
│       └── SuperProductivityLauncher.swift # Disparador para focar o Super Productivity
├── plugin/                            # Plugin para o Super Productivity
│   ├── manifest.json                  # Manifesto do plugin
│   └── plugin.js                      # Host script minimalista com detecção de finalização
├── scripts/
│   ├── build-macos-app.sh             # Compilação release e empacotamento .app
│   └── package-plugin.sh              # Empacotamento do arquivo .zip do plugin
├── release/                           # Artefatos prontos para uso
│   ├── Foco DS.app                    # Aplicativo macOS compilado
│   ├── Foco-DS-macOS.zip              # ZIP do app macOS
│   └── foco-ds-super-productivity.zip # ZIP do plugin Super Productivity
├── LICENSE                            # Licença MIT
└── README.md                          # Documentação oficial
```

---

## 👤 Autor

Desenvolvido por **Douglas Santana** ([@Douglock](https://github.com/Douglock)).

> *"A clareza precede o sucesso. O foco sustenta a maestria."*

---

## 📄 Licença

Este projeto é software livre sob a licença [MIT](LICENSE).
