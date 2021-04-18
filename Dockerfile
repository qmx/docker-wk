ARG SSH_HOST_KEYS_HASH=sha256:9a6630c2fbed11a3f806c5a5c1fe1550b628311d8701680fd740cae94b377e6c
FROM qmxme/openssh@$SSH_HOST_KEYS_HASH as ssh_host_keys

# base distro
FROM debian:sid

# setup env
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

# default package set
RUN apt-get update -qq && apt-get upgrade -y && apt-get install -y \
	ca-certificates \
	curl \
	git \
	locales \
	openssh-server \
	sudo \
	xz-utils \
	zsh \
	--no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
	locale-gen --purge $LANG && \
	dpkg-reconfigure --frontend=noninteractive locales && \
	update-locale LANG=$LANG LC_ALL=$LC_ALL LANGUAGE=$LANGUAGE
RUN update-ca-certificates -f

# sshd setup
RUN mkdir /var/run/sshd
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN sed 's/#Port 22/Port 3222/' -i /etc/ssh/sshd_config
RUN echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config
COPY --from=ssh_host_keys /etc/ssh/ssh_host* /etc/ssh/

# user setup
ARG user=qmx
ARG uid=1000
ARG github_user=qmx
RUN useradd -m $user -u $uid -G users,sudo -s /bin/zsh
RUN mkdir -m 0755 /nix && chown $user /nix
USER $user
ENV USER=$user
RUN mkdir ~/.ssh && curl -fsL https://github.com/$github_user.keys > ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

# dotfile setup
RUN git clone https://github.com/qmx/dotfiles.git ~/.dotfiles # foo
RUN cd ~/.dotfiles && ./bootstrap.sh
RUN cd ~/.dotfiles && PATH=/home/$user/.nix-profile/bin:$PATH; ./switch.sh

# make sure we start sshd at the end - always keep this at the bottom
USER root
EXPOSE 3222
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
