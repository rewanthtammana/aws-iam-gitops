FROM public.ecr.aws/lambda/python:3.11

# Copy requirements.txt
COPY requirements.txt ${LAMBDA_TASK_ROOT}

ARG GITHUB_USERNAME
ARG GITHUB_REPO
ARG GITHUB_TOKEN

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}
RUN sed -i "s/GITHUB_USERNAME/$GITHUB_USERNAME/g" ${LAMBDA_TASK_ROOT}/lambda_function.py
RUN sed -i "s/GITHUB_REPO/$GITHUB_REPO/g" ${LAMBDA_TASK_ROOT}/lambda_function.py
RUN sed -i "s/GITHUB_TOKEN/$GITHUB_TOKEN/g" ${LAMBDA_TASK_ROOT}/lambda_function.py

# Install the specified packages
RUN pip install -r requirements.txt

RUN yum update && yum -y install git

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]
