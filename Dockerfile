##############################################################################################
ARG PYTHON_VERSION=3.10-slim-bullseye

##############################################################################################
# Stage Build
##############################################################################################
FROM python:${PYTHON_VERSION} AS build-image

LABEL company="ChainML"
LABEL stage="intermediate"

RUN apt-get update && \
    apt-get -y install git ssh curl build-essential && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y

# Set PATH to point to rust tools
ENV PATH="$PATH:/root/.cargo/bin"

# Setup ssh. This is needed to pull the private `theoriq-sdk` python package
RUN mkdir -p -m 0600 /root/.ssh && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts

# Install python dependencies inside a virtual enviroment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .

RUN --mount=type=ssh \
    pip install --upgrade pip && \
    pip install -r requirements.txt


##############################################################################################
# Stage Runtime
##############################################################################################
FROM python:${PYTHON_VERSION} AS runtime-image

LABEL company="ChainML"
LABEL stage="final"

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy environment built in the previous stage
COPY --from=build-image /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY data /data
COPY src /src

# Set proper permissions
RUN chown -R appuser:appuser /data /src

WORKDIR /src
EXPOSE 8080

# Switch to non-root user
USER appuser

ENTRYPOINT ["python3"]
CMD ["app.py"]