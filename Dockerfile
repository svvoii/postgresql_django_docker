FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
	build-essential \
	libpq-dev \
	&& rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip pipenv

COPY Pipfile ./
RUN pipenv install --system --skip-lock

COPY . .

RUN chmod +x /app/entrypoint.sh
