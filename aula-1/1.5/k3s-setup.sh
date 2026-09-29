#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"
mkdir -p ~/.kube

# Baixa para um arquivo temporario: se o vagrant ssh falhar, o kubeconfig atual fica intacto
TMP_CONFIG="$(mktemp)"
trap 'rm -f "$TMP_CONFIG"' EXIT
if ! vagrant ssh -c "sudo cat /etc/rancher/k3s/k3s.yaml" 2>/dev/null > "$TMP_CONFIG" || [ ! -s "$TMP_CONFIG" ]; then
  echo "ERRO: nao foi possivel ler o kubeconfig da VM. Ela esta rodando? (vagrant status)" >&2
  exit 1
fi

if [ -f ~/.kube/config ]; then
  BACKUP=~/.kube/config.bak-$(date +%Y%m%d-%H%M%S)
  cp -p ~/.kube/config "$BACKUP"
  echo "Backup do kubeconfig anterior salvo em $BACKUP"
fi

mv "$TMP_CONFIG" ~/.kube/config
chmod 600 ~/.kube/config

echo "kubeconfig copiado para ~/.kube/config"
kubectl cluster-info
