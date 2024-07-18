# SETUP POSTGRESQL DATABASE FOR DJANGO WITH DOCKER

This is a guide on how to setup PostgreSQL database for Django project using Docker.  
In this guide I use `pipenv` to manage the virtual environment for the Django project.  

Steps to install `pip`, `pipenv`:

**PREREQUISITES:**  

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


## 1. In the root directory of the project, activating virtual environment with pipenv:

```bash
pipenv shell
```

*Do `pipenv --venv` to check if the virtual environment is activated. It will show the path to the virtual environment.*  
*`deactivate` to deactivate the virtual environment.*  
*`pipenv --rm` to remove the virtual environment.*  
*`pipenv --clear` to clear the cache.*  

**NOTE:** *Created virtual environments with `pipenv` are stored in the `~/.local/share/virtualenvs` directory.*  


## 2. Installing Django and creating a new Django project:

*To install Django:*  
```bash
pipenv install django
```

*To create a new Django project:*  
```bash
django-admin startproject _my_project
```


## 3. Installing the package to manage environment variables and creating `.env` file:


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

# postgres:

DATABASE_URL=postgres://postgres:postgres@db:5432/postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
```


## 4. Installing dependencies for PostgreSQL.

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


## 5. Modifying `settings.py` file.

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


## 6. Crafting custom Docker image for Django project:

*Creating `Dockerfile` in the root directory of the project:*

```Dockerfile
FROM python:3.10-slim-buster

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


## 7. Creating `entrypoint.sh` file to run the Django project.

*In the root directory of the project, creating `entrypoint.sh` file:*

```bash
#!/bin/sh

python _my_project/manage.py migrate
python _my_project/manage.py runserver 0.0.0.0:8000
```

*The script will run the Django project. It can be modified as needed.*  


## 8. Crafting `docker-compose.yml` file to run the Django project with PostgreSQL database in a separate container.

```yml
services:
  db:
    image: postgres:13.3
    env_file: .env
    volumes:
      - postgres_data:/var/lib/postgresql/data/


  web:
    build: 
      context: .
    command: >
      sh -c "./entrypoint.sh"
    ports:
      - "8000:8000"
    env_file: .env
    volumes:
      - .:/app

volumes:
  postgres_data:
```


## 9. Running the following commands to build the Docker images and start the containers.

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


## 10. Cloud based PostgreSQL DB

**NOTE:** *This will show an example of how to setup cloud based postgresql.*
*Skip if you want to use the DB in the separate container.*  

*All that needed is to remove the `db` service from `docker-compose.yml` file and add proper credentials to the `.env` file.*  

- This is how the `docker-compose.yml` file might look like:

```yml
services:

  web:
    build: 
      context: .
    command: sh -c "./entrypoint.sh"
    ports:
      - "8000:8000"
    env_file: .env
    volumes:
      - .:/app

```

- This is how the `.env` file might look like:

**NOTE:** *In this example we use cloud based service offered by [neon](https://console.neon.tech/) which povides the database we need for this project.*  
- Why ? - *It is free for basic use, super easy to setup adatabase, relatively easy to setup connection for our Django project.*

```txt
# python:
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1

# django:
DEBUG=True
SECRET_KEY='some_secret_words'
ALLOWED_HOSTS=*

# postgres:

PGHOST='find it on your neon project dashboard'
PGDATABASE='find it on your neon project dashboard'
PGUSER='find it on your neon project dashboard'
PGPASSWORD='find it on your neon project dashboard'
PGENDPOINTID='this is your neon project ID'

DATABASE_URL=postgres://$PGUSER:$PGPASSWORD@$PGHOST:5432/$PGDATABASE?sslmode=require&options=endpoint%3D$PGENDPOINTID

```

*Here, thanks to `DATABASE_URL` all the necessary credentials will be sent to the endpoint of cloud service which provides access to postgresql databas.*  
*More info about connection and its issues [here](https://neon.tech/docs/connect/connection-errors).*

**HOW THIS WORKS:** *The database setting in `settings.py` : `'default': env.db()` thanks to `django-environ` package will use the postgresql variables from `.env` file and establish the access to the database via `DATABASE_URL`.*  


