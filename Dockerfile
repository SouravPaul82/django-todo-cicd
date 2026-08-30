FROM python:3.10-slim
RUN pip install --no-cache-dir django==3.2
COPY . .
EXPOSE 8001
CMD ["python","manage.py","runserver","0.0.0.0:8001"]


