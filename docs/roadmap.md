# Roadmap

## Proximas etapas

### 1. Conta de e-mail de controle para relatorios enviados por clientes

Objetivo:
Criar uma conta de e-mail corporativa dedicada para receber copia oculta dos relatorios enviados a partir do app.

Beneficios:
- centraliza os relatorios enviados pelos clientes em um unico canal
- facilita auditoria, acompanhamento comercial e suporte tecnico
- reduz risco de perda de historico quando o envio depende apenas do destinatario final

Escopo sugerido:
- criar uma conta exclusiva, por exemplo `relatorios@...`
- adicionar essa conta como BCC nos envios de relatorios por e-mail
- avaliar se o endereco deve ficar fixo no app ou configuravel
- refletir esse comportamento na politica de privacidade e no fluxo interno da empresa

Observacoes:
- ideal para uma proxima versao, com validacao juridica e operacional
- recomendavel testar em Android e iOS para garantir que o BCC seja mantido no app de e-mail nativo

### 2. Armazenamento e envio dos relatorios em PDF

Objetivo:
Expandir o fluxo atual para priorizar relatorios em PDF, com armazenamento e compartilhamento mais consistentes.

Beneficios:
- entrega um formato mais apresentavel para clientes e equipes tecnicas
- melhora padronizacao visual e historico documental
- reduz dependencia exclusiva de CSV para compartilhamento externo

Escopo sugerido:
- definir uma pasta padrao para salvar PDFs gerados pelo app
- permitir envio de PDF por e-mail no mesmo fluxo usado para relatorios
- avaliar envio combinado de CSV + PDF ou opcao de escolher o formato
- revisar nomes de arquivo, padrao visual e organizacao por obra/periodo

Observacoes:
- pode evoluir depois para armazenamento em nuvem ou sincronizacao corporativa
- vale considerar retencao de arquivos, espaco local e estrategia de backup

### 3. Secao com videos sobre o funcionamento do CWS Admix

Objetivo:
Adicionar uma secao no app com videos explicativos para apresentar o funcionamento do CWS Admix e apoiar o uso tecnico/comercial em campo.

Beneficios:
- facilita entendimento rapido do produto e da tecnologia
- reforca treinamento de equipes, clientes e especificadores
- amplia o valor do app como ferramenta de apoio tecnico

Escopo sugerido:
- criar uma area dedicada para videos institucionais e tecnicos
- organizar os videos por tema, por exemplo funcionamento, aplicacao, beneficios e boas praticas
- permitir abertura simples no app ou via link externo
- avaliar suporte a miniaturas, titulos curtos e breve descricao de cada video

Observacoes:
- ideal usar links gerenciaveis para facilitar atualizacao sem depender de nova versao do app
- vale alinhar quais videos serao institucionais e quais terao foco tecnico/comercial

### 4. Aviso de atualizacao no Android (implementado)

Objetivo:
Habilitar no Android a verificacao de novas versoes publicadas na Google Play. O servico atual encerra a verificacao fora do iOS e consulta apenas a App Store da Apple.

Escopo sugerido:
- implementar a verificacao de atualizacao pela Google Play usando uma solucao oficial e compativel com a distribuicao do app
- comparar corretamente a versao e o `versionCode` instalados com a versao disponivel
- abrir a pagina correta do aplicativo na Google Play ao tocar em Atualizar
- manter o comportamento atual do iOS e separar as regras especificas de cada loja
- adicionar testes para Android sem remover os testes existentes de iOS

Observacoes:
- implementado para o proximo build usando a API oficial In-App Updates da Google Play
- validar em um aparelho com a versao anterior instalada e a nova versao publicada na faixa de testes da Google Play
