# base image
FROM python:3.9.4-slim

# set working directory
WORKDIR /usr/src/app

# add and install requirements
COPY silver* /usr/src/app/wheels/
RUN pip3 install --upgrade pip
RUN pip3 install --find-links /usr/src/app/wheels/ silver-spork

ENV FLASK_APP=silver_spork
# run server
CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0"]
EXPOSE 5000

