FROM quay.io/centos/centos:stream9-development

ARG USER_ID=${USER_ID:-1001}
ARG APP_DIR=${APP_DIR:-/app}
ARG DEVEL_COLLECTION_LIBRARY=0
ARG DEVEL_COLLECTION_REPO=git+https://github.com/ansible/event-driven-ansible.git

USER 0
RUN useradd -u $USER_ID -d $APP_DIR appuser -G root
WORKDIR $APP_DIR

# Copy application files
COPY . $APP_DIR

# Set permissions so that files are owned by root group so this works
# with the random UID that gets assigned when running in Openshift.
RUN chown -R $USER_ID:root $APP_DIR \
    && chmod -R 0775 $APP_DIR \
    && find $APP_DIR -type d -exec chmod g+s {} \; \
    && chmod -x $APP_DIR/tests/e2e/files/passwords/*.*

RUN dnf install -y java-17-openjdk-devel python3-pip postgresql-devel gcc python3-devel

RUN bash -c "if [ $DEVEL_COLLECTION_LIBRARY -ne 0 ]; then \
    dnf install -y git; fi"

USER $USER_ID
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH="${PATH}:$APP_DIR/.local/bin"
RUN pip install -U pip \
    && pip install ansible-core \
    ansible-runner \
    jmespath \
    asyncio \
    aiohttp \
    aiokafka \
    watchdog \
    azure-servicebus \
    aiobotocore \
    && ansible-galaxy collection install ansible.eda

RUN bash -c "if [ $DEVEL_COLLECTION_LIBRARY -ne 0 ]; then \
    ansible-galaxy collection install ${DEVEL_COLLECTION_REPO} --force; fi"

# Set permissions again after python dependencies are installed
RUN chmod -R 0775 $APP_DIR \
    && chown -R $USER_ID:root $APP_DIR

RUN pip install .[production]

