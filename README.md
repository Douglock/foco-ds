# 🎯 Foco DS

<div align="center">

![GitHub repo size](https://img.shields.io/github/repo-size/Douglock/foco-ds?style=for-the-badge&color=10b981)
![GitHub stars](https://img.shields.io/github/stars/Douglock/foco-ds?style=for-the-badge&color=eab308)
![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)
![Status](https://img.shields.io/badge/status-ativo%20%26%20minimalista-emerald?style=for-the-badge)

**HUD Minimalista Flutuante para Super Productivity no macOS.**  
*Exibe apenas o que importa: tarefa ativa, tempo de foco e progresso. Zero botões intrusivos. Um clique para voltar ao Super Productivity.*

[Visão Geral](#-visão-geral) •
[Instalação](#-instalação-rápida) •
[Como Funciona](#-como-funciona) •
[Arquitetura](#-arquitetura-do-projeto) •
[Autor](#-autor)

</div>

---

## 💡 Visão Geral

O **Foco DS** foi projetado com uma premissa clara: **menos é mais**.

Em vez de sobrecarregar o usuário com botões, controles de play/pause ou editores de tarefas na barra flutuante, o **Foco DS atua como um espelho ambiente (HUD)**:
- **100% Passivo (Read-Only)**: Todo o gerenciamento de tarefas, cronômetro e pausas continua sendo feito no Super Productivity.
- **Display Flutuante Discreto**: Uma pílula em *dark glassmorphism* que exibe o nome da tarefa ativa, o tempo trabalhado e o status de foco/pausa.
- **Clique Direto**: Clicar na pílula traz imediatamente o **Super Productivity para primeiro plano** focado na tarefa.
- **Arraste Livre**: Posicione a pílula onde quiser no monitor (ou deixe-a no topo da tela).
- **Consumo Mínimo de Recursos**: Menos de 30 MB de RAM e 0% de CPU em repouso.

---

## ⚡ Instalação Rápida

### 1. Instalar o Plugin no Super Productivity
1. No Super Productivity, acesse **Configurações → Plugins → Escolher arquivo de plugin**.
2. Selecione o arquivo [`release/foco-ds-super-productivity.zip`](release/foco-ds-super-productivity.zip).

### 2. Abrir o App no macOS
1. Baixe ou descompacte [`release/Foco-DS-macOS.zip`](release/Foco-DS-macOS.zip) (ou copie `Foco DS.app` para a sua pasta **Aplicativos**).
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
│  • Exibe: 🟢 Tarefa Ativa • 18:42                          │
│  • Clique: Traz o Super Productivity para o primeiro plano │
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
│       ├── FocoDSPillView.swift       # Visual Glassmorphism da pílula com arraste nativo
│       ├── FocoDSBridge.swift         # Servidor local ultra leve (Network.framework NWListener)
│       └── SuperProductivityLauncher.swift # Disparador para focar o Super Productivity
├── plugin/                            # Plugin para o Super Productivity
│   ├── manifest.json                  # Manifesto do plugin
│   └── plugin.js                      # Host script minimalista de envio de estado
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
