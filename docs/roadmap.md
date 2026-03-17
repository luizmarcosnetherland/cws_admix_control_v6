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
