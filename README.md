# IA como Copiloto em Infra — Material de apoio

Labs do curso, organizados por aula (`aula-1/` a `aula-4/`), e o PDF
`AI-IaC-Material-de-Apoio.pdf`.

O PDF chama este repositório de `ai-iac-labs/`. Dentro da VM do lab, a raiz do
repositório fica em `~/ai-iac-labs`, então os caminhos dos exercícios
(`~/ai-iac-labs/aula-X/...`) funcionam como nas aulas.

## Pré-requisitos (máquina host)

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- `kubectl` e, opcionalmente, `helm`, se você quiser usar o cluster direto do host
- Cerca de 3 GB de RAM livres (a VM usa 2 GB e 2 CPUs) e acesso à internet
- As portas `6443`, `8060` e `8443` livres em `127.0.0.1`. A `6443` é
  obrigatória (veja a errata ao final).

## Passo a passo

### 1. Subir a VM

```bash
cd aula-1/1.5
vagrant up      # primeira vez: ~5-10 min
```

O provisionamento instala k3s, Helm, Terraform, Node.js LTS (NodeSource),
Gemini CLI e Kiro CLI. No fim, ele mostra as versões instaladas.

### 2. (Opcional) Usar um binário próprio do Kiro CLI

Se quiser usar um binário do Kiro em vez do instalador oficial, coloque
`kiro-cli` (e também `kiro-cli-chat` e `kiro-cli-term`, se tiver) em `bin/`,
na raiz do repositório, antes do `vagrant up`. A pasta `bin/` está no
`.gitignore`.

Sem `bin/kiro-cli`, o provisionamento instala o Kiro CLI com o comando oficial
publicado em <https://kiro.dev/>, como usuário `vagrant`, em
`~/.local/bin/kiro-cli`:

```bash
curl -fsSL https://cli.kiro.dev/install | bash
```

Se a instalação falhar, o provisionamento só mostra um aviso e continua.
Depois você pode instalar manualmente dentro da VM com o mesmo comando.

### 3. Entrar na VM e fazer login nas IAs

```bash
vagrant ssh
```

**Kiro CLI.** A VM não tem navegador, então use o *device flow*: o CLI mostra
uma URL e um código, e você conclui o login no navegador do host (ou no
celular).

```bash
kiro-cli login --use-device-flow
kiro-cli whoami     # confirma o login
```

Métodos de login disponíveis (fonte: <https://kiro.dev/>):

| Método | Precisa de conta AWS? |
|---|---|
| GitHub | Não |
| Google | Não |
| AWS Builder ID | Não. É um cadastro gratuito, separado de uma conta AWS. |
| AWS IAM Identity Center | Usa o Identity Center da sua organização: `kiro-cli login --license pro --identity-provider <URL> --region <região>` |

Login por provedor de identidade externo (IdP) ainda não funciona com device
flow.

**Gemini CLI.** Gere uma chave em <https://aistudio.google.com/apikey>:

```bash
echo 'export GEMINI_API_KEY="sua-chave"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Validar o ambiente (dentro da VM)

```bash
cd ~/ai-iac-labs/aula-1
bash 01-validacao-ambiente.sh
```

### 5. (Opcional) Usar o cluster a partir do host

Rode no host, na mesma pasta do Vagrantfile:

```bash
cd aula-1/1.5
./k3s-setup.sh
kubectl get nodes
```

> **Windows:** o `k3s-setup.sh` é um script bash. Rode-o no **Git Bash** ou no
> **WSL**, e não no PowerShell ou no Prompt de Comando. O kubeconfig vai para o
> `~/.kube/config` do ambiente onde você rodou o script, então use o `kubectl`
> nesse mesmo ambiente.

O script copia o kubeconfig da VM para `~/.kube/config`. **Se já existir um
`~/.kube/config`, ele é salvo antes em `~/.kube/config.bak-AAAAMMDD-HHMMSS`.**
Para voltar ao anterior:

```bash
cp ~/.kube/config.bak-<data> ~/.kube/config
```

### Comandos úteis do Vagrant (em `aula-1/1.5`)

```bash
vagrant halt        # desliga a VM (preserva dados)
vagrant up          # liga de novo
vagrant provision   # reexecuta o provisionamento
vagrant destroy     # apaga a VM (depois disso, rode ./k3s-setup.sh de novo)
```

## Errata do PDF

As páginas seguem a numeração do visualizador de PDF. O número impresso no
rodapé do PDF é uma unidade menor.

| Pág. | O PDF diz | Correto |
|---|---|---|
| Todas | `ai-iac-labs/aula-X/...` | `ai-iac-labs/` é a **raiz deste repositório**. Na VM: `~/ai-iac-labs/aula-X/...` |
| 9 | Vagrantfile em `material-de-apoio/ai-iac-labs/aula1/1.5/Vagrantfile` | `aula-1/1.5/Vagrantfile` (com hífen em `aula-1`) |
| 10 | `cd material-de-apoio/ai-iac-labs/aula1/1.5/` | `cd aula-1/1.5` |
| 10 | Rodar `./k3s-setup.sh` "na raiz do projeto" | Rodar em `aula-1/1.5/`, a mesma pasta do Vagrantfile |
| 10 | Rodar `k3s-setup.sh` de novo após `halt` + `up` "pois o IP pode mudar" | O kubeconfig aponta para `127.0.0.1:6443`, então o IP não muda. Rode de novo só depois de `vagrant destroy` + `vagrant up`, que cria um cluster novo com credenciais novas |
| 10 | Node.js "via fnm" | Node.js LTS via **NodeSource (apt)**, instalado para todos os usuários. Com o fnm, o `node` e o `gemini` ficavam inacessíveis para o usuário `vagrant` |
| 10 | Kiro CLI "binário copiado de `./bin/`" | Opcional: usa `bin/kiro-cli*` da raiz do repositório, se existir. Senão, usa o instalador oficial (<https://kiro.dev/>) em `~/.local/bin` do usuário `vagrant` |
| 11 | Portas: `6443 → 6443` | Continua igual, mas agora **sem `auto_correct`**. Se a 6443 do host estiver ocupada, o `vagrant up` falha com erro de colisão de porta. Antes, o Vagrant trocava a porta e o kubeconfig parava de funcionar sem aviso. Libere a porta e rode de novo |
| 11 | Pastas sincronizadas `./ai-iac-labs → /home/vagrant/ai-iac-labs` e `./bin → /home/vagrant/bin` | Uma só: **raiz do repositório → `/home/vagrant/ai-iac-labs`**. O `bin/` aparece em `~/ai-iac-labs/bin` |
| 11, 33 e exercícios | `which kiro-cli`, `kiro auth`, `kiro chat` | O instalador oficial cria o comando **`kiro-cli`**. Troque `kiro auth` por `kiro-cli login --use-device-flow` e `kiro chat "..."` por `kiro-cli chat "..."`. O script de validação aceita `kiro-cli` ou `kiro`, e o `aula-3/3.5/pipeline.sh` usa `kiro-cli` por padrão (outro comando: `KIRO_BIN=... ./pipeline.sh`) |
