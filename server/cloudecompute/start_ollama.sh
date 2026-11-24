

apt install lshw
# Проверяем, установлена ли ollama
command -v ollama >/dev/null || curl -fsSL https://ollama.com/install.sh | sh
OLLAMA_HOST=0.0.0.0:6006 OLLAMA_NUM_CTX=262144 OLLAMA_KEEP_ALIVE=-1 OLLAMA_DEBUG=1 ollama serve &

OLLAMA_HOST=0.0.0.0:6006 ollama show unsloth/GLM-5.3-GGUF:UD-IQ1_S --modelfile > ./Modelfile
echo "PARAMETER num_ctx 262144" >> ./Modelfile
OLLAMA_HOST=0.0.0.0:6006 ollama create unsloth/GLM-5.3-GGUF:UD-IQ1_S -f ./Modelfile

#curl http://76.69.188.175:21074/api/generate -d '{
#  "model": "qwen3.6:35b-a3b-q4_K_M",
#  "keep_alive": 0
#}'

#curl http://76.69.188.175:21074/api/generate -d '{
#  "model": "qwen3.6:35b-a3b-q4_K_M",
#  "prompt": "",
#  "keep_alive": -1,
#  "options": {
#    "num_ctx": 49152
#  }
#}'
