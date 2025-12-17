# Solução: Download Paralelo para Speed Test

## 📋 Resumo do Problema

O aplicativo estava apresentando resultados de download subestimados em conexões Wi-Fi/Dados Móveis (~20-25 Mbps) comparado ao Fast.com (70 Mbps) na mesma rede. O problema estava relacionado à falta de paralelismo na implementação da biblioteca `flutter_speed_test_plus`.

## 🔍 Análise da Causa Raiz

### Problemas Identificados

1. **Falta de Paralelismo**: A biblioteca `flutter_speed_test_plus` usa apenas uma única conexão TCP (`SpeedTestSocket.startDownloadRepeat`), o que não é suficiente para saturar a banda em conexões Wi-Fi com latência média/alta.

2. **Limitação do TCP Window Scaling**: Em uma única conexão, o TCP precisa escalar a janela de recepção gradualmente. Em Wi-Fi com latência, isso pode levar vários segundos, limitando o throughput inicial.

3. **Inclusão do Ramp-Up**: O cálculo da velocidade média incluía a fase inicial lenta (ramp-up), puxando a média para baixo.

4. **Falta de Filtro Estatístico**: Não havia remoção de outliers, resultando em medições menos precisas.

### Comparação com Metodologias de Referência

#### Fast.com (Netflix)
- ✅ Usa múltiplas conexões HTTPS paralelas
- ✅ Descarta fase de ramp-up
- ✅ Calcula média móvel (rolling average)
- ✅ Duração dinâmica até estabilização

#### Speedtest.net (Ookla)
- ✅ Usa até 4 threads HTTP para download
- ✅ Remove 2 amostras mais rápidas e 25% mais lentas
- ✅ Calcula média dos ~75% restantes
- ✅ Ajusta dinamicamente tamanho de chunk e buffer

## ✅ Solução Implementada

### Nova Implementação: `ParallelSpeedTestRepositoryImpl`

A solução implementa uma versão customizada que segue as melhores práticas das metodologias de referência:

#### 1. **Múltiplas Conexões Paralelas**
```dart
static const int _defaultParallelConnections = 4;
```
- Usa 4 conexões HTTP paralelas por padrão (padrão Speedtest.net)
- Cada conexão baixa dados simultaneamente
- Agrega o throughput de todas as conexões

#### 2. **Exclusão de Ramp-Up**
```dart
static const int _rampUpDurationSeconds = 2; // Descartar primeiros 2 segundos
```
- Ignora os primeiros 2 segundos de cada conexão
- Calcula velocidade apenas após estabilização inicial
- Evita que a fase lenta puxe a média para baixo

#### 3. **Filtro Estatístico**
```dart
static const double _outlierRemovalPercent = 0.25; // Remove 25% mais lentos
```
- Ordena amostras por velocidade
- Remove 25% das amostras mais lentas (outliers e ramp-up residual)
- Calcula média das amostras filtradas

#### 4. **Cálculo de Velocidade Agregada**
- Coleta amostras de todas as conexões paralelas
- Calcula velocidade agregada em tempo real
- Atualiza progresso durante o teste

### Estrutura da Implementação

```
ParallelSpeedTestRepositoryImpl
├── _selectServer()              # Seleciona servidor via Fast.com API
├── _testDownloadParallel()      # Teste de download com múltiplas conexões
│   ├── _startDownloadConnection() # Inicia cada conexão individual
│   └── _calculateCurrentSpeed()  # Calcula velocidade agregada
├── _calculateFinalSpeed()        # Aplica filtro estatístico
└── _testUpload()                 # Teste de upload (simplificado)
```

## 🔧 Como Usar

### Ativação da Nova Implementação

A nova implementação já está configurada no módulo. Para alternar entre implementações:

**Arquivo**: `lib/app/modules/speed_test/speed_test_module.dart`

```dart
// Nova implementação (paralela) - RECOMENDADO
i.addLazySingleton<ISpeedTestRepository>(ParallelSpeedTestRepositoryImpl.new);

// Implementação original (biblioteca)
// i.addLazySingleton<ISpeedTestRepository>(SpeedTestRepositoryImpl.new);
```

### Remoção do Multiplicador Artificial

A nova implementação **NÃO precisa** do multiplicador `downloadRateMultiplier = 2.5` que estava sendo usado como workaround. A velocidade é calculada corretamente através do paralelismo.

**Antes** (com workaround):
```dart
const double downloadRateMultiplier = 2.5;
downloadRate = download.transferRate * downloadRateMultiplier;
```

**Depois** (sem necessidade de multiplicador):
```dart
// A velocidade já é calculada corretamente
downloadRate = await _testDownloadParallel(...);
```

## 📊 Parâmetros Configuráveis

Os seguintes parâmetros podem ser ajustados conforme necessário:

```dart
static const int _defaultParallelConnections = 4;        // Número de conexões paralelas
static const int _rampUpDurationSeconds = 2;             // Tempo de ramp-up a descartar
static const int _minTestDurationSeconds = 5;             // Duração mínima do teste
static const int _maxTestDurationSeconds = 30;           // Duração máxima do teste
static const double _outlierRemovalPercent = 0.25;       // Percentual de outliers a remover
```

### Recomendações de Ajuste

- **Conexões Paralelas**: 
  - Wi-Fi: 4-6 conexões (padrão: 4)
  - Ethernet: 2-4 conexões (menor latência)
  - Dados Móveis: 4-8 conexões (maior latência)

- **Duração do Teste**:
  - Redes rápidas (>100 Mbps): 5-10 segundos
  - Redes médias (20-100 Mbps): 10-20 segundos
  - Redes lentas (<20 Mbps): 20-30 segundos

## 🧪 Testes e Validação

### Testes Recomendados

1. **Comparação com Fast.com**:
   - Execute teste na mesma rede Wi-Fi
   - Compare resultados (devem estar próximos)

2. **Teste em Diferentes Tipos de Conexão**:
   - Wi-Fi 2.4GHz
   - Wi-Fi 5GHz
   - Ethernet
   - Dados Móveis (4G/5G)

3. **Validação de Estabilidade**:
   - Execute múltiplos testes consecutivos
   - Verifique consistência dos resultados

### Métricas Esperadas

- **Precisão**: Resultados devem estar dentro de ±10% do Fast.com
- **Consistência**: Múltiplos testes devem variar menos de ±5%
- **Performance**: Teste deve completar em 5-30 segundos

## 📝 Notas Técnicas

### Dependências Adicionadas

```yaml
dependencies:
  http: ^1.2.2  # Para múltiplas conexões HTTP paralelas
```

### Compatibilidade

- ✅ Android
- ✅ iOS (requer testes)
- ✅ Web (requer testes)
- ✅ Desktop (requer testes)

### Limitações Conhecidas

1. **Upload**: A implementação de upload ainda é simplificada e pode ser melhorada no futuro
2. **Servidores**: Atualmente usa apenas Fast.com API. Pode ser expandido para suportar outros servidores
3. **Adaptação Dinâmica**: O número de conexões paralelas é fixo. Pode ser melhorado para adaptar-se dinamicamente à latência

## 🔄 Próximos Passos (Opcional)

1. **Upload Paralelo**: Implementar múltiplas conexões para upload também
2. **Adaptação Dinâmica**: Ajustar número de conexões baseado na latência medida
3. **Suporte a Múltiplos Servidores**: Permitir seleção de servidor ou fallback automático
4. **Otimização de Buffer**: Ajustar tamanho de buffer dinamicamente baseado na velocidade

## 📚 Referências

- [Fast.com Methodology](https://fast.com)
- [Speedtest.net Methodology](https://www.speedtest.net)
- [TCP Window Scaling](https://en.wikipedia.org/wiki/TCP_window_scale_option)
- [HTTP/2 Multiplexing](https://http2.github.io/)
