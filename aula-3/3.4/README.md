# 3.4 — Code review de Terraform assistido por IA

## Objetivo
Usar IA como "primeiro reviewer" de código Terraform para Kubernetes, comparar com análise manual, e aplicar correções.

## Pré-requisitos
```bash
terraform version
kubectl get nodes
```

---

## Roteiro de Comandos

### Passo 1 — Ler o código (análise manual primeiro)
```bash
cd ~/ai-iac-labs/aula-3/3.4
cat codigo-para-review.tf
```

> **Exercício:** Leia o código e tente identificar problemas usando o `checklist-review.md`. Anote quantos você encontrou.

```bash
cat checklist-review.md
```

### Passo 2 — Validar que o código funciona sintaticamente
```bash
# Copiar para um diretório de trabalho temporário
mkdir -p /tmp/review-lab
cp codigo-para-review.tf /tmp/review-lab/main.tf
cd /tmp/review-lab

terraform init
terraform validate
```

> **Ponto-chave:** O código é sintaticamente válido — `terraform validate` passa. Os problemas são **semânticos** (segurança, boas práticas), não sintáticos.

### Passo 3 — Pedir review à IA
```bash
cd ~/ai-iac-labs/aula-3/3.4

# Enviar o prompt (colar o código onde indicado)
kiro chat "$(cat prompt-review.md)

$(cat codigo-para-review.tf)"
```

Ou abrir sessão interativa e colar prompt + código.

### Passo 4 — Comparar findings
```bash
# Ver o gabarito
cat gabarito.md
```

> **Exercício de comparação:**
> - Quantos findings você encontrou manualmente? ___
> - Quantos a IA encontrou? ___
> - A IA pegou algo que você não viu? ___
> - A IA deu algum falso positivo? ___
> - A IA classificou as severidades corretamente? ___

### Passo 5 — Aplicar correções por prioridade

Ordem de correção (blast radius decrescente):

**1. RBAC — reduzir permissões:**
```hcl
# ANTES (perigoso):
rule {
  api_groups = [""]
  resources  = ["*"]
  verbs      = ["*"]
}

# DEPOIS (mínimo):
rule {
  api_groups = [""]
  resources  = ["configmaps"]
  verbs      = ["get", "list"]
}
```

**2. Secret — marcar sensitive e usar envFrom:**
```hcl
# Variável:
variable "db_password" {
  type      = string
  sensitive = true
  default   = "production-password-123"
}

# No deployment — trocar env inline por envFrom:
env_from {
  secret_ref {
    name = kubernetes_secret.app.metadata[0].name
  }
}
```

**3. NetworkPolicy — restringir:**
```hcl
ingress {
  from {
    pod_selector {
      match_labels = { "allowed-client" = "true" }
    }
  }
  ports {
    port     = "80"
    protocol = "TCP"
  }
}
```

**4. Resiliência — adicionar probes e limits:**
```hcl
resources {
  limits   = { cpu = "100m", memory = "128Mi" }
  requests = { cpu = "50m", memory = "64Mi" }
}

liveness_probe {
  http_get { path = "/"; port = 80 }
  initial_delay_seconds = 5
  period_seconds        = 10
}
```

### Passo 6 — Validar o código corrigido
```bash
# Usar a versão corrigida de referência
cp ~/ai-iac-labs/aula-3/3.4/codigo-corrigido.tf /tmp/review-lab/main.tf
cd /tmp/review-lab

terraform validate
terraform plan
```

> **O que observar no plan:** Todos os resources são criados corretamente? Variáveis sensitive mostram `(sensitive value)`?

### Passo 7 — (Opcional) Aplicar e testar
```bash
terraform apply -auto-approve

# Verificar RBAC
kubectl get role -n review-app -o yaml | grep -A5 rules

# Verificar NetworkPolicy
kubectl get networkpolicy -n review-app -o yaml | grep -A10 ingress

# Verificar probes
kubectl get deployment review-app -n review-app -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
```

### Passo 8 — Cleanup
```bash
cd /tmp/review-lab
terraform destroy -auto-approve
rm -rf /tmp/review-lab
```

---

## Estrutura dos arquivos

```
3.4/
├── README.md               ← Este roteiro
├── codigo-para-review.tf   ← Código com 10 problemas intencionais
├── codigo-corrigido.tf     ← Versão corrigida (referência)
├── prompt-review.md        ← Prompt estruturado para review com IA
├── checklist-review.md     ← Checklist manual (comparar com IA)
└── gabarito.md             ← Resposta: todos os problemas e prioridade
```

## Problemas por categoria

| Categoria | Qtd | Severidade |
|-----------|-----|-----------|
| Segurança (RBAC) | 2 | ALTA |
| Segurança (Secrets) | 2 | ALTA |
| Segurança (Network) | 1 | ALTA |
| Resiliência | 3 | MÉDIA |
| Boas práticas | 2 | BAIXA |

## Pontos-chave para discussão

1. **IA como primeiro reviewer** — pega o óbvio rápido, libera o humano para contexto
2. **Validação ≠ segurança** — `terraform validate` passa mesmo com código inseguro
3. **Falsos positivos** — a IA pode sugerir fixes desnecessários (avaliar criticamente)
4. **Prioridade** — corrigir por blast radius (RBAC > Secrets > Network > Resiliência > Estilo)
5. **Checklist + IA** — combinação é mais eficaz que qualquer um isolado
6. **A IA não conhece suas políticas** — ela não sabe se seu time permite :latest em dev
