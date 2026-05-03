#!/bin/bash

# --- НАСТРОЙКИ ---
VPS_USER="user"
#VPS_IP="195.208.16.1"
#VPS_PORT="43878"
VPS_IP="195.208.16.1"
VPS_PORT="43526"
LOCAL_PORT="4000"
#REMOTE_PORT="4000"
REMOTE_PORT="11434"
MODEL_NAME="ollama/qwen2.5-coder:7b" # Если используете LiteLLM

# --- ЗАПУСК ТУННЕЛЯ ---
echo "Opening SSH tunnel to $VPS_IP on port $VPS_PORT..."

# Запускаем туннель и сохраняем его PID
# -f (фон), -N (без команд), -L (проброс порта)
ssh -p "$VPS_PORT" -f -N -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} \
    -o StrictHostKeyChecking=no \
    -o ExitOnForwardFailure=yes \
    ${VPS_USER}@${VPS_IP}

# Даем секунду на установку соединения
sleep 1

# Ищем PID процесса ssh, который держит этот конкретный порт
SSH_PID=$(pgrep -f "ssh.*-L ${LOCAL_PORT}:localhost:${REMOTE_PORT}")

if [ -n "$SSH_PID" ]; then
    echo "Tunnel established (PID: $SSH_PID)."
else
    echo "ERROR: Failed to open tunnel. Check if port $LOCAL_PORT is already in use."
    exit 1
fi

# 1. Указываем роутеру, где искать вашу модель (наш туннель)
#export OPENAI_API_BASE="http://localhost:${LOCAL_PORT}"
#export OPENAI_API_KEY="not-needed"
#export CLAUDE_CODE_ROUTER_CONFIG_PATH="./claude-code-router-config.json"

# 2. Запускаем роутер в фоновом режиме на порту 3456 (дефолт для CCR)
# Если CCR еще не установлен: npm install -g @musistudio/claude-code-router
#ccr start &
#CCR_PID=$!

# Даем роутеру время на инициализацию
sleep 200000000

# --- ОКРУЖЕНИЕ И ЗАПУСК ---
#export ANTHROPIC_BASE_URL="http://localhost:3456"
#export ANTHROPIC_API_KEY="local-mode"
#export CLAUDE_CODE_USE_KEY_FROM_ENV=true
#
#echo "Starting Claude CLI..."
#CLAUDE_CONFIG_DIR=~/ollama/.claude-config claude

# --- ЗАВЕРШЕНИЕ ---
echo "Closing tunnel (PID: $SSH_PID)..."
kill "$SSH_PID"
echo "Done."