# Speed Test POC - Diagnóstico de Rede

## 📋 Sobre o Projeto

Este é um projeto Flutter desenvolvido para realizar testes de velocidade de internet e diagnóstico de conexão. O aplicativo foi criado como uma **Prova de Conceito (POC)** para ser integrado em sistemas de PDV (Ponto de Venda) para lojas autônomas com self-checkout, rodando em totens Android.

## 🎯 Objetivo

O objetivo principal deste aplicativo é **otimizar o processo de diagnóstico de problemas de conexão** enfrentados pela equipe de suporte técnico quando clientes relatam problemas de conectividade nos totens Android.

### Problema que Resolve

Atualmente, quando um cliente relata problemas de conexão (o sistema informa "sem internet"), a equipe de suporte precisa:

1. Acessar o totem remotamente (via ferramentas de acesso remoto)
2. Sair do aplicativo principal
3. Abrir o navegador
4. Realizar um teste de velocidade manualmente
5. Verificar se a conexão atende aos requisitos

Este processo é **demorado e trabalhoso**, especialmente quando o totem está em modo quiosque (requer destravar o dispositivo).

### Solução Proposta

Este aplicativo permite realizar testes de velocidade **diretamente dentro do sistema**, em uma tela de configurações com acesso restrito, sem necessidade de sair do aplicativo principal ou destravar o dispositivo.

## 🔧 Funcionalidades

### Testes Realizados

1. **Velocidade de Download** - Mede a taxa de download em Mbps
2. **Velocidade de Upload** - Mede a taxa de upload em Mbps (importante para funcionalidades que requerem envio de dados)
3. **Latência** - Mede o tempo de resposta (ping) em milissegundos
4. **Qualidade de Conexão** - Avaliação geral baseada nos três parâmetros acima

### Informações de Rede

- Tipo de conexão (Wi-Fi, Ethernet, Dados Móveis)
- Detalhes técnicos da conexão (SSID, IP, sinal, etc.)
- IP do servidor utilizado no teste

### Recursos Adicionais

- **Cancelamento de teste** - Permite interromper um teste em andamento
- **Atualização em tempo real** - Valores são atualizados durante a execução do teste
- **Interface adaptativa** - Layout otimizado para totens (tela grande) e dispositivos móveis
- **Indicador de qualidade** - Avalia se a conexão é adequada para operações críticas (TEF, upload de dados, etc.)

## 🏗️ Arquitetura

O projeto segue uma arquitetura limpa com separação de responsabilidades:

```
lib/
├── app/
│   ├── modules/
│   │   └── speed_test/
│   │       ├── domain/          # Regras de negócio
│   │       │   ├── entities/    # Entidades do domínio
│   │       │   ├── repositories/ # Interfaces dos repositórios
│   │       │   └── usecase/     # Casos de uso
│   │       ├── infrastructure/  # Implementações técnicas
│   │       │   └── repositories/ # Implementação dos repositórios
│   │       └── presentation/    # Interface do usuário
│   │           ├── pages/        # Telas
│   │           └── mobx/        # Gerenciamento de estado
│   └── shared/                  # Recursos compartilhados
└── main.dart
```

### Tecnologias Utilizadas

- **Flutter** - Framework de desenvolvimento
- **MobX** - Gerenciamento de estado reativo
- **Flutter Modular** - Injeção de dependências e roteamento
- **flutter_speed_test_plus** - Biblioteca para testes de velocidade
- **dart_ping** - Biblioteca para testes de latência
- **connectivity_plus** - Detecção de tipo de conexão
- **wifi_iot** - Informações detalhadas de Wi-Fi

## 📱 Contexto de Uso

### Ambiente

- **Dispositivo**: Totens Android em lojas físicas
- **Aplicativo Principal**: Sistema de PDV com self-checkout
- **Gateway de Pagamento**: TEF (Transferência Eletrônica de Fundos) com pinpad anexo
- **VPN**: Conexão VPN específica (necessária para comunicação com o gateway de pagamento)

### Requisitos de Conexão

Para o funcionamento adequado do sistema, a conexão precisa atender aos seguintes requisitos:

- **Download**: Mínimo de 2 Mbps (recomendado: 5+ Mbps)
- **Upload**: Mínimo de 1 Mbps (recomendado: 2+ Mbps)
- **Latência**: Idealmente abaixo de 200ms (crítico para TEF)

### Casos de Uso

1. **Diagnóstico de Problemas de TEF**
   - Cliente relata que o pagamento não funciona
   - Suporte acessa a tela de diagnóstico
   - Verifica se a conexão atende aos requisitos mínimos

2. **Validação de Upload**
   - Verifica se a velocidade de upload é suficiente para envio de dados
   - Importante para funcionalidades que requerem upload (ex: envio de imagens)

3. **Troubleshooting de Rede**
   - Identifica problemas de conectividade
   - Fornece argumentos técnicos para o cliente
   - Ajuda a diferenciar problemas do sistema vs. problemas de infraestrutura

## 🚀 Como Usar

### Executar o Teste

1. Acesse a tela de diagnóstico (área restrita do aplicativo)
2. Verifique as informações de conexão exibidas
3. Clique em **"INICIAR TESTE"**
4. Aguarde a conclusão dos testes (Download → Upload → Latência)
5. Analise os resultados e a qualidade da conexão

## 📊 Interpretação dos Resultados

### Qualidade da Conexão

- **Excelente** (≥80%): Conexão ideal para todas as funcionalidades
- **Boa** (≥60%): Conexão adequada para operação normal
- **Regular** (≥40%): Pode apresentar problemas ocasionais
- **Ruim** (≥20%): Provavelmente causará problemas
- **Insuficiente** (<20%): Não adequada para operação

### Critérios de Avaliação

A qualidade é calculada com base em:

- **Download** (40 pontos): Mínimo 2 Mbps para TEF
- **Upload** (30 pontos): Mínimo 1 Mbps para upload de dados
- **Latência** (30 pontos): Crítico para TEF, ideal <100ms

## 🔒 Acesso Restrito

Esta funcionalidade está disponível apenas em uma **área de configurações com acesso restrito** do aplicativo principal, onde também é possível:

- Configurar TEF
- Configurar modo quiosque
- Outras configurações administrativas

## 📝 Notas Técnicas

- O teste utiliza a API Fast.com para medir velocidade
- A latência é medida através de ping para 8.8.8.8 (Google DNS)
- Os resultados são exibidos em tempo real durante a execução
- O teste pode ser cancelado a qualquer momento

## 🛠️ Desenvolvimento

### Pré-requisitos

- Flutter SDK 3.5.1 ou superior
- Dart SDK compatível

### Instalação

```bash
# Clone o repositório
git clone <repository-url>

# Entre no diretório
cd speed_test_poc_2

# Instale as dependências
flutter pub get

# Execute o código gerado do MobX
flutter pub run build_runner build --delete-conflicting-outputs

# Execute o aplicativo
flutter run
```

### Build

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 📄 Licença

Este projeto é uma prova de conceito desenvolvida para uso em sistemas de PDV e diagnóstico de rede.

## 👥 Contribuição

Este é um projeto de código aberto. Contribuições são bem-vindas!

---

**Versão**: 1.0.0  
**Última atualização**: 2025
