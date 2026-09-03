# 🎯 Foco DS

<div align="center">

![GitHub repo size](https://img.shields.io/github/repo-size/Douglock/foco-ds?style=for-the-badge&color=10b981)
![GitHub stars](https://img.shields.io/github/stars/Douglock/foco-ds?style=for-the-badge&color=eab308)
![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)
![Status](https://img.shields.io/badge/status-ativo%20%26%20funcional-emerald?style=for-the-badge)

**Aplicativo para gestão de tempo, hiperfoco e alta performance pessoal.**  
*Transformando disciplina em rotina através de ciclos adaptativos de trabalho profundo e sons ambientes nativos.*

[Visão Geral](#-visão-geral) •
[Funcionalidades](#-funcionalidades) •
[Arquitetura](#-arquitetura-do-projeto) •
[Atalhos](#-atalhos-de-teclado) •
[Como Começar](#-como-começar) •
[Autor](#-autor)

</div>

---

## 💡 Visão Geral

O **Foco DS** é uma aplicação completa concebida para desenvolvedores, criadores e profissionais que precisam proteger sua atenção e maximizar a produtividade diária.

Construído com padrões modernos da web (ES Modules, Web Audio API pura, sem dependências externas pesadas), o app une estética refinada em **dark glassmorphism**, áudio sintetizado para indução de foco e anotações anti-distração.

---

## ✨ Funcionalidades

- ⏱️ **Ciclos Adaptativos de Concentração**:
  - **Pomodoro Clássico**: 25 min foco + 5 min pausa.
  - **Deep Work Intenso**: 50 min foco + 10 min pausa.
  - **Ciclo Ultradiano**: 90 min foco + 15 min pausa profunda.
  - **Duração Personalizada**: Ajuste flexível de 1 a 120 minutos.
- 🎯 **Ancoragem de Intenção Única**:
  - Campo no topo para definir seu único foco da sessão, mantendo a mente orientada a resultados.
- 🎧 **Sons Ambientes Nativos (Web Audio API)**:
  - *Deep Brown Noise*: Ruído marrom profundo para abafar ruídos externos e induzir calma.
  - *Chuva Suave (Pink Noise)*: Ruído suave com corte de frequências para relaxamento ativo.
  - *Frequências Binaurais Alfa (10Hz)*: Estimulação por diferença de fase estéreo para foco mental.
  - *Sino Zen*: Chime suave ao término de cada bloco.
- 📝 **Anotações de Alívio Mental (Anti-Distração)**:
  - Bloco de notas rápido acessível pelo teclado (`N`) para descarregar pensamentos passageiros sem quebrar a linha de raciocínio.
- 📊 **Tracking Diário & Streaks**:
  - Métricas salvas localmente: streak de dias consecutivos, minutos focados hoje, total de sessões e gráfico dos últimos 7 dias.
- ⚡ **Alta Precisão Temporal**:
  - Motor de contagem corrigido por timestamp (`Date.now()`), garantindo que o cronômetro não congele ou atrase ao alternar abas no navegador.
- 🖥️ **Modo Tela Cheia & Design Responsivo**:
  - Interface fluida adaptada para desktops, tablets e smartphones.

---

## ⌨️ Atalhos de Teclado

| Tecla | Ação |
| :---: | :--- |
| <kbd>Espaço</kbd> | Iniciar ou Pausar a sessão atual |
| <kbd>R</kbd> | Reiniciar o cronômetro |
| <kbd>N</kbd> | Abrir/Fechar Anotações de Alívio Mental |
| <kbd>M</kbd> | Abrir seletor de Sons Ambientes |

---

## 🏗️ Arquitetura do Projeto

```text
foco-ds/
├── modules/
│   ├── audio.js         # Sintetizador puro Web Audio API (ruídos e chimes)
│   ├── storage.js       # Gerenciador de persistência (LocalStorage, streaks e notas)
│   └── timer.js         # Motor de temporização de alta precisão com drift-correction
├── styles/
│   └── main.css         # Design system com Glassmorphism, animações e paleta dark
├── index.html           # Interface semântica e acessível
├── main.js              # Controlador principal da aplicação
├── .gitignore           # Regras de exclusão do Git
├── LICENSE              # Licença MIT
├── package.json         # Manifesto do projeto
└── README.md            # Documentação técnica oficial
```

---

## 🚀 Como Começar

### Executando Localmente

1. Clone o repositório:
```bash
git clone https://github.com/Douglock/foco-ds.git
cd foco-ds
```

2. Abra o arquivo `index.html` diretamente em seu navegador, ou inicie um servidor estático local:
```bash
# Com Python 3
python3 -m http.server 3000

# Ou com Node.js
npx serve .
```

3. Acesse `http://localhost:3000` e aproveite suas sessões de foco!

---

## 👤 Autor

Desenvolvido por **Douglas Santana** ([@Douglock](https://github.com/Douglock)).

> *"A clareza precede o sucesso. O foco sustenta a maestria."*

---

## 📄 Licença

Este projeto está sob a licença [MIT](LICENSE).
