#!/bin/bash
# valida.sh — Verifica se todos os recursos do payment-api existem no cluster
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  if kubectl get "$1" -n payment 2>/dev/null | grep -q "$2"; then
    echo -e "${GREEN}✓${NC} $1/$2"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} $1/$2 — NÃO ENCONTRADO"
    FAIL=$((FAIL + 1))
  fi
}

check_ns() {
  if kubectl get ns payment &>/dev/null; then
    echo -e "${GREEN}✓${NC} namespace/payment"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} namespace/payment — NÃO ENCONTRADO"
    FAIL=$((FAIL + 1))
  fi
}

check_type() {
  local count
  count=$(kubectl get "$1" -n payment --no-headers 2>/dev/null | wc -l)
  if [[ "$count" -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} $1 (${count} encontrado(s))"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} $1 — NENHUM ENCONTRADO"
    FAIL=$((FAIL + 1))
  fi
}

echo "Validando recursos do payment-api no namespace 'payment'..."
echo ""

check_ns
check_type resourcequota
check_type limitrange
check_type configmap
check_type secret
check_type serviceaccount
check_type role
check_type rolebinding
check_type deployment
check_type service
check_type networkpolicy

echo ""
echo "Resultado: ${PASS} OK, ${FAIL} falhas (total esperado: 11)"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}✓ Todos os recursos criados com sucesso!${NC}"
else
  echo -e "${YELLOW}⚠ Alguns recursos não foram encontrados. Verifique os nomes gerados pela IA.${NC}"
  echo "  Dica: kubectl get all -n payment && kubectl get configmap,secret,sa,role,rolebinding,netpol -n payment"
  exit 1
fi
