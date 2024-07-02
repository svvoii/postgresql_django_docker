FROM python:3.10-slim-buster

# Set the working directory in the container
WORKDIR /usr/src/app


# env variables:

# Prevents Python from writing pyc files to disc (equivalent to python -B option)
ENV PYTHONUNBUFFERED 1
# Prevents Python from buffering stdout and stderr (equivalent to python -u option)
ENV PYTHONDONTWRITEBYTECODE 1


# Install psycopg2 dependencies
RUN apt-get update && apt-get install -y \
	build-essential \
	libpq-dev \
	&& rm -rf /var/lib/apt/lists/*


# Install system dependencies
RUN pip install --upgrade pip pipenv flake8
COPY Pipfile* ./
RUN pipenv install --system --ignore-pipfile


# Copy the current directory contents into the container at the working directory
COPY . .

# lint
RUN flake8 --ignore=E501,F401 .
