
---

### 1. **Diagrama de Fluxo Principal**  
```mermaid
flowchart TD
    A[Início] --> B[Verifica Root]
    B --> C{É root?}
    C --> |Sim| D[Carrega Logs/Variáveis]
    C --> |Não| E[Erro: Sai do Script]
    D --> F[Instala Dependências]
    F --> G[Habilita Serviços]
    G --> H[Monitoramento Contínuo]
    H --> I{Precisa Mudar Perfil?}
    I --> |Sim| J[Aplica Perfil Holístico]
    I --> |Não| H
    J --> H
```

**Explicação Humana:**  
O script começa verificando se está rodando como root. Se sim, instala dependências, liga serviços como TLP e thermald, e entra num loop infinito de monitoramento. A cada 30s, decide se precisa mudar o perfil de energia com base no uso do sistema.

---

### 2. **Estrutura dos Perfis Holísticos**  
```mermaid
flowchart LR
    A[Chave do Perfil] --> B((Ex: 050))
    B --> C[CPU Governor]
    B --> D[GPU Perf]
    B --> E[ZRAM%]
    B --> F[Swappiness]
    B --> G[...+12 parâmetros]
```

**Explicação Humana:**  
Cada perfil (como "050") é uma combinação pré-definida de configurações que afetam CPU, GPU, memória, etc. É uma "receita de bolo" para balancear desempenho e energia.

---

### 3. **Funções Nucleares**  
```mermaid
flowchart LR
    A[Funções] --> B[governor_apply]
    A --> C[gpu_dpm]
    A --> D[zram_opt]
    A --> E[energy_opt]
    A --> F[ajustar_swappiness]
    
    B --> G["/sys/.../cpufreq"]
    C --> H["/sys/class/drm/card0/device"]
    D --> I["/dev/zram0,1,2..."]
    E --> J["MSR/Registros da CPU"]
    F --> K["/proc/sys/vm/swappiness"]

```

**Explicação Humana:**  
Cada função mexe em um subsistema diferente do Linux. Por exemplo, `governor_apply` altera governadores da CPU escrevendo em `/sys`, enquanto `zram_opt` cria dispositivos de swap na RAM.

---

### 4. **Máquina Bayesiana (faz_o_urro)**  
```mermaid
flowchart TD
    A[Métricas do Sistema] --> B[Histórico FIFO]
    B --> C[Cálculo da Média]
    C --> D{Usuário está dentro da\njanela de tolerância?}
    D --> |Sim| E[Não faz nada]
    D --> |Não| F[Colapsa para novo perfil]
```

**Explicação Humana:**  
O script guarda um histórico das últimas medições de uso da CPU. Se o uso atual fugir da média (ex: ±5%), ele muda de perfil. É um "filtro" para evitar mudanças bruscas por oscilações momentâneas.

---

### 5. **Sistema de Logs e Erros**  
```mermaid
flowchart LR
    A[Evento] --> B{É repetido?}
    B --> |Sim| C[Ignora]
    B --> |Não| D[Registra no Log]
    D --> E[INFO/WARN/ERROR]
    E --> F[Notificação Desktop]
```

**Explicação Humana:**  
O log evita spam repetindo a mesma mensagem. Erros graves (como falta de permissão) disparam notificações no desktop (se disponível).

---

### 6. **Gerenciador de Dependências**  
```mermaid
flowchart TD
    A[Verifica Pacote] --> B{Está instalado?}
    B --> |Sim| C[Segue em frente]
    B --> |Não| D[Tenta Instalar]
    D --> E{Conseguiu?}
    E --> |Sim| C
    E --> |Não| F[Erro: Aborta]
```

**Explicação Humana:**  
O script checa se ferramentas como `tlp` ou `lm-sensors` estão instaladas. Se faltar algo, tenta instalar via `apt-get`. Se falhar, o script morre.

---

### 7. **Visão Geral do Motor de Decisão**  
```mermaid
flowchart TD
    A[Loop Infinito] --> B[Mede Uso da CPU]
    B --> C[Compara com Perfis]
    C --> D{Aplicação Necessária?}
    D --> |Sim| E[Modifica Sistema]
    D --> |Não| F[Espera 30s]
    E --> F
    F --> A
```

**Explicação Humana:**  
O coração do script é um loop que verifica constantemente se o sistema está dentro dos parâmetros desejados. Se não estiver, dispara as mudanças necessárias.
---
Para verificar se o serviço e o timer estão rodando e aplicando as configurações corretamente, siga os passos abaixo:

---

### **1. Verifique o status do timer**
Use o comando abaixo para verificar se o timer está ativo e funcionando:

```bash
systemctl status urro.timer
```

- Se o timer estiver ativo, você verá algo como:
  ```
  ● urro.timer - URRO Timer (cada 5 segundos)
     Loaded: loaded (/etc/systemd/system/urro.timer; enabled; vendor preset: enabled)
     Active: active (waiting) since Fri 2025-04-25 14:30:00 UTC; 10s ago
     Trigger: Fri 2025-04-25 14:30:05 UTC; 5s left
  ```

---

### **2. Verifique o status do serviço**
O serviço `urro.service` é executado pelo timer. Para verificar se ele está sendo acionado corretamente, use:

```bash
systemctl status urro.service
```

- Se o serviço estiver sendo executado periodicamente, você verá algo como:
  ```
  ● urro.service - URRO Engine - Motor de cruzamento bayesiano
     Loaded: loaded (/etc/systemd/system/urro.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Fri 2025-04-25 14:30:05 UTC; 5s ago
     TriggeredBy: urro.timer
  ```

---

### **3. Verifique os logs do serviço**
Os logs do serviço podem ser visualizados com o comando:

```bash
journalctl -u urro.service
```

- Isso mostrará as mensagens geradas pelo script `urro_engine.sh`. Por exemplo:
  ```
  Apr 25 14:30:00 hostname urro_engine.sh[12345]: 🔁 Fri Apr 25 14:30:00 2025 :: Média CPU: 35% | Perfil: 040
  Apr 25 14:30:00 hostname urro_engine.sh[12345]: → Governor: ondemand | TDP: 15 | Alg ZRAM: zstd | Streams: 2 | Swappiness: 10
  ```

---

### **4. Verifique as configurações aplicadas**
Você pode verificar manualmente se as configurações foram aplicadas corretamente:

- **Governor da CPU**:
  ```bash
  cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  ```

- **TDP**:
  ```bash
  cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw
  ```

- **Algoritmo do ZRAM**:
  ```bash
  cat /sys/block/zram*/comp_algorithm
  ```

- **Swappiness**:
  ```bash
  cat /proc/sys/vm/swappiness
  ```

---

### **5. Teste manual do script**
Se quiser testar o script manualmente para verificar se ele aplica as configurações, execute o seguinte comando:

```bash
sudo /opt/urro/urro_engine.sh
```

Isso executará o script diretamente e aplicará as configurações. Você verá as mensagens no terminal, como:

```
🔁 Fri Apr 25 14:30:00 2025 :: Média CPU: 35% | Perfil: 040
→ Governor: ondemand | TDP: 15 | Alg ZRAM: zstd | Streams: 2 | Swappiness: 10
```

---

### **6. Verifique o comportamento do sistema**
Observe se as configurações estão sendo aplicadas corretamente:
- A frequência da CPU deve mudar de acordo com o governor configurado.
- O algoritmo de compressão do ZRAM deve ser atualizado.
- O valor de swappiness deve refletir o configurado.

---

Se algo não estiver funcionando como esperado, você pode verificar os logs do sistema para identificar possíveis erros:

```bash
journalctl -xe
```
