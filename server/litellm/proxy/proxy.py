from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import httpx
import json

app = FastAPI()

LITELLM_URL = "http://localhost:4000"
NUM_CTX = 49152
CHARS_PER_TOKEN = 4.9
OUTPUT_RESERVE_TOKENS = 8000
TOTAL_CHARS = NUM_CTX * CHARS_PER_TOKEN
OUTPUT_RESERVE_CHARS = OUTPUT_RESERVE_TOKENS * CHARS_PER_TOKEN


def strip_thinking(messages: list) -> list:
    """Убирает thinking_blocks из assistant сообщений — экономит ~30-50% размера"""
    result = []
    for msg in messages:
        if msg.get("role") == "assistant" and "thinking_blocks" in msg:
            msg = dict(msg)
            del msg["thinking_blocks"]
        result.append(msg)
    return result


def trim_messages(messages: list, budget_chars: int) -> tuple:
    """
    Режет только полные пары tool_call+tool_result с начала истории.
    Никогда не разрывает пару assistant(tool_calls) + следующие tool results.
    Всегда сохраняет первое сообщение (исходная задача).
    """
    if not messages:
        return messages, 0

    total = sum(len(json.dumps(m)) for m in messages)
    if total <= budget_chars:
        return messages, 0

    first = messages[0]
    rest = messages[1:]

    # Находим безопасные точки обрезки — только между парами
    i = 0
    while i < len(rest):
        candidate = [first] + rest[i:]
        if sum(len(json.dumps(m)) for m in candidate) <= budget_chars:
            return candidate, i

        msg = rest[i]
        if msg.get("role") == "assistant" and msg.get("tool_calls"):
            # Пропускаем всю пару: assistant + tool results
            i += 1
            while i < len(rest) and rest[i].get("role") == "tool":
                i += 1
        else:
            i += 1

    # Ничего не влезло — оставляем только первое + последние 2
    return [first] + rest[-2:], len(rest) - 2


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy(request: Request, path: str):
    body = await request.body()
    headers = dict(request.headers)
    headers.pop("host", None)
    headers.pop("transfer-encoding", None)

    if path.startswith("v1/messages") and body:
        try:
            data = json.loads(body)
            before = len(body)
            msg_count = len(data.get("messages", []))

            # 1. Убираем thinking_blocks
            if "messages" in data:
                data["messages"] = strip_thinking(data["messages"])

            # 2. Вычисляем бюджет
            sys_chars = len(json.dumps(data.get("system", "")))
            tools_chars = len(json.dumps(data.get("tools", [])))
            msg_budget = int(TOTAL_CHARS - sys_chars - tools_chars - OUTPUT_RESERVE_CHARS)
            msg_budget = max(msg_budget, 20_000)

            # 3. Режем messages сохраняя пары
            if "messages" in data:
                data["messages"], trimmed = trim_messages(data["messages"], msg_budget)
                if trimmed > 0:
                    print(f"[proxy] trimmed {trimmed} messages, kept {len(data['messages'])}/{msg_count}")

            body = json.dumps(data).encode()
            headers["content-length"] = str(len(body))
            print(f"[proxy] {before/1024:.1f}KB → {len(body)/1024:.1f}KB "
                  f"(sys={sys_chars/1024:.1f}KB tools={tools_chars/1024:.1f}KB "
                  f"budget={msg_budget/1024:.1f}KB)")

        except Exception as e:
            print(f"[proxy] Error: {e}")

    url = f"{LITELLM_URL}/{path}"
    if request.url.query:
        url += f"?{request.url.query}"

    async with httpx.AsyncClient(timeout=600) as client:
        req = client.build_request(
            method=request.method,
            url=url,
            headers=headers,
            content=body,
        )
        try:
            response = await client.send(req, stream=True)
            return StreamingResponse(
                response.aiter_bytes(),
                status_code=response.status_code,
                headers=dict(response.headers),
            )
        except (httpx.ReadError, httpx.RemoteProtocolError):
            pass