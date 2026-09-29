# 3.5 — Pipeline completo de Terraform com assistente de IA

## Objetivo

Montar um pipeline IaC end-to-end **sem ferramenta de CI** — usando um shell script como orquestrador e o assistente de IA nos pontos de geração, review e documentação. O aluno vive o fluxo completo de um serviço novo do zero.

## Conceito

```
Especificar → Gerar (IA) → Validar (terraform) → Revisar (IA) → Corrigir → Aplicar → Documentar (IA) → Reproduzir
     ↑                                                    |
     └────────── iterar se review encontrar problemas ────┘
```

O `pipeline.sh` é o runner. Cada `read -p` é um **gate humano**. A IA assiste, o humano decide.

## Estrutura

```
3.5/
├── README.md           ← Este roteiro
├── pipeline.sh         ← Pipeline executável (o "CI" local)
├── valida.sh           ← Checa se todos os resources existem no cluster
├── prompts/
│   ├── 01-gerar-nginx.md ← Prompt para gerar toda a infra (usado pelo pipeline.sh)
│   ├── 01-gerar.md     ← Variante do prompt de geração (http-echo, base do gabarito)
│   ├── 02-review.md    ← Prompt para code review de segurança
│   └── 03-documentar.md ← Prompt para gerar README do módulo
└── referencia/         ← Gabarito (consultar só se travar: cp referencia/*.tf .)
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

> **Atenção: o gabarito não usa nginx.** O `pipeline.sh` pede à IA um serviço
> com `nginx:1.27-alpine` na porta **80** (`prompts/01-gerar-nginx.md`), mas o
> gabarito em `referencia/` foi gerado a partir de `prompts/01-gerar.md` e usa
> `hashicorp/http-echo:0.2.3` na porta **5678**. Os dois criam os mesmos 11
> recursos e passam no `./valida.sh`. Se você copiar o gabarito
> (`cp referencia/*.tf .`), lembre que:
>
> - o pod responde o texto `payment-api running`, e não a página padrão do nginx;
> - o Service e a NetworkPolicy ficam na porta **5678**. No teste de
>   NetworkPolicy abaixo, troque `http://payment-api:80` por
>   `http://payment-api:5678`, senão até o pod com a label vai falhar;
> - o review da IA (etapa 4) pode apontar a diferença em relação ao prompt.
>   Isso é esperado e não é um erro do seu código.

## Pré-requisitos

```bash
terraform version        # >= 1.5
kubectl get nodes        # k3s rodando
which kiro || which gemini  # assistente disponível
```

---

## Como executar

### Modo guiado (recomendado)

```bash
cd ~/ai-iac-labs/aula-3/3.5
./pipeline.sh
```

O script guia passo a passo, pausando para você interagir com a IA.

### Modo manual (passo a passo)

Se preferir executar cada etapa manualmente:

#### Passo 1 — Especificar
Leia os requisitos abaixo e entenda o que será criado:

- Namespace `payment` com ResourceQuota (6 pods, 1Gi) e LimitRange
- Deployment `payment-api`: nginx:1.27-alpine, 2 réplicas, porta 80, probes, limits
- ConfigMap + Secret via envFrom
- ServiceAccount + Role + RoleBinding (ler configmaps/secrets)
- NetworkPolicy: ingress apenas de pods com label `allowed-client=true`, porta 80

#### Passo 2 — Gerar com IA
```bash
kiro chat < prompts/01-gerar-nginx.md
```
Salve o output como `main.tf`, `variables.tf`, `outputs.tf`.

#### Passo 3 — Validar
```bash
terraform init
terraform validate
terraform plan -out=tfplan
```
**Checkpoint:** o plan deve mostrar 9-11 resources a criar.

#### Passo 4 — Revisar com IA
```bash
kiro chat < prompts/02-review.md
```
Cole `main.tf` onde indicado. Analise os findings.

#### Passo 5 — Corrigir e re-validar
Aplique as correções pertinentes, depois:
```bash
terraform validate
terraform plan -out=tfplan
```
**Critério:** plan sem erros. Se a IA sugeriu algo que quebra o plan, ignore.

#### Passo 6 — Aplicar
```bash
terraform apply tfplan

# Verificar
kubectl get all -n payment
kubectl get configmap,secret,sa -n payment
kubectl get role,rolebinding -n payment
kubectl get networkpolicy,resourcequota,limitrange -n payment
```

Ou use o script de validação:
```bash
./valida.sh
```

#### Passo 7 — Documentar
```bash
kiro chat < prompts/03-documentar.md
```
Salve como `MODULE-README.md`.

#### Passo 8 — Provar reprodutibilidade
```bash
terraform destroy -auto-approve
kubectl get ns payment           # deve dar NotFound
terraform apply -auto-approve
kubectl get all -n payment       # tudo de volta
```

---

## Testar NetworkPolicy (opcional)

```bash
# Deve funcionar (tem a label)
kubectl run test-ok --rm -it --image=curlimages/curl -n payment \
  --labels="allowed-client=true" -- curl -s http://payment-api:80

# Deve ser bloqueado (sem label)
kubectl run test-blocked --rm -it --image=curlimages/curl -n payment \
  -- curl -s --connect-timeout 3 http://payment-api:80
```

> **Nota:** NetworkPolicy depende do CNI. Flannel padrão não enforça. Com Calico, sim.

---

## Pontos-chave para discussão

1. **Pipeline ≠ CI tool** — é só "etapas com gates". O terminal é o runner, o script é a definição.
2. **IA em 3 papéis** — geração, review e documentação são usos diferentes da mesma ferramenta.
3. **terraform plan como gate** — nenhum apply sem plan limpo, independente do que a IA sugeriu.
4. **Human-in-the-loop** — a IA propõe, o humano valida com ferramentas reais.
5. **Reprodutibilidade** — destroy + apply prova que o código é autossuficiente.
6. **De script para CI** — depois basta trocar `read -p` por aprovação no PR e chamadas de API.

## Cleanup

```bash
terraform destroy -auto-approve
```
