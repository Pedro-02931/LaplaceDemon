#!/bin/bash

# Carrega especificações do hardware Intel
load_intel_specs() {
    # --- CPU ---
    # TDP (Thermal Design Power) em Watts (ex: 15W, 28W)
    readonly MAX_TDP=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null | awk '{print $1/1000000}') || 15 # Fallback 15W
    
    # Frequências da GPU Integrada (ex: Intel UHD Graphics)
    readonly MAX_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_max_freq_mhz 2>/dev/null) || 900 # Fallback 900MHz
    readonly MIN_GPU_CLOCK=$(cat /sys/class/drm/card0/gt_min_freq_mhz 2>/dev/null) || 300
    
    # EPB (Energy Performance Bias) suportado
    readonly EPB_PERFORMANCE="00"   # Máximo desempenho
    readonly EPB_BALANCED="08"      # Balanceado
    readonly EPB_POWERSAVE="0F"     # Máxima economia
    
    # --- Sistema ---
    readonly CORES_TOTAL=$(nproc)   # Núcleos lógicos disponíveis
}

load_intel_specs # Executa ao iniciar o script