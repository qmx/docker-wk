ARG DEBIAN_BUSTER_HASH=sha256:9646b0ee6d68448e09cdee7ac8deb336e519113e5717ec0856d38ca813912930
ARG DEBIAN_SID_HASH=sha256:fc6ae865d58728644a7242375b777a03c8933600c0aff9df491e745b15ba9d3e
ARG SSH_HOST_KEYS_HASH=sha256:9a6630c2fbed11a3f806c5a5c1fe1550b628311d8701680fd740cae94b377e6c

## golang tools
FROM qmxme/golang-tools:0.0.1 as golang_builder

# define default base debian image
FROM debian:sid@$DEBIAN_SID_HASH as debian_base

# rust-analyzer
FROM qmxme/rust-analyzer:392e745 as ra_builder

# rust tools
FROM qmxme/rust-tools:0.0.2 as rust_builder

# rust web tools
FROM qmxme/rust-web-tools:0.0.1 as rust_web_builder

# install terraform
FROM qmxme/curl as terraform_builder
RUN curl -L -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.16/terraform_0.12.16_linux_amd64.zip
RUN cd /usr/local/bin && unzip /tmp/terraform.zip && chmod 755 /usr/local/bin/terraform

# install kubectl
FROM qmxme/curl as kubectl_builder
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod 755 /usr/local/bin/kubectl

# install helm
FROM qmxme/curl as helm_builder
RUN curl -L -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.0.0-linux-amd64.tar.gz
WORKDIR /tmp
RUN tar -zxvf helm.tar.gz
RUN cp linux-amd64/helm /usr/local/bin

# install docker-compose
FROM qmxme/curl as compose_builder
RUN curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
RUN chmod 755 /usr/local/bin/docker-compose

# install coursier
FROM qmxme/curl as coursier_builder
RUN curl -L -o /usr/local/bin/coursier https://github.com/coursier/coursier/releases/download/v1.1.0-M9/coursier
RUN chmod 755 /usr/local/bin/coursier

# SSH host keys
FROM qmxme/openssh@$SSH_HOST_KEYS_HASH as ssh_host_keys

# base distro
FROM debian_base

# setup env
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

# default package set
RUN apt-get update -qq && apt-get upgrade -y && apt-get install -qq -y \
	apache2-utils \
	apt-transport-https \
	awscli \
	bat \
	build-essential \
	ca-certificates \
	cargo \
	clang \
	cmake \
	curl \
	debcargo \
	default-libmysqlclient-dev \
	default-mysql-client \
	direnv \
	dnsutils \
	docker.io \
	entr \
	exuberant-ctags \
	fakeroot-ng \
	fd-find \
	flake8 \
	fzf \
	gdb \
	git \
	git-crypt \
	gnupg \
	golang-1.13 \
	htop \
	hub \
	hugo \
	ipcalc \
	jq \
	kafkacat \
	less \
	libclang-dev \
	liblzma-dev \
	libpq-dev \
	libprotoc-dev \
	librdkafka-dev \
	libsqlite3-dev \
	libssl-dev \
	lldb \
	locales \
	man \
	mosh \
	mtr-tiny \
	musl-tools \
	ncdu \
	neovim \
	netcat-openbsd \
	nodejs \
	npm \
	openjdk-11-jdk-headless \
	openssh-server \
	pkg-config \
	protobuf-compiler \
	pwgen \
	python \
	python3 \
	python3-flake8 \
	python3-pip \
	python3-setuptools \
	python3-venv \
	python3-wheel \
	qrencode \
	quilt \
	redis-server \
	restic \
	ripgrep \
	rsync \
	rustc \
	rust-src \
	shellcheck \
	socat \
	sqlite3 \
	stow \
	strace \
	sudo \
	tmate \
	tmux \
	unzip \
	vim-nox \
	wabt \
	zgen \
	zip \
	zlib1g-dev \
	zsh \
	--no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
	locale-gen --purge $LANG && \
	dpkg-reconfigure --frontend=noninteractive locales && \
	update-locale LANG=$LANG LC_ALL=$LC_ALL LANGUAGE=$LANGUAGE

# enable yarn repo
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq && apt-get install -qq -y \
	yarn \
	--no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

# sshd setup
RUN mkdir /var/run/sshd
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN sed 's/#Port 22/Port 3222/' -i /etc/ssh/sshd_config
RUN echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config
COPY --from=ssh_host_keys /etc/ssh/ssh_host* /etc/ssh/

# rust tools
RUN curl -L -o /tmp/cpubars_0.2.1_amd64.deb https://github.com/qmx/cpubars/releases/download/0.2.1/cpubars_0.2.1_amd64.deb && dpkg -i /tmp/cpubars_0.2.1_amd64.deb && rm /tmp/*.deb
RUN curl -L -o /tmp/marinara_0.2.0_amd64.deb https://github.com/qmx/marinara/releases/download/0.2.0/marinara_0.2.0_amd64.deb && dpkg -i /tmp/marinara_0.2.0_amd64.deb && rm /tmp/*.deb
RUN curl -L -o /tmp/jump_0.22.0_amd64.deb https://github.com/gsamokovarov/jump/releases/download/v0.22.0/jump_0.22.0_amd64.deb && dpkg -i /tmp/jump_0.22.0_amd64.deb && rm /tmp/*.deb
RUN curl -L -o /tmp/wk_0.4.0_amd64.deb https://github.com/qmx/wk/releases/download/0.4.0/wk_0.4.0_amd64.deb && dpkg -i /tmp/wk_0.4.0_amd64.deb && rm /tmp/*.deb
RUN curl -L -o /tmp/cargo-docserver_0.1.2_amd64.deb https://github.com/qmx/cargo-docserver/releases/download/0.1.2/cargo-docserver_0.1.2_amd64.deb && dpkg -i /tmp/cargo-docserver_0.1.2_amd64.deb && rm /tmp/*.deb

# install dive
RUN curl -L -o /tmp/dive.deb https://github.com/wagoodman/dive/releases/download/v0.9.1/dive_0.9.1_linux_amd64.deb && dpkg -i /tmp/dive.deb && rm /tmp/*.deb

# rust essential crates
COPY --from=rust_builder /opt/rust-tools/bin/* /usr/local/bin/
COPY --from=rust_web_builder /opt/rust-tools/bin/* /usr/local/bin/
COPY --from=ra_builder /opt/rust-tools/bin/* /usr/local/bin/

# golang tools
COPY --from=golang_builder /go/bin/* /usr/local/bin/

# terraform
COPY --from=terraform_builder /usr/local/bin/terraform /usr/local/bin/

# kubectl
COPY --from=kubectl_builder /usr/local/bin/kubectl /usr/local/bin/

# helm
COPY --from=helm_builder /usr/local/bin/helm /usr/local/bin/

# docker-compose
COPY --from=compose_builder /usr/local/bin/docker-compose /usr/local/bin/

# coursier
COPY --from=coursier_builder /usr/local/bin/coursier /usr/local/bin/

# user setup
ARG user=qmx
ARG uid=1000
ARG github_user=qmx
RUN useradd -m $user -u $uid -G users,sudo,docker -s /bin/zsh
USER $user
RUN mkdir ~/.ssh && curl -fsL https://github.com/$github_user.keys > ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

# some empty folders, with proper permissions
RUN mkdir -p ~/bin ~/.cargo/bin ~/.config ~/tmp ~/.gnupg ~/.local ~/.vim && chmod 700 ~/.gnupg

# install metals-vim
RUN coursier bootstrap  --java-opt -Xss4m --java-opt -Xms100m --java-opt -Dmetals.client=coc.nvim org.scalameta:metals_2.12:0.7.0 -r bintray:scalacenter/releases -o ~/bin/metals-vim -f

# dotfile setup
RUN git clone --recursive https://github.com/qmx/dotfiles.git ~/.dotfiles
RUN cd ~/.dotfiles && stow -v .

# install rust
RUN curl -sSf https://sh.rustup.rs | zsh -s -- -y --default-toolchain 1.39.0
RUN . /home/$user/.cargo/env && rustup toolchain link system /usr && rustup component add rustfmt rust-src rls
RUN vim -c 'CocInstall -sync coc-rls coc-git coc-json coc-html|q'

# make sure we start sshd at the end - always keep this at the bottom
USER root
EXPOSE 3222
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
