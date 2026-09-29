# Aula 1 — Introdução à IA Generativa para profissionais de Infra

## Estrutura

```
aula-1/
├── README.md                      # Este arquivo
├── 01-validacao-ambiente.sh       # Script de validação do ambiente completo
├── 02-primeiro-prompt-kiro.md     # Primeiro contato com Kiro CLI
├── 03-primeiro-prompt-gemini.md   # Primeiro contato com Gemini CLI
├── 04-demo-temperatura.md        # Demonstração do efeito de temperatura
├── 05-demo-contexto.md           # Demonstração de janela de contexto
├── 1.4/
│   └── 06-casos-uso-infra.md     # Exemplos práticos de IA em DevOps/SRE
└── 1.5/
    ├── Vagrantfile               # VM do lab (k3s, Helm, Terraform, Kiro, Gemini)
    └── k3s-setup.sh              # Copia o kubeconfig da VM para o host
```

Para subir o ambiente, veja o [README da raiz do repositório](../README.md).

## Pré-requisitos

- VM do lab rodando (`vagrant up && vagrant ssh`)
- k3s instalado e funcionando
- Helm instalado
- Kiro CLI configurado (`kiro auth`)
- Gemini CLI configurado (`export GEMINI_API_KEY=...`)

## Objetivo

Ao final desta aula você terá:
- Ambiente completo funcionando (k3s + Helm + Kiro + Gemini)
- Entendimento prático de como LLMs geram respostas
- Visão clara de onde IA agrega valor em operações
