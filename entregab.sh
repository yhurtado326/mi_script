#!/usr/bin/env bash

# Autolimpieza (ejecutar luego de la clonacióm)
# sed -i 's/\r$//' entregab.sh

RUTA_REPORTE=""

function bienvenida() {
  echo "====================================================="
  echo "            BIENVENIDO ESTIMADO USUARIO              "
  echo "====================================================="
  echo ""
}

function verificar_sistema() {
  echo "🔍 Verificando sistema operativo..."
  OS=$(uname -s)
  echo "✅ Sistema detectado: $OS"
}

function verificar_nmap() {
  if ! command -v nmap &> /dev/null; then
    echo "📦 Nmap no está instalado. Instalando..."
    if [[ "$OS" == "Linux" ]]; then
      if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y nmap whois dnsutils cron
        sudo systemctl enable --now cron
      elif [ -f /etc/redhat-release ]; then
        sudo dnf install -y nmap whois bind-utils cronie
        sudo systemctl enable --now crond
      fi
    elif [[ "$OS" == "Darwin" ]]; then
      brew install nmap whois bind cron
    else
      echo "❌ No se pudo instalar Nmap automáticamente. Instálalo manualmente."
      exit 1
    fi
    echo "✅ Herramientas instaladas con éxito."
  else
    echo "✅ Nmap ya está instalado."
  fi
}

function leer_objetivo() {
  read -p "🧭 Ingrese la IP a escanear: " OBJETIVO
}

function definir_archivo() {
  local tipo=$1
  mkdir -p "$RUTA_REPORTE"
  echo "$RUTA_REPORTE/${tipo}_${OBJETIVO}_$(date +%Y%m%d_%H%M%S).txt"
}

# 1. ESCANEAR PUERTOS
function escanear_puertos() {
  leer_objetivo
    if [[ -n "$OBJETIVO" ]]; then
    echo "🛠️ Escaneando todos los puertos del 1 al 1024 en $OBJETIVO..."
    if [ -n "$RUTA_REPORTE" ]; then
      archivo=$(definir_archivo "puertos")
      nmap --stats-every 5s -p1-1024 "$OBJETIVO" | tee "$archivo"
    else
      nmap --stats-every 5s -p1-1024 "$OBJETIVO"
    fi
  fi
}

# 2. ESCANEAR EQUIPOS
function escanear_equipos_red() {
  read -p "🌐 Ingrese la dirección de red para escanear los equipos: " RED
  if [[ -n "$RED" ]]; then
    echo "📡 Escaneando equipos en la red $RED..."
    if [ -n "$RUTA_REPORTE" ]; then
      archivo=$(definir_archivo "equipos_red")
      nmap --stats-every 5s -sn "$RED" | tee "$archivo"
    else
      nmap --stats-every 5s -sn "$RED"
    fi
  fi
}

# 3. ESCANEAR S.O
function escanear_so_icmp() {
  leer_objetivo
  if [[ -n "$OBJETIVO" ]]; then
    echo "🔍 Detectando sistema operativo de $OBJETIVO basado en TTL ..."

    local ttl_valor
    ttl_valor=$(ping -c 3 "$OBJETIVO" \
      | grep -oE 'ttl=[0-9]+' \
      | head -n1 \
      | cut -d'=' -f2)
      
    if [[ -n "$ttl_valor" ]]; then
      if (( ttl_valor > 100 )); then
        echo "💡 Posiblemente Windows."
        [[ -n "$RUTA_REPORTE" ]] && echo "Posiblemente Windows." >> "$(definir_archivo "so_icmp")"
      elif (( ttl_valor < 70 )); then
        echo "🐧 Posiblemente Linux."
        [[ -n "$RUTA_REPORTE" ]] && echo "Posiblemente Linux." >> "$(definir_archivo "so_icmp")"
      fi
    else
      echo "❌ No se pudo obtener el TTL para $OBJETIVO."
    fi
  fi   
}

# 4. REALIZAR DOS
function realizar_dos() {
  leer_objetivo
  if [[ -n "$OBJETIVO" ]]; then
    read -p "🔢 Ingrese el número total de peticiones ICMP a enviar: " NUM_PETICIONES
    if [[ -n "$NUM_PETICIONES" ]] && [[ "$NUM_PETICIONES" -gt 0 ]]; then
      echo "💥 Realizando un ataque DoS simulado con $NUM_PETICIONES peticiones ICMP de 10 en 10 a $OBJETIVO (¡CUIDADO! Use con responsabilidad)."
      for ((i=1; i<=$NUM_PETICIONES; i+=10)); do
        ping -c 10 "$OBJETIVO" &
        sleep 0.1 #Esperar un poco para no saturar demasiado
      done
      wait # Esperar a que terminen todos los procesos de ping en segundo plano
      echo "✅ Envío de $NUM_PETICIONES peticiones ICMP completado."
      if [ -n "$RUTA_REPORTE" ]; then
        echo "Realización de ataque DoS simulado con $NUM_PETICIONES peticiones ICMP de 10 en 10 a $OBJETIVO completado." >> "$(definir_archivo "dos"))"
      fi
    else
      echo "❌ Número de peticiones no válido."
    fi
  fi
}

# 5. VERIFICAR IP
function verificar_ip() {
  read -p "🌐 Ingrese el dominio para verificar su IP: " DOMINIO
  if [[ -n "$DOMINIO" ]]; then
    echo "🔍 Obteniendo la IP de $DOMINIO..."
    IP=$(dig +short A "$DOMINIO" 2>/dev/null)
    if [[ -n "$IP" ]]; then
      echo "✅ La IP de $DOMINIO es: $IP"
      if [ -n "$RUTA_REPORTE" ]; then
        echo "La IP de $DOMINIO es: $IP" >> "$(definir_archivo "verificar_ip"))"
      fi
    else
      echo "❌ No se pudo obtener la IP del dominio."
    fi
  fi
}

# 6. SALIR

function mostrar_menu() {
  echo ""
  echo "====================================================="
  echo "            EL MENÙ DEGUSTACIÓN DE IPs               "
  echo "====================================================="
  echo "1. Escanear Puertos"
  echo "2. Escanear Equipos en Red"
  echo "3. Escanear S.O"
  echo "4. Realizar DOS"
  echo "5. Verificar IP de Dominio"
  echo "6. Salir"
  echo ""
}

# -------------------------------
# EJECUCIÓN PRINCIPAL DEL SCRIPT
# -------------------------------

clear
bienvenida
verificar_sistema
verificar_nmap

while true; do
  mostrar_menu
  read -p "Seleccione una opción [1-6]: " OPCION
  case $OPCION in
    1) escanear_puertos ;;
    2) escanear_equipos_red ;;
    3) escanear_so_icmp ;;
    4) realizar_dos ;;
    5) verificar_ip ;;
    6) echo "👋 ¡Gracias!"; exit 0 ;;
    *) echo "❌ Opción no válida. Intente de nuevo." ;;
  esac
  echo ""
  read -p "Presione Enter para continuar..." dummy
  clear
done
