# SETUP POSTGRESQL DATABASE FOR DJANGO WITH DOCKER

Steps to install `pip`, `pipenv`:

```bash
sudo apt update
sudo apt install python3-pip
python3 -m pip install --upgrade pip
pip install pipenv
```

*Check the installation:*

```bash
pip --version
pipenv --version
```

*if `not found` error occurs, add `pip` `pipenv` to the PATH:*

```bash
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc
```
*and restart the terminal.*

*If still not working, add the export statement to the `.bashrc` file.*

```bash
vim ~/.bashrc
```
*Add the `export PATH="$HOME/.local/bin:$PATH"` to the end of the file. And save, exit. `source ~/.bashrc` again and restart the terminal.*  


## 1. In the root directory of the project, activating virtual environment with pipenv:

```bash
pipenv shell
```

## 2. Installing Django:

```bash
pipenv install django
```
## 3. Creating new Django project:

**NOTE:** *NO NEED TO CREATE A NEW PROJECT IF `_config` DIRECTORY ALREADY EXISTS. !!!*

```bash
django-admin startproject _config .
```

## 4. Creating `.env` file in the root directory of the project:

*In the `.env` file, adding the following lines:*

```txt
DEBUG=True
SECRET_KEY='your_secret_key'
ALLOWED_HOSTS=*
```

## 5. Installing the package to manage environment variables:

```bash
pipenv install django-environ
```

## 6. In the `_config/settings.py` file, adding the following lines to read the environment variables:

```python
import environ

env = environ.Env(
	DEBUG=(bool, False)
)
# reading .env file
environ.Env.read_env()

# changing the following 

# SECRET_KEY = 'your_secret_key'
SECRET_KEY = env('SECRET_KEY')

# DEBUG = True
DEBUG = env('DEBUG')

# ALLOWED_HOSTS = ['*']
ALLOWED_HOSTS = env.list('ALLOWED_HOSTS')
...
```

## 7. Crafting custom Docker image for Django and PostgreSQL:

*Creating `Dockerfile` in the root directory of the project:*

```Dockerfile
FROM python:3.10-slim-buster

WORKDIR /usr/src/app

# env variables:
ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1


# Install system dependencies
RUN pip install --upgrade pip pipenv flake8
COPY Pipfile Pipfile.lock ./
RUN pipenv install --system --ignore-pipfile

# Copy the current directory contents into the container at the working directory
COPY . .

# lint
RUN flake8 --ignore=E501,F401 .

```

## 8. Creating `docker-compose.yml` file in the root directory of the project:

```yml
version: '3.7'

services:
  web:
    build: 
      context: .
    command: >
      sh -c "python manage.py runserver 0.0.0.0:8000"
    ports:
      - "8000:8000"
    env_file: .env
    volumes:
      - .:/usr/src/app

```

## 9. Running the following command to build the Docker image and start the container to check if everything is working:

```bash
docker-compose up --build
```
**Note:** *If any error occurs, fix it and run the command again.*  
*First time I had to fix tabs in the settings.py file (change tabs to 4 spaces in VSCode).*  
*There might be also a clash of the Python version in the Dockerfile and the Pipfile.*  

- To update the Pipfile.lock if any changes are made to the Pipfile, run the following : `pipenv lock` before running the `docker-compose up --build` command.  

- To stop the container, press `Ctrl + C`.
- To check all the containers, run the following : `docker ps -a`.
- To remove the container, run the following : `docker-compose down`.  
- To check the available images run the following : `docker images`.  
- To remove the image, run the following : `docker rmi <image_id>`.    


## 10. Installing dependencies for PostgreSQL:

```bash
pipenv install psycopg2
```

**Note:** *THIS PRODUCES ERRORS ON SCHOOL'S DUMPS... Likely related to the dependencies for `psycopg2` which had to be installed with `sudo` access.. Looking for solution..*

*So, solution is to install the dependencies for `psycopg2` with `sudo` access:*

```bash
sudo apt update
sudo apt install python3-dev libpq-dev
```
*Then, `pipenv install psycopg2`. This should work fine.*  

*However, this is not the solution for the school's dumps...*  


## 11. Adding the following lines to the `Dockerfile` to install PostgreSQL dependencies:

```Dockerfile
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
```


## 12. Adding the following lines to the `docker-compose.yml` file to include PostgreSQL service:

```yml
services:
  db:
    image: postgres:13.3
    volumes:
      - postgres_data:/var/lib/postgresql/data/
      env_file: .env
  web:
    build: 
      context: .
    command: >
      sh -c "python manage.py migrate &&
              python manage.py runserver 0.0.0.0:8000"
    ports:
      - "8000:8000"
    env_file: .env
    volumes:
      - .:/usr/src/app

volumes:
  postgres_data:

```


## 13. Adding the following lines to the `settings.py` file to configure the database:

```python
...
DATABASES = {
	'default': env.db()
}
...
```

**Note:** *At this point the setup should be working fine for the local development environment.*  
**THIS DOES NOT WORK FOR SCHOOL'S DUMPS...**  


