FROM python:3.6

EXPOSE 8888

RUN mkdir /app
COPY setup.py /app
RUN pip install -e /app && pip install jupyter

COPY greenguard /app/greenguard
COPY notebooks /app/notebooks

RUN adduser jupyter --uid 1000 --disabled-password --system

WORKDIR /app
USER jupyter
CMD /usr/local/bin/jupyter notebook --ip 0.0.0.0 --NotebookApp.token=''
