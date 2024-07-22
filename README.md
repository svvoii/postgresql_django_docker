# ***SETUP POSTGRESQL DATABASE FOR DJANGO WITH DOCKER***

This is a guide on how to setup PostgreSQL database for Django project using Docker.  
In this guide I use `pipenv` to manage the virtual environment for the Django project.  

Steps to install `pip`, `pipenv`:

## 0. **PREREQUISITES:**  

*Skip if `pip` and `pipenv` are already installed. Check with `pip --version` and `pipenv --version`.*  

*Ubuntu:*  

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


## 1. **ACTIVATING VIRTUAL ENVIRONMENT**

*In the root directory of the project, activating virtual environment with pipenv:*

```bash
pipenv shell
```

*Do `pipenv --venv` to check if the virtual environment is activated. It will show the path to the virtual environment.*  
*`deactivate` to deactivate the virtual environment.*  
*`pipenv --rm` to remove the virtual environment.*  
*`pipenv --clear` to clear the cache.*  

**NOTE:** *Created virtual environments with `pipenv` are stored in the `~/.local/share/virtualenvs` directory.*  


## 2. **INSTALLING DJANGO**  

*To install Django:*  
```bash
pipenv install django
```

*To create a new Django project:*  
```bash
django-admin startproject _my_project
```


## 3. **MANAGING ENVIRONMENT VARIABLES**  

*Installing the package to manage environment variables and creating `.env` file:*


*To install the package `django-environ` to manage environment variables:*  

```bash
pipenv install django-environ
```

*Creating `.env` file in the root directory of the project:*

*In the `.env` file, adding the following lines:*

```txt
# python:
PYTHONUNBUFFERED=1 # Prevents Python from writing pyc files to disc (equivalent to python -B option)
PYTHONDONTWRITEBYTECODE=1 # Prevents Python from buffering stdout and stderr (equivalent to python -u option)

# django:
DEBUG=True
SECRET_KEY='some_secret_words'
ALLOWED_HOSTS=*

# for PostgreSQL as well as Django in separate docker containers:
DATABASE_URL=postgres://postgres:postgres@db:5432/postgres

POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
```


## 4. **POSTGRESQL DEPENDENCIES**  

*Django requires specific adapter `psycopg2` to connect to PostgreSQL database.*

**NOTE 1:** *This wont work for the school's dumps with no sudo access... For solution go to NOTE 2 bellow.*    

*Before installing `psycopg2` on Linux, the following dependencies should be available `libpq-dev`:*  

```bash
sudo apt update
sudo apt install python3-dev libpq-dev
```

*On MacOS, simply install the `postgresql` with brew before installing `psycopg2`.*  

```bash
brew update
brew install postgresql
```

*Then, install `psycopg2` with pipenv:*  

```bash
pipenv install psycopg2
```

**THIS PRODUCES ERRORS ON SCHOOL'S DUMPS. This is related to the system dependencies for `psycopg2` which had to be installed with `sudo` access..**   


**NOTE 2:** *One solution is to install the `psycopg2-binary` instead:*

*If you are on the school's dump:*

```bash
pipenv install psycopg2-binary
```

**NOTE THAT INSIDE THE DOCKER CONTAINER WE CAN INSTALL PROPER DEPENDENCIES AND USE `psycopg2`, which is recommended.**

*So, we modify `Pipefile` to include `psycopg2` instead of `psycopg2-binary`:*
*In the `Pipfile` file, changing one line with `psycopg2` instead of `psycopg2-binary:*  

*Contents of the `Pipfile` file:*  

```Pipfile
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]
django = "*"
django-environ = "*"
psycopg2 = "*"

[dev-packages]

[requires]
python_version = "3.10"

```  


## 5. **SETTING UP DJANGO PROJECT**  

*In `_my_project/_my_project/settitng.py` adding the following lines to read the environment variables:*  

```python
import environ

env = environ.Env(
	DEBUG=(bool, False)
)

environ.Env.read_env() # reading .env file

# changing the following:

SECRET_KEY = env('SECRET_KEY')

DEBUG = env('DEBUG')

ALLOWED_HOSTS = env.list('ALLOWED_HOSTS')
...
...
DATABASES = {
	'default': env.db()
}
...
```


## 6. **DOCKERIZING DJANGO PROJECT**  

*Creating `Dockerfile` in the root directory of the project:*

```Dockerfile
FROM python:3.12-slim

# Seting working directory in the container:
WORKDIR /app

# Installing dependencies for psycopg2:
RUN apt-get update && apt-get install -y \
	build-essential \
	libpq-dev \
	&& rm -rf /var/lib/apt/lists/*

# Installing dependencies for the project:
RUN pip install --upgrade pip pipenv
COPY Pipfile ./
RUN pipenv install --system --skip-lock

# Copy the current directory contents into the working directory:
COPY . .
RUN chmod +x /app/entrypoint.sh

```


## 7. **SETTING UP THE ENTRYPOINT**  

*In the root directory of the project, creating `entrypoint.sh` file:*

```bash
#!/bin/bash

python _my_project/manage.py migrate
python _my_project/manage.py runserver 0.0.0.0:8000
```

**NOTE:** *Since we share the volume with the container, the changes made in the local files will be reflected in the container. Even though we use `RUN chmod +x /app/entrypoint.sh` in the `Dockerfile`, there might still be an error running container: `permission denied`. This is because the file is created on the local machine and updated in the container once we mount the volume in the `docker-compose.yml` file.*  

*To fix this, we use `#!/bin/bash` in the `entrypoint.sh` file and run `/bin/bash "/app/entrypoint.sh"` in the `docker-compose.yml` file. (`#!/bin/sh` might not work for that matter)*  

*The script will run the Django project. It can be modified as needed later on.*  


## 8. **DOCKER COMPOSE**

*Adding `docker-compose.yml` file in the root directory of the project:*  

```yml
services:

  web:
    build:
      context: .
    container_name: web-app
    command: /bin/bash "/app/entrypoint.sh"
    env_file: .env
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    
  db:
    image: postgres:latest
    container_name: db-app
    env_file: .env
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data/

volumes:
  postgres_data:

```


## 9. **BUILDING AND RUNNING THE DOCKER CONTAINERS**  

*Running the following commands to build the Docker images and start the containers.*

```bash
docker-compose build
```
*This will build the custom Docker image.*

```bash
docker-compose up
```
*This will start the containers and run the Django project.*  

*Check the `localhost:8000` in the browser to see if the Django project is running.*  

- `Ctrl + C` - to stop the containers.
- `docker ps -a` - to check all available containers.
- `docker-compose down` - to remove the containers.  
- `docker images` - to check the available images (and their IDs).  
- `docker rmi <image_id>` - to remove the image.    


**NOTE:** *At this point the setup should be working fine with Django project in a docker container.*  


## 10. **SETTING UP CLOUD BASED POSTGRESQL DATABASE**  

**NOTE:** *This will show an example of how to setup cloud based postgresql.*
*Skip if you want to use the DB in the separate container.*  

*All that needed is to remove the `db` service from `docker-compose.yml` file and add proper credentials to the `.env` file.*  

*- **This is how the `docker-compose.yml` file might look like:***

```yml
services:

  web:
    build:
      context: .
    container_name: web-app
    command: /bin/bash "/app/entrypoint.sh"
    env_file: .env
    ports:
      - "8000:8000"
    volumes:
      - .:/app

```

*- **This is how the `.env` file might look like:***

```txt
# python:
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1

# django:
DEBUG=True
SECRET_KEY='some_secret_words'
ALLOWED_HOSTS=*

# for PostgreSQL db in the cloud (AWS, neon):
DATABASE_URL=postgres://$PGUSER:$PGPASSWORD@$PGHOST:5432/$PGDATABASE?sslmode=require

PGHOST='find it on your neon project dashboard'
PGDATABASE='find it on your neon project dashboard'
PGUSER='find it on your neon project dashboard'
PGPASSWORD='find it on your neon project dashboard'
PGENDPOINTID='this is your neon project ID'
```

**NOTE:** *In this example we use cloud based service offered by [neon](https://console.neon.tech/) which povides the database we need for this project.*  
- Why ? - *It is free for basic use, super easy to setup adatabase, relatively easy to setup connection for our Django project.*

*More info about database connection issues [here](https://neon.tech/docs/connect/connection-errors), if needed.*

*- **This is how the `settings.py` file might look like:***

```python
...
DATABASES = {
	# for using cloud based postgresql database:
	'default': {
		'ENGINE': 'django.db.backends.postgresql',
		'NAME': env('PGDATABASE'),
		'USER': env('PGUSER'),
		'PASSWORD': env('PGPASSWORD'),
		'HOST': env('PGHOST'),
		'PORT': env('PGPORT', default=5432),
		'OPTIONS': {
			'sslmode': 'require',
			# 'options': f'endpoint={env("PGENDPOINTID")}'
		},
	}
}
...
```

***This shall allow the Django project to connect to the PostgreSQL database in the cloud.***  


# CUSTOMIZATION OF THE WORKFLOW

***So, examples above cover the basic setup of the Django project in two scenarios:***  
1. With both the PostgreSQL database and Django project in separate Docker containers.    
2. With PostgreSQL database in the cloud (example of neon service) which works on both ocasions:  
  *- when the Django project is run in the separate Docker container.*  
  *- when the Django project is run on the local machine.*  

***This can be applied to a variety of projects requirements and customized as needed.***  

***Moving forward, lets see how to customize the workflow in a way where we can run the Django project on the local machine and connect to the PostgreSQL database in a Docker container.***  

*For that to happen we would need to connect to the Docker container from the local machine. So, we need to specify the port in the `docker-compose.yml` file. As well as modify a bit the `DATABASE_URL` in the `.env` file.*  


## 11. **DJANGO ON LOCAL MACHINE AND POSTGRESQL IN A CONTAINER**  

*Running the PostgreSQL database in a Docker container and connecting to it from the local machine.*  


**- *Modifying `.env` file:***  

```txt
...
# for PostgreSQL in a docker container and django locally:
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres

POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
```
*Here we are changing the `db` service name to `localhost`*


**- *Modifying `settings.py` file:***  

```python
...
DATABASES = {
	'default': env.db()
}
...
```


**- *Modifying `docker-compose.yml` file:***  

*In the `docker-compose.yml` file adding the port to the `db` service:*  

```yml
services:

  web:
    build:
      context: .
    container_name: web-app
    command: /bin/bash "/app/entrypoint.sh"
    env_file: .env
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    
  db:
    image: postgres:latest
    env_file: .env
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data/

volumes:
  postgres_data:

```

*Here we are adding the port `5432:5432` to the `db` service.*


***Once the changes are made, we can start the `db` service only:***  

```bash
docker-compose up -d db
```

*Then navigate the the directory with `manage.py` and run the server:*

```bash
python manage.py runserver
```

**That should be it for the setup.**  


# BONUS

## 12. **MAKEFILE**   

**Adding `Makefile` to make life easier with `docker` and `docker-compose` commands.**

*I usually use `Makefile` to run the `docker-compose` commands. It is a simple way to run the commands with just one word. Especially in the beginning when the commands are run often.*  

*it also helps to visualize the commands and the workflow.*  

*Creating `Makefile` in the root directory of the project (same level with `Dockerfile` and `docker-compose.yml`):*

```Makefile
GREEN = \033[0;32m
RED = \033[0;31m
MAGENTA = \033[0;35m
CYAN = \033[0;36m
NC = \033[0m


build:
	@echo "${GREEN}Building the project...${NC}"
	docker-compose build

build-no-cache:
	@echo "${RED}Building the project without cache...${NC}"
	docker-compose build --no-cache

up:
	@echo "${GREEN}Starting the project...${NC}"
	docker-compose up

up-db:
	@echo "${GREEN}Starting container with database only...${NC}"
	docker-compose up -d db

down:
	@echo "${RED}Stopping the project...${NC}"
	docker stop $$(docker ps -a -q) 2>/dev/null || true
	docker rm $$(docker ps -a -q) 2>/dev/null || true

rmi:
	@echo "${RED}Removing the images...${NC}"
	docker rmi $$(docker images -q) --force 2>/dev/null || true

rmvol:
	@echo "${RED}Removing the volumes...${NC}"
	docker volume rm $$(docker volume ls -q) 2>/dev/null || true

ls:
	@echo "${MAGENTA}-> Docker images:${NC}" && docker images
	@echo "${MAGENTA}-> Docker containers:${NC}" && docker ps -a
	@echo "${MAGENTA}-> Docker volumes:${NC}" && docker volume ls

clean:
	@echo "${RED}Cleaning all...${NC}"
	make down
	make rmi
	make rmvol

```

**Available commands:**
- `make build` - to build the project.
- `make build-no-cache` - to build the project without cache.
- `make up` - to start the project (runs all services).  
- `make up-db` - to start the project with the database only.
- `make down` - to stop the project (removes all containers).  
- `make rmi` - to remove all images.  
- `make rmvol` - to remove all volumes.
- `make ls` - to list all images and containers.  
- `make clean` - to clean all (stop the project, remove all containers, images and volumes).  
