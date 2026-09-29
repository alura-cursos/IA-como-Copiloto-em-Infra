#!/bin/bash
# Aula 1 — Validacao do ambiente de lab
# Execute: bash 01-validacao-ambiente.sh

set -e

echo "============================================"
echo " Alura AI-IaC Lab — Validacao do Ambiente"
echo "============================================"
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        echo "[OK]   $name"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "--- Ferramentas de Infra ---"
check "kubectl instalado" "kubectl version --client"
check "k3s rodando" "kubectl get nodes | grep -q Ready"
check "helm instalado" "helm version"
check "terraform instalado" "terraform version"

echo ""
echo "--- Assistentes de IA ---"
check "Kiro CLI instalado (kiro-cli ou kiro)" "command -v kiro-cli || command -v kiro"
check "Gemini CLI instalado" "which gemini"

echo ""
echo "--- Kubernetes saudavel ---"
check "Namespace kube-system ok" "kubectl get pods -n kube-system | grep -q Running"
check "CoreDNS rodando" "kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q Running"
check "Traefik rodando" "kubectl get pods -n kube-system | grep traefik | grep -q Running"

echo ""
echo "--- Conectividade ---"
check "Acesso a internet" "curl -s --max-time 5 https://google.com > /dev/null"

echo ""
echo "============================================"
echo " Resultado: $PASS passed, $FAIL failed"
echo "============================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "ATENCAO: Corrija os itens [FAIL] antes de continuar."
    echo "         Consulte o Vagrantfile ou execute 'vagrant provision'."
    exit 1
else
    echo ""
    echo "Ambiente pronto! Pode seguir para os exercicios."
fi
