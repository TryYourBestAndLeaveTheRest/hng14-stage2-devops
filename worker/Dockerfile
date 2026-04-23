FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY worker/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY worker/worker.py /app/worker.py

USER app

HEALTHCHECK --interval=15s --timeout=3s --retries=5 \
  CMD python -c "import os, redis; r=redis.Redis(host=os.getenv('REDIS_HOST','redis'), port=int(os.getenv('REDIS_PORT','6379')), db=int(os.getenv('REDIS_DB','0')), password=os.getenv('REDIS_PASSWORD')); r.ping()"

CMD ["python", "worker.py"]
