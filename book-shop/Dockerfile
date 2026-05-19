FROM python:3.11-slim

WORKDIR /app

ARG APP_ARTIFACT

COPY ${APP_ARTIFACT} /tmp/app.tar.gz

RUN tar -xzf /tmp/app.tar.gz -C /app --strip-components=1 \
    && rm /tmp/app.tar.gz \
    && pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

CMD ["sh", "-c", "python manage.py migrate && python manage.py collectstatic --noinput && python manage.py runserver 0.0.0.0:8000"]
