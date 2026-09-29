#!/bin/bash
# pipeline.sh — Pipeline IaC com Kiro CLI integrado (sem CI)
# Uso (dentro da VM do lab): cd ~/ai-iac-labs/aula-3/3.5 && ./pipeline.sh
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

KIRO="${KIRO_BIN:-kiro-cli}"

# Os caminhos abaixo (prompts/, main.tf...) sao relativos a pasta do script
cd "$(dirname "$0")"

gate() {
  echo ""
  echo -e "${YELLOW}═══════════════════════════════════════${NC}"
  echo -e "${YELLOW}  $1${NC}"
  echo -e "${YELLOW}═══════════════════════════════════════${NC}"
  echo ""
}

ok() { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${BLUE}→ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# ─────────────────────────────────────
# PRÉ-REQUISITOS
# ─────────────────────────────────────
gate "PRÉ-REQUISITOS: ferramentas + k3s"

command -v terraform >/dev/null || fail "terraform não encontrado. Rode este script dentro da VM do lab (vagrant ssh)"
command -v "$KIRO" >/dev/null || fail "Kiro CLI ('$KIRO') não encontrado. Instale o Kiro CLI ou defina KIRO_BIN"
ok "terraform e $KIRO disponíveis"

info "Verificando acesso ao k3s..."
kubectl get nodes >/dev/null 2>&1 || fail "kubectl não conecta ao cluster. Verifique com: kubectl get nodes"
ok "kubectl conectado ao cluster"
echo ""

# ─────────────────────────────────────
gate "ETAPA 1/8: ESPECIFICAR"
echo "Requisitos do serviço payment-api:"
echo "  • Namespace 'payment' com ResourceQuota (6 pods, 1Gi RAM) e LimitRange"
echo "  • Deployment: nginx:1.27-alpine, 2 réplicas, porta 80, probes, limits"
echo "  • Secret + ConfigMap via envFrom"
echo "  • RBAC: ServiceAccount + Role + RoleBinding"
echo "  • NetworkPolicy: ingress apenas de pods com label allowed-client=true, porta 80"
echo ""
info "O prompt completo está em prompts/01-gerar-nginx.md"
read -p "Pressione ENTER para gerar o código com Kiro..."

# ─────────────────────────────────────
gate "ETAPA 2/8: GERAR COM IA"
PROMPT_GERAR=$(cat prompts/01-gerar-nginx.md)
info "Chamando Kiro para gerar o código Terraform..."
echo ""
$KIRO chat "$PROMPT_GERAR"
echo ""

if [[ ! -f main.tf ]]; then
  info "Kiro não salvou os arquivos automaticamente."
  info "Copie o código gerado para main.tf, variables.tf, outputs.tf"
  info "Ou use os arquivos de referência: cp referencia/*.tf ."
  read -p "Pressione ENTER quando os arquivos estiverem prontos..."
fi

[[ -f main.tf ]] || fail "main.tf não encontrado nesta pasta"
[[ -f variables.tf ]] || fail "variables.tf não encontrado"
ok "Arquivos de código encontrados"

# ─────────────────────────────────────
gate "ETAPA 3/8: VALIDAR"
info "terraform init"
terraform init -input=false -no-color
ok "Init OK"

echo ""
info "terraform validate"
terraform validate -no-color
ok "Validate OK"

echo ""
info "terraform plan"
terraform plan -out=tfplan -no-color 2>&1 | tee plan-output.txt

RESOURCE_COUNT=$(grep -c "will be created" plan-output.txt || true)
echo ""
echo -e "Resources a criar: ${GREEN}${RESOURCE_COUNT}${NC} (esperado: 9-11)"
[[ "$RESOURCE_COUNT" -lt 7 ]] && echo -e "${YELLOW}⚠ Poucos resources. Revise o código.${NC}"
ok "Plan gerado com sucesso"

# ─────────────────────────────────────
gate "ETAPA 4/8: REVISAR COM IA"
PROMPT_REVIEW=$(cat prompts/02-review.md)
CODE=$(cat main.tf)
REVIEW_INPUT="${PROMPT_REVIEW/\[COLE O CONTEÚDO DE main.tf AQUI\]/$CODE}"

info "Chamando Kiro para code review de segurança..."
echo ""
$KIRO chat "$REVIEW_INPUT"
echo ""
read -p "Aplique as correções pertinentes. ENTER quando pronto..."

# ─────────────────────────────────────
gate "ETAPA 5/8: CORRIGIR E RE-VALIDAR"
echo "Nesta etapa o ciclo de feedback se fecha:"
echo "  1. Você aplicou (ou não) os findings do review da IA"
echo "  2. Agora o terraform validate confirma que o código é válido"
echo "  3. E o terraform plan mostra o estado final antes do apply"
echo "  Se o plan estiver limpo → seguimos para aplicar"
echo "  Se houver erros → volte e corrija antes de continuar"
echo ""
info "Re-validando após correções..."
terraform validate -no-color
ok "Validate OK"

terraform plan -out=tfplan -no-color 2>&1 | tee plan-output.txt
ok "Plan limpo após review"
read -p "Satisfeito com o plan? ENTER para aplicar, Ctrl+C para abortar..."

# ─────────────────────────────────────
gate "ETAPA 6/8: APLICAR"
info "terraform apply"
terraform apply tfplan
ok "Apply concluído"

echo ""
info "Verificando recursos no cluster..."
echo ""
kubectl get ns payment
kubectl get deploy,svc,pods -n payment
kubectl get configmap,secret,sa -n payment
kubectl get role,rolebinding -n payment
kubectl get networkpolicy -n payment
kubectl get resourcequota,limitrange -n payment
echo ""
ok "Recursos criados no k3s"

# ─────────────────────────────────────
gate "ETAPA 7/8: DOCUMENTAR COM IA"
PROMPT_DOC=$(cat prompts/03-documentar.md)
VARS=$(cat variables.tf)
OUTS=$(cat outputs.tf 2>/dev/null || echo "# sem outputs.tf")
DOC_INPUT="${PROMPT_DOC/\[COLE O CONTEÚDO DE variables.tf AQUI\]/$VARS}"
DOC_INPUT="${DOC_INPUT/\[COLE O CONTEÚDO DE outputs.tf AQUI\]/$OUTS}"

info "Chamando Kiro para gerar documentação..."
echo ""
$KIRO chat "$DOC_INPUT" | tee MODULE-README.md
echo ""
ok "Documentação salva em MODULE-README.md"

# ─────────────────────────────────────
gate "ETAPA 8/8: PROVAR REPRODUTIBILIDADE"
info "terraform destroy"
terraform destroy -auto-approve -no-color
ok "Recursos destruídos"

echo ""
info "Aguardando namespace ser removido..."
sleep 3

info "terraform apply (recriando do zero)"
terraform apply -auto-approve -no-color
ok "Infraestrutura recriada com sucesso"

echo ""
kubectl get all -n payment

# ─────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ PIPELINE CONCLUÍDO COM SUCESSO${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "O que foi feito:"
echo "  1. Especificou requisitos em linguagem natural"
echo "  2. Gerou código Terraform com Kiro"
echo "  3. Validou com terraform validate + plan"
echo "  4. Fez code review assistido por Kiro"
echo "  5. Corrigiu findings e re-validou"
echo "  6. Aplicou no k3s e confirmou com kubectl"
echo "  7. Documentou o módulo com Kiro"
echo "  8. Provou reprodutibilidade (destroy + apply)"
echo ""
echo -e "${YELLOW}⚠ Os recursos do payment-api CONTINUAM no cluster (namespace 'payment').${NC}"
info "Quando terminar, remova com:"
echo "  cd ~/ai-iac-labs/aula-3/3.5 && terraform destroy -auto-approve"
